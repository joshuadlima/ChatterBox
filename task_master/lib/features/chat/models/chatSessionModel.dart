import 'chatMessageModel.dart';

class ChatSessionModel {
  final List<ChatMessage> messages;
  final bool isActive;
  final bool isStartLoading;
  final List<String>? interests;

  // Constructor with default values
  const ChatSessionModel({
    this.messages = const [],
    this.isActive = false,
    this.isStartLoading = false,
    this.interests = const [],
  });

  // copyWith to add immutable copies of  a state
  ChatSessionModel copyWith({
    List<ChatMessage>? messages,
    bool? isActive,
    bool? isStartLoading,
    List<String>? interests,
  }) {
    return ChatSessionModel(
      messages: messages ?? this.messages,
      isActive: isActive ?? this.isActive,
      isStartLoading: isStartLoading ?? this.isStartLoading,
      interests: interests ?? this.interests,
    );
  }
}
