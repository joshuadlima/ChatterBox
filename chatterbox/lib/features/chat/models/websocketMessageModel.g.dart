// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'websocketMessageModel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebsocketMessage _$WebsocketMessageFromJson(Map<String, dynamic> json) =>
    WebsocketMessage(
      json['type'] as String,
      json['description'] as String,
      DateTime.parse(json['timestamp'] as String),
      json['data'] == null
          ? null
          : Data.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$WebsocketMessageToJson(WebsocketMessage instance) =>
    <String, dynamic>{
      'type': instance.type,
      'description': instance.description,
      'timestamp': instance.timestamp.toIso8601String(),
      'data': instance.data?.toJson(),
    };

Data _$DataFromJson(Map<String, dynamic> json) => Data(
  message: json['message'] as String?,
  interests:
      (json['interests'] as List<dynamic>?)?.map((e) => e as String).toList(),
  sdp: json['sdp'] as String?,
  type: json['type'] as String?,
  candidate: json['candidate'] as String?,
  sdpMid: json['sdpMid'] as String?,
  sdpMLineIndex: (json['sdpMLineIndex'] as num?)?.toInt(),
  role: json['role'] as String?,
);

Map<String, dynamic> _$DataToJson(Data instance) => <String, dynamic>{
  if (instance.interests case final value?) 'interests': value,
  if (instance.message case final value?) 'message': value,
  if (instance.sdp case final value?) 'sdp': value,
  if (instance.type case final value?) 'type': value,
  if (instance.candidate case final value?) 'candidate': value,
  if (instance.sdpMid case final value?) 'sdpMid': value,
  if (instance.sdpMLineIndex case final value?) 'sdpMLineIndex': value,
  if (instance.role case final value?) 'role': value,
};
