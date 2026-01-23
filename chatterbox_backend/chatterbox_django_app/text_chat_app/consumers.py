from asyncio.log import logger
from datetime import datetime
import json
import uuid

from .lua_scripts import lua_script_loader as lscr
from channels.generic.websocket import AsyncWebsocketConsumer
import redis.asyncio as redis

# Redis connection pool to be used for all users (module level)
REDIS_POOL = redis.ConnectionPool(
    host="redis", port=6379, db=1, decode_responses=True, max_connections=15
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
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.redis_client = None
        self.match_script_sha = None
        self.set_profile_script_sha = None
        self.stop_matching_script_sha = None
        self.end_chat_script_sha = None
        self.clean_up_script_sha = None

        self.user_id = None
        self.room_name = None
        
    async def _ensure_redis(self):
        if self.redis_client:
            return

        try:
            self.redis_client = redis.Redis(connection_pool=REDIS_POOL)
            await self.redis_client.ping()

            # Load and register the Lua scripts
            atomic_match_script = lscr.LuaScriptLoader.load('find_match')
            set_profile_script = lscr.LuaScriptLoader.load('set_profile')
            stop_matching_script = lscr.LuaScriptLoader.load('stop_matching')
            end_chat_script = lscr.LuaScriptLoader.load('end_chat')
            clean_up_script = lscr.LuaScriptLoader.load('clean_up')

            self.match_script_sha = await self.redis_client.script_load(atomic_match_script)
            self.set_profile_script_sha = await self.redis_client.script_load(set_profile_script)
            self.stop_matching_script_sha = await self.redis_client.script_load(stop_matching_script)
            self.end_chat_script_sha = await self.redis_client.script_load(end_chat_script)
            self.clean_up_script_sha = await self.redis_client.script_load(clean_up_script)

        except redis.ConnectionError as e:
            logger.error(f"Redis connection failed: {e}")
            self.redis_client = None

    async def connect(self):
        self.user_id = str(uuid.uuid4())
        await self.accept()

        # connection confirmation
        await self.send_response(
            "connection_established",
            "Connection established successfully",
        )

    async def disconnect(self, close_code):
        await self._ensure_redis()
        if not self.redis_client:
            return
        
        try:
            partner_id = await self.redis_client.evalsha(
                self.clean_up_script_sha,
                0,
                self.user_id
            )
            
            if partner_id:
                partner_channel = await self.redis_client.hget(f"user_meta:{partner_id}", "channel")

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

        except redis.exceptions.NoScriptError:
            # Script was flushed, reload it
            clean_up_script = lscr.LuaScriptLoader.load('clean_up')
            self.clean_up_script_sha = await self.redis_client.script_load(clean_up_script)
        except Exception as e:
            logger.exception(f"Error during cleanup: {e}")

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
                await self.handle_chat_message(text_data_json["data"].get("message", ""))
            elif message_type == "end_chat":
                await self.end_chat()
            else:
                await self.send_response("error", f"Invalid message type: {message_type}")
        except json.JSONDecodeError:
            await self.send_response("error", "Invalid JSON format")
        except Exception as e:
            logger.error(f"Error processing message: {e}")
            await self.send_response("error", "An unexpected error occurred.")

    async def set_profile(self, interests):
        await self._ensure_redis()
        if not self.redis_client:
            await self.send_response("error", "Redis unavailable")
            return
        
        try:
            await self.redis_client.evalsha(
                self.set_profile_script_sha,
                0,  # number of keys (we use ARGV only)
                self.user_id,
                self.channel_name,
                json.dumps(interests)
            )
            await self.send_response("success", "Interests received, you can start matching.")
            
        except redis.exceptions.NoScriptError:
            # Script was flushed, reload it
            set_profile_script = lscr.LuaScriptLoader.load('set_profile')
            self.set_profile_script_sha = await self.redis_client.script_load(set_profile_script)
            await self.send_response("error", "Please try matching again")
        except Exception as e:
            logger.exception(f"Error during matching: {e}")
            await self.send_response("error", "Matching failed, please try again")
            
    async def find_match(self):
        await self._ensure_redis()
        
        if not self.redis_client:
            await self.send_response("error", "Redis unavailable")
            return None
        
        # Call Lua script atomically
        try:
            user_interests = await self.redis_client.hget(f"user_meta:{self.user_id}", "interests")
            keys = [f"interest:{topic}" for topic in user_interests.split(',')]
            
            result = await self.redis_client.evalsha(
                self.match_script_sha,
                len(keys),
                *keys,
                self.user_id,
                self.channel_name
            )

            if result:
                partner_user_id = result
                
                if not partner_user_id:
                    await self.send_response("no_match", "No match found, still searching")
                    return
                
                partner_channel = await self.redis_client.hget(f"user_meta:{partner_user_id}", "channel")
                # Create room and notify both users
                self.room_name = f"room_{uuid.uuid4().hex[:8]}"

                # Add both users to the same room group
                await self.channel_layer.group_add(self.room_name, self.channel_name)
                await self.channel_layer.group_add(self.room_name, partner_channel)

                # Notify self
                await self.handle_match_found({
                    "partner_user_id": partner_user_id,
                    "partner_channel": partner_channel,
                })

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
                await self.handle_room_assignment({"room_name": self.room_name})
                await self.inter_consumer_communication(
                    partner_channel,
                    {"type": "handle_room_assignment", "room_name": self.room_name},
                )
            else:
                await self.send_response("no_match", "No match found, still searching")

        except redis.exceptions.NoScriptError:
            # Script was flushed, reload it
            atomic_match_script = lscr.LuaScriptLoader.load('find_match')
            self.match_script_sha = await self.redis_client.script_load(atomic_match_script)
            await self.send_response("error", "Please try matching again")
        except Exception as e:
            logger.exception(f"Error during matching: {e}")
            await self.send_response("error", "Matching failed, please try again")
            
    async def stop_matching(self):
        await self._ensure_redis()
        
        if not self.redis_client:
            await self.send_response("error", "Redis unavailable")
            return
        
        try:
            user_interests = await self.redis_client.hget(f"user_meta:{self.user_id}", "interests")
            keys = [f"interest:{topic}" for topic in user_interests.split(',')]
            
            await self.redis_client.evalsha(
                self.stop_matching_script_sha,
                len(keys),
                *keys,
                self.user_id
            )
            
            await self.send_response("success", "You have stopped looking for a match.")
        except redis.exceptions.NoScriptError:
            # Script was flushed, reload it
            stop_matching_script = lscr.LuaScriptLoader.load('stop_matching')
            self.stop_matching_script_sha = await self.redis_client.script_load(stop_matching_script)
            await self.send_response("error", "Please try matching again")
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
        await self._ensure_redis()
        if not self.redis_client:
            await self.send_response("error", "Redis unavailable")
            return
        
        try:
            partner_id = await self.redis_client.evalsha(
                self.end_chat_script_sha,
                0,
                self.user_id
            )
            
            if partner_id:
                partner_channel = await self.redis_client.hget(f"user_meta:{partner_id}", "channel")

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
        except redis.exceptions.NoScriptError:
            # Script was flushed, reload it
            end_chat_script = lscr.LuaScriptLoader.load('end_chat')
            self.end_chat_script_sha = await self.redis_client.script_load(end_chat_script)
            await self.send_response("error", "Please try ending the chat again")
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
        await self.send_response(
            "success_matched",
            "You have saved current room name",
        )

    async def handle_match_found(self, event):
        await self.send_response(
            "success",
            "Match found and partner details saved",
        )

    # Receive message from room group -> Send to Individual users
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
        if data:
            response["data"] = data

        await self.send(text_data=json.dumps(response))
