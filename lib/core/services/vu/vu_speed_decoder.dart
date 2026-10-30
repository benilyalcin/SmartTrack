import 'dart:typed_data';

import '../../models/vehicle_unit_data.dart';

class VuSpeedDecoder {
  VuSpeedDecoder._();

  static const int _speedBlockSize = 64;
  static const int _speedBlockHeaderSize = 4;

  static const int _signatureLength = 128;

  /// The detailed speed of a TREP 0x04 block as sessions of consecutive
  /// minutes.
  static List<VuSpeedSession> decode(Uint8List block) =>
      _structured(block) ?? _search(block);

  /// VuDetailedSpeedData by its structure: a count, that many one minute
  /// records (a TimeReal and 60 speeds), the signature. Consecutive minutes
  /// make one session, and a minute on its own is a session too - the
  /// search below needed two in a row and dropped single ones.
  static List<VuSpeedSession>? _structured(Uint8List b) {
    if (b.length < 2) return null;
    final count = (b[0] << 8) | b[1];
    if (2 + count * _speedBlockSize + _signatureLength != b.length) {
      return null;
    }

    final sessions = <VuSpeedSession>[];
    DateTime? runStart;
    DateTime? last;
    var samples = <int>[];
    void close() {
      if (runStart == null || last == null || samples.isEmpty) return;
      final max = samples.reduce((a, b) => a > b ? a : b);
      final total = samples.fold<int>(0, (s, v) => s + v);
      sessions.add(
        VuSpeedSession(
          start: runStart,
          end: last.add(const Duration(minutes: 1)),
          maxSpeedKmh: max,
          avgSpeedKmh: total / samples.length,
          speedSamples: samples,
        ),
      );
    }

    for (var k = 0; k < count; k++) {
      final at = 2 + k * _speedBlockSize;
      final seconds =
          (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
      if (seconds == 0 || seconds == 0xFFFFFFFF) continue;
      final t = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      );
      final continues =
          last != null && t.difference(last) == const Duration(minutes: 1);
      if (!continues) {
        close();
        runStart = t;
        samples = <int>[];
      }
      samples.addAll(
        b.sublist(at + _speedBlockHeaderSize, at + _speedBlockSize),
      );
      last = t;
    }
    close();
    sessions.sort((a, b) => b.start.compareTo(a.start));
    return sessions;
  }

  static List<VuSpeedSession> _search(Uint8List block) {
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
      if (isClaimed(seed) || !stepsByOneMinute(seed, seed + _speedBlockSize)) {
        continue;
      }

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
