import 'package:chatterbox/features/chat/providers/chatSessionProvider.dart';
import 'package:flutter/material.dart';

Widget buildMessage(BuildContext context, String text, ChatMessageType type) {
  const purple = Color(0xFF6200EE);

  // System/Admin messages
  if (type == ChatMessageType.admin) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(text.toUpperCase(),
            style: TextStyle(color: purple.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
      ),
    );
  }

  // Setup alignment and colors for Self vs Partner
  final isSelf = type == ChatMessageType.self;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    child: Column(
      crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isSelf ? purple : purple.withOpacity(0.08),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isSelf ? 20 : 4), // Sharp corner for partner
              bottomRight: Radius.circular(isSelf ? 4 : 20), // Sharp corner for self
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelf ? Colors.white : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}