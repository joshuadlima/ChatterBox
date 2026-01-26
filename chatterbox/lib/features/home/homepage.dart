import 'package:chatterbox/features/chat/chatpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../chat/interestsUi.dart';
import '../chat/providers/interestsProvider.dart';
import '../chat/videoChatPage.dart';
class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interests = ref.watch(interestsProvider);
    final bool isReady = interests.isNotEmpty;
    const purple = Color(0xFF6200EE);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("chatterbox.",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: purple, letterSpacing: -2)),

            Text(isReady ? interests.join(" • ").toUpperCase() : "CONNECTION STANDBY",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: purple.withOpacity(0.4), letterSpacing: 1.5)),

            const Spacer(),

            _ActionTile(
              label: "TEXT CHAT",
              icon: Icons.chat_bubble_outline,
              active: isReady,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(title: 'Chat'))),
            ),

            const SizedBox(height: 16),

            _ActionTile(
              label: "VIDEO CALL",
              icon: Icons.videocam_outlined,
              active: isReady,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VideoChatPage())),
            ),

            const Spacer(),

            Center(
              child: TextButton(
                onPressed: () => showInterestsBottomSheet(context, ref),
                child: Text(isReady ? "Edit Interests" : "Set interests to unlock",
                    style: TextStyle(color: purple.withOpacity(isReady ? 0.3 : 1.0), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ActionTile({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF6200EE);

    return Opacity(
      opacity: active ? 1.0 : 0.2, // to handle button disable appearance
      child: Material(
        color: purple,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: active ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 16),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}