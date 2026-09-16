import 'dart:typed_data';

import '../../models/vehicle_unit_data.dart';
import 'vu_byte_reader.dart';
import 'vu_field_codecs.dart';

class VuTechnicalDecoder {
  VuTechnicalDecoder._();

  static const int _vuIdentificationWidth = 116;
  static const int _sensorPairedWidth = 20;
  static const int _blockHeaderWidth =
      _vuIdentificationWidth + _sensorPairedWidth + 1;
  static const int _calibrationRecordWidth = 167;

  static ({
    VuTechnicalData technicalData,
    List<VuCalibrationRecord> calibrationRecords,
  })?
  decode(Uint8List block) {
    for (var offset = 0; offset + _blockHeaderWidth <= block.length; offset++) {
      final result = _tryParseAt(block, offset);
      if (result != null) return result;
    }
    return null;
  }

  static ({
    VuTechnicalData technicalData,
    List<VuCalibrationRecord> calibrationRecords,
  })?
  _tryParseAt(Uint8List data, int offset) {
    final reader = VuByteReader(data, offset);

    final mfgName = _tryReadName(reader);
    if (mfgName == null) return null;

    final mfgAddress = _tryReadName(reader);
    if (mfgAddress == null) return null;

    final partNumber = _tryReadIa5(reader, 16);
    if (partNumber == null) return null;

    final serial = _tryReadExtendedSerial(reader);
    if (serial == null) return null;

    final softwareVersion = _tryReadIa5(reader, 4);
    if (softwareVersion == null) return null;

    final softInstallationDate = _timeReal(reader);
    final manufacturingDate = _timeReal(reader);
    if (manufacturingDate == null) return null;

    final approvalNumber = _tryReadIa5(reader, 8);
    if (approvalNumber == null) return null;

    final sensorSerial = _tryReadExtendedSerial(reader);
    if (sensorSerial == null) return null;

    final sensorApprovalNumber = _tryReadIa5(reader, 8);
    if (sensorApprovalNumber == null) return null;

    final sensorPairingDateFirst = _timeReal(reader);
    if (sensorPairingDateFirst == null) return null;

    if (!reader.canRead(1)) return null;
    final calibrationCount = reader.readUint8();

    if (calibrationCount == 0 || calibrationCount > 30) return null;

    final firstRecord = _tryParseCalibration(data, reader.position);
    if (firstRecord == null) return null;

    final calibrationRecords = <VuCalibrationRecord>[firstRecord];
    var pos = reader.position + _calibrationRecordWidth;
    for (var i = 1; i < calibrationCount; i++) {
      final next = _tryParseCalibration(data, pos);
      if (next == null) break;
      calibrationRecords.add(next);
      pos += _calibrationRecordWidth;
    }

    return (
      technicalData: VuTechnicalData(
        manufacturerName: mfgName,
        manufacturerAddress: mfgAddress,
        partNumber: partNumber,
        serialNumber: serial.serialNumber,
        serialMonth: serial.month,
        serialYear: serial.year,
        equipmentType: serial.equipmentType,
        manufacturerCode: serial.manufacturerCode,
        softwareVersion: softwareVersion,
        softInstallationDate: softInstallationDate,
        manufacturingDate: manufacturingDate,
        approvalNumber: approvalNumber,
        sensorSerialNumber: sensorSerial.serialNumber,
        sensorSerialMonth: sensorSerial.month,
        sensorSerialYear: sensorSerial.year,
        sensorEquipmentType: sensorSerial.equipmentType,
        sensorManufacturerCode: sensorSerial.manufacturerCode,
        sensorApprovalNumber: sensorApprovalNumber,
        sensorPairingDateFirst: sensorPairingDateFirst,
        numberOfCalibrationRecords: calibrationCount,
      ),
      calibrationRecords: calibrationRecords,
    );
  }

  static VuCalibrationRecord? _tryParseCalibration(Uint8List data, int offset) {
    if (offset + _calibrationRecordWidth > data.length) return null;
    final reader = VuByteReader(data, offset);
    final purpose = reader.readUint8();
    if (purpose > 20) return null;

    final workshopName = _tryReadName(reader);
    if (workshopName == null) return null;
    final workshopAddress = _tryReadName(reader);
    if (workshopAddress == null) return null;

    final workshopCard = _tryReadFullCardNumber(reader);
    if (workshopCard == null) return null;
    final cardExpiry = _timeReal(reader);

    final vinSlice = reader.readBytes(17);
    if (!VuFieldCodecs.isCleanAsciiField(vinSlice)) return null;
    final vin = VuFieldCodecs.cleanAsciiText(vinSlice);
    if (vin.length < 5) return null;

    reader.skip(1);
    reader.skip(1);
    final vrnSlice = reader.readBytes(13);
    if (!VuFieldCodecs.isCleanAsciiField(vrnSlice)) return null;
    final vrn = VuFieldCodecs.cleanAsciiText(vrnSlice);

    reader.skip(4);
    if (!reader.canRead(2)) return null;
    final tyreCircumference = reader.readUint16();
    reader.skip(15);
    final authorisedSpeed = reader.readUint8();

    if (authorisedSpeed > 150) return null;

    final oldOdometer = reader.readUint24();
    final newOdometer = reader.readUint24();
    final oldTime = _timeReal(reader);
    final newTime = _timeReal(reader);
    final nextCalibration = _timeReal(reader);

    return VuCalibrationRecord(
      purpose: purpose,
      workshopName: workshopName,
      workshopAddress: workshopAddress,
      workshopCardNumber: workshopCard,
      workshopCardExpiryDate: cardExpiry,
      vin: vin,
      vrn: vrn,
      tyreCircumferenceMm: tyreCircumference,
      authorisedSpeedKmh: authorisedSpeed,
      oldOdometerKm: oldOdometer,
      newOdometerKm: newOdometer,
      oldTime: oldTime,
      newTime: newTime,
      nextCalibrationDate: nextCalibration,
    );
  }

  static String? _tryReadFullCardNumber(VuByteReader reader) {
    final slice = reader.readBytes(18);
    if (slice.every((b) => b == 0)) return '';
    final numberSlice = Uint8List.sublistView(slice, 2, 18);
    if (!VuFieldCodecs.isCleanAsciiField(numberSlice)) return null;
    return VuFieldCodecs.cleanAsciiText(numberSlice);
  }

  static VuExtendedSerial? _tryReadExtendedSerial(VuByteReader reader) {
    if (!reader.canRead(8)) return null;
    final serialNumber = reader.readUint32();
    final month = VuFieldCodecs.bcdDigits(reader.readUint8());
    final year = VuFieldCodecs.bcdDigits(reader.readUint8());
    final equipmentType = reader.readUint8();
    final manufacturerCode = reader.readUint8();
    if (month == null || month < 1 || month > 12) return null;
    if (year == null) return null;
    if (serialNumber == 0) return null;
    return VuExtendedSerial(
      serialNumber: serialNumber,
      month: month,
      year: year,
      equipmentType: equipmentType,
      manufacturerCode: manufacturerCode,
    );
  }

  static String? _tryReadIa5(VuByteReader reader, int width) {
    if (!reader.canRead(width)) return null;
    final slice = reader.readBytes(width);
    if (!VuFieldCodecs.isCleanAsciiField(slice)) return null;
    return VuFieldCodecs.cleanAsciiText(slice);
  }

  static String? _tryReadName(VuByteReader reader) {
    if (!reader.canRead(36)) return null;
    final codepage = reader.readUint8();
    final slice = reader.readBytes(35);
    if (!VuFieldCodecs.nameCodepages.contains(codepage)) return null;
    if (!VuFieldCodecs.isCleanNameField(slice)) return null;
    return VuFieldCodecs.decodeCodepageText(codepage, slice);
  }

  static DateTime? _timeReal(VuByteReader reader) {
    if (!reader.canRead(4)) return null;
    return reader.readTimeReal(minYear: 2015, maxYear: 2035);
  }
}

class VuExtendedSerial {
  final int serialNumber;
  final int month;
  final int year;
  final int equipmentType;
  final int manufacturerCode;

  const VuExtendedSerial({
    required this.serialNumber,
    required this.month,
    required this.year,
    required this.equipmentType,
    required this.manufacturerCode,
  });
}
