from channels.generic.websocket import AsyncWebsocketConsumer
from .lua_scripts import lua_script_loader as lscr
import redis.asyncio as redis
from datetime import datetime
import asyncio
import logging
import json
import uuid

logger = logging.getLogger(__name__)

# Redis connection pool to be used for all users (module level)
REDIS_POOL = redis.ConnectionPool(
    host="redis", port=6379, db=1, decode_responses=True, max_connections=50
)

"""
Demo requests:

1. To submit interests
{
    "type": "submit_interests",
    "description": "Request to submit interests",
    "timestamp": "2025-10-01T12:00:00",
    "data": { "interests": ["general"] }
}

2. To start matching
{
    "type": "start_matching",
    "description": "Request to start matching",
    "timestamp": "2025-10-01T12:00:00"
}

3. To stop matching
{
    "type": "end_matching",
    "description": "Request to end matching",
    "timestamp": "2025-10-01T12:00:00"
}

4. To chat
{
    "type": "chat_message",
    "description": "Request to send chat message",
    "timestamp": "2025-10-01T12:00:00",
    "data": { "message": "Hello partner!" }
}

5. To end chat
{
    "type": "end_chat",
    "description": "Request to end chat",
    "timestamp": "2025-10-01T12:00:00"
}

"""


class ChatConsumer(AsyncWebsocketConsumer):
    # Class-level SHAs: Load once, use for all instances
    _SCRIPT_SHAS = {}
    _LOAD_LOCK = (
        asyncio.Lock()
    )  # Prevent multiple concurrent lua script loads (Thundering herd)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.redis_client = None
        self.user_id = None
        self.room_name = None

    async def _load_scripts_globally(self):
        async with ChatConsumer._LOAD_LOCK:
            if not ChatConsumer._SCRIPT_SHAS:  # second check
                # Helper to load scripts into Redis and store SHAs for all consumers to share.
                scripts = [
                    "find_match",
                    "set_profile",
                    "stop_matching",
                    "end_chat",
                    "clean_up",
                ]
                for s in scripts:
                    content = lscr.LuaScriptLoader.load(s)
                    ChatConsumer._SCRIPT_SHAS[s] = await self.redis_client.script_load(
                        content
                    )
                logger.info("Lua scripts loaded into Redis successfully.")

    async def _safe_evalsha(self, script_name, numkeys, *args):
        # Helper to handle the NoScriptError globally so we don't repeat try/except blocks
        try:
            return await self.redis_client.evalsha(
                self._SCRIPT_SHAS[script_name], numkeys, *args
            )
        except redis.exceptions.NoScriptError:
            # If Redis was flushed, reload everything
            await self._load_scripts_globally()
            return await self.redis_client.evalsha(
                self._SCRIPT_SHAS[script_name], numkeys, *args
            )

    async def connect(self):
        self.user_id = str(uuid.uuid4())
        self.redis_client = redis.Redis(connection_pool=REDIS_POOL)

        if not ChatConsumer._SCRIPT_SHAS:
            await self._load_scripts_globally()

        await self.accept()
        await self.send_response(
            "connection_established",
            "Connected",
        )

    async def disconnect(self, close_code):
        if not self.redis_client:
            return

        try:
            partner_id = await self._safe_evalsha("clean_up", 0, self.user_id)

            if partner_id:
                partner_channel = await self.redis_client.hget(
                    f"user_meta:{partner_id}", "channel"
                )

                # Notify partner
                await self.inter_consumer_communication(
                    partner_channel,
                    {"type": "handle_partner_ended_chat"},
                )

            # Leave room group if in a room
            if self.room_name:
                await self.channel_layer.group_discard(
                    self.room_name, self.channel_name
                )

        except Exception as e:
            logger.exception(f"Error during cleanup: {e}")
        finally:
            await self.redis_client.aclose()

    # Receive message from WebSocket and handle it based on its type
    async def receive(self, text_data):
        try:
            text_data_json = json.loads(text_data)
            message_type = text_data_json.get("type")

            if message_type == "submit_interests":
                await self.set_profile(text_data_json["data"].get("interests", []))
            elif message_type == "start_matching":
                await self.find_match()
            elif message_type == "end_matching":
                await self.stop_matching()
            elif message_type == "chat_message":
                await self.handle_chat_message(
                    text_data_json["data"].get("message", "")
                )
            elif message_type == "end_chat":
                await self.end_chat()
            elif message_type == "webrtc_signal":
                await self.webrtc_signal(text_data_json.get("data", {}))
            else:
                await self.send_response(
                    "error", f"Invalid message type: {message_type}"
                )
        except json.JSONDecodeError:
            await self.send_response("error", "Invalid JSON format")
        except Exception as e:
            logger.error(f"Error processing message: {e}")
            await self.send_response("error", "An unexpected error occurred.")

    async def set_profile(self, interests):
        if not self.redis_client:
            await self.send_response("error", "Redis unavailable")
            return

        try:
            await self._safe_evalsha(
                "set_profile",
                0,  # number of keys (we use ARGV only)
                self.user_id,
                self.channel_name,
                json.dumps(interests),
            )
            await self.send_response(
                "success", "Interests received, you can start matching."
            )
        except Exception as e:
            logger.exception(f"Error during matching: {e}")
            await self.send_response("error", "Matching failed, please try again")

    async def find_match(self):
        if not self.redis_client:
            await self.send_response("error", "Redis unavailable")
            return None

        # Call Lua script atomically
        try:
            user_interests = await self.redis_client.hget(
                f"user_meta:{self.user_id}", "interests"
            )

            if not user_interests:
                await self.send_response(
                    "error", "No interests found. Please set profile first."
                )
                return

            keys = [f"interest:{topic}" for topic in user_interests.split(",")]

            result = await self._safe_evalsha(
                "find_match",
                len(keys),
                *keys,
                self.user_id,
                self.channel_name,
            )

            if result:
                partner_user_id = result

                if not partner_user_id:
                    await self.send_response(
                        "no_match", "No match found, still searching"
                    )
                    return

                partner_channel = await self.redis_client.hget(
                    f"user_meta:{partner_user_id}", "channel"
                )
                # Create room and notify both users
                self.room_name = f"room_{uuid.uuid4().hex[:8]}"

                # Add both users to the same room group
                await self.channel_layer.group_add(self.room_name, self.channel_name)
                await self.channel_layer.group_add(self.room_name, partner_channel)

                # Notify self
                await self.handle_match_found(
                    {
                        "partner_user_id": partner_user_id,
                        "partner_channel": partner_channel,
                    }
                )

                # Notify partner
                await self.inter_consumer_communication(
                    partner_channel,
                    {
                        "type": "handle_match_found",
                        "partner_user_id": self.user_id,
                        "partner_channel": self.channel_name,
                    },
                )

                # Share room name with both
                await self.handle_room_assignment(
                    {
                        "room_name": self.room_name,
                        "role": "caller",  # for webRTC communication
                    }
                )

                await self.inter_consumer_communication(
                    partner_channel,
                    {
                        "type": "handle_room_assignment",
                        "room_name": self.room_name,
                        "role": "callee",  # for webRTC communication
                    },
                )
            else:
                await self.send_response("no_match", "No match found, still searching")

        except Exception as e:
            logger.exception(f"Error during matching: {e}")
            await self.send_response("error", "Matching failed, please try again")

    async def stop_matching(self):
        if not self.redis_client:
            await self.send_response("error", "Redis unavailable")
            return

        try:
            user_interests = await self.redis_client.hget(
                f"user_meta:{self.user_id}", "interests"
            )
            keys = [f"interest:{topic}" for topic in user_interests.split(",")]

            if not user_interests:
                await self.send_response(
                    "success", "You weren't in any matching queues."
                )
                return

            await self._safe_evalsha("stop_matching", len(keys), *keys, self.user_id)

            await self.send_response("success", "You have stopped looking for a match.")

        except Exception as e:
            logger.exception(f"Error during matching: {e}")
            await self.send_response("error", "Operation failed, please try again")

    async def handle_chat_message(self, message):
        if not self.room_name:
            await self.send_response("error", "You are not in a chat room")
            return

        await self.channel_layer.group_send(
            self.room_name,
            {"type": "chat_message", "message": message, "sender_id": self.user_id},
        )

    async def end_chat(self):
        if not self.redis_client:
            await self.send_response("error", "Redis unavailable")
            return

        try:
            partner_id = await self._safe_evalsha("end_chat", 0, self.user_id)

            if partner_id:
                partner_channel = await self.redis_client.hget(
                    f"user_meta:{partner_id}", "channel"
                )

                # Notify partner
                await self.inter_consumer_communication(
                    partner_channel,
                    {"type": "handle_partner_ended_chat"},
                )

            self.room_name = None

            await self.send_response(
                "success",
                "You have ended the chat",
            )

        except Exception as e:
            logger.exception(f"Error during ending chat: {e}")
            await self.send_response("error", "Operation failed, please try again")

    async def handle_partner_ended_chat(self, event):
        self.room_name = None

        # Notify the partner's frontend that the chat is over
        await self.send_response(
            "partner_left_chat",
            "Your partner has ended the chat",
        )

    async def inter_consumer_communication(self, partner_channel, message):
        if partner_channel:
            await self.channel_layer.send(partner_channel, message)

    async def handle_room_assignment(self, event):
        self.room_name = event["room_name"]
        role = event.get("role")
        await self.send_response(
            "success_matched", "You have saved current room name", {"role": role}
        )

    async def handle_match_found(self, event):
        role = event.get("role")
        await self.send_response(
            "success",
            "Match found and partner details saved",
        )

    async def webrtc_signal(self, signal_data):
        if not self.room_name:
            await self.send_response("error", "You are not in a chat room")
            return

        await self.channel_layer.group_send(
            self.room_name,
            {"type": "signal_relay", "sender_id": self.user_id, "payload": signal_data},
        )

    # Receive a webRTC signal relay message from room group -> Send to Individual user members (other than sender)
    async def signal_relay(self, event):
        # Do not send the signal back to the person who originated it
        if event["sender_id"] == self.user_id:
            return

        # Send the WebRTC data to the Flutter app
        await self.send_response(
            "webrtc_signal", "Incoming WebRTC signaling data", event["payload"]
        )

    # Receive a chat message from room group -> Send to Individual user members (other than sender)
    async def chat_message(self, event):
        message = event["message"]
        sender_id = event["sender_id"]

        # Skip if this is our own message
        if sender_id == self.user_id:
            return

        # Send message to WebSocket
        await self.send_response(
            "chat_message",
            "Message sent successfully",
            {"message": message},
        )

    async def send_response(self, response_type, description, data=None):
        # Utility method to send structured responses
        response = {
            "type": response_type,
            "description": description,
            "timestamp": datetime.now().isoformat(),
        }
        if data is not None: 
            response["data"] = data

        await self.send(text_data=json.dumps(response))
