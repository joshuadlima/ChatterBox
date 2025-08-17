import 'package:chatterbox/features/chat/providers/chatSessionProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/chatMessageModel.dart';

class ChatPage extends ConsumerWidget {
  final String title;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ChatPage({super.key, this.title = 'ChatterBox!'});

  void _sendMessage(BuildContext context, WidgetRef ref) {
    final messageText = _messageController.text.trim();
    if (messageText.isNotEmpty) {
      print('Sending message: $messageText');

      ref.read(chatSessionProvider.notifier).addMessage(messageText, true);
      _buildMessage(context, messageText, true);
    }

    _messageController.clear();
  }

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
                _showInterestsBottomSheet(context, ref),
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
                return _buildMessage(context, message.text, message.isMe);
              },
            ),
          ),
          _buildMessageInputBar(context, ref),
        ],
      ),
    );
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

  Widget _buildMessage(BuildContext context, String message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * 0.9, // Set the maximum width
          // You can also add minWidth if needed, e.g., minWidth: 50.0,
        ),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
          decoration: BoxDecoration(
            color:
                isMe
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Text(
            message,
            style: TextStyle(
              color:
                  isMe
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

void _showInterestsBottomSheet(BuildContext context, WidgetRef ref) {
  final TextEditingController interestsController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext bottomSheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom, // Adjust for keyboard
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // So bottom sheet only takes needed height
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Enter your interests comma separated: ',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: 12),
            TextField(
              controller: interestsController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'example: Friends, Cooking, Space, Travel',
                border: InputBorder.none,
                filled: true,
                fillColor: Theme.of(context).colorScheme.inversePrimary,
                hintStyle: Theme.of(context).textTheme.labelMedium,
              ),
              onSubmitted: (_) {
                // Allow submitting with keyboard action
                _submitInterests(context, ref, interestsController.text);
              },
            ),
            SizedBox(height: 12),
            ElevatedButton(

              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onTertiary,
              ),
              child: Text('Find Chat'),
              onPressed: () {
                _submitInterests(context, ref, interestsController.text);
              },
            ),
            SizedBox(height: 8), // Some padding at the bottom
          ],
        ),
      );
    },
  ).whenComplete(() {
    // interestsController.dispose(); // Dispose the controller when sheet is closed
  });
}

void _submitInterests(BuildContext context, WidgetRef ref, String interestsText) {
  final interests = interestsText.split(',') // Split by comma
      .map((e) => e.trim())                  // Trim whitespace
      .where((e) => e.isNotEmpty)            // Remove empty strings
      .map((e) => e.toLowerCase())           // Convert to lowercase
      .toList();

  print(interests);

  if (interests.isNotEmpty) {
    // Call your provider method
    ref.read(chatSessionProvider.notifier).startChat(interests);
    Navigator.pop(context); // Close the bottom sheet
  } else {
    // Optional: Show a small error/warning if no interests are entered
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please enter at least one interest.')),
    );
  }
}
