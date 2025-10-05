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

  Data({
    this.message,
    this.interests,
  });

  factory Data.fromJson(Map<String, dynamic> json) => _$DataFromJson(json);

  Map<String, dynamic> toJson() => _$DataToJson(this);
}
