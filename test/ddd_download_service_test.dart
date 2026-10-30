import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/ddd_download_service.dart';

/// A K-line answer in the long form the parsers expect: 80 F0 EE, length,
/// data, checksum.
List<int> _answer(List<int> data) {
  final frame = [0x80, 0xF0, 0xEE, data.length, ...data];
  return [...frame, frame.fold<int>(0, (s, b) => s + b) & 0xFF];
}

/// A bench STC 8255 behind the dongle, playing back the overview of the
/// 19 October reference download (downloadable from 1 June) and holding
/// activities for 15 October only.
class _FakeUnit {
  _FakeUnit(Uint8List reference)
    : overview = reference.sublist(2, 623),
      day15 = reference.sublist(2326, 2472);

  final Uint8List overview;
  final Uint8List day15;
  final activityRequests = <DateTime>[];
  List<List<int>> _pending = [];

  /// Goes silent - its session timed out - when this day is asked.
  DateTime? dropSessionAt;

  /// Stays silent for good once it has dropped the session.
  bool deadAfterDrop = false;
  bool _silent = false;
  int reopens = 0;

  Future<List<int>> call(
    List<int> cmd, {
    int waitMs = 800,
    String label = '',
    int? prefixOverride,
  }) async {
    if (_silent) {
      if (deadAfterDrop) return const [];
      // Only a new session brings it back.
      if (cmd[0] != 0x81) return const [];
      _silent = false;
      reopens++;
    }
    if (cmd[0] == 0x81) return _answer([0xC1, 0xEA, 0x8F]); // StartComm
    final sid = cmd[4];
    switch (sid) {
      case 0x10:
        return _answer([0x50, 0x81]);
      case 0x35:
        return _answer([0x75, 0x00, 0xFF]);
      case 0x36:
        final trtp = cmd[5];
        if (trtp == 0x01) return _send(0x01, overview);
        if (trtp == 0x02) {
          final seconds =
              (cmd[6] << 24) | (cmd[7] << 16) | (cmd[8] << 8) | cmd[9];
          final day = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000,
            isUtc: true,
          );
          activityRequests.add(day);
          if (day == dropSessionAt) {
            dropSessionAt = null;
            _silent = true;
            return const [];
          }
          if (day == DateTime.utc(2026, 10, 15)) return _send(0x02, day15);
          return _answer([0x7F, 0x36, 0xFA]); // dataNotAvailable
        }
        return _answer([0x7F, 0x36, 0x31]);
      case 0x83: // acknowledge: the next sub-message
        return _pending.isEmpty
            ? _answer([0x7F, 0x83, 0x24])
            : _pending.removeAt(0);
      case 0x37:
        return _answer([0x77]);
      case 0x82:
        return _answer([0xC2]);
    }
    return _answer([0x7F, sid, 0x11]);
  }

  /// [payload] as sub-messages of up to 251 bytes, each `76 trtp counter`;
  /// all but the last have the length byte 0xFF.
  List<int> _send(int trtp, Uint8List payload) {
    final messages = <List<int>>[];
    var counter = 1;
    for (var at = 0; at < payload.length; at += 251) {
      final chunk = payload.sublist(
        at,
        at + 251 > payload.length ? payload.length : at + 251,
      );
      final body = [0x76, trtp, counter >> 8, counter & 0xFF, ...chunk];
      final last = at + 251 >= payload.length;
      final frame = [0x80, 0xF0, 0xEE, last ? body.length : 0xFF, ...body];
      messages.add([...frame, frame.fold<int>(0, (s, b) => s + b) & 0xFF]);
      counter++;
    }
    _pending = messages.sublist(1);
    return messages.first;
  }
}

void main() {
  final reference = Uint8List.fromList(
    File('test/fixtures/vu/gen1_stc8255_bench_reference.ddd').readAsBytesSync(),
  );

  test('reads the downloadable period out of the overview', () {
    final period = DddDownloadService.downloadablePeriod(
      Uint8List.sublistView(reference, 0, 623),
    );
    expect(period!.first, DateTime.utc(2026, 6, 1));
    expect(period.last, DateTime.utc(2026, 10, 19, 12, 35, 10));
  });

  test(
    'asks each day of the downloadable period once, today included',
    () async {
      final unit = _FakeUnit(reference);
      final result = await DddDownloadService.instance.downloadAll(
        sendAndReceive: unit.call,
        activityRangeStart: DateTime(2025, 10, 20), // "everything", a year back
        activityRangeEnd: DateTime(2026, 10, 19),
        includeEventsFaults: false,
        includeDetailedSpeed: false,
        includeTechnicalData: false,
      );

      // 1 June to 19 October: 141 days, none before the unit's period and
      // none asked twice for being empty.
      expect(unit.activityRequests, hasLength(141));
      expect(unit.activityRequests.first, DateTime.utc(2026, 6, 1));
      expect(unit.activityRequests.last, DateTime.utc(2026, 10, 19));
      expect(unit.activityRequests.toSet(), hasLength(141));

      // The overview and the one day with data, each behind its header.
      final vu = result.vuBytes!;
      expect(vu.sublist(0, 623), reference.sublist(0, 623));
      expect(vu.sublist(623), reference.sublist(2324, 2472));
    },
  );

  test('a session that times out part way is opened again', () async {
    final unit = _FakeUnit(reference)
      ..dropSessionAt = DateTime.utc(2026, 8, 17);
    final result = await DddDownloadService.instance.downloadAll(
      sendAndReceive: unit.call,
      activityRangeStart: DateTime(2026, 6, 1),
      activityRangeEnd: DateTime(2026, 10, 19),
      includeEventsFaults: false,
      includeDetailedSpeed: false,
      includeTechnicalData: false,
    );

    expect(unit.reopens, 1);
    // 17 August asked twice - unanswered, then in the new session - and
    // every day after it still asked.
    expect(unit.activityRequests, hasLength(142));
    expect(
      unit.activityRequests.where((d) => d == DateTime.utc(2026, 8, 17)),
      hasLength(2),
    );
    expect(unit.activityRequests.last, DateTime.utc(2026, 10, 19));
    expect(result.vuBytes!.sublist(623), reference.sublist(2324, 2472));
  });

  test('a unit gone silent for good is not asked day after day', () async {
    final unit = _FakeUnit(reference)
      ..dropSessionAt = DateTime.utc(2026, 8, 17)
      ..deadAfterDrop = true;
    final result = await DddDownloadService.instance.downloadAll(
      sendAndReceive: unit.call,
      activityRangeStart: DateTime(2026, 6, 1),
      activityRangeEnd: DateTime(2026, 10, 19),
      includeEventsFaults: false,
      includeDetailedSpeed: false,
      includeTechnicalData: false,
    );

    // Up to 17 August, which got no answer; the reopen got none either.
    expect(unit.activityRequests.last, DateTime.utc(2026, 8, 17));
    expect(unit.activityRequests, hasLength(78));
    // What came before is kept.
    expect(result.vuBytes!.sublist(0, 623), reference.sublist(0, 623));
  });
}
