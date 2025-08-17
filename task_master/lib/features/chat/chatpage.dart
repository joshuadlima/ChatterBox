import 'package:chatterbox/features/chat/providers/chatSessionProvider.dart';
import 'package:chatterbox/features/chat/searchBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'interestsUi.dart';
import 'messageBuilder.dart';
import 'models/chatMessageModel.dart';

class ChatPage extends ConsumerWidget {
  ChatPage({super.key, this.title = 'ChatterBox!'});

  final String title;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final List<ChatMessage> messages = ref.watch(
      chatSessionProvider.select((state) => state.messages),
    );

    final bool isActive = ref.watch(
      chatSessionProvider.select((state) => state.isActive),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('ChatterBox!'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child:
            isActive
                ? ElevatedButton(
              onPressed:
                  () => {
                ref.read(chatSessionProvider.notifier).endChat(),
              },
              child: Text('End Chat'),
            )
                : ElevatedButton(
              onPressed:
                  () => {
                showInterestsBottomSheet(context, ref),
              },
              child: Text('Start Chat'),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              // to scroll to new messages
              reverse: false,
              // for bottom up
              padding: const EdgeInsets.all(8.0),
              itemCount: messages.length,
              itemBuilder: (BuildContext context, int index) {
                final ChatMessage message = messages[index];
                return buildMessage(context, message.text, message.isMe);
              },
            ),
          ),
          _buildMessageInputBar(context, ref),
        ],
      ),
    );
  }

  void _sendMessage(BuildContext context, WidgetRef ref) {
    final messageText = _messageController.text.trim();
    if (messageText.isNotEmpty) {
      print('Sending message: $messageText');

      ref.read(chatSessionProvider.notifier).addMessage(messageText, true);
      buildMessage(context, messageText, true);
    }

    _messageController.clear();
  }

  Widget _buildMessageInputBar(BuildContext context, WidgetRef ref) {
    final bool isActive = ref.watch(
      chatSessionProvider.select((state) => state.isActive),
    );

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
              readOnly: !isActive,
              decoration: InputDecoration(
                hintText: isActive ? 'Type a message...' : 'Start the chat to begin!',

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
            onPressed: isActive ? () => _sendMessage(context, ref) : null,
            disabledColor: Theme.of(context).colorScheme.surfaceDim,
            color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceDim,
          ),
        ],
      ),
    );
  }

}
