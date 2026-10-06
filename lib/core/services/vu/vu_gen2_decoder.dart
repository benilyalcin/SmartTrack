import 'dart:typed_data';

import '../../models/card_file_details.dart';
import '../../models/vehicle_unit_data.dart';
import 'vu_activity_decoder.dart';
import 'vu_field_codecs.dart';
import 'vu_file_decoder.dart';
import 'vu_speed_decoder.dart';

/// Generation 2 (v1 and v2) vehicle unit downloads, as an ATC 8256 sends
/// them over ITS. Unlike Gen1 every block is a run of RecordArrays -
/// recordType (1), recordSize (2), noOfRecords (2), then the records - so
/// the file is walked by its headers instead of searched (Annex 1C
/// Appendix 7, 2.2.6).
///
/// A record is read by its leading fields, which v1 and v2 share; v2's
/// extra trailing fields, and the certificates and signatures, are skipped.
class VuGen2Decoder {
  VuGen2Decoder._();

  // RecordType values (Appendix 1).
  static const int _activityChangeInfo = 0x01;
  static const int _currentDateTime = 0x03;
  static const int _odometerMidnight = 0x05;
  static const int _dateOfDayDownloaded = 0x06;
  static const int _sensorPairedV1 = 0x07;
  static const int _signature = 0x08;
  static const int _specificCondition = 0x09;
  static const int _vin = 0x0A;
  static const int _vrn = 0x0B;
  static const int _calibration = 0x0C;
  static const int _cardIw = 0x0D;
  static const int _detailedSpeed = 0x12;
  static const int _downloadablePeriod = 0x13;
  static const int _downloadActivity = 0x14;
  static const int _event = 0x15;
  static const int _fault = 0x18;
  static const int _identification = 0x19;
  static const int _overspeedingEvent = 0x1B;
  static const int _placeDailyWorkPeriod = 0x1C;
  static const int _sensorPaired = 0x20;
  static const int _vehicleRegistration = 0x24;

  /// 0x21-0x25 for v1 and 0x31-0x35 for v2, whose detailed speed keeps
  /// v1's 0x24.
  static bool isGen2Trep(int trep) =>
      (trep >= 0x21 && trep <= 0x25) || (trep >= 0x31 && trep <= 0x35);

  static bool handles(Uint8List data) =>
      data.length >= 2 && data[0] == 0x76 && isGen2Trep(data[1]);

  static VehicleUnitData decode(Uint8List data) {
    var vin = '';
    var vrn = '';
    VuOverviewData? overview;
    final names = <String>[];
    final days = <VuDailyActivity>[];
    final eventsAndFaults = <VuEventOrFault>[];
    final overspeeding = <VuOverspeedingEvent>[];
    final speedSessions = <VuSpeedSession>[];
    final calibrations = <VuCalibrationRecord>[];
    VuTechnicalData? technical;

    for (final block in _blocks(data)) {
      switch (block.trep & 0x0F) {
        case 0x01:
          vin = _ia5(block.first(_vin, 17), 0, 17);
          final registration =
              block.first(_vehicleRegistration, 13) ?? block.first(_vrn, 13);
          if (registration != null) {
            vrn = _ia5(registration, registration.length - 13, 13);
          }
          final period = block.first(_downloadablePeriod, 8);
          overview = VuOverviewData(
            currentDateTime: _time(block.first(_currentDateTime, 4), 0),
            downloadablePeriodStart: _time(period, 0),
            downloadablePeriodEnd: _time(period, 4),
          );
          final download = block.first(_downloadActivity, 59);
          if (download != null) names.add(_name(download, 23));
        case 0x02:
          final day = _day(block);
          if (day != null) days.add(day);
        case 0x03:
          eventsAndFaults
            ..addAll(block.each(_event, 87).map((r) => _eventOrFault(r, false)))
            ..addAll(block.each(_fault, 86).map((r) => _eventOrFault(r, true)));
          overspeeding.addAll(
            block.each(_overspeedingEvent, 32).map(_overspeedingEventOf),
          );
        case 0x04:
          final speed = block.arrays[_detailedSpeed];
          if (speed != null && speed.size == 64) {
            speedSessions.addAll(VuSpeedDecoder.decode(speed.bytes));
          }
        case 0x05:
          calibrations.addAll(
            block.each(_calibration, 167).map(_calibrationOf),
          );
          final sensor =
              block.first(_sensorPaired, 28) ??
              block.first(_sensorPairedV1, 28);
          technical = _technical(
            block.first(_identification, 124),
            sensor,
            calibrations.length,
          );
      }
    }

    days.sort((a, b) => b.date.compareTo(a.date));
    int newestFirst(DateTime? a, DateTime? b) =>
        (b ?? DateTime(0)).compareTo(a ?? DateTime(0));
    eventsAndFaults.sort((a, b) => newestFirst(a.beginTime, b.beginTime));
    overspeeding.sort((a, b) => newestFirst(a.beginTime, b.beginTime));
    speedSessions.sort((a, b) => b.start.compareTo(a.start));

    if (technical case final t?) {
      names.addAll([t.manufacturerName, t.manufacturerAddress]);
    }
    for (final c in calibrations) {
      names.addAll([c.workshopName, c.workshopAddress]);
    }

    return VehicleUnitData(
      vin: vin,
      vehicleRegistrationNumber: vrn,
      identificationTexts: VuFileDecoder.buildIdentificationTexts(
        // A unit fills unset names with '?'.
        names
            .where((n) => n.replaceAll('?', '').trim().isNotEmpty)
            .toSet()
            .toList(),
        technical,
        calibrations,
        days,
      ),
      speedSessions: speedSessions,
      dailyActivities: days,
      eventsAndFaults: eventsAndFaults,
      overspeedingEvents: overspeeding,
      calibrationRecords: calibrations,
      technicalData: technical,
      overview: overview,
    );
  }

  /// The blocks in order, each with its RecordArrays by type. A record type
  /// is never 0x76, so a TREP header is told apart from the next array.
  /// Every block ends with its signature; a cut-off file keeps only the
  /// blocks that got that far, not a day with half its records.
  static Iterable<_Block> _blocks(Uint8List data) =>
      _walk(data).where((b) => b.arrays.containsKey(_signature));

  static List<_Block> _walk(Uint8List data) {
    final blocks = <_Block>[];
    _Block? current;
    var p = 0;
    while (p < data.length) {
      if (data[p] == 0x76) {
        if (p + 2 > data.length || !isGen2Trep(data[p + 1])) break;
        current = _Block(data[p + 1]);
        blocks.add(current);
        p += 2;
        continue;
      }
      if (current == null || p + 5 > data.length) break;
      final type = data[p];
      final size = (data[p + 1] << 8) | data[p + 2];
      final count = (data[p + 3] << 8) | data[p + 4];
      final start = p + 5;
      final end = start + size * count;
      if (end > data.length) break;
      current.arrays.putIfAbsent(
        type,
        () => _Records(Uint8List.sublistView(data, start, end), size, count),
      );
      p = end;
    }
    return blocks;
  }

  /// One TREP 0x22/0x32 block: a calendar day.
  static VuDailyActivity? _day(_Block block) {
    final date = _time(block.first(_dateOfDayDownloaded, 4), 0);
    if (date == null) return null;
    final dayStart = DateTime(date.year, date.month, date.day);
    final odometer = block.first(_odometerMidnight, 3);

    return VuDailyActivity(
      date: dayStart,
      odometerMidnightKm: odometer == null ? 0 : _u24(odometer, 0),
      cardSessions: [
        for (final r in block.each(_cardIw, 110))
          VuCardSession(
            surname: _name(r, 0),
            firstName: _name(r, 36),
            cardType: r[72],
            cardNumber: _ia5(r, 74, 16),
            insertionTime: _time(r, 95),
            odometerAtInsertionKm: _u24(r, 99),
            cardSlot: r[102],
            withdrawalTime: _time(r, 103),
            odometerAtWithdrawalKm: _u24(r, 107),
          ),
      ],
      activities: VuActivityDecoder.buildActivities(dayStart, [
        for (final r in block.each(_activityChangeInfo, 2)) _u16(r, 0),
      ]),
      places: [
        // FullCardNumberAndGeneration (19), then the PlaceAuthRecord.
        for (final r in block.each(_placeDailyWorkPeriod, 29))
          if (_time(r, 19) case final entry?)
            PlaceRecord(
              entryTime: entry,
              entryType: r[23],
              countryCode: r[24],
              region: r[25],
              odometerKm: _u24(r, 26),
            ),
      ],
      specificConditions: [
        for (final r in block.each(_specificCondition, 5))
          if (_time(r, 0) case final t?)
            SpecificConditionRecord(time: t, type: r[4]),
      ],
    );
  }

  /// Type, purpose, begin, end, then the four card slots (driver and
  /// co-driver at the begin and at the end); events add a similar-events
  /// count after them.
  static VuEventOrFault _eventOrFault(Uint8List r, bool isFault) =>
      VuEventOrFault(
        type: r[0],
        recordPurpose: r[1],
        isFault: isFault,
        beginTime: _time(r, 2),
        endTime: _time(r, 6),
        driverCardNumber: _cardNumber(r, 10),
        codriverCardNumber: _cardNumber(r, 29),
        similarEventsNumber: isFault ? 0 : r[86],
      );

  static VuOverspeedingEvent _overspeedingEventOf(Uint8List r) =>
      VuOverspeedingEvent(
        beginTime: _time(r, 2),
        endTime: _time(r, 6),
        maxSpeedKmh: r[10],
        avgSpeedKmh: r[11],
        driverCardNumber: _cardNumber(r, 12),
        similarEventsNumber: r[31],
      );

  /// The first 167 bytes, laid out as in Gen1; the sensor, seal and v2
  /// country fields that follow are not read.
  static VuCalibrationRecord _calibrationOf(Uint8List r) => VuCalibrationRecord(
    purpose: r[0],
    workshopName: _name(r, 1),
    workshopAddress: _name(r, 37),
    workshopCardNumber: _cardNumber(r, 73),
    workshopCardExpiryDate: _time(r, 91),
    vin: _ia5(r, 95, 17),
    vrn: _ia5(r, 114, 13),
    tyreCircumferenceMm: _u16(r, 131),
    authorisedSpeedKmh: r[148],
    oldOdometerKm: _u24(r, 149),
    newOdometerKm: _u24(r, 152),
    oldTime: _time(r, 155),
    newTime: _time(r, 159),
    nextCalibrationDate: _time(r, 163),
  );

  /// VuIdentification (name, address, part number, serial, software
  /// version and installation date, manufacturing date, approval) and the
  /// first paired motion sensor (serial, approval, pairing date).
  static VuTechnicalData? _technical(
    Uint8List? id,
    Uint8List? sensor,
    int calibrations,
  ) {
    if (id == null) return null;
    final serial = _Serial(id, 88);
    final sensorSerial = sensor == null ? null : _Serial(sensor, 0);
    return VuTechnicalData(
      manufacturerName: _name(id, 0),
      manufacturerAddress: _name(id, 36),
      partNumber: _ia5(id, 72, 16),
      serialNumber: serial.number,
      serialMonth: serial.month,
      serialYear: serial.year,
      equipmentType: serial.equipmentType,
      manufacturerCode: serial.manufacturerCode,
      softwareVersion: _ia5(id, 96, 4),
      softInstallationDate: _time(id, 100),
      manufacturingDate: _time(id, 104),
      approvalNumber: _ia5(id, 108, 16),
      sensorSerialNumber: sensorSerial?.number ?? 0,
      sensorSerialMonth: sensorSerial?.month ?? 0,
      sensorSerialYear: sensorSerial?.year ?? 0,
      sensorEquipmentType: sensorSerial?.equipmentType ?? 0,
      sensorManufacturerCode: sensorSerial?.manufacturerCode ?? 0,
      sensorApprovalNumber: sensor == null ? '' : _ia5(sensor, 8, 16),
      sensorPairingDateFirst: _time(sensor, 24),
      numberOfCalibrationRecords: calibrations,
    );
  }

  static int _u16(Uint8List r, int o) => (r[o] << 8) | r[o + 1];

  static int _u24(Uint8List r, int o) =>
      (r[o] << 16) | (r[o + 1] << 8) | r[o + 2];

  /// TimeReal; 0 and all-ones mean "not set".
  static DateTime? _time(Uint8List? r, int o) {
    if (r == null || r.length < o + 4) return null;
    final seconds =
        (r[o] << 24) | (r[o + 1] << 16) | (r[o + 2] << 8) | r[o + 3];
    if (seconds == 0 || seconds == 0xFFFFFFFF) return null;
    final t = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    return t.year < 2000 || t.year > 2100 ? null : t;
  }

  static String _ia5(Uint8List? r, int o, int n) => r == null
      ? ''
      : VuFieldCodecs.cleanAsciiText(Uint8List.sublistView(r, o, o + n));

  /// Name: a code page, then 35 bytes.
  static String _name(Uint8List r, int o) => VuFieldCodecs.decodeCodepageText(
    r[o],
    Uint8List.sublistView(r, o + 1, o + 36),
  );

  /// FullCardNumber: card type, issuing state, 16 characters; no card when
  /// the type is 0.
  static String _cardNumber(Uint8List r, int o) =>
      r[o] == 0 ? '' : _ia5(r, o + 2, 16);
}

class _Block {
  _Block(this.trep);

  final int trep;
  final Map<int, _Records> arrays = {};

  /// The records of [type], each long enough for the [minSize] bytes read
  /// from it; none when the unit wrote shorter ones.
  Iterable<Uint8List> each(int type, int minSize) sync* {
    final records = arrays[type];
    if (records == null || records.size < minSize) return;
    for (var i = 0; i < records.count; i++) {
      yield Uint8List.sublistView(
        records.bytes,
        i * records.size,
        (i + 1) * records.size,
      );
    }
  }

  Uint8List? first(int type, int minSize) {
    final it = each(type, minSize).iterator;
    return it.moveNext() ? it.current : null;
  }
}

class _Records {
  _Records(this.bytes, this.size, this.count);

  final Uint8List bytes;
  final int size;
  final int count;
}

/// ExtendedSerialNumber: number (4), month and year (BCD), equipment type,
/// manufacturer code.
class _Serial {
  _Serial(Uint8List r, int o)
    : number = (r[o] << 24) | (r[o + 1] << 16) | (r[o + 2] << 8) | r[o + 3],
      month = VuFieldCodecs.bcdDigits(r[o + 4]) ?? 0,
      year = VuFieldCodecs.bcdDigits(r[o + 5]) ?? 0,
      equipmentType = r[o + 6],
      manufacturerCode = r[o + 7];

  final int number;
  final int month;
  final int year;
  final int equipmentType;
  final int manufacturerCode;
}
