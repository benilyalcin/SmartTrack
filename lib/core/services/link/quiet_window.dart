import '../../config/sync_config.dart';
import '../driving_time_calculator.dart';

/// Decides from live samples whether this is a quiet window, a time a card
/// download may take the line:
///
///   card inserted (a card download needs it)
///   AND (speed 0 for long enough OR the activity is rest/break
///        OR, once known, the ignition is off)
///   AND not driving.
///
/// Taking the card out is not a reason to start: then there is nothing to
/// download.
class QuietWindowDetector {
  QuietWindowDetector([this.config = SyncConfig.defaults]);

  final SyncConfig config;

  DateTime? _lastSampleAt;
  DateTime? _stoppedSince;
  int? _speedKmh;
  ActivityType? _activity;
  bool _cardInserted = false;
  bool? _ignitionOn;

  DateTime? get lastSampleAt => _lastSampleAt;

  /// Takes a live sample. [ignitionOn] stays null until a signal for it is
  /// known; then it is used too.
  void onSample({
    required DateTime at,
    required int? speedKmh,
    required ActivityType? activity,
    required bool cardInserted,
    bool? ignitionOn,
  }) {
    _lastSampleAt = at;
    _activity = activity;
    _cardInserted = cardInserted;
    _ignitionOn = ignitionOn;
    _speedKmh = speedKmh;
    if (speedKmh == null || speedKmh > 0) {
      _stoppedSince = null;
    } else {
      _stoppedSince ??= at;
    }
  }

  /// Forget everything: contact is lost, the samples are no longer current.
  void reset() {
    _lastSampleAt = null;
    _stoppedSince = null;
    _speedKmh = null;
    _activity = null;
    _cardInserted = false;
    _ignitionOn = null;
  }

  bool get isMoving =>
      (_speedKmh ?? 0) > 0 || _activity == ActivityType.driving;

  /// Whether a download may start at [now]. [mandatory] (stale card data)
  /// is content with the shorter stop of
  /// [SyncConfig.forcedQuietSpeedZeroFor]; driving still never qualifies.
  bool isOpen(DateTime now, {bool mandatory = false}) {
    if (_lastSampleAt == null || !_cardInserted || isMoving) return false;
    if (_ignitionOn == false) return true;
    if (_activity == ActivityType.rest) return true;
    final since = _stoppedSince;
    if (since == null) return false;
    final needed = mandatory
        ? config.forcedQuietSpeedZeroFor
        : config.effectiveQuietSpeedZeroFor;
    return now.difference(since) >= needed;
  }
}
