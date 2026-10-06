import 'dart:convert';
import 'dart:typed_data';

import '../models/card_file_details.dart';
import 'real_card_activity_parser.dart';
import 'real_card_identification_parser.dart';

class RealCardDetailsParser {
  RealCardDetailsParser._();

  static const int _efCardDownload = 0x050E;
  static const int _efDrivingLicenceInfo = 0x0521;
  static const int _efCurrentUsage = 0x0507;
  static const int _efControlActivityData = 0x0508;
  static const int _efPlaces = 0x0506;
  static const int _efSpecificConditions = 0x0522;
  static const int _efVehiclesUsed = 0x0505;

  /// On a Gen2 card a single record is taken from the Gen2 application when
  /// it has one, and lists are merged from both (see
  /// [RealCardFileScanner.findGen2Block]).
  static CardFileDetails parse(Uint8List rawBytes) {
    Uint8List? gen1(int fid) => RealCardFileScanner.findBlock(rawBytes, fid);
    Uint8List? gen2(int fid) =>
        RealCardFileScanner.findGen2Block(rawBytes, fid);
    Uint8List? either(int fid) => gen2(fid) ?? gen1(fid);

    final downloadBlock = either(_efCardDownload);
    final lastDownloadDate = downloadBlock != null && downloadBlock.length >= 4
        ? _timeReal(downloadBlock, 0)
        : null;

    var authority = '';
    var licenceNumber = '';
    final licenceBlock = either(_efDrivingLicenceInfo);
    if (licenceBlock != null && licenceBlock.length >= 53) {
      authority = _ia5(licenceBlock, 1, 35);
      licenceNumber = _ia5(licenceBlock, 37, 16);
    }

    DateTime? sessionOpenTime;
    var currentVehicle = '';
    final usageBlock = either(_efCurrentUsage);
    if (usageBlock != null && usageBlock.length >= 19) {
      sessionOpenTime = _timeReal(usageBlock, 0);
      currentVehicle = _ia5(usageBlock, 6, 13);
    }

    ControlActivityRecord? control;
    final controlBlock = either(_efControlActivityData);
    if (controlBlock != null && controlBlock.length >= 46) {
      final controlTime = _timeReal(controlBlock, 1);

      if (controlTime != null) {
        control = ControlActivityRecord(
          controlType: controlBlock[0],
          controlTime: controlTime,
          // FullCardNumber: card type and issuing state, then the number.
          controlCardNumber: _ia5(controlBlock, 7, 16),
          controlVehicleRegistration: _ia5(controlBlock, 25, 13),
          downloadPeriodBegin: _timeReal(controlBlock, 38),
          downloadPeriodEnd: _timeReal(controlBlock, 42),
        );
      }
    }

    final seenVehicles = <(String, DateTime?)>{};
    final vehicleRecords =
        [
          for (final (block, size) in [
            (gen2(_efVehiclesUsed), RealCardVehicleUsedParser.gen2RecordSize),
            (gen1(_efVehiclesUsed), RealCardVehicleUsedParser.gen1RecordSize),
          ])
            if (block != null)
              for (final v in RealCardVehicleUsedParser.allRecords(
                block,
                recordSize: size,
              ))
                if (seenVehicles.add((v.vehicleRegistration, v.firstUse))) v,
        ]..sort(
          (a, b) =>
              (b.firstUse ?? DateTime(0)).compareTo(a.firstUse ?? DateTime(0)),
        );

    // Gen1: a one-byte pointer, then 10-byte PlaceRecords. Gen2: a two-byte
    // pointer, and each record adds a GNSS position (21 bytes).
    final seenPlaces = <(DateTime, int)>{};
    final places = <PlaceRecord>[];
    for (final (block, header, size) in [
      (gen2(_efPlaces), 2, 21),
      (gen1(_efPlaces), 1, 10),
    ]) {
      if (block == null || block.length <= header) continue;
      final body = Uint8List.sublistView(block, header);
      for (var offset = 0; offset + size <= body.length; offset += size) {
        final entryTime = _timeReal(body, offset);
        if (entryTime == null) continue;
        if (!seenPlaces.add((entryTime, body[offset + 4]))) continue;
        places.add(
          PlaceRecord(
            entryTime: entryTime,
            entryType: body[offset + 4],
            countryCode: body[offset + 5],
            region: body[offset + 6],
            odometerKm:
                (body[offset + 7] << 16) |
                (body[offset + 8] << 8) |
                body[offset + 9],
          ),
        );
      }
    }
    places.sort((a, b) => b.entryTime!.compareTo(a.entryTime!));

    // Gen2 puts a two-byte pointer before the 5-byte records.
    final seenConditions = <(DateTime, int)>{};
    final specificConditions = <SpecificConditionRecord>[];
    for (final (block, header) in [
      (gen2(_efSpecificConditions), 2),
      (gen1(_efSpecificConditions), 0),
    ]) {
      if (block == null) continue;
      for (var offset = header; offset + 5 <= block.length; offset += 5) {
        final time = _timeReal(block, offset);
        if (time == null) continue;
        if (!seenConditions.add((time, block[offset + 4]))) continue;
        specificConditions.add(
          SpecificConditionRecord(time: time, type: block[offset + 4]),
        );
      }
    }
    specificConditions.sort((a, b) => a.time!.compareTo(b.time!));

    return CardFileDetails(
      lastDownloadDate: lastDownloadDate,
      drivingLicenceAuthority: authority,
      drivingLicenceNumber: licenceNumber,
      currentUsageSessionOpenTime: sessionOpenTime,
      currentUsageVehicleRegistration: currentVehicle,
      lastControlActivity: control,
      vehicleRecords: vehicleRecords,
      places: places,
      specificConditions: specificConditions,
    );
  }

  static String _ia5(Uint8List data, int offset, int length) {
    if (offset + length > data.length) return '';
    final slice = Uint8List.sublistView(data, offset, offset + length);
    return latin1
        .decode(slice, allowInvalid: true)
        .replaceAll('\x00', '')
        .replaceAll('\xff', '')
        .trim();
  }

  static DateTime? _timeReal(Uint8List data, int offset) {
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
