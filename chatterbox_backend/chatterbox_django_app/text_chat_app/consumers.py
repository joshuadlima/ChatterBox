from asyncio.log import logger
from datetime import datetime
import json
import random
import uuid

from .lua_scripts import lua_script_loader as lscr
from asgiref.sync import async_to_sync
from channels.generic.websocket import WebsocketConsumer
import redis

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

class ChatConsumer(WebsocketConsumer):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # using connection pool instead of creating a new connection for each user
        try:
            self.redis_client = redis.Redis(connection_pool=REDIS_POOL)
            # Test the connection
            self.redis_client.ping()
            
            # Load and register the Lua scripts
            atomic_match_script = lscr.LuaScriptLoader.load('find_match')
            set_profile_script = lscr.LuaScriptLoader.load('set_profile')
            stop_matching_script = lscr.LuaScriptLoader.load('stop_matching')
            end_chat_script = lscr.LuaScriptLoader.load('end_chat')
            clean_up_script = lscr.LuaScriptLoader.load('clean_up')
            
            self.match_script_sha = self.redis_client.script_load(atomic_match_script)
            self.set_profile_script_sha = self.redis_client.script_load(set_profile_script)
            self.stop_matching_script_sha = self.redis_client.script_load(stop_matching_script)
            self.end_chat_script_sha = self.redis_client.script_load(end_chat_script)
            self.clean_up_script_sha = self.redis_client.script_load(clean_up_script)
            
        except redis.ConnectionError as e:
            logger.error(f"Redis connection failed: {e}")
            self.redis_client = None
        
        self.user_id = None
        self.room_name = None

    def connect(self):
        self.user_id = str(uuid.uuid4())
        self.accept()

        # connection confirmation
        self.send_response(
            "connection_established",
            "Connection established successfully",
        )

    def disconnect(self, close_code):
        try:
            partner_id = self.redis_client.evalsha(
                self.clean_up_script_sha,
                0,
                self.user_id
            )
            
            if partner_id:
                partner_channel = self.redis_client.hget(f"user_meta:{partner_id}", "channel")

                # Notify partner
                self.inter_consumer_communication(
                    partner_channel,
                    {"type": "handle_partner_ended_chat"},
                )

            # Leave room group if in a room
            if self.room_name:
                async_to_sync(self.channel_layer.group_discard)(
                    self.room_name, self.channel_name
                )
            
        except redis.exceptions.NoScriptError:
            # Script was flushed, reload it
            clean_up_script = lscr.LuaScriptLoader.load('clean_up')
            self.clean_up_script_sha = self.redis_client.script_load(clean_up_script)
        except Exception as e:
            logger.exception(f"Error during cleanup: {e}")

    # Receive message from WebSocket and handle it based on its type
    def receive(self, text_data):
        try:
            text_data_json = json.loads(text_data)
            message_type = text_data_json.get("type")
            
            if message_type == "submit_interests":
                self.set_profile(text_data_json["data"].get("interests", []))
            elif message_type == "start_matching":
                self.find_match()
            elif message_type == "end_matching":
                self.stop_matching()
            elif message_type == "chat_message":
                self.handle_chat_message(text_data_json["data"].get("message", ""))
            elif message_type == "end_chat":
                self.end_chat()
            else:
                self.send_response("error", f"Invalid message type: {message_type}")
        except json.JSONDecodeError:
            self.send_response("error", "Invalid JSON format")
        except Exception as e:
            logger.error(f"Error processing message: {e}")
            self.send_response("error", "An unexpected error occurred.")

    def set_profile(self, interests):
        if not self.redis_client:
            self.send_response("error", "Redis unavailable")
            return
        
        try:
            self.redis_client.evalsha(
                self.set_profile_script_sha,
                0,  # number of keys (we use ARGV only)
                self.user_id,
                self.channel_name,
                json.dumps(interests)
            )
            self.send_response("success", "Interests received, you can start matching.")
            
        except redis.exceptions.NoScriptError:
            # Script was flushed, reload it
            set_profile_script = lscr.LuaScriptLoader.load('set_profile')
            self.set_profile_script_sha = self.redis_client.script_load(set_profile_script)
            self.send_response("error", "Please try matching again")
        except Exception as e:
            logger.exception(f"Error during matching: {e}")
            self.send_response("error", "Matching failed, please try again")

    def find_match(self):
        if not self.redis_client:
            self.send_response("error", "Redis unavailable")
            return None
        
        # Call Lua script atomically
        try:
            user_interests = self.redis_client.hget(f"user_meta:{self.user_id}", "interests")
            keys = [f"interest:{topic}" for topic in user_interests.split(',')]
            
            result = self.redis_client.evalsha(
                self.match_script_sha,
                len(keys),
                *keys,
                self.user_id,
                self.channel_name
            )

            if result:
                partner_user_id = result
                
                if not partner_user_id:
                    self.send_response("no_match", "No match found, still searching")
                    return
                
                partner_channel = self.redis_client.hget(f"user_meta:{partner_user_id}", "channel")

                # Create room and notify both users
                self.room_name = f"room_{uuid.uuid4().hex[:8]}"

                # Add both users to the same room group
                async_to_sync(self.channel_layer.group_add)(self.room_name, self.channel_name)
                async_to_sync(self.channel_layer.group_add)(self.room_name, partner_channel)

                # Notify self
                self.handle_match_found({
                    "partner_user_id": partner_user_id,
                    "partner_channel": partner_channel,
                })

                # Notify partner
                self.inter_consumer_communication(
                    partner_channel,
                    {
                        "type": "handle_match_found",
                        "partner_user_id": self.user_id,
                        "partner_channel": self.channel_name,
                    },
                )

                # Share room name with both
                self.handle_room_assignment({"room_name": self.room_name})
                self.inter_consumer_communication(
                    partner_channel,
                    {"type": "handle_room_assignment", "room_name": self.room_name},
                )
            else:
                self.send_response("no_match", "No match found, still searching")

        except redis.exceptions.NoScriptError:
            # Script was flushed, reload it
            atomic_match_script = lscr.LuaScriptLoader.load('find_match')
            self.match_script_sha = self.redis_client.script_load(atomic_match_script)
            self.send_response("error", "Please try matching again")
        except Exception as e:
            logger.exception(f"Error during matching: {e}")
            self.send_response("error", "Matching failed, please try again")

    def stop_matching(self):
        if not self.redis_client:
            self.send_response("error", "Redis unavailable")
            return
        
        try:
            user_interests = self.redis_client.hget(f"user_meta:{self.user_id}", "interests")
            keys = [f"interest:{topic}" for topic in user_interests.split(',')]
            
            self.redis_client.evalsha(
                self.stop_matching_script_sha,
                len(keys),
                *keys,
                self.user_id
            )
            
            self.send_response("success", "You have stopped looking for a match.")
        except redis.exceptions.NoScriptError:
            # Script was flushed, reload it
            stop_matching_script = lscr.LuaScriptLoader.load('stop_matching')
            self.stop_matching_script_sha = self.redis_client.script_load(stop_matching_script)
            self.send_response("error", "Please try matching again")
        except Exception as e:
            logger.exception(f"Error during matching: {e}")
            self.send_response("error", "Operation failed, please try again")
            
    def handle_chat_message(self, message):
        if not self.room_name:
            self.send_response("error", "You are not in a chat room")
            return

        async_to_sync(self.channel_layer.group_send)(
            self.room_name,
            {"type": "chat_message", "message": message, "sender_id": self.user_id},
        )

    def end_chat(self):
        if not self.redis_client:
            self.send_response("error", "Redis unavailable")
            return
        
        try:
            partner_id = self.redis_client.evalsha(
                self.end_chat_script_sha,
                0,
                self.user_id
            )
            
            if partner_id:
                partner_channel = self.redis_client.hget(f"user_meta:{partner_id}", "channel")

                # Notify partner
                self.inter_consumer_communication(
                    partner_channel,
                    {"type": "handle_partner_ended_chat"},
                )

            self.room_name = None

            self.send_response(
                "success",
                "You have ended the chat",
            )
        except redis.exceptions.NoScriptError:
            # Script was flushed, reload it
            end_chat_script = lscr.LuaScriptLoader.load('end_chat')
            self.end_chat_script_sha = self.redis_client.script_load(end_chat_script)
            self.send_response("error", "Please try ending the chat again")
        except Exception as e:
            logger.exception(f"Error during ending chat: {e}")
            self.send_response("error", "Operation failed, please try again")

    def handle_partner_ended_chat(self, event):
        self.room_name = None
        
        # Notify the partner's frontend that the chat is over
        self.send_response(
            "partner_left_chat",
            "Your partner has ended the chat",
        )

    def inter_consumer_communication(self, partner_channel, message):
        if partner_channel:
            async_to_sync(self.channel_layer.send)(partner_channel, message)

    def handle_room_assignment(self, event):
        self.room_name = event["room_name"]
        self.send_response(
            "success_matched",
            "You have saved current room name",
        )

    def handle_match_found(self, event):
        self.send_response(
            "success",
            "Match found and partner details saved",
        )

    # Receive message from room group -> Send to Individual users
    def chat_message(self, event):
        message = event["message"]
        sender_id = event["sender_id"]

        # Skip if this is our own message
        if sender_id == self.user_id:
            return

        # Send message to WebSocket
        self.send_response(
            "chat_message",
            "Message sent successfully",
            {"message": message},
        )

    def send_response(self, response_type, description, data=None):
        # Utility method to send structured responses
        response = {
            "type": response_type,
            "description": description,
            "timestamp": datetime.now().isoformat(),
        }
        if data:
            response["data"] = data

        self.send(text_data=json.dumps(response))
