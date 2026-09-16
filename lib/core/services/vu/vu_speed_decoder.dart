import 'dart:typed_data';

import '../../models/vehicle_unit_data.dart';

class VuSpeedDecoder {
  VuSpeedDecoder._();

  static const int _speedBlockSize = 64;
  static const int _speedBlockHeaderSize = 4;

  static List<VuSpeedSession> decode(Uint8List block) {
    DateTime? blockTime(int offset) {
      if (offset + _speedBlockHeaderSize > block.length) return null;
      final seconds =
          (block[offset] << 24) |
          (block[offset + 1] << 16) |
          (block[offset + 2] << 8) |
          block[offset + 3];
      if (seconds <= 0) return null;
      final t = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      );
      return (t.year >= 2015 && t.year <= 2035) ? t : null;
    }

    bool stepsByOneMinute(int fromOffset, int toOffset) {
      final a = blockTime(fromOffset);
      final b = blockTime(toOffset);
      if (a == null || b == null) return false;
      return b.difference(a) == const Duration(minutes: 1);
    }

    final claimed = List<bool>.filled(
      (block.length ~/ _speedBlockSize) + 1,
      false,
    );
    bool isClaimed(int offset) => claimed[offset ~/ _speedBlockSize];
    void claim(int offset) => claimed[offset ~/ _speedBlockSize] = true;

    final sessions = <VuSpeedSession>[];
    for (var seed = 0; seed + _speedBlockSize <= block.length; seed++) {
      if (isClaimed(seed) || !stepsByOneMinute(seed, seed + _speedBlockSize))
        continue;

      var start = seed;
      while (start - _speedBlockSize >= 0 &&
          stepsByOneMinute(start - _speedBlockSize, start)) {
        start -= _speedBlockSize;
      }
      var end = seed;
      while (end + _speedBlockSize <= block.length &&
          stepsByOneMinute(end, end + _speedBlockSize)) {
        end += _speedBlockSize;
      }
      end += _speedBlockSize;

      var maxSpeed = 0;
      var totalSpeed = 0;
      var sampleCount = 0;
      final samples = <int>[];
      for (var offset = start; offset < end; offset += _speedBlockSize) {
        claim(offset);
        for (
          var s = offset + _speedBlockHeaderSize;
          s < offset + _speedBlockSize;
          s++
        ) {
          final speed = block[s];
          if (speed > maxSpeed) maxSpeed = speed;
          totalSpeed += speed;
          sampleCount++;
          samples.add(speed);
        }
      }

      sessions.add(
        VuSpeedSession(
          start: blockTime(start)!,
          end: blockTime(
            end - _speedBlockSize,
          )!.add(const Duration(minutes: 1)),
          maxSpeedKmh: maxSpeed,
          avgSpeedKmh: sampleCount > 0 ? totalSpeed / sampleCount : 0,
          speedSamples: samples,
        ),
      );
    }

    sessions.sort((a, b) => b.start.compareTo(a.start));
    return sessions;
  }
}
