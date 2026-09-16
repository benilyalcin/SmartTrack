import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/core/services/vu/vu_activity_decoder.dart';

Uint8List _dayRecord(DateTime utcMidnight, {Uint8List? signature}) {
  final seconds = utcMidnight.millisecondsSinceEpoch ~/ 1000;
  final builder = BytesBuilder();
  builder.add([
    (seconds >> 24) & 0xFF,
    (seconds >> 16) & 0xFF,
    (seconds >> 8) & 0xFF,
    seconds & 0xFF,
  ]);
  builder.add([0, 0, 0]);
  builder.add([0, 0]);
  builder.add([0, 0]);
  builder.add([0]);
  builder.add([0, 0]);
  builder.add(signature ?? Uint8List(128));
  return builder.takeBytes();
}

Uint8List _dayRecordWithChanges(
  DateTime utcMidnight,
  List<(DriverSlot, int, int)> changes,
) {
  final seconds = utcMidnight.millisecondsSinceEpoch ~/ 1000;
  final builder = BytesBuilder();
  builder.add([
    (seconds >> 24) & 0xFF,
    (seconds >> 16) & 0xFF,
    (seconds >> 8) & 0xFF,
    seconds & 0xFF,
  ]);
  builder.add([0, 0, 0]);
  builder.add([0, 0]);
  builder.add([(changes.length >> 8) & 0xFF, changes.length & 0xFF]);
  for (final (slot, minutes, workType) in changes) {
    final slotBit = slot == DriverSlot.coDriver ? 1 : 0;
    final raw = (slotBit << 15) | (workType << 11) | (minutes & 0x7FF);
    builder.add([(raw >> 8) & 0xFF, raw & 0xFF]);
  }
  builder.add([0]);
  builder.add([0, 0]);
  builder.add(Uint8List(128));
  return builder.takeBytes();
}

void main() {
  group('VuActivityDecoder.decodeFromStream', () {
    test('decodes a single marked day', () {
      final data = Uint8List.fromList([
        0x76,
        0x02,
        ..._dayRecord(DateTime.utc(2026, 6, 24)),
      ]);
      final days = VuActivityDecoder.decodeFromStream(
        data,
        0,
        referenceNow: DateTime.utc(2026, 7, 1),
      );
      expect(days, hasLength(1));

      expect(days[0].date, DateTime(2026, 6, 24));
    });

    test(
      'a coincidental 76-02 byte pair inside one day\'s own signature does not split it',
      () {
        final poisonedSignature = Uint8List(128);
        poisonedSignature[60] = 0x76;
        poisonedSignature[61] = 0x02;

        final day1 = _dayRecord(
          DateTime.utc(2026, 6, 24),
          signature: poisonedSignature,
        );
        final day2 = _dayRecord(DateTime.utc(2026, 6, 25));
        final data = Uint8List.fromList([
          0x76,
          0x02,
          ...day1,
          0x76,
          0x02,
          ...day2,
        ]);

        final days = VuActivityDecoder.decodeFromStream(
          data,
          0,
          referenceNow: DateTime.utc(2026, 7, 1),
        );
        expect(days, hasLength(2));
        expect(
          days.map((d) => d.date),
          containsAll([DateTime(2026, 6, 24), DateTime(2026, 6, 25)]),
        );
      },
    );

    test(
      'a corrupted middle day is skipped, later valid days are still recovered',
      () {
        final day1 = _dayRecord(DateTime.utc(2026, 6, 24));
        final day2 = _dayRecord(DateTime.utc(2026, 6, 25));
        final day3 = _dayRecord(DateTime.utc(2026, 6, 26));
        final garbage = Uint8List.fromList(
          List.generate(150, (i) => (i * 37 + 5) % 256),
        );

        final data = Uint8List.fromList([
          0x76,
          0x02,
          ...day1,
          0x76,
          0x02,
          ...garbage,
          0x76,
          0x02,
          ...day2,
          0x76,
          0x02,
          ...day3,
        ]);

        final days = VuActivityDecoder.decodeFromStream(
          data,
          0,
          referenceNow: DateTime.utc(2026, 7, 1),
        );
        expect(
          days.map((d) => d.date),
          containsAll([
            DateTime(2026, 6, 24),
            DateTime(2026, 6, 25),
            DateTime(2026, 6, 26),
          ]),
        );
      },
    );

    test(
      'an anchor hint landing before the real start still finds the true first day',
      () {
        final unrelatedBytes = Uint8List.fromList(
          List.generate(50, (i) => (i * 91 + 3) % 256),
        );
        final day1 = _dayRecord(DateTime.utc(2026, 6, 24));
        final data = Uint8List.fromList([
          ...unrelatedBytes,
          0x76,
          0x02,
          ...day1,
        ]);

        final days = VuActivityDecoder.decodeFromStream(
          data,
          0,
          referenceNow: DateTime.utc(2026, 7, 1),
        );
        expect(days, hasLength(1));
        expect(days[0].date, DateTime(2026, 6, 24));
      },
    );

    test('returns an empty list when nothing in the buffer validates', () {
      final data = Uint8List.fromList(List.generate(100, (i) => i % 256));
      expect(VuActivityDecoder.decodeFromStream(data, 0), isEmpty);
    });

    test(
      'a lone mandatory co-driver opening entry does not produce a co-driver activity',
      () {
        final day = _dayRecordWithChanges(DateTime.utc(2026, 6, 24), [
          (DriverSlot.driver, 0, 0),
          (DriverSlot.coDriver, 0, 0),
        ]);
        final data = Uint8List.fromList([0x76, 0x02, ...day]);
        final days = VuActivityDecoder.decodeFromStream(
          data,
          0,
          referenceNow: DateTime.utc(2026, 7, 1),
        );
        expect(days, hasLength(1));
        expect(
          days[0].activities.any((a) => a.slot == DriverSlot.coDriver),
          isFalse,
        );

        expect(
          days[0].activities.any((a) => a.slot == DriverSlot.driver),
          isTrue,
        );
      },
    );

    test(
      'genuine multi-entry co-driver activity is kept, with correct per-slot segment boundaries',
      () {
        final day = _dayRecordWithChanges(DateTime.utc(2026, 6, 24), [
          (DriverSlot.driver, 0, 0),
          (DriverSlot.coDriver, 0, 0),
          (DriverSlot.coDriver, 5 * 60, 3),
          (DriverSlot.driver, 8 * 60, 3),
          (DriverSlot.coDriver, 10 * 60, 0),
        ]);
        final data = Uint8List.fromList([0x76, 0x02, ...day]);
        final days = VuActivityDecoder.decodeFromStream(
          data,
          0,
          referenceNow: DateTime.utc(2026, 7, 1),
        );
        expect(days, hasLength(1));

        final driverActs =
            days[0].activities
                .where((a) => a.slot == DriverSlot.driver)
                .toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));
        expect(driverActs, hasLength(2));
        expect(driverActs[0].type, ActivityType.rest);
        expect(driverActs[0].endTime, DateTime(2026, 6, 24, 8));
        expect(driverActs[1].type, ActivityType.driving);

        final coDriverActs =
            days[0].activities
                .where((a) => a.slot == DriverSlot.coDriver)
                .toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));
        expect(coDriverActs, hasLength(3));
        expect(coDriverActs[0].type, ActivityType.rest);
        expect(coDriverActs[0].endTime, DateTime(2026, 6, 24, 5));
        expect(coDriverActs[1].type, ActivityType.driving);
        expect(coDriverActs[1].startTime, DateTime(2026, 6, 24, 5));
        expect(coDriverActs[1].endTime, DateTime(2026, 6, 24, 10));
        expect(coDriverActs[2].type, ActivityType.rest);
        expect(coDriverActs[2].startTime, DateTime(2026, 6, 24, 10));
      },
    );
  });
}
