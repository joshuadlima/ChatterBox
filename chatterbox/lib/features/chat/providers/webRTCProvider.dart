import '../models/websocketMessageModel.dart';
import 'package:chatterbox/features/chat/providers/webSocketProvider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

// A state class to hold our renderers and connection status
enum ChatStatus { idle, searching, connected }

class WebRTCState {
  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final bool isConnected;
  final bool isMicOn;
  final bool isVideoOn;
  final ChatStatus status;

  WebRTCState({
    required this.localRenderer,
    required this.remoteRenderer,
    this.isConnected = false,
    this.isMicOn = true,
    this.isVideoOn = true,
    this.status = ChatStatus.idle,
  });

  WebRTCState copyWith({bool? isConnected, bool? isMicOn, bool? isVideoOn, ChatStatus? status}) {
    return WebRTCState(
      localRenderer: localRenderer,
      remoteRenderer: remoteRenderer,
      isConnected: isConnected ?? this.isConnected,
      isMicOn: isMicOn ?? this.isMicOn,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      status: status ?? this.status,
    );
  }
}

class WebRTCNotifier extends StateNotifier<WebRTCState> {
  final WebSocketService _wsService;
  final Ref _ref;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  // Track if remote description is set to buffer ICE candidates if they arrive too early
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _iceCandidateQueue = [];

  WebRTCNotifier(this._wsService, this._ref)
      : super(WebRTCState(
    localRenderer: RTCVideoRenderer(),
    remoteRenderer: RTCVideoRenderer(),
  )) {
    _initialize();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  Future<void> _initialize() async {
    await _requestPermissions();
    await state.localRenderer.initialize();
    await state.remoteRenderer.initialize();
    await startLocalStream();
    _listenToSignaling();
  }

  void _listenToSignaling() {
    _ref.listen(webSocketMessagesProvider, (previous, next) {
      final msg = next.asData?.value;
      print("MESSAGE IS THIS BROTHA -> ->  ${msg?.toJson().toString()}");
      if (msg == null) return;

      switch (msg.type) {
        case "success_matched":
          if (msg.data?.role == 'caller') {
            print('CALLER');
            _initiateCall();
          } else if(msg.data?.role == 'callee') {
            // If callee, just ensure connection is prepared
            print('CALLEE');
            _preparePeerConnection();
          }
          break;

        case "webrtc_signal":
          if (msg.data != null) _handleIncomingSignal(msg.data!);
          break;

        case "partner_left_chat":
          leaveChat();
          break;
      }
    });
  }

  // --- Handshake Logic ---

  Future<void> _preparePeerConnection() async {
    if (_peerConnection != null) return;

    Map<String, dynamic> config = {
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
      ]
    };

    _peerConnection = await createPeerConnection(config);

    // Send local ICE candidates to partner
    _peerConnection!.onIceCandidate = (candidate) {
      _wsService.sendWebRTCSignal({
        'type': 'candidate',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    // Handle incoming remote stream
    _peerConnection!.onTrack = (event) {
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        state.remoteRenderer.srcObject = event.streams[0];
        state = state.copyWith(isConnected: true, status: ChatStatus.connected);
      }
    };

    // Add local tracks
    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
  }

  Future<void> _initiateCall() async {
    await _preparePeerConnection();
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _wsService.sendWebRTCSignal({
      'type': 'offer',
      'sdp': offer.sdp,
    });
  }

  Future<void> _handleIncomingSignal(Data data) async {
    await _preparePeerConnection();

    if (data.type == 'offer' && data.sdp != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data.sdp, 'offer'),
      );
      _remoteDescriptionSet = true;

      // Create and send answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _wsService.sendWebRTCSignal({
        'type': 'answer',
        'sdp': answer.sdp,
      });

      // Process any queued candidates
      for (var candidate in _iceCandidateQueue) {
        await _peerConnection!.addCandidate(candidate);
      }
      _iceCandidateQueue.clear();

    } else if (data.type == 'answer' && data.sdp != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data.sdp, 'answer'),
      );
      _remoteDescriptionSet = true;

    } else if (data.candidate != null) {
      RTCIceCandidate candidate = RTCIceCandidate(
        data.candidate!,
        data.sdpMid!,
        data.sdpMLineIndex!,
      );

      if (_remoteDescriptionSet) {
        await _peerConnection!.addCandidate(candidate);
      } else {
        _iceCandidateQueue.add(candidate);
      }
    }
  }

  // --- Controls ---

  Future<void> startLocalStream() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'}
    });
    state.localRenderer.srcObject = _localStream;
  }

  void leaveChat() {
    _peerConnection?.close();
    _peerConnection = null;
    _remoteDescriptionSet = false;
    state.remoteRenderer.srcObject = null;
    state = state.copyWith(isConnected: false, status: ChatStatus.idle);

    _wsService.endChat();
  }

  @override
  void dispose() {
    state.localRenderer.dispose();
    state.remoteRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }
}

final webrtcProvider = StateNotifierProvider.autoDispose<WebRTCNotifier, WebRTCState>((ref) {
  final wsService = ref.watch(webSocketServiceProvider.notifier);
  return WebRTCNotifier(wsService, ref);
});