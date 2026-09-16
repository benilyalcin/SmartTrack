import 'dart:collection';

import 'package:flutter/foundation.dart';

class DongleDownloadResult {
  final String label;
  final int trep;
  final int subMessageCount;
  final Uint8List bytes;
  final bool complete;
  final DateTime timestamp;

  const DongleDownloadResult({
    required this.label,
    required this.trep,
    required this.subMessageCount,
    required this.bytes,
    required this.complete,
    required this.timestamp,
  });
}

class DongleDownloadResultService extends ChangeNotifier {
  DongleDownloadResultService._();
  static final DongleDownloadResultService instance =
      DongleDownloadResultService._();

  static const int maxResults = 50;

  final List<DongleDownloadResult> _results = [];

  List<DongleDownloadResult> get results =>
      UnmodifiableListView(_results.reversed);

  void add(DongleDownloadResult result) {
    _results.add(result);
    if (_results.length > maxResults) {
      _results.removeRange(0, _results.length - maxResults);
    }
    notifyListeners();
  }

  void clear() {
    _results.clear();
    notifyListeners();
  }
}
