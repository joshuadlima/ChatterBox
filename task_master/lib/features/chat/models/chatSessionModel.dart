import 'chatMessageModel.dart';

class ChatSessionModel {
  final List<ChatMessage> messages;
  final bool isActive;
  final List<String>? interests;

  // Constructor with default values
  const ChatSessionModel({
    this.messages = const [],
    this.isActive = false,
    this.interests = const [],
  });

  // copyWith to add immutable copies of  a state
  ChatSessionModel copyWith({
    List<ChatMessage>? messages,
    bool? isActive,
    List<String>? interests,
  }) {
    return ChatSessionModel(
      messages: messages ?? this.messages,
      isActive: isActive ?? this.isActive,
      interests: interests ?? this.interests,
    );
  }
}
