import 'package:chatterbox/features/chat/providers/chatSessionProvider.dart';
import 'package:chatterbox/features/chat/providers/webSocketProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'messageBuilder.dart';
import 'models/webSocketConnectionStatus.dart';

class ChatPage extends ConsumerWidget {
  ChatPage({super.key, this.title = 'chatterbox.'});
  final String title;
  final TextEditingController _messageController = TextEditingController();
  final purple = const Color(0xFF6200EE);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: BackButton(color: purple),
        title: Text("chatterbox.", style: TextStyle(color: purple, fontWeight: FontWeight.w900, letterSpacing: -1)),
        actions: [_buildHeaderAction(ref)],
      ),
      body: Column(
        children: [
          Expanded(child: _buildChatArea(ref)),
          _buildInputBar(ref),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(WidgetRef ref) {
    final status = ref.watch(webSocketServiceProvider);
    final notifier = ref.read(webSocketServiceProvider.notifier);

    String label = "CONNECT";
    VoidCallback? action = () => notifier.connect();

    if (status == WebSocketConnectionStatus.connected) { label = "START"; action = () => notifier.startMatching(); }
    if (status == WebSocketConnectionStatus.matching) { label = "STOP"; action = () => notifier.stopMatching(); }
    if (status == WebSocketConnectionStatus.matched) { label = "END"; action = () => notifier.endChat(); }

    return TextButton(
      onPressed: status == WebSocketConnectionStatus.connecting ? null : action,
      child: Text(label, style: TextStyle(color: purple, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }

  Widget _buildChatArea(WidgetRef ref) {
    final status = ref.watch(webSocketServiceProvider);
    final messages = ref.watch(chatSessionProvider).messages;

    if (status == WebSocketConnectionStatus.matching || status == WebSocketConnectionStatus.connecting) {
      return Center(
        child: Text("SEARCHING...", style: TextStyle(color: purple.withOpacity(0.3), fontWeight: FontWeight.w900, letterSpacing: 2)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: messages.length,
      itemBuilder: (context, i) => buildMessage(context, messages[i].text, messages[i].messageType),
    );
  }

  Widget _buildInputBar(WidgetRef ref) {
    final isMatched = ref.watch(webSocketServiceProvider) == WebSocketConnectionStatus.matched;

    return Opacity(
      opacity: isMatched ? 1.0 : 0.2,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 10, 30), // Extra bottom padding for "Lean" look
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: purple.withOpacity(0.1))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: isMatched,
                decoration: const InputDecoration(hintText: "Write something...", border: InputBorder.none),
                onSubmitted: (_) => _sendMessage(ref),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send_rounded, color: purple),
              onPressed: isMatched ? () => _sendMessage(ref) : null,
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(WidgetRef ref) {
    if (_messageController.text.trim().isEmpty) return;
    ref.read(chatSessionProvider.notifier).addMessage(_messageController.text, ChatMessageType.self);
    _messageController.clear();
  }
}