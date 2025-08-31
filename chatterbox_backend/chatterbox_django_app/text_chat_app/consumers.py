import json

from asgiref.sync import async_to_sync
from channels.generic.websocket import WebsocketConsumer
import redis

class ChatConsumer(WebsocketConsumer):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        # using a different Redis database than the one used for channel layers
        self.redis_client = redis.Redis(host='redis', port=6379, db=1, decode_responses=True) 
        
        # For user interests
        self.user_interests = []
        
        
    def connect(self):
        self.room_name = self.scope["url_route"]["kwargs"]["room_name"]
        self.room_group_name = f"chat_{self.room_name}"
        
        # Perform matching and subscribe accordingly - TODO

        # Join room group
        async_to_sync(self.channel_layer.group_add)(
            self.room_group_name, self.channel_name
        )

        self.accept()

    def disconnect(self, close_code):
        # Leave room group
        async_to_sync(self.channel_layer.group_discard)(
            self.room_group_name, self.channel_name
        )

    # Receive message from WebSocket -> Broadcast to room group
    def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message = text_data_json["message"]

        # Send message to room group
        async_to_sync(self.channel_layer.group_send)(
            self.room_group_name, {"type": "chat.message", "message": message} # calls chat_message
        )

    # Receive message from room group -> Send to Individual users
    def chat_message(self, event):
        message = event["message"]

        # Send message to WebSocket
        self.send(text_data=json.dumps({"message": message}))
