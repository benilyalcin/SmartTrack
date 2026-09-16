import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/vu/vu_block_framer.dart';

void main() {
  group('VuBlockFramer.locateBlocks', () {
    test('finds a single block and its end is EOF', () {
      final data = Uint8List.fromList([0x76, 0x01, 10, 20, 30]);
      final ranges = VuBlockFramer.locateBlocks(data);
      expect(ranges, hasLength(1));
      expect(ranges[0].trep, 0x01);
      expect(ranges[0].start, 2);
      expect(ranges[0].end, 5);
      expect(ranges[0].length, 3);
    });

    test('a block ends where the next marker starts', () {
      final data = Uint8List.fromList([
        0x76,
        0x01,
        10,
        20,
        0x76,
        0x02,
        30,
        40,
        50,
      ]);
      final ranges = VuBlockFramer.locateBlocks(data);
      expect(ranges, hasLength(2));
      expect(ranges[0].trep, 0x01);
      expect(ranges[0].start, 2);
      expect(ranges[0].end, 4);
      expect(ranges[1].trep, 0x02);
      expect(ranges[1].start, 6);
      expect(ranges[1].end, 9);
    });

    test('TREP=02 (Activities) legitimately repeats once per day', () {
      final data = Uint8List.fromList([
        0x76,
        0x02,
        1,
        2,
        3,
        0x76,
        0x02,
        4,
        5,
        0x76,
        0x02,
        6,
      ]);
      final ranges = VuBlockFramer.locateBlocks(data);
      expect(ranges, hasLength(3));
      expect(ranges.every((r) => r.trep == 0x02), isTrue);
      expect(ranges[0].length, 3);
      expect(ranges[1].length, 2);
      expect(ranges[2].length, 1);
    });

    test('returns an empty list for a file with no markers at all', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(VuBlockFramer.locateBlocks(data), isEmpty);
    });

    test('does not treat an out-of-range second byte as a marker', () {
      final data = Uint8List.fromList([0x76, 0x07, 1, 2, 3]);
      expect(VuBlockFramer.locateBlocks(data), isEmpty);
    });
  });

  group('VuBlockFramer.slicesFor', () {
    test('returns one slice per matching-TREP range, in file order', () {
      final data = Uint8List.fromList([
        0x76,
        0x02,
        1,
        2,
        0x76,
        0x01,
        9,
        0x76,
        0x02,
        3,
      ]);
      final ranges = VuBlockFramer.locateBlocks(data);
      final daySlices = VuBlockFramer.slicesFor(data, ranges, 0x02);
      expect(daySlices, hasLength(2));
      expect(daySlices[0], Uint8List.fromList([1, 2]));
      expect(daySlices[1], Uint8List.fromList([3]));
    });

    test('returns an empty list when no range matches the requested TREP', () {
      final data = Uint8List.fromList([0x76, 0x01, 9]);
      final ranges = VuBlockFramer.locateBlocks(data);
      expect(VuBlockFramer.slicesFor(data, ranges, 0x05), isEmpty);
    });
  });
}
