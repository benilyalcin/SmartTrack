import 'dart:typed_data';

import 'driving_time_calculator.dart';

class RealCardFileScanner {
  RealCardFileScanner._();

  static const int _efIdentification = 0x0520;
  static const int _efEventsData = 0x0502;
  static const int _efFaultsData = 0x0503;
  static const int _efDriverActivity = 0x0504;
  static const int _efVehiclesUsed = 0x0505;

  static Uint8List? findBlock(Uint8List data, int fid) => _findBlock(data, fid);

  static Uint8List? _findBlock(Uint8List data, int fid) {
    final hi = (fid >> 8) & 0xFF;
    final lo = fid & 0xFF;
    for (var offset = 0; offset + 5 <= data.length; offset++) {
      if (data[offset] != hi ||
          data[offset + 1] != lo ||
          data[offset + 2] != 0x00)
        continue;
      final length = (data[offset + 3] << 8) | data[offset + 4];
      final dataStart = offset + 5;
      final dataEnd = dataStart + length;
      if (length <= 0 || dataEnd > data.length) continue;
      return Uint8List.sublistView(data, dataStart, dataEnd);
    }
    return null;
  }

  static Uint8List? findDriverActivityBlock(Uint8List data) =>
      _findBlock(data, _efDriverActivity);

  static Uint8List? findIdentificationBlock(Uint8List data) =>
      _findBlock(data, _efIdentification);

  static Uint8List? findEventsBlock(Uint8List data) =>
      _findBlock(data, _efEventsData);

  static Uint8List? findFaultsBlock(Uint8List data) =>
      _findBlock(data, _efFaultsData);

  static Uint8List? findVehiclesUsedBlock(Uint8List data) =>
      _findBlock(data, _efVehiclesUsed);
}

class RealCardActivityParser {
  RealCardActivityParser._();

  static const _minValidYear = 2000;
  static const _maxValidYear = 2100;

  static const _maxDailyRecords = 400;

  static List<TachographActivity> parse(Uint8List efDriverActivity) {
    if (efDriverActivity.length < 4) return const [];

    final oldest = (efDriverActivity[0] << 8) | efDriverActivity[1];
    final newest = (efDriverActivity[2] << 8) | efDriverActivity[3];
    final circularLength = efDriverActivity.length - 4;
    if (oldest < 0 || oldest > circularLength) return const [];

    final raw = <_RawRecord>[];
    if (oldest <= newest) {
      _walkRawRecords(efDriverActivity, 4 + oldest, 4 + newest, raw);
    } else {
      _walkRawRecords(efDriverActivity, 4 + oldest, 4 + circularLength, raw);
      _walkRawRecords(efDriverActivity, 2, 4 + newest, raw);
    }

    final result = <TachographActivity>[];
    for (final r in raw) {
      final dayStart = DateTime(r.date.year, r.date.month, r.date.day);
      result.addAll(_decodeRecord(efDriverActivity, dayStart, r));
    }

    result.sort((a, b) => a.startTime.compareTo(b.startTime));
    return result;
  }

  static void _walkRawRecords(
    Uint8List data,
    int startOffset,
    int stopOffsetExclusive,
    List<_RawRecord> out,
  ) {
    var offset = startOffset;
    var recordsRead = 0;
    while (recordsRead < _maxDailyRecords &&
        offset + 12 <= data.length &&
        offset < stopOffsetExclusive) {
      final recordLength = (data[offset + 2] << 8) | data[offset + 3];
      final date = _parseTimeReal(data, offset + 4);
      final presenceCounter = (data[offset + 8] << 8) | data[offset + 9];

      final headerPlausible =
          recordLength >= 12 &&
          (recordLength - 12) % 2 == 0 &&
          offset + recordLength <= data.length &&
          date != null &&
          date.year >= _minValidYear &&
          date.year <= _maxValidYear;
      if (!headerPlausible) break;

      out.add(
        _RawRecord(
          offset: offset,
          recordLength: recordLength,
          date: date,
          presenceCounter: presenceCounter,
        ),
      );
      offset += recordLength;
      recordsRead++;
    }
  }

  static List<TachographActivity> _decodeRecord(
    Uint8List data,
    DateTime dayStart,
    _RawRecord record,
  ) {
    final entryCount = (record.recordLength - 12) ~/ 2;
    final times = <int>[];
    final types = <ActivityType>[];
    final slots = <DriverSlot>[];
    final crews = <bool>[];

    for (var i = 0; i < entryCount; i++) {
      final entryOffset = record.offset + 12 + i * 2;
      final entryRaw = (data[entryOffset] << 8) | data[entryOffset + 1];

      final slotBit = (entryRaw >> 15) & 0x1;
      final crewBit = (entryRaw >> 14) & 0x1;
      final cardNotInserted = ((entryRaw >> 13) & 0x1) == 1;
      final activityBits = (entryRaw >> 11) & 0x3;
      final minutes = entryRaw & 0x7FF;
      if (minutes > 1439) continue;

      times.add(minutes);

      final manuallyEnteredWhileAbsent = cardNotInserted && crewBit == 1;
      types.add(
        (cardNotInserted && !manuallyEnteredWhileAbsent)
            ? ActivityType.unknown
            : _activityTypeFromBits(activityBits),
      );
      slots.add(slotBit == 0 ? DriverSlot.driver : DriverSlot.coDriver);

      crews.add(!cardNotInserted && crewBit == 1);
    }

    final result = <TachographActivity>[];
    for (var i = 0; i < times.length; i++) {
      final segStart = dayStart.add(Duration(minutes: times[i]));
      final segEnd = i + 1 < times.length
          ? dayStart.add(Duration(minutes: times[i + 1]))
          : dayStart.add(const Duration(days: 1));
      if (!segEnd.isAfter(segStart)) continue;
      result.add(
        TachographActivity(
          type: types[i],
          startTime: segStart,
          endTime: segEnd,
          slot: slots[i],
          isCrew: crews[i],
          recordPresenceCounter: record.presenceCounter,
        ),
      );
    }
    return result;
  }

  static ActivityType _activityTypeFromBits(int bits) {
    switch (bits) {
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

  static DateTime? _parseTimeReal(Uint8List data, int offset) {
    if (offset + 4 > data.length) return null;
    final seconds =
        (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
    if (seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }
}

class _RawRecord {
  const _RawRecord({
    required this.offset,
    required this.recordLength,
    required this.date,
    required this.presenceCounter,
  });

  final int offset;
  final int recordLength;
  final DateTime date;
  final int presenceCounter;
}
