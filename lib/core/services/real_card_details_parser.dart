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

  static CardFileDetails parse(Uint8List rawBytes) {
    final downloadBlock = RealCardFileScanner.findBlock(
      rawBytes,
      _efCardDownload,
    );
    final lastDownloadDate = downloadBlock != null && downloadBlock.length >= 4
        ? _timeReal(downloadBlock, 0)
        : null;

    var authority = '';
    var licenceNumber = '';
    final licenceBlock = RealCardFileScanner.findBlock(
      rawBytes,
      _efDrivingLicenceInfo,
    );
    if (licenceBlock != null && licenceBlock.length >= 53) {
      authority = _ia5(licenceBlock, 1, 35);
      licenceNumber = _ia5(licenceBlock, 37, 16);
    }

    DateTime? sessionOpenTime;
    var currentVehicle = '';
    final usageBlock = RealCardFileScanner.findBlock(rawBytes, _efCurrentUsage);
    if (usageBlock != null && usageBlock.length >= 19) {
      sessionOpenTime = _timeReal(usageBlock, 0);
      currentVehicle = _ia5(usageBlock, 6, 13);
    }

    ControlActivityRecord? control;
    final controlBlock = RealCardFileScanner.findBlock(
      rawBytes,
      _efControlActivityData,
    );
    if (controlBlock != null && controlBlock.length >= 46) {
      final controlTime = _timeReal(controlBlock, 1);

      if (controlTime != null) {
        control = ControlActivityRecord(
          controlType: controlBlock[0],
          controlTime: controlTime,
          controlCardNumber: _ia5(controlBlock, 5, 18),
          controlVehicleRegistration: _ia5(controlBlock, 25, 13),
          downloadPeriodBegin: _timeReal(controlBlock, 38),
          downloadPeriodEnd: _timeReal(controlBlock, 42),
        );
      }
    }

    var vehicleRecords = const <VehicleUsageRecord>[];
    final vehiclesBlock = RealCardFileScanner.findBlock(
      rawBytes,
      _efVehiclesUsed,
    );
    if (vehiclesBlock != null) {
      vehicleRecords = RealCardVehicleUsedParser.allRecords(vehiclesBlock);
    }

    final places = <PlaceRecord>[];
    final placesBlock = RealCardFileScanner.findBlock(rawBytes, _efPlaces);
    if (placesBlock != null && placesBlock.length > 1) {
      final body = Uint8List.sublistView(placesBlock, 1);
      for (var offset = 0; offset + 10 <= body.length; offset += 10) {
        final entryTime = _timeReal(body, offset);
        if (entryTime == null) continue;
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
      places.sort((a, b) => b.entryTime!.compareTo(a.entryTime!));
    }

    final specificConditions = <SpecificConditionRecord>[];
    final scBlock = RealCardFileScanner.findBlock(
      rawBytes,
      _efSpecificConditions,
    );
    if (scBlock != null) {
      for (var offset = 0; offset + 5 <= scBlock.length; offset += 5) {
        final time = _timeReal(scBlock, offset);
        if (time == null) continue;
        specificConditions.add(
          SpecificConditionRecord(time: time, type: scBlock[offset + 4]),
        );
      }
      specificConditions.sort((a, b) => a.time!.compareTo(b.time!));
    }

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
