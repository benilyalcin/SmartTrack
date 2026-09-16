import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/vu/vu_byte_reader.dart';

Uint8List _epochBytes(DateTime utc) {
  final seconds = utc.millisecondsSinceEpoch ~/ 1000;
  return Uint8List.fromList([
    (seconds >> 24) & 0xFF,
    (seconds >> 16) & 0xFF,
    (seconds >> 8) & 0xFF,
    seconds & 0xFF,
  ]);
}

void main() {
  group('VuByteReader primitives', () {
    test('reads uint8/16/24/32 big-endian and advances position', () {
      final reader = VuByteReader(
        Uint8List.fromList([
          0x01,
          0x02,
          0x03,
          0x00,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x01,
        ]),
      );
      expect(reader.readUint8(), 0x01);
      expect(reader.readUint16(), 0x0203);
      expect(reader.readUint24(), 0x000001);
      expect(reader.readUint32(), 0x00000001);
      expect(reader.position, 10);
      expect(reader.remaining, 0);
    });

    test('skip and readBytes advance the cursor by exactly n', () {
      final reader = VuByteReader(Uint8List.fromList([1, 2, 3, 4, 5]));
      reader.skip(2);
      expect(reader.readBytes(2), Uint8List.fromList([3, 4]));
      expect(reader.position, 4);
    });

    test('canRead reflects remaining bytes', () {
      final reader = VuByteReader(Uint8List.fromList([1, 2, 3]));
      expect(reader.canRead(3), isTrue);
      expect(reader.canRead(4), isFalse);
      reader.skip(3);
      expect(reader.canRead(1), isFalse);
    });
  });

  group('VuByteReader.readTimeReal', () {
    test('decodes a plausible epoch within the given year range', () {
      final utc = DateTime.utc(2026, 1, 5, 12, 30);
      final reader = VuByteReader(_epochBytes(utc));
      final t = reader.readTimeReal(minYear: 2000, maxYear: 2100);
      expect(t, isNotNull);
      expect(t!.toUtc().year, 2026);
      expect(t.toUtc().month, 1);
      expect(t.toUtc().day, 5);
      expect(reader.position, 4);
    });

    test('rejects a zero epoch but still consumes 4 bytes', () {
      final reader = VuByteReader(Uint8List.fromList([0, 0, 0, 0]));
      expect(reader.readTimeReal(), isNull);
      expect(reader.position, 4);
    });

    test('rejects a year outside the given plausibility window', () {
      final utc = DateTime.utc(1990, 1, 1);
      final reader = VuByteReader(_epochBytes(utc));
      expect(reader.readTimeReal(minYear: 2000, maxYear: 2100), isNull);
      expect(reader.position, 4);
    });
  });
}
