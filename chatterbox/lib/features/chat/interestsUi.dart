
import 'package:chatterbox/features/chat/providers/chatSessionProvider.dart';
import 'package:chatterbox/features/chat/providers/interestsProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future<void> showInterestsBottomSheet(BuildContext context, WidgetRef ref) async {
  // Get current interests from the provider state instead of fetching SharedPreferences
  final List<String> currentInterests = ref.read(interestsProvider);
  final TextEditingController controller = TextEditingController(text: currentInterests.join(', '));
  const purple = Color(0xFF6200EE);

  void handleSave() {
    final interests = controller.text.split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.toLowerCase())
        .toList();

    if (interests.isNotEmpty) {
      ref.read(interestsProvider.notifier).save(interests.take(5).toList());
      Navigator.pop(context);
    } else {
      Fluttertoast.showToast(msg: "Please enter at least one interest.");
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
        left: 30, right: 30, top: 30,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TOP 5 INTERESTS",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: purple.withOpacity(0.4), letterSpacing: 1.5)),

          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: "Space, Cooking, Coding...",
              hintStyle: TextStyle(color: Colors.black12),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 20),
            ),
            onSubmitted: (_) => handleSave(),
          ),

          const SizedBox(height: 10),

          Material(
            color: purple,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: handleSave,
              borderRadius: BorderRadius.circular(15),
              child: const SizedBox(
                height: 60,
                child: Center(
                  child: Text("SAVE CHOICES",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}