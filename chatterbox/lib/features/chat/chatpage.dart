import 'package:chatterbox/features/chat/models/chatSessionModel.dart';
import 'package:chatterbox/features/chat/providers/chatSessionProvider.dart';
import 'package:chatterbox/features/chat/providers/webSocketProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'interestsUi.dart';
import 'messageBuilder.dart';
import 'models/chatMessageModel.dart';
import 'models/webSocketConnectionStatus.dart';

class ChatPage extends ConsumerWidget {
  ChatPage({super.key, this.title = 'ChatterBox!'});

  final String title;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('ChatterBox!'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: _buildAppBarAction(context, ref),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(child: _buildChatScreen(context, ref)),
          _buildMessageInputBar(context, ref),
        ],
      ),
    );
  }

  Widget _buildAppBarAction(BuildContext context, WidgetRef ref) {
    final wsStatus = ref.watch(webSocketServiceProvider);

    switch (wsStatus) {
      case WebSocketConnectionStatus.connected:
        return ElevatedButton(
          onPressed: () {
            ref.read(webSocketServiceProvider.notifier).startMatching();
          },
          child: Text('Start Chat'),
        );

      case WebSocketConnectionStatus.matched:
        return ElevatedButton(
          onPressed: () {
            ref.read(webSocketServiceProvider.notifier).endChat();
            ref.read(chatSessionProvider.notifier).clearChat();
          },
          child: Text('End Chat'),
        );

      case WebSocketConnectionStatus.matching:
        return ElevatedButton(
          onPressed: () {
            ref.read(webSocketServiceProvider.notifier).stopMatching();
          },
          child: Text('Stop Matching'),
        );

      case WebSocketConnectionStatus.connecting:
        return ElevatedButton(onPressed: null, child: Text('Connecting...'));

      // for disconnected or error
      default:
        return ElevatedButton(
          onPressed: () {
            ref.read(webSocketServiceProvider.notifier).connect();
          },
          child: Text('Connect'),
        );
    }
  }

  Widget _buildChatScreen(BuildContext context, WidgetRef ref) {
    final wsStatus = ref.watch(webSocketServiceProvider);
    final List<ChatMessage> messages = ref.watch(
      chatSessionProvider.select((state) => state.messages),
    );

    switch (wsStatus) {
      case WebSocketConnectionStatus.connecting ||
          WebSocketConnectionStatus.matching:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Text("Loading, Please wait !!"),
            ),
          ],
        );

      default: // all other cases
        return ListView.builder(
          controller: _scrollController,
          // to scroll to new messages
          reverse: false,
          // for bottom up
          padding: const EdgeInsets.all(8.0),
          itemCount: messages.length,
          itemBuilder: (BuildContext context, int index) {
            final ChatMessage message = messages[index];
            return buildMessage(context, message.text, message.messageType);
          },
        );
    }
  }

  Widget _buildMessageInputBar(BuildContext context, WidgetRef ref) {
    final wsStatus = ref.watch(webSocketServiceProvider);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      margin: EdgeInsets.fromLTRB(8, 8, 8, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // Or another suitable color
        boxShadow: [BoxShadow(blurRadius: 5.0, color: Colors.black12)],
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _messageController,
              readOnly: wsStatus != WebSocketConnectionStatus.matched,
              decoration: InputDecoration(
                hintText:
                    wsStatus == WebSocketConnectionStatus.matched
                        ? 'Type a message...'
                        : 'Start the chat to begin!',

                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
                ),

                // remove border (bottom line)
                border: InputBorder.none,
              ),

              // Send on keyboard submit action
              onSubmitted: (_) => _sendMessage(context, ref),
              textInputAction: TextInputAction.send,

              // Allow multi-line input
              minLines: 1,
              maxLines: 4,
            ),
          ),

          IconButton(
            icon: Icon(Icons.send),
            onPressed:
                wsStatus == WebSocketConnectionStatus.matched
                    ? () => _sendMessage(context, ref)
                    : null,
            disabledColor: Theme.of(context).colorScheme.surfaceDim,
            color:
                wsStatus == WebSocketConnectionStatus.matched
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceDim,
          ),
        ],
      ),
    );
  }

  void _sendMessage(BuildContext context, WidgetRef ref) {
    final messageText = _messageController.text.trim();
    if (messageText.isNotEmpty) {
      print('Sending message: $messageText');

      ref
          .read(chatSessionProvider.notifier)
          .addMessage(messageText, ChatMessageType.self);
      buildMessage(context, messageText, ChatMessageType.self);
    }

    _messageController.clear();
  }
}
