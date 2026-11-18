import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/card_first_activity_log.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';

TachographActivity _a(
  ActivityType type,
  DateTime start,
  DateTime end, {
  bool manual = false,
  int? counter,
}) => TachographActivity(
  type: type,
  startTime: start,
  endTime: end,
  isManualEntry: manual,
  recordPresenceCounter: counter,
);

DateTime _z(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 10, day, hour, minute);

String _show(List<TachographActivity> log) => log
    .map(
      (a) =>
          '${a.type.name} ${a.startTime.toUtc().toIso8601String()}'
          '-${a.endTime.toUtc().toIso8601String()}'
          '${a.isManualEntry ? ' manual' : ''}',
    )
    .join('\n');

void main() {
  // The 19 October card day from the field: rest, work, card out, work.
  final cardDay = [
    _a(ActivityType.rest, _z(19, 0), _z(19, 7, 53), counter: 5),
    _a(ActivityType.work, _z(19, 7, 53), _z(19, 8, 5), counter: 5),
    _a(ActivityType.unknown, _z(19, 8, 5), _z(19, 12, 33), counter: 5),
    _a(ActivityType.work, _z(19, 12, 33), _z(20, 0), counter: 5),
  ];

  test('the card file wins over live and manual records on its day', () {
    final log = cardFirstActivityLog(
      cardLog: cardDay,
      downloadedAt: _z(21, 9),
      appLog: [
        _a(ActivityType.available, _z(18, 10), _z(19, 8), manual: true),
        _a(ActivityType.rest, _z(19, 9), _z(19, 11), manual: true),
      ],
    );

    expect(
      _show(log),
      _show([
        // The manual entry keeps only the part before the card day.
        _a(ActivityType.available, _z(18, 10), _z(19, 0), manual: true),
        ...cardDay,
      ]),
    );
  });

  test('app records take over after the download time', () {
    final log = cardFirstActivityLog(
      cardLog: cardDay,
      downloadedAt: _z(19, 14),
      appLog: [
        _a(ActivityType.work, _z(19, 13), _z(19, 15)),
        _a(ActivityType.driving, _z(19, 15), _z(19, 17)),
      ],
    );

    expect(
      _show(log),
      _show([
        ...cardDay.take(3),
        // The card runs its last activity to midnight; it is cut at the
        // download.
        _a(ActivityType.work, _z(19, 12, 33), _z(19, 14)),
        _a(ActivityType.work, _z(19, 14), _z(19, 15)),
        _a(ActivityType.driving, _z(19, 15), _z(19, 17)),
      ]),
    );
  });

  test('a day the card has no record for comes from the app', () {
    final log = cardFirstActivityLog(
      cardLog: cardDay,
      downloadedAt: _z(21, 9),
      appLog: [_a(ActivityType.driving, _z(20, 6), _z(20, 9))],
    );

    expect(log.last.type, ActivityType.driving);
    expect(log.last.startTime, _z(20, 6));
    expect(log.last.endTime, _z(20, 9));
  });

  test('an app record spanning two card days keeps only the gap between', () {
    final log = cardFirstActivityLog(
      cardLog: [
        _a(ActivityType.rest, _z(15, 0), _z(16, 0), counter: 1),
        _a(ActivityType.rest, _z(17, 0), _z(18, 0), counter: 2),
      ],
      downloadedAt: _z(21, 9),
      appLog: [_a(ActivityType.work, _z(15, 20), _z(17, 4), manual: true)],
    );

    final manual = log.where((a) => a.isManualEntry).toList();
    expect(manual, hasLength(1));
    expect(manual.single.startTime, _z(16, 0));
    expect(manual.single.endTime, _z(17, 0));
  });

  test('only the latest record of a date is kept', () {
    final log = cardFirstActivityLog(
      cardLog: [
        _a(ActivityType.driving, _z(12, 0), _z(13, 0), counter: 3),
        _a(ActivityType.rest, _z(12, 0), _z(13, 0), counter: 4),
      ],
      downloadedAt: _z(21, 9),
      appLog: const [],
    );

    expect(log, hasLength(1));
    expect(log.single.type, ActivityType.rest);
  });
}
