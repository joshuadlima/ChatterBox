
import 'package:chatterbox/features/chat/providers/chatSessionProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void showInterestsBottomSheet(BuildContext context, WidgetRef ref) {
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
  );
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
