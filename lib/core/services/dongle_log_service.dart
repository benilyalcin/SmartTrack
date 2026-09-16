import 'dart:collection';

import 'package:flutter/foundation.dart';

class DongleLogService extends ChangeNotifier {
  DongleLogService._();
  static final DongleLogService instance = DongleLogService._();

  static const int maxLines = 4000;
  static const int _trimSlack = 500;

  final List<String> _lines = [];

  List<String> get lines => UnmodifiableListView(_lines);

  void add(String line) {
    _lines.add(line);
    if (_lines.length > maxLines + _trimSlack) {
      _lines.removeRange(0, _lines.length - maxLines);
    }
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}
