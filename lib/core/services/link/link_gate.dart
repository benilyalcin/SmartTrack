import 'dart:async';

import 'package:flutter/foundation.dart';

/// What the one line to the unit is doing. Live reads and a card download
/// cannot share it: while a download runs, no live data comes.
enum LinkMode { idle, live, ddd }

/// Set by the scheduler (or anyone) to stop a card download at the next
/// block. What was read until then is thrown away.
class DownloadCancelToken {
  bool _cancelled = false;
  String? _reason;

  bool get isCancelled => _cancelled;
  String? get reason => _reason;

  void cancel([String? reason]) {
    _cancelled = true;
    _reason ??= reason;
  }
}

/// Hands the line to live reads or to a card download, never both.
///
/// A live read asks [tryBeginLive] first and is skipped while a download
/// holds the line. A download goes through [runDdd], which waits for the
/// live read in flight to end and keeps new ones out until it is done.
class LinkGate extends ChangeNotifier {
  LinkGate();

  static final LinkGate instance = LinkGate();

  bool _connected = false;
  int _liveInFlight = 0;
  int _dddDepth = 0;
  Completer<void>? _liveDrained;

  LinkMode get mode => _dddDepth > 0
      ? LinkMode.ddd
      : (_connected ? LinkMode.live : LinkMode.idle);

  bool get isDddMode => _dddDepth > 0;

  void setConnected(bool connected) {
    if (_connected == connected) return;
    _connected = connected;
    notifyListeners();
  }

  /// False while a download holds the line: the live read must not start.
  bool tryBeginLive() {
    if (_dddDepth > 0) return false;
    _liveInFlight++;
    return true;
  }

  void endLive() {
    if (_liveInFlight > 0) _liveInFlight--;
    if (_liveInFlight == 0) {
      _liveDrained?.complete();
      _liveDrained = null;
    }
  }

  /// Runs [body] with the line in DDD mode. Nested calls (the scheduler
  /// around the download service) share one DDD period.
  Future<T> runDdd<T>(Future<T> Function() body) async {
    _dddDepth++;
    if (_dddDepth == 1) notifyListeners();
    try {
      while (_liveInFlight > 0) {
        await (_liveDrained ??= Completer<void>()).future;
      }
      return await body();
    } finally {
      _dddDepth--;
      if (_dddDepth == 0) notifyListeners();
    }
  }
}
