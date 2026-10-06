import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/core/services/real_card_activity_parser.dart';
import 'package:smarttrack_mine/core/services/real_card_details_parser.dart';
import 'package:smarttrack_mine/core/services/tachograph_parser.dart';

void main() {
  // A Gen2 driver card downloaded from the bench ATC 8256 (2026-10-06). It
  // carries both applications: Gen2 with this week's use, Gen1 with what a
  // Gen1 unit wrote in 2025.
  final card = File(
    'test/fixtures/card/gen2_driver_bench.ddd',
  ).readAsBytesSync();

  group('Gen2 driver card', () {
    test('the files are walked: Gen1 and Gen2 copies are told apart', () {
      final gen2 = RealCardFileScanner.findGen2Block(card, 0x0504)!;
      final gen1 = RealCardFileScanner.findBlock(card, 0x0504)!;
      expect(gen2.length, 13780);
      expect(gen1.length, 13780);
      expect(gen1.offsetInBytes, isNot(gen2.offsetInBytes));
      // Each one's first day record: 2021 in Gen2, 2025 in Gen1.
      int year(Uint8List ef) => DateTime.fromMillisecondsSinceEpoch(
        ((ef[8] << 24) | (ef[9] << 16) | (ef[10] << 8) | ef[11]) * 1000,
        isUtc: true,
      ).year;
      expect(year(gen2), 2021);
      expect(year(gen1), 2025);
    });

    test('identity, and the newest day is not dropped', () {
      final parsed = DddFileParser().parse(card);
      expect(parsed.cardNumber, 'UTO2011124032000');
      expect(parsed.holderSurname, 'Driver 11124032');
      expect(parsed.vehicleRegistration, 'BKARATAS');

      DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);
      final days = parsed.activityLog.map((a) => day(a.startTime)).toSet();
      // Gen2's days, newest included, and Gen1's older ones.
      expect(
        days,
        containsAll([
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 6),
          DateTime(2025, 1, 17),
        ]),
      );

      final work = parsed.activityLog.firstWhere(
        (a) => a.type == ActivityType.work && a.startTime.day == 5,
        orElse: () => throw StateError('no work on the 5th'),
      );
      expect(work.startTime, DateTime(2026, 10, 5, 14, 14));
      expect(
        parsed.activityLog.any(
          (a) =>
              a.type == ActivityType.work &&
              a.startTime == DateTime(2026, 10, 5, 17, 44) &&
              a.endTime == DateTime(2026, 10, 5, 19, 11),
        ),
        isTrue,
      );
    });

    test('events come from both applications; empty fault files give none', () {
      final parsed = DddFileParser().parse(card);
      expect(parsed.lastEvents, isNotEmpty);
      expect(parsed.lastEvents.first.timestamp.year, 2026);
      expect(parsed.lastFaults, isEmpty);
    });

    test('details: Gen2 single records, merged lists', () {
      final d = RealCardDetailsParser.parse(card);
      expect(d.lastDownloadDate, DateTime.utc(2026, 10, 5, 19, 46, 27));
      expect(d.drivingLicenceNumber, 'DL11124032');
      expect(d.currentUsageVehicleRegistration, 'BKARATAS');
      expect(
        d.currentUsageSessionOpenTime,
        DateTime.utc(2026, 10, 6, 15, 39, 44),
      );

      final control = d.lastControlActivity!;
      expect(control.controlTime, DateTime.utc(2026, 10, 6, 15, 33, 13));
      expect(control.controlCardNumber, 'UTO2032013022000');
      expect(control.controlVehicleRegistration, 'BKARATAS');

      expect(d.vehicleRecords.first.vehicleRegistration, 'BKARATAS');
      expect(
        d.vehicleRecords.map((v) => v.vehicleRegistration),
        contains('4563245'),
      );
      expect(d.places.first.entryTime, DateTime.utc(2026, 10, 6, 15, 39));
      expect(d.specificConditions, hasLength(4));
    });

    test(
      'a file that is not a clean run of files still falls back to search',
      () {
        final noisy = Uint8List.fromList([0xAA, ...card]);
        expect(RealCardFileScanner.findGen2Block(noisy, 0x0504), isNull);
        expect(RealCardFileScanner.findBlock(noisy, 0x0504), isNotNull);
      },
    );
  });
}
