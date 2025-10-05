import 'package:chatterbox/features/chat/providers/chatSessionProvider.dart';

class ChatMessage {
  final String id;
  final String text;
  final ChatMessageType messageType;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.messageType,
    required this.timestamp,
  });
}
