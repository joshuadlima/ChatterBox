from django.urls import path, re_path

from . import consumers

websocket_urlpatterns = [
    path('ws/textchat/', consumers.ChatConsumer.as_asgi()),
    # re_path(r"textchat/ws/chat/(?P<room_name>\w+)/$", consumers.ChatConsumer.as_asgi()),
]
