import 'chatMessageModel.dart';

class ChatSessionModel {
  final List<ChatMessage> messages;
  final bool isActive;
  final bool isStartLoading;

  // Constructor with default values
  const ChatSessionModel({
    this.messages = const [],
    this.isActive = false,
    this.isStartLoading = false,
  });

  // copyWith to add immutable copies of  a state
  ChatSessionModel copyWith({
    List<ChatMessage>? messages,
    bool? isActive,
    bool? isStartLoading,
  }) {
    return ChatSessionModel(
      messages: messages ?? this.messages,
      isActive: isActive ?? this.isActive,
      isStartLoading: isStartLoading ?? this.isStartLoading,
    );
  }
}
