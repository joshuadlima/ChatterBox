import 'dart:async';
import 'dart:convert';
import 'package:chatterbox/features/chat/models/websocketMessageModel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import '../models/webSocketConnectionStatus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String? _webSocketUrl = dotenv.env['WEBSOCKET_URL'];

class WebSocketService extends StateNotifier<WebSocketConnectionStatus> {
  String? statusMessage;
  IOWebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;

  // StreamController to broadcast parsed messages
  final StreamController<WebsocketMessage> _parsedMessagesController =
  StreamController<WebsocketMessage>.broadcast();

  // Change the return type of the public stream getter
  Stream<WebsocketMessage> get parsedMessages => _parsedMessagesController.stream;

  WebSocketService() : super(WebSocketConnectionStatus.disconnected);

  Future<void> connect() async {
    if (state == WebSocketConnectionStatus.connected || state == WebSocketConnectionStatus.connecting) {
      print("WS: Already connected or connecting.");
      return;
    }

    print("WS: Attempting to connect to $_webSocketUrl...");
    state = WebSocketConnectionStatus.connecting;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? interests = prefs.getStringList('userInterests');

    if(interests!.isEmpty) {
      statusMessage = "Please submit at least one interest !!";
      state = WebSocketConnectionStatus.error;
      return;
    }

    try {
      // authentication, passing herders -> future scope

      _channel = IOWebSocketChannel.connect(Uri.parse(_webSocketUrl!));
      await _channel!.ready; // Wait for the connection to be established

      state = WebSocketConnectionStatus.connected;
      print("WS: Connected to $_webSocketUrl");

      _submitInterests(interests);

      _channelSubscription = _channel!.stream.listen(
        _onMessageReceived,
        onError: (error) {
          statusMessage = "WS: Error - $error";
          print("WS: Error - $error");
          state = WebSocketConnectionStatus.error;
          _disconnect(); // Clean up on error
        },
        onDone: () {
          print("WS: Connection closed.");
          // Only set to disconnected if it wasn't a manual disconnect or already an error
          if (state != WebSocketConnectionStatus.error) {
            state = WebSocketConnectionStatus.disconnected;
          }
        },
        cancelOnError: true, // Important to prevent further errors after one occurs
      );
    } catch (e) {
      statusMessage = "WS: Connection failed - $e";
      Fluttertoast.showToast(msg: "WS Error: ${e.toString()}");
      print("WS: Connection failed - $e");
      state = WebSocketConnectionStatus.error;
      _channel = null; // Ensure channel is null on failure
    }
  }

  void _onMessageReceived(dynamic message) {
    try {
      final Map<String, dynamic> messageJson = jsonDecode(message as String);
      final WebsocketMessage wsMessage = WebsocketMessage.fromJson(messageJson);

      print("WS: message received, type: ${wsMessage.type}");
      if(wsMessage.type != "success") {
        _parsedMessagesController.add(wsMessage);
      }

    } catch (e) {
      print("WS: Error parsing message - $e, Raw message: $message");
    }
  }

  void handleMatchSuccess() {
    if(state == WebSocketConnectionStatus.matching) {
      state = WebSocketConnectionStatus.matched;
    }
    else {
      print("WS: Cannot handle match success. Not in matching state.");
    }
  }

  void _submitInterests(List<String>? interests) {
    WebsocketMessage wsMessage = WebsocketMessage("submit_interests", "Request to submit interests", DateTime.now(), Data(interests: interests));
    if (state == WebSocketConnectionStatus.connected && _channel != null) {
      print("WS: Sending message - $wsMessage");
      _channel!.sink.add(jsonEncode(wsMessage.toJson()));
    } else {
      print("WS: Cannot send message. Not connected.");
    }
  }

  void sendWebRTCSignal(Map<String, dynamic> signalData) {
    // Use 'webrtc_signal' as the type to match your Django logic
    final wsMessage = WebsocketMessage(
      "webrtc_signal",
      "WebRTC Handshake Data",
      DateTime.now(),
      Data(
        sdp: signalData['sdp'],
        type: signalData['type'],
        candidate: signalData['candidate'],
        sdpMid: signalData['sdpMid'],
        sdpMLineIndex: signalData['sdpMLineIndex'],
      ),
    );

    print("MESSAGE Getting sent is ----> ${wsMessage.toJson().toString()}");

    if (_channel != null) {
      _channel!.sink.add(jsonEncode(wsMessage.toJson()));
    }
  }

  void startMatching() {
    WebsocketMessage wsMessage = WebsocketMessage("start_matching", "Request to start matching", DateTime.now(), Data());
    if (state == WebSocketConnectionStatus.connected && _channel != null) {
      print("WS: Sending message - $wsMessage");
      state = WebSocketConnectionStatus.matching;
      _channel!.sink.add(jsonEncode(wsMessage.toJson()));
    } else {
      print("WS: Cannot send message. Not connected.");
    }
  }

  void stopMatching() {
    WebsocketMessage wsMessage = WebsocketMessage("end_matching", "Request to end matching", DateTime.now(), Data());
    if (state == WebSocketConnectionStatus.matching && _channel != null) {
      print("WS: Sending message - $wsMessage");
      _channel!.sink.add(jsonEncode(wsMessage.toJson()));
      state = WebSocketConnectionStatus.connected;
    } else {
      print("WS: Cannot send message. Not connected.");
    }
  }

  void sendMessage(String message) {
    WebsocketMessage wsMessage = WebsocketMessage("chat_message", "Request to send chat message", DateTime.now(), Data(message: message));
    if (state == WebSocketConnectionStatus.matched && _channel != null) {
      print("WS: Sending message - $wsMessage");
      _channel!.sink.add(jsonEncode(wsMessage.toJson()));
    } else {
      print("WS: Cannot send message. Not connected.");
    }
  }

  void endChat() {
    WebsocketMessage wsMessage = WebsocketMessage("end_chat", "Request to end chat", DateTime.now(), Data());
    if (state == WebSocketConnectionStatus.matched && _channel != null) {
      print("WS: Sending message - $wsMessage");
      _channel!.sink.add(jsonEncode(wsMessage.toJson()));
      state = WebSocketConnectionStatus.connected;
    } else {
      print("WS: Cannot send message. Not connected.");
    }
  }

  void _disconnect() {
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _channelSubscription = null;
  }

  void disposeConnection() {
    print("WS: Disposing connection explicitly.");
    _disconnect();
    state = WebSocketConnectionStatus.disconnected; // Or disconnected
  }

  @override
  void dispose() {
    print("WS: WebSocketService disposed.");
    disposeConnection();
    _parsedMessagesController.close();
    super.dispose();
  }
}

final webSocketServiceProvider = StateNotifierProvider.autoDispose<WebSocketService, WebSocketConnectionStatus>((ref) {
  final service = WebSocketService();
  return service;
});

// A provider to easily access the parsed messages stream
final webSocketMessagesProvider = StreamProvider.autoDispose<WebsocketMessage>((ref) {
  final wsService = ref.watch(webSocketServiceProvider.notifier);
  return wsService.parsedMessages;
});
