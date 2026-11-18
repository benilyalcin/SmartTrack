import '../../config/sync_config.dart';

/// Turns the UTC instants the data is kept in into what the UI shows, and
/// back. Only the UI uses this; nothing is stored in display time.
///
/// A display calendar day does not line up with a UTC day: with UTC+3,
/// 18 November runs from 17 November 21:00 to 18 November 21:00 UTC.
class DisplayTime {
  const DisplayTime(this.offset);

  DisplayTime.fromConfig([SyncConfig config = SyncConfig.defaults])
    : offset = config.displayUtcOffset;

  /// Display time minus UTC.
  final Duration offset;

  /// [instant] as wall-clock time in the display zone. The result is flagged
  /// UTC only so that its fields read as the display time; it is not an
  /// instant and must not be compared with one.
  DateTime wallClock(DateTime instant) => instant.toUtc().add(offset);

  /// The instant at wall-clock time [y]-[m]-[d] [h]:[min] in the display
  /// zone, in UTC.
  DateTime fromWallClock(int y, int m, int d, [int h = 0, int min = 0]) =>
      DateTime.utc(y, m, d, h, min).subtract(offset);

  /// The display calendar day [instant] falls on (fields only, see
  /// [wallClock]).
  DateTime displayDay(DateTime instant) {
    final w = wallClock(instant);
    return DateTime.utc(w.year, w.month, w.day);
  }

  /// Start (inclusive) and end (exclusive) in UTC of the display calendar
  /// day with the date fields of [date].
  ({DateTime start, DateTime end}) dayRangeUtc(DateTime date) {
    final start = fromWallClock(date.year, date.month, date.day);
    // Calendar arithmetic on the fields, so a day stays a day.
    final next = DateTime.utc(date.year, date.month, date.day + 1);
    return (start: start, end: fromWallClock(next.year, next.month, next.day));
  }

  /// The UTC calendar days a query for display day [date] has to look at:
  /// the ones it touches plus one either side, for records kept per UTC day.
  List<DateTime> utcDaysToQuery(DateTime date) {
    final range = dayRangeUtc(date);
    final first = _utcDay(range.start).subtract(const Duration(days: 1));
    final last = _utcDay(
      range.end.subtract(const Duration(microseconds: 1)),
    ).add(const Duration(days: 1));
    return [
      for (
        var d = first;
        !d.isAfter(last);
        d = DateTime.utc(d.year, d.month, d.day + 1)
      )
        d,
    ];
  }

  /// HH:mm in the display zone.
  String hm(DateTime instant) {
    final w = wallClock(instant);
    return '${_two(w.hour)}:${_two(w.minute)}';
  }

  static DateTime _utcDay(DateTime t) {
    final u = t.toUtc();
    return DateTime.utc(u.year, u.month, u.day);
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
