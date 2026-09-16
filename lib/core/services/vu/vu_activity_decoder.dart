import 'dart:typed_data';

import '../../models/card_file_details.dart';
import '../../models/vehicle_unit_data.dart';
import '../driving_time_calculator.dart';
import 'vu_byte_reader.dart';
import 'vu_field_codecs.dart';

class VuActivityDecoder {
  VuActivityDecoder._();

  static const int _signatureLength = 128;
  static const int _maxCardIwRecords = 50;
  static const int _maxActivityChanges = 2000;
  static const int _maxPlaceRecords = 112;
  static const int _maxSpecificConditions = 56;

  static const int _maxDaysInPast = 400;

  static const int _maxDaysInFuture = 60;

  static List<VuDailyActivity> decodeFromStream(
    Uint8List data,
    int searchFrom, {
    DateTime? referenceNow,
  }) {
    final now = (referenceNow ?? DateTime.now()).toUtc();
    int? pos = _findFirstValidDayStart(data, searchFrom, now);
    if (pos == null) return const [];
    final days = <VuDailyActivity>[];
    while (pos != null && pos + 7 <= data.length) {
      final result = _tryParseDay(data, pos, now);
      if (result == null) {
        pos = _findFirstValidDayStart(data, pos + 1, now);
        continue;
      }
      days.add(result.day);
      final end = pos + result.recordLength;
      if (end <= pos) break;
      if (end + 1 < data.length &&
          data[end] == 0x76 &&
          data[end + 1] >= 0x01 &&
          data[end + 1] <= 0x06) {
        if (data[end + 1] != 0x02) break;
        pos = end + 2;
      } else {
        pos = end;
      }
    }
    days.sort((a, b) => b.date.compareTo(a.date));
    return days;
  }

  static int? _findFirstValidDayStart(Uint8List data, int from, DateTime now) {
    for (
      var offset = from < 0 ? 0 : from;
      offset + 7 <= data.length;
      offset++
    ) {
      if (_tryParseDay(data, offset, now) != null) return offset;
    }
    return null;
  }

  static List<VuDailyActivity> decodeConcatenated(
    Uint8List data, {
    DateTime? referenceNow,
  }) {
    final now = (referenceNow ?? DateTime.now()).toUtc();
    final days = <VuDailyActivity>[];
    var offset = 0;
    while (offset + 7 <= data.length) {
      final result = _tryParseDay(data, offset, now);
      if (result == null) break;
      days.add(result.day);
      final next = offset + result.recordLength;
      if (next <= offset) break;
      offset = next;
    }
    return days;
  }

  static ({VuDailyActivity day, int recordLength})? _tryParseDay(
    Uint8List data,
    int offset,
    DateTime now,
  ) {
    final reader = VuByteReader(data, offset);
    if (!reader.canRead(4)) return null;
    final rawEpoch = reader.readRawEpochSeconds();

    if (rawEpoch <= 0 || rawEpoch % 86400 != 0) return null;
    final date = _plausibleRecentDate(rawEpoch, now);
    if (date == null) return null;

    if (!reader.canRead(3)) return null;
    final odometerMidnight = reader.readUint24();

    if (!reader.canRead(2)) return null;
    final noOfIw = reader.readUint16();
    if (noOfIw > _maxCardIwRecords) return null;

    final sessions = <VuCardSession>[];
    for (var i = 0; i < noOfIw; i++) {
      const recordWidth = 36 + 36 + 18 + 4 + 4 + 3 + 1 + 4 + 3 + 15 + 4 + 1;
      if (!reader.canRead(recordWidth)) return null;

      final surname = _readCardName(reader.readBytes(36));
      final firstName = _readCardName(reader.readBytes(36));

      final cardType = reader.readUint8();
      reader.skip(1);
      final cardNumber = VuFieldCodecs.cleanAsciiText(reader.readBytes(16));

      reader.skip(4);
      final insertionTime = _tightTimeReal(reader, now);
      final odoAtInsertion = reader.readUint24();
      final slot = reader.readUint8();
      final withdrawalTime = _tightTimeReal(reader, now);
      final odoAtWithdrawal = reader.readUint24();
      reader.skip(15 + 4);
      reader.skip(1);

      sessions.add(
        VuCardSession(
          surname: surname,
          firstName: firstName,
          cardNumber: cardNumber,
          insertionTime: insertionTime,
          withdrawalTime: withdrawalTime,
          odometerAtInsertionKm: odoAtInsertion,
          odometerAtWithdrawalKm: odoAtWithdrawal,
          cardSlot: slot,
          cardType: cardType,
        ),
      );
    }

    if (!reader.canRead(2)) return null;
    final noOfActivityChanges = reader.readUint16();
    if (noOfActivityChanges > _maxActivityChanges) return null;
    if (!reader.canRead(noOfActivityChanges * 2)) return null;

    final dayStart = DateTime(date.year, date.month, date.day);
    final minutesList = <int>[];
    final types = <ActivityType>[];
    final slots = <DriverSlot>[];
    final crews = <bool>[];
    final cardInsertedFlags = <bool>[];
    for (var i = 0; i < noOfActivityChanges; i++) {
      final raw = reader.readUint16();
      final minutes = raw & 0x7FF;
      if (minutes > 1439) continue;
      final slotBit = (raw >> 15) & 1;
      final crewBit = (raw >> 14) & 1;

      final cardStatusBit = (raw >> 13) & 1;
      final workType = (raw >> 11) & 0x3;
      minutesList.add(minutes);
      types.add(_activityTypeFromWorkType(workType));
      slots.add(slotBit == 0 ? DriverSlot.driver : DriverSlot.coDriver);
      crews.add(crewBit == 1);
      cardInsertedFlags.add(cardStatusBit == 0);
    }

    final activities = <TachographActivity>[];
    for (final targetSlot in DriverSlot.values) {
      final indices = [
        for (var i = 0; i < minutesList.length; i++)
          if (slots[i] == targetSlot) i,
      ];

      if (targetSlot == DriverSlot.coDriver && indices.length < 2) continue;
      for (var k = 0; k < indices.length; k++) {
        final i = indices[k];
        final segStart = dayStart.add(Duration(minutes: minutesList[i]));
        final segEnd = k + 1 < indices.length
            ? dayStart.add(Duration(minutes: minutesList[indices[k + 1]]))
            : dayStart.add(const Duration(days: 1));
        if (!segEnd.isAfter(segStart)) continue;
        activities.add(
          TachographActivity(
            type: types[i],
            startTime: segStart,
            endTime: segEnd,
            slot: slots[i],
            isCrew: crews[i],
            cardInserted: cardInsertedFlags[i],
          ),
        );
      }
    }
    activities.sort((a, b) => a.startTime.compareTo(b.startTime));

    if (!reader.canRead(1)) return null;
    final noOfPlaces = reader.readUint8();
    if (noOfPlaces > _maxPlaceRecords) return null;
    final places = <PlaceRecord>[];
    for (var i = 0; i < noOfPlaces; i++) {
      const placeRecordWidth = 18 + 10;
      if (!reader.canRead(placeRecordWidth)) return null;
      reader.skip(18);
      final entryTime = _tightTimeReal(reader, now);
      final entryType = reader.readUint8();
      final country = reader.readUint8();
      final region = reader.readUint8();
      final placeOdometer = reader.readUint24();
      if (entryTime != null) {
        places.add(
          PlaceRecord(
            entryTime: entryTime,
            entryType: entryType,
            countryCode: country,
            region: region,
            odometerKm: placeOdometer,
          ),
        );
      }
    }

    if (!reader.canRead(2)) return null;
    final noOfSpecificConditions = reader.readUint16();
    if (noOfSpecificConditions > _maxSpecificConditions) return null;
    if (!reader.canRead(noOfSpecificConditions * 5)) return null;
    final specificConditions = <SpecificConditionRecord>[];
    for (var i = 0; i < noOfSpecificConditions; i++) {
      final t = _tightTimeReal(reader, now);
      final type = reader.readUint8();
      if (t != null)
        specificConditions.add(SpecificConditionRecord(time: t, type: type));
    }

    if (!reader.canRead(_signatureLength)) return null;
    reader.skip(_signatureLength);

    return (
      day: VuDailyActivity(
        date: dayStart,
        odometerMidnightKm: odometerMidnight,
        cardSessions: sessions,
        activities: activities,
        places: places,
        specificConditions: specificConditions,
      ),
      recordLength: reader.position - offset,
    );
  }

  static ActivityType _activityTypeFromWorkType(int workType) {
    switch (workType) {
      case 0:
        return ActivityType.rest;
      case 1:
        return ActivityType.available;
      case 2:
        return ActivityType.work;
      case 3:
      default:
        return ActivityType.driving;
    }
  }

  static String _readCardName(Uint8List slice) {
    return VuFieldCodecs.cleanAsciiText(Uint8List.sublistView(slice, 1, 36));
  }

  static DateTime? _tightTimeReal(VuByteReader reader, DateTime now) {
    if (!reader.canRead(4)) return null;
    final seconds = reader.readUint32();
    return _plausibleRecentDate(seconds, now);
  }

  static DateTime? _plausibleRecentDate(int seconds, DateTime now) {
    if (seconds <= 0) return null;
    final t = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    if (t.isAfter(now.add(const Duration(days: _maxDaysInFuture)))) return null;
    if (now.difference(t).inDays > _maxDaysInPast) return null;
    return t;
  }
}
