from asyncio.log import logger
from datetime import datetime
import json
import random
import uuid

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
    "description": "Submitting interests",
    "timestamp": "2025-10-01T12:00:00",
    "data": { "interests": ["general"] }
}

2. To start matching
{
    "type": "start_matching",
    "description": "Starting matching",
    "timestamp": "2025-10-01T12:00:00"
}

3. To stop matching
{
    "type": "end_matching",
    "description": "Ending matching",
    "timestamp": "2025-10-01T12:00:00"
}

4. To chat
{
    "type": "chat_message",
    "description": "Sending chat message",
    "timestamp": "2025-10-01T12:00:00",
    "data": { "message": "Hello partner!" }
}

5. To end chat
{
    "type": "end_chat",
    "description": "Ending chat",
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
        except redis.ConnectionError as e:
            logger.error(f"Redis connection failed: {e}")
            self.redis_client = None

        self.user_interests = []
        self.user_id = None
        self.room_name = None
        self.partner_user_id = None
        self.partner_channel = None

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
            # End chat if in progress
            if self.room_name:
                self.handle_end_chat()

            # Remove user entry from waiting area
            if self.redis_client and self.redis_client.exists(f"user:{self.user_id}"):
                self.redis_client.delete(f"user:{self.user_id}")

            # Remove interests from Redis sets
            self.remove_interests()

            # Leave room group if in a room
            if self.room_name:
                async_to_sync(self.channel_layer.group_discard)(
                    self.room_name, self.channel_name
                )

        except Exception as e:
            logger.error(f"Error during disconnect cleanup: {e}")

    # Receive message from WebSocket and handle it based on its type
    def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message_type = text_data_json["type"]

        # Handle different message types
        if message_type == "submit_interests":
            self.handle_interests(text_data_json["data"].get("interests", []))
        elif message_type == "start_matching":
            self.handle_matching()
        elif message_type == "end_matching":
            self.stop_handle_matching()
        elif message_type == "chat_message":
            self.handle_chat_message(text_data_json["data"].get("message", ""))
        elif message_type == "end_chat":
            self.handle_end_chat()
        else:
            self.send_response("error", "Invalid message type")

    def handle_interests(self, interests):
        if not interests or not isinstance(interests, list):
            self.send_response("error", "Interests must be a non-empty list")
            return

        self.user_interests = interests

        # Add interests to Redis set for matching
        self.add_interests()

        self.send_response("success", "Interests received, you can start matching")

    def add_interests(self):
        # get rid of old interests first
        self.remove_interests()

        # add new interests
        for interest in self.user_interests:
            if not self.redis_client.sismember(
                f"waiting_users:{interest}", self.user_id
            ):
                self.redis_client.sadd(f"waiting_users:{interest}", self.user_id)

    def remove_interests(self):
        for interest in self.user_interests:
            if self.redis_client.sismember(f"waiting_users:{interest}", self.user_id):
                self.redis_client.srem(f"waiting_users:{interest}", self.user_id)

    def handle_matching(self):
        if not self.user_interests:
            self.send_response("error", "Please submit interests first")
            return

        matched_partner = self.find_match()
        if matched_partner:
            # get partner channel name for creating a room
            partner_channel = self.redis_client.hget(
                f"user:{matched_partner}", "channel_name"
            )

            # Remove self and partner from the waiting list
            self.redis_client.delete(f"user:{self.user_id}")
            self.redis_client.delete(f"user:{matched_partner}")

            # Create a unique room for the matched pair
            self.room_name = f"room_{uuid.uuid4().hex[:8]}"

            # Add both users to the same room group
            async_to_sync(self.channel_layer.group_add)(
                self.room_name, self.channel_name
            )
            async_to_sync(self.channel_layer.group_add)(self.room_name, partner_channel)

            # Notify both users of the match
            # -> for self
            self.handle_match_found(
                {
                    "partner_user_id": matched_partner,
                    "partner_channel": partner_channel,
                }
            )

            # -> for partner
            self.inter_consumer_communication(
                partner_channel,
                {
                    "type": "handle_match_found",
                    "partner_user_id": self.user_id,
                    "partner_channel": self.channel_name,
                },
            )

            # share room name with both users
            self.handle_room_assignment({"room_name": self.room_name})

            self.inter_consumer_communication(
                partner_channel,
                {"type": "handle_room_assignment", "room_name": self.room_name},
            )
        else:
            self.send_response(
                "no_match",
                "No match found, but nothing to fear, we are watching you",
            )

    def find_match(self):
        # make user visible for matching
        self.redis_client.hset(
            f"user:{self.user_id}", "channel_name", self.channel_name
        )

        probable_matches = []
        for interest in self.user_interests:
            waiting_users = self.redis_client.smembers(f"waiting_users:{interest}")

            for user in waiting_users:
                if (
                    user != self.user_id
                    and self.redis_client.exists(f"user:{user}")
                    and user not in probable_matches
                ):
                    probable_matches.append(user)

        #  return a random user from the list
        return random.choice(probable_matches) if probable_matches else None

    def stop_handle_matching(self):
        self.redis_client.delete(f"user:{self.user_id}")
        self.send_response("success", "You have stopped looking for a match.")

    def handle_chat_message(self, message):
        if not self.room_name:
            self.send_response("error", "You are not in a chat room")
            return

        async_to_sync(self.channel_layer.group_send)(
            self.room_name,
            {"type": "chat_message", "message": message, "sender_id": self.user_id},
        )

    def handle_end_chat(self, event={"ending_party": "self"}):
        ending_party = event["ending_party"]
        if self.room_name:
            async_to_sync(self.channel_layer.group_discard)(
                self.room_name, self.channel_name
            )

            # notify partner that chat has ended
            self.inter_consumer_communication(
                self.partner_channel,
                {"type": "handle_end_chat", "ending_party": "partner"},
            )

            self.room_name = None
            self.partner_user_id = None
            self.partner_channel = None

            self.send_response(
                "success",
                (
                    "You have left the chat"
                    if ending_party == "self"
                    else "Your partner has left the chat"
                ),
            )
        else:
            self.send_response("error", "You are not in a chat room")

    def inter_consumer_communication(self, partner_channel, message):
        async_to_sync(self.channel_layer.send)(partner_channel, message)

    def handle_room_assignment(self, event):
        self.room_name = event["room_name"]
        self.send_response(
            "success",
            "You have saved current room name",
        )

    def handle_match_found(self, event):
        self.partner_user_id = event["partner_user_id"]
        self.partner_channel = event["partner_channel"]
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
