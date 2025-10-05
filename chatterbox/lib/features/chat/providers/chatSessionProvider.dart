import 'package:chatterbox/features/chat/providers/webSocketProvider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chatMessageModel.dart';
import '../models/chatSessionModel.dart';
import '../models/websocketMessageModel.dart';

enum ChatMessageType { self, partner, admin }

class ChatSessionNotifier extends StateNotifier<ChatSessionModel> {
  final Ref _ref;

  ChatSessionNotifier(this._ref)
    : super(
        ChatSessionModel(messages: [], isActive: false, isStartLoading: false),
      ){
    _listenToWebsocketMessages(); // call the message listener method
  }

  void addMessage(String text, ChatMessageType messageType) {
    switch (messageType) {
      case ChatMessageType.self:
        _ref.read(webSocketServiceProvider.notifier).sendMessage(text);
        final newMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          messageType: ChatMessageType.self,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(messages: [...state.messages, newMessage]);
        break;

      case ChatMessageType.partner:
        final newMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          messageType: ChatMessageType.partner,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(messages: [...state.messages, newMessage]);
        break;

      case ChatMessageType.admin:
        final newMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          messageType: ChatMessageType.admin,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(messages: [...state.messages, newMessage]);
        break;
    }
  }

  void _listenToWebsocketMessages() {
    _ref.listen<AsyncValue<WebsocketMessage>>(webSocketMessagesProvider, (previous, next) {
      // Get the actual message data from the AsyncValue
      final wsMessage = next.asData?.value;

      if(wsMessage != null) {
        switch (wsMessage.type) {
          case "chat_message":
            addMessage(wsMessage.data!.message!, ChatMessageType.partner);
            break;

          case "success_matched":
            _ref.read(webSocketServiceProvider.notifier).handleMatchSuccess();
            break;

          case "error" || "partner_left_chat":
            addMessage(wsMessage.description, ChatMessageType.admin);
            break;

          default: // do nothing for type success
            break;
        }
      }
    });
  }

  void clearChat() {
    state = state.copyWith(messages: []);
  }
}

// declare the builder
final chatSessionProvider =
    StateNotifierProvider.autoDispose<ChatSessionNotifier, ChatSessionModel>((
      ref,
    ) {
      print("RIVERPOD - Creating ChatSessionNotifier instance now!");
      return ChatSessionNotifier(ref);
    });
