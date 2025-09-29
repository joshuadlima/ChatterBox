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
);

Map<String, dynamic> _$DataToJson(Data instance) => <String, dynamic>{
  if (instance.interests case final value?) 'interests': value,
  if (instance.message case final value?) 'message': value,
};
