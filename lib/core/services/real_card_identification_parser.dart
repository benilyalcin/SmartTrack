import 'dart:convert';
import 'dart:typed_data';

import '../models/card_file_details.dart';
import 'eu_event_fault_codes.dart';
import 'tachograph_parser.dart';

class RealCardIdentificationParser {
  RealCardIdentificationParser._();

  static const int _nameFieldLen = 36;
  static const int _cardNumberLen = 16;
  static const int _timeRealLen = 4;
  static const int _cardIdentificationLen =
      1 + _cardNumberLen + _nameFieldLen + _timeRealLen * 3;

  static const int _driverHolderIdentificationLen = _nameFieldLen * 2 + 4 + 2;

  static const int _workshopHolderIdentificationLen = _nameFieldLen * 4 + 2;

  static CardIdentity? parse(Uint8List efIdentification) {
    if (efIdentification.length <
        _cardIdentificationLen + _driverHolderIdentificationLen)
      return null;

    var offset = 0;
    final nationCode = efIdentification[offset];
    offset += 1;
    final cardNumber = _decodeAscii(efIdentification, offset, _cardNumberLen);
    offset += _cardNumberLen;
    offset += _nameFieldLen;
    final issueDate = _parseTimeReal(efIdentification, offset);
    offset += _timeRealLen;
    offset += _timeRealLen;
    final expiryDate = _parseTimeReal(efIdentification, offset);
    offset += _timeRealLen;

    final remaining = efIdentification.length - offset;
    String surname;
    String firstNames;
    DateTime? birthDate;
    String language;

    if (remaining >= _workshopHolderIdentificationLen) {
      offset += _nameFieldLen;
      offset += _nameFieldLen;
      surname = _decodeName(efIdentification, offset);
      offset += _nameFieldLen;
      firstNames = _decodeName(efIdentification, offset);
      offset += _nameFieldLen;
      birthDate = null;
      language = _decodeAscii(efIdentification, offset, 2);
    } else {
      surname = _decodeName(efIdentification, offset);
      offset += _nameFieldLen;
      firstNames = _decodeName(efIdentification, offset);
      offset += _nameFieldLen;
      birthDate = _parseDatef(efIdentification, offset);
      offset += 4;
      language = _decodeAscii(efIdentification, offset, 2);
    }

    return CardIdentity(
      cardIssuingMemberState: nationCode.toString(),
      cardNumber: cardNumber,
      holderSurname: surname,
      holderFirstName: firstNames,
      cardIssueDate: issueDate,
      cardExpiryDate: expiryDate,
      dateOfBirth: birthDate,
      language: language,
    );
  }

  static String _decodeAscii(Uint8List data, int offset, int length) {
    if (offset + length > data.length) return '';
    final slice = Uint8List.sublistView(data, offset, offset + length);

    return latin1.decode(slice).trim();
  }

  static String _decodeName(Uint8List data, int offset) {
    if (offset + _nameFieldLen > data.length) return '';
    return _decodeAscii(data, offset + 1, _nameFieldLen - 1);
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

  static DateTime? _parseDatef(Uint8List data, int offset) {
    if (offset + 4 > data.length) return null;
    final year = _bcd(data[offset]) * 100 + _bcd(data[offset + 1]);
    final month = _bcd(data[offset + 2]);
    final day = _bcd(data[offset + 3]);
    if (year < 1900 ||
        year > 2100 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31)
      return null;
    return DateTime(year, month, day);
  }

  static int _bcd(int byte) => ((byte >> 4) & 0xF) * 10 + (byte & 0xF);
}

class CardIdentity {
  final String cardIssuingMemberState;
  final String cardNumber;
  final String holderSurname;
  final String holderFirstName;
  final DateTime? cardIssueDate;
  final DateTime? cardExpiryDate;
  final DateTime? dateOfBirth;
  final String language;

  CardIdentity({
    required this.cardIssuingMemberState,
    required this.cardNumber,
    required this.holderSurname,
    required this.holderFirstName,
    required this.cardIssueDate,
    required this.cardExpiryDate,
    required this.dateOfBirth,
    required this.language,
  });
}

class RealCardEventFaultParser {
  RealCardEventFaultParser._();

  static const _recordSize = 24;
  static const _minValidYear = 2000;
  static const _maxValidYear = 2100;

  static List<TachoEvent> parse(Uint8List efBlock, {required bool isFault}) {
    final result = <TachoEvent>[];
    for (
      var offset = 0;
      offset + _recordSize <= efBlock.length;
      offset += _recordSize
    ) {
      final code = efBlock[offset];
      if (code == 0) continue;
      final begin = _parseTimeReal(efBlock, offset + 1);
      final end = _parseTimeReal(efBlock, offset + 5);
      final timestamp = begin ?? end;
      if (timestamp == null) continue;
      result.add(
        TachoEvent(
          code: code,
          description: isFault
              ? EuEventFaultCodes.faultLabel(code)
              : EuEventFaultCodes.eventLabel(code),
          timestamp: timestamp,
          isFault: isFault,
        ),
      );
    }
    return result;
  }

  static DateTime? _parseTimeReal(Uint8List data, int offset) {
    if (offset + 4 > data.length) return null;
    final seconds =
        (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
    if (seconds <= 0) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    if (dt.year < _minValidYear || dt.year > _maxValidYear) return null;
    return dt;
  }
}

class RealCardVehicleUsedParser {
  RealCardVehicleUsedParser._();

  static const _recordSize = 31;
  static const _headerLen = 2;

  static String latestVehicleRegistration(Uint8List efBlock) {
    if (efBlock.length <= _headerLen) return '';
    final body = Uint8List.sublistView(efBlock, _headerLen);

    String best = '';
    DateTime? bestLastUse;
    for (
      var offset = 0;
      offset + _recordSize <= body.length;
      offset += _recordSize
    ) {
      final lastUse = _parseTimeReal(body, offset + 10);
      if (lastUse == null) continue;
      final plate = _decodeVehicleRegistration(body, offset + 14);
      if (plate.isEmpty) continue;
      if (bestLastUse == null || lastUse.isAfter(bestLastUse)) {
        bestLastUse = lastUse;
        best = plate;
      }
    }
    return best;
  }

  static List<VehicleUsageRecord> allRecords(Uint8List efBlock) {
    if (efBlock.length <= _headerLen) return const [];
    final body = Uint8List.sublistView(efBlock, _headerLen);

    final result = <VehicleUsageRecord>[];
    for (
      var offset = 0;
      offset + _recordSize <= body.length;
      offset += _recordSize
    ) {
      final odometerBegin =
          (body[offset] << 16) | (body[offset + 1] << 8) | body[offset + 2];
      final odometerEndRaw =
          (body[offset + 3] << 16) | (body[offset + 4] << 8) | body[offset + 5];

      final odometerEnd = odometerEndRaw == 0xFFFFFF ? null : odometerEndRaw;
      final firstUse = _parseTimeReal(body, offset + 6);
      final lastUse = _parseTimeReal(body, offset + 10);
      final plate = _decodeVehicleRegistration(body, offset + 14);
      if (odometerBegin == 0 &&
          odometerEndRaw == 0 &&
          firstUse == null &&
          lastUse == null &&
          plate.isEmpty) {
        continue;
      }
      result.add(
        VehicleUsageRecord(
          vehicleRegistration: plate,
          odometerBeginKm: odometerBegin,
          odometerEndKm: odometerEnd,
          firstUse: firstUse,
          lastUse: lastUse,
        ),
      );
    }
    result.sort((a, b) {
      final aTime = a.firstUse ?? DateTime(0);
      final bTime = b.firstUse ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return result;
  }

  static String _decodeVehicleRegistration(Uint8List data, int offset) {
    if (offset + 15 > data.length) return '';
    final slice = Uint8List.sublistView(data, offset + 2, offset + 15);
    return latin1.decode(slice).trim();
  }

  static DateTime? _parseTimeReal(Uint8List data, int offset) {
    if (offset + 4 > data.length) return null;
    final seconds =
        (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
    if (seconds <= 0) return null;
    final result = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    );
    if (result.year < 2000 || result.year > 2100) return null;
    return result;
  }
}
