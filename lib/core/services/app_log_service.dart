import 'dart:collection';

import 'package:flutter/foundation.dart';

class AppLogService extends ChangeNotifier {
  AppLogService._();
  static final AppLogService instance = AppLogService._();

  /// A live BLE connection writes about seven lines a second, so this holds
  /// about an hour - enough to still have the handshake after a bench session.
  static const int maxLines = 25000;

  static const int _trimSlack = 500;

  final List<String> _lines = [];

  List<String> get lines => UnmodifiableListView(_lines);

  void add(String line) {
    _lines.add('${_timestamp(DateTime.now())} $line');
    if (_lines.length > maxLines + _trimSlack) {
      _lines.removeRange(0, _lines.length - maxLines);
    }
    notifyListeners();
  }

  /// HH:mm:ss.SSS, comparable side by side with the vehicle unit's own log.
  static String _timestamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}
