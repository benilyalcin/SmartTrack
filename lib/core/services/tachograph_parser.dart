import 'dart:typed_data';

import 'driving_time_calculator.dart';
import 'real_card_activity_parser.dart';
import 'real_card_identification_parser.dart';

class TlvRecord {
  final int tag;
  final int length;
  final Uint8List value;

  TlvRecord({required this.tag, required this.length, required this.value});

  @override
  String toString() =>
      'TLV(tag=0x${tag.toRadixString(16).toUpperCase()}, len=$length, val=[${value.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}])';
}

class TlvDecoder {
  List<TlvRecord> decode(Uint8List data) {
    final records = <TlvRecord>[];
    int index = 0;

    while (index < data.length) {
      if (index >= data.length) break;
      int tag = data[index] & 0xFF;
      index++;

      if (tag == 0x00 || tag == 0xFF) continue;

      if ((tag & 0x1F) == 0x1F) {
        while (index < data.length && (data[index] & 0x80) != 0) {
          tag = (tag << 8) | (data[index] & 0xFF);
          index++;
        }
        if (index < data.length) {
          tag = (tag << 8) | (data[index] & 0xFF);
          index++;
        }
      }

      if (index >= data.length) break;
      int length = data[index] & 0xFF;
      index++;

      if (length > 127) {
        final numLengthBytes = (length & 0x7F).clamp(0, 4);
        length = 0;
        for (int i = 0; i < numLengthBytes; i++) {
          if (index >= data.length) break;
          length = (length << 8) | (data[index] & 0xFF);
          index++;
        }
      }

      if (index + length > data.length) {
        length = data.length - index;
      }
      final value = Uint8List.sublistView(data, index, index + length);
      index += length;

      records.add(TlvRecord(tag: tag, length: length, value: value));
    }
    return records;
  }
}

class TachoTags {
  static const int efIdentification = 0x0520;
  static const int efDriverActivity = 0x0504;
  static const int efEventsData = 0x0502;
  static const int efFaultsData = 0x0503;
  static const int efCardDownload = 0x050E;
  static const int efVehiclesUsed = 0x0505;

  static const int tagCardHolderName = 0x01;
  static const int tagDrivingTime = 0x02;
  static const int tagDailyDrivingTime = 0x03;
  static const int tagWeeklyDrivingTime = 0x04;
  static const int tagBiWeeklyDrivingTime = 0x05;
  static const int tagOdometer = 0x06;
  static const int tagSpeed = 0x07;
  static const int tagLastBreakDuration = 0x08;
  static const int tagBreakRemaining = 0x09;
  static const int tagEventCode = 0x10;
  static const int tagFaultCode = 0x11;
  static const int tagTimestamp = 0x12;
  static const int tagVehicleReg = 0x13;

  static const int tagCardNumber = 0x14;
  static const int tagCardIssuingMemberState = 0x15;
  static const int tagHolderSurname = 0x16;
  static const int tagHolderFirstName = 0x17;
  static const int tagCardExpiryDate = 0x18;

  static const int tagActivityRecord = 0x19;

  static const int tagDateOfBirth = 0x1A;
  static const int tagLanguage = 0x1B;
  static const int tagLicenseNumber = 0x1C;
  static const int tagCardIssueDate = 0x1D;
}

class TachographDriverData {
  final String driverName;
  final int currentDrivingMinutes;
  final int dailyDrivingMinutes;
  final int weeklyDrivingMinutes;
  final int biWeeklyDrivingMinutes;
  final int odometerKm;
  final int speedKmh;
  final int lastBreakMinutes;
  final int breakRemainingMinutes;
  final String vehicleRegistration;

  final List<TachoEvent> lastEvents;
  final List<TachoEvent> lastFaults;

  final String cardNumber;
  final String cardIssuingMemberState;
  final String holderSurname;
  final String holderFirstName;
  final DateTime? cardExpiryDate;
  final DateTime? dateOfBirth;
  final String language;
  final String licenseNumber;
  final DateTime? cardIssueDate;

  final List<TachographActivity> activityLog;

  TachographDriverData({
    this.driverName = '',
    this.currentDrivingMinutes = 0,
    this.dailyDrivingMinutes = 0,
    this.weeklyDrivingMinutes = 0,
    this.biWeeklyDrivingMinutes = 0,
    this.odometerKm = 0,
    this.speedKmh = 0,
    this.lastBreakMinutes = 0,
    this.breakRemainingMinutes = 270,
    this.vehicleRegistration = '',
    this.lastEvents = const [],
    this.lastFaults = const [],
    this.cardNumber = '',
    this.cardIssuingMemberState = '',
    this.holderSurname = '',
    this.holderFirstName = '',
    this.cardExpiryDate,
    this.dateOfBirth,
    this.language = '',
    this.licenseNumber = '',
    this.cardIssueDate,
    this.activityLog = const [],
  });

  String get holderFullName {
    final full = '$holderFirstName $holderSurname'.trim();
    return full.isNotEmpty ? full : driverName;
  }

  int get minutesUntilMandatoryBreak {
    const limit = 270;
    final remaining = limit - currentDrivingMinutes;
    return remaining > 0 ? remaining : 0;
  }

  double get weeklyDrivingFraction =>
      (weeklyDrivingMinutes / (56 * 60)).clamp(0.0, 1.0);

  double get biWeeklyDrivingFraction =>
      (biWeeklyDrivingMinutes / (90 * 60)).clamp(0.0, 1.0);

  bool get isBreakWarning =>
      minutesUntilMandatoryBreak <= 15 && minutesUntilMandatoryBreak > 0;

  bool get isBreakOverdue => minutesUntilMandatoryBreak <= 0;

  static String formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class TachoEvent {
  final int code;
  final String description;
  final DateTime timestamp;
  final bool isFault;

  TachoEvent({
    required this.code,
    required this.description,
    required this.timestamp,
    this.isFault = false,
  });
}

class DddFileParser {
  final TlvDecoder _decoder = TlvDecoder();

  static const Map<int, String> eventDescriptions = {
    0x01: 'Kart takılmadı (sürüş)',
    0x02: 'Kart çıkarıldı (sürüş sırasında)',
    0x03: 'Hız aşımı',
    0x04: 'Güç kesintisi',
    0x05: 'Sensör hatası',
    0x06: 'Veri bütünlüğü hatası',
    0x07: 'Zaman çakışması',
    0x08: 'Son geçerli konum',
    0x09: 'Kalibrasyon hatası',
    0x0A: 'Süre ihlali',
  };

  static const Map<int, String> faultDescriptions = {
    0x01: 'Kart okuyucu arızası',
    0x02: 'Yazıcı arızası',
    0x03: 'Ekran arızası',
    0x04: 'İndirme arızası',
    0x05: 'Sensör arızası',
    0x06: 'Dahili elektronik arıza',
  };

  TachographDriverData parse(Uint8List rawBytes) {
    final records = _decoder.decode(rawBytes);

    String driverName = '';
    int currentDriving = 0;
    int dailyDriving = 0;
    int weeklyDriving = 0;
    int biWeeklyDriving = 0;
    int odometer = 0;
    int speed = 0;
    int lastBreak = 0;
    int breakRemaining = 270;
    String vehicleReg = '';
    final events = <TachoEvent>[];
    final faults = <TachoEvent>[];
    String cardNumber = '';
    String cardIssuingMemberState = '';
    String holderSurname = '';
    String holderFirstName = '';
    DateTime? cardExpiryDate;
    DateTime? dateOfBirth;
    String language = '';
    String licenseNumber = '';
    DateTime? cardIssueDate;
    final activityLog = <TachographActivity>[];

    for (final record in records) {
      switch (record.tag) {
        case TachoTags.tagCardHolderName:
          driverName = String.fromCharCodes(record.value).trim();
          break;
        case TachoTags.tagCardNumber:
          cardNumber = String.fromCharCodes(record.value).trim();
          break;
        case TachoTags.tagCardIssuingMemberState:
          cardIssuingMemberState = String.fromCharCodes(record.value).trim();
          break;
        case TachoTags.tagHolderSurname:
          holderSurname = String.fromCharCodes(record.value).trim();
          break;
        case TachoTags.tagHolderFirstName:
          holderFirstName = String.fromCharCodes(record.value).trim();
          break;
        case TachoTags.tagCardExpiryDate:
          cardExpiryDate = _parseEpochSeconds(record.value);
          break;
        case TachoTags.tagDateOfBirth:
          dateOfBirth = _parseEpochSeconds(record.value);
          break;
        case TachoTags.tagLanguage:
          language = String.fromCharCodes(record.value).trim();
          break;
        case TachoTags.tagLicenseNumber:
          licenseNumber = String.fromCharCodes(record.value).trim();
          break;
        case TachoTags.tagCardIssueDate:
          cardIssueDate = _parseEpochSeconds(record.value);
          break;
        case TachoTags.tagActivityRecord:
          activityLog.addAll(_parseActivityRecords(record.value));
          break;
        case TachoTags.tagDrivingTime:
          currentDriving = _bytesToInt(record.value);
          break;
        case TachoTags.tagDailyDrivingTime:
          dailyDriving = _bytesToInt(record.value);
          break;
        case TachoTags.tagWeeklyDrivingTime:
          weeklyDriving = _bytesToInt(record.value);
          break;
        case TachoTags.tagBiWeeklyDrivingTime:
          biWeeklyDriving = _bytesToInt(record.value);
          break;
        case TachoTags.tagOdometer:
          odometer = _bytesToInt(record.value);
          break;
        case TachoTags.tagSpeed:
          speed = _bytesToInt(record.value);
          break;
        case TachoTags.tagLastBreakDuration:
          lastBreak = _bytesToInt(record.value);
          break;
        case TachoTags.tagBreakRemaining:
          breakRemaining = _bytesToInt(record.value);
          break;
        case TachoTags.tagVehicleReg:
          vehicleReg = String.fromCharCodes(record.value).trim();
          break;
        case TachoTags.tagEventCode:
          events.add(_parseEventOrFault(record.value, isFault: false));
          break;
        case TachoTags.tagFaultCode:
          faults.add(_parseEventOrFault(record.value, isFault: true));
          break;
      }
    }

    final realActivityBlock = RealCardFileScanner.findDriverActivityBlock(
      rawBytes,
    );
    if (realActivityBlock != null) {
      activityLog.addAll(RealCardActivityParser.parse(realActivityBlock));
    }

    final realIdentificationBlock = RealCardFileScanner.findIdentificationBlock(
      rawBytes,
    );
    final identity = realIdentificationBlock != null
        ? RealCardIdentificationParser.parse(realIdentificationBlock)
        : null;
    if (identity != null) {
      if (cardNumber.isEmpty) cardNumber = identity.cardNumber;
      if (cardIssuingMemberState.isEmpty)
        cardIssuingMemberState = identity.cardIssuingMemberState;
      if (holderSurname.isEmpty) holderSurname = identity.holderSurname;
      if (holderFirstName.isEmpty) holderFirstName = identity.holderFirstName;
      cardExpiryDate ??= identity.cardExpiryDate;
      dateOfBirth ??= identity.dateOfBirth;
      if (language.isEmpty) language = identity.language;
      cardIssueDate ??= identity.cardIssueDate;
    }

    final realEventsBlock = RealCardFileScanner.findEventsBlock(rawBytes);
    final realFaultsBlock = RealCardFileScanner.findFaultsBlock(rawBytes);
    if (realEventsBlock != null || realFaultsBlock != null) {
      events.clear();
      faults.clear();
    }
    if (realEventsBlock != null) {
      events.addAll(
        RealCardEventFaultParser.parse(realEventsBlock, isFault: false),
      );
    }
    if (realFaultsBlock != null) {
      faults.addAll(
        RealCardEventFaultParser.parse(realFaultsBlock, isFault: true),
      );
    }

    if (vehicleReg.isEmpty) {
      final realVehiclesUsedBlock = RealCardFileScanner.findVehiclesUsedBlock(
        rawBytes,
      );
      if (realVehiclesUsedBlock != null) {
        vehicleReg = RealCardVehicleUsedParser.latestVehicleRegistration(
          realVehiclesUsedBlock,
        );
      }
    }

    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    faults.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return TachographDriverData(
      driverName: driverName,
      currentDrivingMinutes: currentDriving,
      dailyDrivingMinutes: dailyDriving,
      weeklyDrivingMinutes: weeklyDriving,
      biWeeklyDrivingMinutes: biWeeklyDriving,
      odometerKm: odometer,
      speedKmh: speed,
      lastBreakMinutes: lastBreak,
      breakRemainingMinutes: breakRemaining,
      vehicleRegistration: vehicleReg,
      lastEvents: events,
      lastFaults: faults,
      cardNumber: cardNumber,
      cardIssuingMemberState: cardIssuingMemberState,
      holderSurname: holderSurname,
      holderFirstName: holderFirstName,
      cardExpiryDate: cardExpiryDate,
      dateOfBirth: dateOfBirth,
      language: language,
      licenseNumber: licenseNumber,
      cardIssueDate: cardIssueDate,
      activityLog: activityLog
        ..sort((a, b) => a.startTime.compareTo(b.startTime)),
    );
  }

  TachoEvent _parseEventOrFault(Uint8List value, {required bool isFault}) {
    final code = value.isNotEmpty ? value[0] : 0;
    final timestamp = value.length >= 5
        ? (_parseEpochSeconds(Uint8List.sublistView(value, 1, 5)) ??
              DateTime.now())
        : DateTime.now();
    final table = isFault ? faultDescriptions : eventDescriptions;
    final label = isFault ? 'Bilinmeyen arıza' : 'Bilinmeyen olay';
    return TachoEvent(
      code: code,
      description: table[code] ?? '$label (0x${code.toRadixString(16)})',
      timestamp: timestamp,
      isFault: isFault,
    );
  }

  int _bytesToInt(Uint8List bytes) {
    int result = 0;
    for (final b in bytes) {
      result = (result << 8) | (b & 0xFF);
    }
    return result;
  }

  DateTime? _parseEpochSeconds(Uint8List data) {
    if (data.length < 4) return null;
    final seconds = _bytesToInt(data);
    if (seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  List<TachographActivity> _parseActivityRecords(Uint8List data) {
    const legacyRecordSize = 9;
    const recordSize = 11;
    final result = <TachographActivity>[];

    final useNewLayout =
        data.length % recordSize == 0 && data.length % legacyRecordSize != 0;
    final step = useNewLayout ? recordSize : legacyRecordSize;

    for (int offset = 0; offset + step <= data.length; offset += step) {
      final typeIndex = data[offset];
      final start = _parseEpochSeconds(
        Uint8List.sublistView(data, offset + 1, offset + 5),
      );
      final end = _parseEpochSeconds(
        Uint8List.sublistView(data, offset + 5, offset + 9),
      );
      if (start == null || end == null) continue;
      if (typeIndex >= ActivityType.values.length) continue;

      final isCrew = useNewLayout && data[offset + 9] == 1;
      final slotIndex = useNewLayout ? data[offset + 10] : 0;
      final slot = slotIndex < DriverSlot.values.length
          ? DriverSlot.values[slotIndex]
          : DriverSlot.driver;

      result.add(
        TachographActivity(
          type: ActivityType.values[typeIndex],
          startTime: start,
          endTime: end,
          isCrew: isCrew,
          slot: slot,
        ),
      );
    }
    return result;
  }
}
