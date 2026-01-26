import 'package:json_annotation/json_annotation.dart';
part 'websocketMessageModel.g.dart';
// dart run build_runner build

@JsonSerializable(explicitToJson: true)
class WebsocketMessage {
  final String type;
  final String description;
  final DateTime timestamp;
  final Data? data;

  WebsocketMessage(
      this.type,
      this.description,
      this.timestamp,
      this.data,
      );

  factory WebsocketMessage.fromJson(Map<String, dynamic> json) =>
      _$WebsocketMessageFromJson(json);

  Map<String, dynamic> toJson() => _$WebsocketMessageToJson(this);
}

@JsonSerializable(includeIfNull: false)
class Data {
  final List<String>? interests;
  final String? message;

  // --- For WebRTC ---
  final String? sdp;
  final String? type; // 'offer' or 'answer'
  final String? candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  final String? role; // 'caller' or 'callee'

  Data({
    this.message,
    this.interests,
    this.sdp,
    this.type,
    this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
    this.role,
  });

  factory Data.fromJson(Map<String, dynamic> json) => _$DataFromJson(json);
  Map<String, dynamic> toJson() => _$DataToJson(this);
}