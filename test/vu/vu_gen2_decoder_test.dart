import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/core/services/vu/vu_file_decoder.dart';
import 'package:smarttrack_mine/core/services/vu/vu_gen2_decoder.dart';

void main() {
  // A Gen2 v2 download from the bench ATC 8256 (2026-10-06): overview,
  // two days of activities, events, detailed speed and technical data.
  final bench = File('test/fixtures/vu/gen2_v2_bench.ddd').readAsBytesSync();

  group('VuGen2Decoder', () {
    test('recognises Gen2 v1 and v2 TREPs, not Gen1', () {
      expect(VuGen2Decoder.handles(Uint8List.fromList([0x76, 0x31])), isTrue);
      expect(VuGen2Decoder.handles(Uint8List.fromList([0x76, 0x21])), isTrue);
      expect(VuGen2Decoder.handles(Uint8List.fromList([0x76, 0x01])), isFalse);
      expect(VuGen2Decoder.handles(bench), isTrue);
    });

    test('overview: vehicle and downloadable period', () {
      final vu = VuFileDecoder.decode(bench);
      expect(vu.vin, '88888888888888888');
      expect(vu.vehicleRegistrationNumber, 'BKARATAS');
      expect(
        vu.overview!.currentDateTime,
        DateTime.utc(2026, 10, 6, 14, 25, 5),
      );
      expect(vu.overview!.downloadablePeriodStart, DateTime.utc(2026, 9, 29));
    });

    test('activities: days, card session, activity changes and place', () {
      final days = VuFileDecoder.decode(bench).dailyActivities;
      expect(days.map((d) => d.date), [
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 5),
      ]);

      final day = days[1];
      final session = day.cardSessions.single;
      expect(session.cardNumber, 'UTO2011124032000');
      expect(session.surname, 'Driver 11124032');
      expect(session.cardType, 1);
      expect(session.cardSlot, 0);
      expect(session.insertionTime, DateTime.utc(2026, 10, 5, 17, 40, 2));
      expect(session.withdrawalTime, DateTime.utc(2026, 10, 6, 13, 9, 48));

      expect(day.activities.map((a) => a.type), [
        ActivityType.rest,
        ActivityType.rest,
        ActivityType.work,
        ActivityType.rest,
      ]);
      expect(day.activities[2].startTime, DateTime(2026, 10, 5, 17, 44));
      expect(day.activities[2].endTime, DateTime(2026, 10, 5, 19, 11));

      final place = day.places.single;
      expect(place.entryTime, DateTime.utc(2026, 10, 5, 17, 40));
      expect(place.countryCode, 0x05);
    });

    test('events, detailed speed and technical data', () {
      final vu = VuFileDecoder.decode(bench);
      expect(vu.eventsAndFaults, hasLength(54));
      final newest = vu.eventsAndFaults.first;
      expect(newest.type, 1);
      expect(newest.driverCardNumber, 'UTO2011124032000');
      expect(newest.codriverCardNumber, '');

      expect(vu.speedSessions, hasLength(3));
      expect(vu.speedSessions.first.maxSpeedKmh, 100);

      final t = vu.technicalData!;
      expect(t.manufacturerName, 'ASELSAN Elektronik San ve Tic AS');
      // Code page 9: ISO 8859-9.
      expect(t.manufacturerAddress, 'İstiklal Marşı Cad. Ankara 06200 TR');
      expect(t.partNumber, '5820-8255-141x');
      expect(t.sensorSerialNumber, 0x056CE71B);
      expect(t.sensorPairingDateFirst, DateTime.utc(2026, 10, 1, 12, 57, 59));
      expect(t.numberOfCalibrationRecords, 4);

      final calibration = vu.calibrationRecords[1];
      expect(calibration.purpose, 2);
      expect(calibration.workshopName, 'UTOPIA Workshop 22013034');
      expect(calibration.workshopCardNumber, 'UTO2022013034000');
      expect(calibration.vrn, 'BKARATAS');
    });

    test('names are labelled by source; unset ones are left out', () {
      final texts = VuFileDecoder.decode(bench).identificationTexts;
      expect(
        texts.map((t) => t.text),
        isNot(contains(predicate<String>((s) => s.startsWith('???')))),
      );
      expect(
        texts.firstWhere((t) => t.text.startsWith('ASELSAN')).sourceLabelKey,
        'ddd.identitySourceManufacturer',
      );
      expect(
        texts.firstWhere((t) => t.text.startsWith('UTOPIA W')).sourceLabelKey,
        'ddd.identitySourceWorkshop',
      );
    });

    test('a cut-off file keeps the blocks that arrived whole', () {
      // The first day's block ends at 1278.
      final vu = VuFileDecoder.decode(Uint8List.sublistView(bench, 0, 1300));
      expect(vu.vehicleRegistrationNumber, 'BKARATAS');
      expect(vu.dailyActivities, hasLength(1));
      expect(vu.eventsAndFaults, isEmpty);
    });
  });
}
