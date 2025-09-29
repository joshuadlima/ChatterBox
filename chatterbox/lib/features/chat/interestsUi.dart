
import 'package:chatterbox/features/chat/providers/chatSessionProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> showInterestsBottomSheet(BuildContext context) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final List<String>? previousInterests = prefs.getStringList('userInterests');
  final String initialText = (previousInterests != null && previousInterests.isNotEmpty)
      ? previousInterests.join(', ') // Join with comma and space for readability
      : '';
  final TextEditingController interestsController = TextEditingController(text: initialText);

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
              'Enter your top 5 interests comma separated: ',
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
                _saveInterests(context, interestsController.text, prefs);
              },
            ),
            SizedBox(height: 12),
            ElevatedButton(

              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onTertiary,
              ),
              child: Text('Save Interests'),
              onPressed: () {
                _saveInterests(context, interestsController.text, prefs);
              },
            ),
            SizedBox(height: 8), // Some padding at the bottom
          ],
        ),
      );
    },
  );
}

Future<void> _saveInterests(BuildContext context, String interestsText, SharedPreferences prefs) async {
  final interests = interestsText.split(',') // Split by comma
      .map((e) => e.trim())                  // Trim whitespace
      .where((e) => e.isNotEmpty)            // Remove empty strings
      .map((e) => e.toLowerCase())           // Convert to lowercase
      .toList();

  if (interests.isNotEmpty) {
    await prefs.setStringList('userInterests', interests.length > 5 ? interests.take(5).toList() : interests);
    if(context.mounted) {
      Navigator.pop(context); // Close the bottom sheet
    }
  } else {
    // Optional: Show a small error/warning if no interests are entered
    Fluttertoast.showToast(
        msg: "Please enter at least one interest.",
        toastLength: Toast.LENGTH_SHORT
    );
  }
}
