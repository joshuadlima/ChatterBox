import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chatMessageModel.dart';
import '../models/chatSessionModel.dart';

class ChatSessionNotifier extends StateNotifier<ChatSessionModel> {
  ChatSessionNotifier({List<String>? interests}) : super(ChatSessionModel(messages: [], isActive: false, isStartLoading: false, interests: interests));

  void addMessage(String text, bool isMe) {
    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isMe: isMe,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(messages: [...state.messages, newMessage]);

    // Temporary: Simulate a reply
    if (isMe && text == "pls reply") {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) { // Check if the notifier is still active
          addMessage("what bro?", false);
        }
      });
    }
  }

  void endChat() {
    state = state.copyWith(isActive: false, messages: [], interests: null);
  }

  Future<void> startChat(List<String>? interests) async {
    state = state.copyWith(isStartLoading: true);

    // simulate load time
    await Future.delayed(Duration(milliseconds: 3000));

    state = state.copyWith(isActive: true, isStartLoading: false, messages: [], interests: interests);
  }
}

// declare the builder
final chatSessionProvider = StateNotifierProvider.autoDispose<ChatSessionNotifier, ChatSessionModel>((ref) {
  print("RIVERPOD - Creating ChatSessionNotifier instance now!");
  return ChatSessionNotifier(interests: null);
});