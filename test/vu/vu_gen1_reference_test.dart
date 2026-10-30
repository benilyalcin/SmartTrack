import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/core/services/tachograph_parser.dart';
import 'package:smarttrack_mine/core/services/vu/vu_block_framer.dart';
import 'package:smarttrack_mine/core/services/vu/vu_file_decoder.dart';

/// Downloads of the STC 8255 bench unit on 19 October 2026: one made with
/// the vendor's tool (reference), one by the app through the dongle 50
/// minutes later. Both were checked byte for byte and against an
/// independent Annex 1B/1C decode; what the app shows has to match it.
Uint8List _fixture(String path) =>
    Uint8List.fromList(File('test/fixtures/$path').readAsBytesSync());

void main() {
  final reference = _fixture('vu/gen1_stc8255_bench_reference.ddd');
  final appDownload = _fixture('vu/gen1_stc8255_bench_app.ddd');
  final workshopCard = _fixture('card/gen1_workshop_bench.ddd');

  group('block framing', () {
    test('walks the blocks by their structure, end to end', () {
      final ranges = VuBlockFramer.walkBlocks(reference)!;
      expect(
        [for (final r in ranges) (r.trep, r.start, r.end)],
        [
          (1, 2, 623),
          (2, 625, 771),
          (2, 773, 1350),
          (2, 1352, 1762),
          (2, 1764, 2324),
          (2, 2326, 2472),
          (2, 2474, 3047),
          (3, 3049, 6091),
          (4, 6093, 6415),
          (5, 6417, 7350),
        ],
      );
    });

    test('a 76 04 inside an activity day is not a speed block', () {
      // Offset 1224 holds the pair inside 14 September's change words.
      expect(reference[1224], 0x76);
      expect(reference[1225], 0x04);
      final speed = VuBlockFramer.locateBlocks(
        reference,
      ).where((r) => r.trep == 4);
      expect([for (final r in speed) r.start], [6093]);
    });
  });

  group('vehicle unit', () {
    final vu = VuFileDecoder.decode(reference);

    test('an unset VIN and plate stay empty, the times are read', () {
      expect(vu.vin, isEmpty);
      expect(vu.vehicleRegistrationNumber, isEmpty);
      expect(
        vu.overview!.currentDateTime,
        DateTime.utc(2026, 10, 19, 12, 35, 10),
      );
      expect(vu.overview!.downloadablePeriodStart, DateTime.utc(2026, 6, 1));
      expect(
        vu.overview!.downloadablePeriodEnd,
        DateTime.utc(2026, 10, 19, 12, 35, 10),
      );
    });

    test('a card number in the download record is not taken for the VIN', () {
      final app = VuFileDecoder.decode(appDownload);
      expect(app.vin, isEmpty);
      expect(
        app.overview!.currentDateTime,
        DateTime.utc(2026, 10, 19, 13, 25, 21),
      );
    });

    test('every fault and event is read', () {
      final faults = vu.eventsAndFaults.where((e) => e.isFault).toList();
      final events = vu.eventsAndFaults.where((e) => !e.isFault).toList();
      expect(faults, hasLength(19));
      expect(faults.where((f) => f.type == 0x30), hasLength(9));
      expect(faults.where((f) => f.type == 0x31), hasLength(10));
      expect(events, hasLength(15));
      // A power interruption from before the clock was set keeps its time.
      expect(
        events.where((e) => e.beginTime == DateTime.utc(2000, 1, 1, 0, 0, 12)),
        hasLength(2),
      );
    });

    test('detailed speed: a lone minute is a session of its own', () {
      final sessions = vu.speedSessions.reversed.toList();
      expect(sessions, hasLength(2));
      expect(sessions[0].start, DateTime.utc(2026, 10, 19, 7, 53));
      expect(sessions[0].end, DateTime.utc(2026, 10, 19, 7, 54));
      expect(sessions[0].maxSpeedKmh, 18);
      expect(sessions[1].start, DateTime.utc(2026, 10, 19, 7, 55));
      expect(sessions[1].end, DateTime.utc(2026, 10, 19, 7, 57));
      expect(sessions[1].maxSpeedKmh, 30);
    });

    test('all six activity days are there', () {
      expect(
        [
          for (final d in vu.dailyActivities)
            '${d.date.year}-${d.date.month}-${d.date.day}',
        ]..sort(),
        [
          '2026-10-12',
          '2026-10-15',
          '2026-10-19',
          '2026-6-1',
          '2026-9-14',
          '2026-9-15',
        ],
      );
    });

    test('activity minutes count from 00:00 UTC', () {
      final day = vu.dailyActivities.firstWhere(
        (d) => d.date.month == 10 && d.date.day == 19,
      );
      final driver = day.activities
          .where((a) => a.slot == DriverSlot.driver)
          .toList();
      expect(driver.first.type, ActivityType.rest);
      expect(driver.first.startTime, DateTime.utc(2026, 10, 19));
      expect(driver[1].type, ActivityType.work);
      expect(driver[1].startTime, DateTime.utc(2026, 10, 19, 7, 53));

      // The card went in at 07:57:11 UTC, and the change word that records
      // it says 07:57: both on the same clock.
      final insertion = day.cardSessions
          .map((s) => s.insertionTime)
          .whereType<DateTime>()
          .firstWhere((t) => t.hour == 7 && t.minute == 57);
      final change = driver.firstWhere(
        (a) => a.startTime == DateTime.utc(2026, 10, 19, 7, 57),
      );
      expect(insertion.difference(change.startTime).inSeconds, 11);
    });
  });

  group('workshop card', () {
    final card = DddFileParser().parse(workshopCard);

    test('identification', () {
      expect(card.cardNumber, '8799431347953000');
      expect(card.holderSurname, 'Smarttrack Tek. ve Tic. A.S.');
    });

    test('activity minutes count from 00:00 UTC', () {
      // 14 September: card not inserted from 00:00, rest at 08:23, card
      // out again at 08:24 - all UTC.
      final rest = card.activityLog.firstWhere(
        (a) =>
            a.type == ActivityType.rest &&
            a.startTime.isAtSameMomentAs(DateTime.utc(2026, 9, 14, 8, 23)),
      );
      expect(rest.endTime, DateTime.utc(2026, 9, 14, 8, 24));
    });
  });
}
