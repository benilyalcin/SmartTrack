import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class BackgroundKeepAliveService {
  BackgroundKeepAliveService._();

  static const MethodChannel _channel = MethodChannel(
    'com.smarttrack/background_service',
  );

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await ph.Permission.notification.request();
    } catch (_) {}
    try {
      await _channel.invokeMethod('start');
    } catch (e) {
      debugPrint('BackgroundKeepAliveService.start failed: $e');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('BackgroundKeepAliveService.stop failed: $e');
    }
  }
}
