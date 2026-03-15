import 'dart:convert';

import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceUtils {
  static const String _deviceIdKey = 'chatterbox_device_id';

  static Future<String> getDeviceIdentifier() async {
    final prefs = await SharedPreferences.getInstance();

    String? cachedId = prefs.getString(_deviceIdKey);
    if (cachedId != null) {
      return cachedId;
    }

    String deviceId = const Uuid().v4();

    try {
      String? androidId = await AndroidId().getId();
      if (androidId != null) {
        deviceId = androidId;
      }
    } on MissingPluginException {
      print('Failed to get Android ID: MissingPluginException');
    } on PlatformException catch (e) {
      print('Failed to get Android ID: ${e.message}');
    }

    // Hash the raw ID to protect user privacy
    final bytes = utf8.encode(deviceId);
    final digest = sha256.convert(bytes);
    final hashedDeviceId = digest.toString();

    await prefs.setString(_deviceIdKey, hashedDeviceId);

    return deviceId;
  }
}

final deviceIdProvider = FutureProvider<String>((ref) async {
  return await DeviceUtils.getDeviceIdentifier();
});