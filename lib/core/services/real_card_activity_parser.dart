import 'dart:typed_data';

import 'driving_time_calculator.dart';

class RealCardFileScanner {
  RealCardFileScanner._();

  static const int _efIdentification = 0x0520;
  static const int _efEventsData = 0x0502;
  static const int _efFaultsData = 0x0503;
  static const int _efDriverActivity = 0x0504;
  static const int _efVehiclesUsed = 0x0505;

  /// The Gen1 application's copy of [fid].
  static Uint8List? findBlock(Uint8List data, int fid) => _findBlock(data, fid);

  /// The Gen2 application's copy of [fid], on a Gen2 card. A Gen2 card keeps
  /// both applications: Gen2 units write the Gen2 one, Gen1 units the Gen1
  /// one, so a full picture needs both.
  static Uint8List? findGen2Block(Uint8List data, int fid) =>
      _walk(data)?[(fid, _gen2Data)];

  static const int _gen1Data = 0x00;
  static const int _gen2Data = 0x02;

  /// A card download is a run of elementary files: FID (2), type (1),
  /// length (2), data. Types 0 and 1 are the Gen1 application's data and
  /// signature, 2 and 3 the Gen2 one's (Annex 1C Appendix 7, 3.3). Null
  /// when the file is not such a run end to end.
  static Map<(int, int), Uint8List>? _walk(Uint8List data) {
    final files = <(int, int), Uint8List>{};
    var p = 0;
    while (p + 5 <= data.length) {
      final type = data[p + 2];
      final length = (data[p + 3] << 8) | data[p + 4];
      if (type > 3 || p + 5 + length > data.length) return null;
      files.putIfAbsent((
        (data[p] << 8) | data[p + 1],
        type,
      ), () => Uint8List.sublistView(data, p + 5, p + 5 + length));
      p += 5 + length;
    }
    return p == data.length ? files : null;
  }

  static Uint8List? _findBlock(Uint8List data, int fid) {
    final files = _walk(data);
    if (files != null) return files[(fid, _gen1Data)];

    // Not a clean run of files: search for the header instead.
    final hi = (fid >> 8) & 0xFF;
    final lo = fid & 0xFF;
    for (var offset = 0; offset + 5 <= data.length; offset++) {
      if (data[offset] != hi ||
          data[offset + 1] != lo ||
          data[offset + 2] != _gen1Data)
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

  /// CardDriverActivity: the oldest and the newest day record's offsets
  /// (each where that record *starts*), then a ring buffer of day records -
  /// previous length (2), this length (2), date, presence counter, distance,
  /// ActivityChangeInfo words. A record can run off the end of the buffer
  /// and continue at its start.
  static List<TachographActivity> parse(Uint8List efDriverActivity) {
    if (efDriverActivity.length < 4 + 12) return const [];

    final oldest = (efDriverActivity[0] << 8) | efDriverActivity[1];
    final newest = (efDriverActivity[2] << 8) | efDriverActivity[3];
    final ring = Uint8List.sublistView(efDriverActivity, 4);
    if (oldest >= ring.length || newest >= ring.length) return const [];

    final result = <TachographActivity>[];
    var offset = oldest;
    for (var read = 0; read < _maxDailyRecords; read++) {
      final length =
          (ring[(offset + 2) % ring.length] << 8) |
          ring[(offset + 3) % ring.length];
      if (length < 12 || (length - 12).isOdd || length > ring.length) break;
      final record = Uint8List.fromList([
        for (var i = 0; i < length; i++) ring[(offset + i) % ring.length],
      ]);
      final date = _parseTimeReal(record, 4);
      if (date == null ||
          date.year < _minValidYear ||
          date.year > _maxValidYear) {
        break;
      }

      result.addAll(
        _decodeRecord(
          record,
          DateTime(date.year, date.month, date.day),
          (record[8] << 8) | record[9],
        ),
      );
      if (offset == newest) break;
      offset = (offset + length) % ring.length;
    }

    result.sort((a, b) => a.startTime.compareTo(b.startTime));
    return result;
  }

  /// One day [record], from its first byte.
  static List<TachographActivity> _decodeRecord(
    Uint8List record,
    DateTime dayStart,
    int presenceCounter,
  ) {
    final entryCount = (record.length - 12) ~/ 2;
    final times = <int>[];
    final types = <ActivityType>[];
    final slots = <DriverSlot>[];
    final crews = <bool>[];

    for (var i = 0; i < entryCount; i++) {
      final entryOffset = 12 + i * 2;
      final entryRaw = (record[entryOffset] << 8) | record[entryOffset + 1];

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
          recordPresenceCounter: presenceCounter,
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
