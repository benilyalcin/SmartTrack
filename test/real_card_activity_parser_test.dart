import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/core/services/real_card_activity_parser.dart';

List<int> _epochBytes(DateTime utc) {
  final secs = utc.millisecondsSinceEpoch ~/ 1000;
  return [
    (secs >> 24) & 0xFF,
    (secs >> 16) & 0xFF,
    (secs >> 8) & 0xFF,
    secs & 0xFF,
  ];
}

List<int> _changeInfo({
  required int slot,
  required bool crew,
  required int activityBits,
  required int minutes,
}) {
  final raw =
      (slot << 15) |
      ((crew ? 1 : 0) << 14) |
      (activityBits << 11) |
      (minutes & 0x7FF);
  return [(raw >> 8) & 0xFF, raw & 0xFF];
}

List<int> _dailyRecord(
  DateTime dayNoonUtc,
  List<List<int>> entries, {
  int counter = 1,
}) {
  final entryBytes = entries.expand((e) => e).toList();
  final recordLength = 12 + entryBytes.length;
  return [
    0x00,
    0x00,
    (recordLength >> 8) & 0xFF,
    recordLength & 0xFF,
    ..._epochBytes(dayNoonUtc),
    (counter >> 8) & 0xFF,
    counter & 0xFF,
    0x00,
    0x64,
    ...entryBytes,
  ];
}

Uint8List _driverActivityEf(List<List<int>> records) {
  const oldest = 0;
  final circular = records.expand((r) => r).toList();
  final newest = circular.length;
  return Uint8List.fromList([
    (oldest >> 8) & 0xFF,
    oldest & 0xFF,
    (newest >> 8) & 0xFF,
    newest & 0xFF,
    ...circular,
  ]);
}

List<int> _efBlock(int fid, List<int> value) {
  return [
    (fid >> 8) & 0xFF,
    fid & 0xFF,
    0x00,
    (value.length >> 8) & 0xFF,
    value.length & 0xFF,
    ...value,
  ];
}

void main() {
  group('RealCardFileScanner.findDriverActivityBlock', () {
    test(
      'isolates EF_Driver_Activity_Data (0x0504) among other elementary files',
      () {
        final activityValue = [0xAA, 0xBB, 0xCC];
        final full = Uint8List.fromList([
          ..._efBlock(0x0520, [0x01, 0x02]),
          ..._efBlock(0x0504, activityValue),
          ..._efBlock(0x0502, [0x03]),
        ]);

        final found = RealCardFileScanner.findDriverActivityBlock(full);
        expect(found, isNotNull);
        expect(found, activityValue);
      },
    );

    test('returns null when there is no matching EF at all', () {
      final full = Uint8List.fromList(_efBlock(0x0520, [0x01, 0x02]));
      expect(RealCardFileScanner.findDriverActivityBlock(full), isNull);
    });

    test(
      'returns null (not a false match) for this app\'s own custom simulator tag format',
      () {
        final simulatorStyle = Uint8List.fromList([
          0x01,
          0x05,
          0x41,
          0x42,
          0x43,
          0x44,
          0x45,
        ]);
        expect(
          RealCardFileScanner.findDriverActivityBlock(simulatorStyle),
          isNull,
        );
      },
    );
  });

  group('RealCardActivityParser.parse', () {
    test(
      'decodes a single day of ActivityChangeInfo entries into real segments',
      () {
        final day = DateTime.utc(2025, 6, 15, 12);
        final entries = [
          _changeInfo(slot: 0, crew: false, activityBits: 3, minutes: 480),
          _changeInfo(slot: 0, crew: false, activityBits: 0, minutes: 600),
          _changeInfo(slot: 1, crew: false, activityBits: 2, minutes: 700),
        ];
        final ef = _driverActivityEf([_dailyRecord(day, entries)]);

        final segments = RealCardActivityParser.parse(ef);

        expect(segments.length, 3);
        expect(segments[0].type, ActivityType.driving);
        expect(segments[0].slot, DriverSlot.driver);
        expect(segments[0].startTime, DateTime(2025, 6, 15, 8, 0));
        expect(segments[0].endTime, DateTime(2025, 6, 15, 10, 0));

        expect(segments[1].type, ActivityType.rest);
        expect(segments[1].startTime, DateTime(2025, 6, 15, 10, 0));
        expect(segments[1].endTime, DateTime(2025, 6, 15, 11, 40));

        expect(segments[2].type, ActivityType.work);
        expect(segments[2].slot, DriverSlot.coDriver);
        expect(segments[2].startTime, DateTime(2025, 6, 15, 11, 40));

        expect(segments[2].endTime, DateTime(2025, 6, 16, 0, 0));
      },
    );

    test(
      'the decoded day fully covers 00:00-24:00 with no gaps (gap-fill safety check)',
      () {
        final day = DateTime.utc(2025, 6, 15, 12);
        final entries = [
          _changeInfo(slot: 0, crew: false, activityBits: 0, minutes: 0),
          _changeInfo(slot: 0, crew: false, activityBits: 3, minutes: 480),
        ];
        final ef = _driverActivityEf([_dailyRecord(day, entries)]);
        final segments = RealCardActivityParser.parse(ef);

        final dayStart = DateTime(2025, 6, 15);
        final dayEnd = DateTime(2025, 6, 16);
        expect(
          DrivingTimeCalculator.segmentsFullyCoverRange(
            segments,
            dayStart,
            dayEnd,
          ),
          isTrue,
        );
      },
    );

    test('two consecutive daily records both get decoded', () {
      final day1 = DateTime.utc(2025, 6, 15, 12);
      final day2 = DateTime.utc(2025, 6, 16, 12);
      final record1 = _dailyRecord(day1, [
        _changeInfo(slot: 0, crew: false, activityBits: 3, minutes: 480),
      ]);
      final record2 = _dailyRecord(day2, [
        _changeInfo(slot: 0, crew: false, activityBits: 0, minutes: 0),
      ]);
      final ef = _driverActivityEf([record1, record2]);

      final segments = RealCardActivityParser.parse(ef);
      expect(segments.length, 2);
      expect(segments[0].startTime.day, 15);
      expect(segments[1].startTime.day, 16);
    });

    test(
      'an empty/erased buffer (all zero bytes) decodes to no segments instead of throwing',
      () {
        final ef = Uint8List(64);
        expect(() => RealCardActivityParser.parse(ef), returnsNormally);
        expect(RealCardActivityParser.parse(ef), isEmpty);
      },
    );

    test(
      'a long chain of records spanning years is read in full, not just its tail',
      () {
        final days = [
          DateTime.utc(2024, 4, 15, 12),
          DateTime.utc(2024, 4, 16, 12),
          DateTime.utc(2025, 11, 24, 12),
          DateTime.utc(2025, 11, 25, 12),
          DateTime.utc(2026, 6, 18, 12),
          DateTime.utc(2026, 7, 23, 12),
        ];
        final records = days
            .map(
              (d) => _dailyRecord(d, [
                _changeInfo(slot: 0, crew: false, activityBits: 0, minutes: 0),
              ]),
            )
            .toList();
        final ef = _driverActivityEf(records);

        final segments = RealCardActivityParser.parse(ef);
        final foundDays = segments
            .map(
              (s) =>
                  '${s.startTime.year}-${s.startTime.month}-${s.startTime.day}',
            )
            .toSet();
        expect(
          foundDays,
          days.map((d) => '${d.year}-${d.month}-${d.day}').toSet(),
        );
      },
    );

    test(
      'a record claiming a length longer than the buffer is rejected, not read out of bounds',
      () {
        final malformed = Uint8List.fromList([
          0x00,
          0x00,
          0x00,
          0x0C,
          0x00,
          0x00,
          0xFF,
          0xFF,
          ..._epochBytes(DateTime.utc(2025, 6, 15, 12)),
          0x00,
          0x01,
          0x00,
          0x64,
        ]);
        expect(() => RealCardActivityParser.parse(malformed), returnsNormally);
        expect(RealCardActivityParser.parse(malformed), isEmpty);
      },
    );

    test(
      'two records for the same calendar date are both kept, not collapsed into one',
      () {
        final day = DateTime.utc(2025, 3, 10, 12);
        final morningRecord = _dailyRecord(day, [
          _changeInfo(slot: 0, crew: false, activityBits: 0, minutes: 0),
        ], counter: 3);
        final laterRecord = _dailyRecord(day, [
          _changeInfo(slot: 0, crew: false, activityBits: 3, minutes: 480),
        ], counter: 9);
        final ef = _driverActivityEf([morningRecord, laterRecord]);

        final segments = RealCardActivityParser.parse(ef);

        expect(segments.length, 2);
        expect(
          segments.any(
            (s) => s.type == ActivityType.rest && s.startTime.hour == 0,
          ),
          isTrue,
        );
        expect(
          segments.any(
            (s) => s.type == ActivityType.driving && s.startTime.hour == 8,
          ),
          isTrue,
        );
      },
    );

    test(
      'wrapped buffer (oldest > newest): tail + head both decoded, the evicted gap between them is not',
      () {
        final tailDate = DateTime.utc(2025, 1, 5, 12);
        final headDate = DateTime.utc(2025, 1, 8, 12);
        final staleDate = DateTime.utc(2024, 6, 1, 12);

        final headEntryBytes = _changeInfo(
          slot: 0,
          crew: false,
          activityBits: 0,
          minutes: 0,
        );
        const headRecordLength = 12 + 2;
        const headCounter = 5;
        final headBodyFrom4 = [
          (headRecordLength >> 8) & 0xFF,
          headRecordLength & 0xFF,
          ..._epochBytes(headDate),
          (headCounter >> 8) & 0xFF,
          headCounter & 0xFF,
          0x00,
          0x64,
          ...headEntryBytes,
        ];
        const newest = headRecordLength - 2;

        final staleBytes = _dailyRecord(staleDate, [
          _changeInfo(slot: 0, crew: false, activityBits: 0, minutes: 0),
        ]);
        final tailBytes = _dailyRecord(tailDate, [
          _changeInfo(slot: 0, crew: false, activityBits: 1, minutes: 360),
        ], counter: 3);
        final oldest = (2 + headRecordLength + staleBytes.length) - 4;

        final ef = Uint8List.fromList([
          (oldest >> 8) & 0xFF,
          oldest & 0xFF,
          (newest >> 8) & 0xFF,
          newest & 0xFF,
          ...headBodyFrom4,
          ...staleBytes,
          ...tailBytes,
        ]);

        final segments = RealCardActivityParser.parse(ef);
        final foundDates = segments
            .map(
              (s) => DateTime(
                s.startTime.year,
                s.startTime.month,
                s.startTime.day,
              ),
            )
            .toSet();

        expect(foundDates, {DateTime(2025, 1, 5), DateTime(2025, 1, 8)});
        expect(foundDates.contains(DateTime(2024, 6, 1)), isFalse);
      },
    );
  });
}
