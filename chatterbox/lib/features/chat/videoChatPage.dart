import 'package:chatterbox/features/chat/providers/webRTCProvider.dart';
import 'package:chatterbox/features/chat/providers/webSocketProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'models/webSocketConnectionStatus.dart';

class VideoChatPage extends ConsumerWidget {
  const VideoChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webrtcState = ref.watch(webrtcProvider);
    final wsStatus = ref.watch(webSocketServiceProvider);
    final isChatting = webrtcState.status == ChatStatus.connected;
    const purple = Color(0xFF6200EE);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // FULL SCREEN VIDEO OR SEARCHING STATUS
          Positioned.fill(
            child: isChatting
                ? RTCVideoView(webrtcState.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                : _buildSearchingState(wsStatus, purple),
          ),

          // MINIMAL LOCAL PREVIEW (Floating Glass)
          Positioned(
            right: 20,
            top: 60,
            child: Container(
              width: 100, height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              clipBehavior: Clip.antiAlias,
              child: RTCVideoView(webrtcState.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            ),
          ),

          // 3. MINIMAL ACTION BAR
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomControls(context, ref, wsStatus, isChatting, purple),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingState(WebSocketConnectionStatus status, Color purple) {
    String label = "STANDBY";
    if (status == WebSocketConnectionStatus.matching) label = "SEARCHING...";
    if (status == WebSocketConnectionStatus.connecting) label = "CONNECTING...";

    return Container(
      color: const Color(0xFF0D0B14),
      child: Center(
        child: Text(label, style: TextStyle(color: purple.withOpacity(0.3), fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 12)),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, WidgetRef ref, WebSocketConnectionStatus status, bool isChatting, Color purple) {
    final wsNotifier = ref.read(webSocketServiceProvider.notifier);

    // Logic to determine the single action
    VoidCallback? onTap;
    IconData icon = Icons.power_settings_new_rounded;
    Color btnColor = purple;

    if (status == WebSocketConnectionStatus.disconnected) {
      onTap = () => wsNotifier.connect();
    } else if (status == WebSocketConnectionStatus.connected) {
      icon = Icons.search_rounded;
      onTap = () => wsNotifier.startMatching();
    } else if (status == WebSocketConnectionStatus.matching || isChatting) {
      icon = Icons.close_rounded;
      btnColor = Colors.redAccent;
      onTap = () => isChatting ? ref.read(webrtcProvider.notifier).leaveChat() : wsNotifier.stopMatching();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 50),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isChatting)
            IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white24), onPressed: () => Navigator.pop(context)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 80, width: 80,
              decoration: BoxDecoration(color: btnColor, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}