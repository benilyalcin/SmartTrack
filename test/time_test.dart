import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/services/time/display_time.dart';
import 'package:smarttrack_mine/core/services/time/legacy_time_migration.dart';
import 'package:smarttrack_mine/core/services/time/tacho_clock.dart';

void main() {
  group('TachoClock', () {
    test('uses the phone clock in UTC before a first reading', () {
      final phone = DateTime.utc(2026, 11, 18, 10);
      final clock = TachoClock(phoneNow: () => phone);
      expect(clock.isSynced, isFalse);
      expect(clock.nowUtc(), phone);
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('keeps the offset of a reading and applies it later', () {
      var phone = DateTime.utc(2026, 11, 18, 10);
      final clock = TachoClock(phoneNow: () => phone);
      // The unit runs 90 s behind the phone.
      clock.sync(DateTime.utc(2026, 11, 18, 9, 58, 30));
      phone = phone.add(const Duration(hours: 2));
      expect(clock.nowUtc(), DateTime.utc(2026, 11, 18, 11, 58, 30));
    });

    test('a local phone time gives the same instant', () {
      final clock = TachoClock()..restore(const Duration(seconds: 5));
      final local = DateTime(2026, 11, 18, 13);
      expect(
        clock.toUnitTime(local),
        local.toUtc().add(const Duration(seconds: 5)),
      );
    });
  });

  group('DisplayTime (UTC+3)', () {
    const display = DisplayTime(Duration(hours: 3));

    test('a display day spans two UTC days', () {
      final range = display.dayRangeUtc(DateTime(2026, 11, 18));
      expect(range.start, DateTime.utc(2026, 11, 17, 21));
      expect(range.end, DateTime.utc(2026, 11, 18, 21));
    });

    test('a UTC record late in the day shows on the next display day', () {
      final instant = DateTime.utc(2026, 11, 17, 22, 30);
      expect(display.displayDay(instant), DateTime.utc(2026, 11, 18));
      expect(display.hm(instant), '01:30');
    });

    test('a segment across UTC midnight falls in one display day', () {
      // 20:00-23:00 UTC is 23:00-02:00 display: it crosses display midnight,
      // not the UTC one's display day.
      final start = DateTime.utc(2026, 11, 17, 20);
      final end = DateTime.utc(2026, 11, 17, 23);
      final day17 = display.dayRangeUtc(DateTime(2026, 11, 17));
      final day18 = display.dayRangeUtc(DateTime(2026, 11, 18));
      expect(start.isBefore(day17.end) && end.isAfter(day17.start), isTrue);
      expect(start.isBefore(day18.end) && end.isAfter(day18.start), isTrue);
    });

    test('a day query looks one UTC day either side', () {
      expect(display.utcDaysToQuery(DateTime(2026, 11, 18)), [
        DateTime.utc(2026, 11, 16),
        DateTime.utc(2026, 11, 17),
        DateTime.utc(2026, 11, 18),
        DateTime.utc(2026, 11, 19),
      ]);
    });

    test('month ends are calendar days', () {
      final range = display.dayRangeUtc(DateTime(2026, 10, 31));
      expect(range.end, DateTime.utc(2026, 10, 31, 21));
    });
  });

  group('LegacyTimeMigration', () {
    setUp(LegacyTimeMigration.resetForTest);

    final legacy = {
      'liveActivityLog': jsonEncode([
        {
          'type': 2,
          'start': '2026-10-19T10:59:00.000',
          'end': '2026-10-19T11:01:00.000',
        },
      ]),
      'manualActivityEntries': jsonEncode([
        {
          'type': 1,
          'start': '2026-10-18T13:02:00.000',
          'end': '2026-10-19T10:59:00.000',
          'note': null,
        },
      ]),
      'lastKnownActivityTime': '2026-10-19T16:25:00.000',
      'ddd_files_index': jsonEncode([
        {
          'id': 'a',
          'downloadedAt': '2026-10-19T16:30:00.000',
          'trashedAt': null,
        },
      ]),
      'liveComplianceSnapshot': jsonEncode({
        'lastDailyRestEnd': '2026-10-19T07:53:00.000',
        'totalBreakTimeMs': 1000,
      }),
    };

    test('local times are read as Istanbul, unit times as UTC', () {
      final out = LegacyTimeMigration.convert(
        legacy,
        legacyOffset: const Duration(hours: 3),
      );
      final live = jsonDecode(out['liveActivityLog']!) as List;
      expect(live.single['start'], '2026-10-19T07:59:00.000Z');
      expect(live.single['type'], 2);
      expect(out['lastKnownActivityTime'], '2026-10-19T13:25:00.000Z');
      final index = jsonDecode(out['ddd_files_index']!) as List;
      expect(index.single['downloadedAt'], '2026-10-19T13:30:00.000Z');
      expect(index.single['trashedAt'], isNull);
      final compliance = jsonDecode(out['liveComplianceSnapshot']!) as Map;
      expect(compliance['lastDailyRestEnd'], '2026-10-19T07:53:00.000Z');
      expect(compliance['totalBreakTimeMs'], 1000);
    });

    test('running it on migrated values changes nothing', () {
      final once = LegacyTimeMigration.convert(
        legacy,
        legacyOffset: const Duration(hours: 3),
      );
      final twice = LegacyTimeMigration.convert({
        ...legacy,
        ...once,
      }, legacyOffset: const Duration(hours: 3));
      expect(twice, isEmpty);
    });

    test('runs once, keeps a backup and can be rolled back', () async {
      SharedPreferences.setMockInitialValues(legacy);
      final prefs = await SharedPreferences.getInstance();
      final files = <String, String>{};

      final changed = await LegacyTimeMigration.run(
        prefs,
        writeFile: (name, contents) async {
          files[name] = contents;
          return name;
        },
      );
      expect(changed, contains('liveActivityLog'));
      expect(prefs.getString('lastKnownActivityTime'), endsWith('Z'));
      expect(files, hasLength(1));
      expect(
        (jsonDecode(files.values.single) as Map)['lastKnownActivityTime'],
        '2026-10-19T16:25:00.000',
      );

      // A second start does nothing.
      expect(await LegacyTimeMigration.run(prefs), isEmpty);

      expect(await LegacyTimeMigration.rollback(prefs), isTrue);
      expect(
        prefs.getString('lastKnownActivityTime'),
        '2026-10-19T16:25:00.000',
      );
      expect(prefs.getString('liveActivityLog'), legacy['liveActivityLog']);
      // And it stays undone.
      expect(await LegacyTimeMigration.run(prefs), isEmpty);
      expect(
        prefs.getString('lastKnownActivityTime'),
        '2026-10-19T16:25:00.000',
      );
    });
  });
}
