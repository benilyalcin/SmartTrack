import 'dart:typed_data';

class KLineFrame {
  static const int taddr = 0xEE;
  static const int saddr = 0xF0;

  static int checksum(List<int> bytes) {
    int sum = 0;
    for (final b in bytes) {
      sum = (sum + b) & 0xFF;
    }
    return sum;
  }

  static List<int> buildRequest(int sid, [List<int> data = const []]) {
    final len = 1 + data.length;
    final frame = <int>[0x80, taddr, saddr, len, sid, ...data];
    frame.add(checksum(frame));
    return frame;
  }

  static List<int> get startCommunication => [0x81, 0xEE, 0xF0, 0x81, 0xE0];

  static List<int> get stopCommunication => [
    0x80,
    0xEE,
    0xF0,
    0x01,
    0x82,
    0xE1,
  ];

  static List<int> get sessionStandard => buildRequest(0x10, [0x81]);

  static List<int> get sessionProgramming => buildRequest(0x10, [0x85]);

  static List<int> get sessionAdjustment => buildRequest(0x10, [0x87]);

  static List<int> get testerPresentNoResp => buildRequest(0x3E, [0x02]);

  static List<int> get testerPresentWithResp => buildRequest(0x3E, [0x01]);

  static List<int> readById(int recordId) {
    final ridH = (recordId >> 8) & 0xFF;
    final ridL = recordId & 0xFF;
    return buildRequest(0x22, [ridH, ridL]);
  }

  static List<int> writeById(int recordId, List<int> data) {
    final ridH = (recordId >> 8) & 0xFF;
    final ridL = recordId & 0xFF;
    return buildRequest(0x2E, [ridH, ridL, ...data]);
  }

  static List<int> startRoutine(int routineId, {int? extraByte}) {
    final ridH = (routineId >> 8) & 0xFF;
    final ridL = routineId & 0xFF;
    final data = <int>[0x01, ridH, ridL];
    if (extraByte != null) data.add(extraByte);
    return buildRequest(0x31, data);
  }

  static List<int> stopRoutine(int routineId, {int? result}) {
    final ridH = (routineId >> 8) & 0xFF;
    final ridL = routineId & 0xFF;
    final data = <int>[0x02, ridH, ridL];
    if (result != null) data.add(result);
    return buildRequest(0x31, data);
  }

  static List<int> requestRoutineResults(int routineId) {
    final ridH = (routineId >> 8) & 0xFF;
    final ridL = routineId & 0xFF;
    return buildRequest(0x31, [0x03, ridH, ridL]);
  }

  static List<int> get ioEnableSpeedInput => [
    0x80,
    0xEE,
    0xF0,
    0x05,
    0x2F,
    0xF9,
    0x60,
    0x03,
    0x01,
    0xEF,
  ];

  static List<int> get ioEnableSpeedOutput => [
    0x80,
    0xEE,
    0xF0,
    0x05,
    0x2F,
    0xF9,
    0x60,
    0x03,
    0x02,
    0xF0,
  ];

  static List<int> get ioEnableRtcOutput => [
    0x80,
    0xEE,
    0xF0,
    0x05,
    0x2F,
    0xF9,
    0x60,
    0x03,
    0x03,
    0xF1,
  ];

  static List<int> get ioResetToDefault => [
    0x80,
    0xEE,
    0xF0,
    0x04,
    0x2F,
    0xF9,
    0x60,
    0x01,
    0xEB,
  ];

  static List<int> get reportDtcCount => [
    0x80,
    0xEE,
    0xF0,
    0x03,
    0x19,
    0x01,
    0x09,
    0x84,
  ];

  static List<int> get reportDtcList => [
    0x80,
    0xEE,
    0xF0,
    0x03,
    0x19,
    0x02,
    0x09,
    0x85,
  ];

  static List<int> get clearAllDtc => [
    0x80,
    0xEE,
    0xF0,
    0x04,
    0x14,
    0xFF,
    0xFF,
    0xFF,
    0x73,
  ];

  static const int baudRate9600 = 0x01;
  static const int baudRate19200 = 0x02;
  static const int baudRate38400 = 0x03;
  static const int baudRate57600 = 0x04;
  static const int baudRate115200 = 0x05;

  static List<int> verifyBaudRate(int baudRateCode) =>
      buildRequest(0x87, [0x01, 0x01, baudRateCode & 0xFF]);

  static List<int> get transitionBaudRate => buildRequest(0x87, [0x02, 0x03]);

  static List<int> get requestUpload => buildRequest(0x35, [
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
  ]);

  static List<int> get transferDataRequestOverview =>
      buildRequest(0x36, [0x01]);

  static List<int> transferDataRequestActivities(DateTime date) {
    final utcMidnight = DateTime.utc(date.year, date.month, date.day);
    final seconds = utcMidnight.millisecondsSinceEpoch ~/ 1000;
    return buildRequest(0x36, [
      0x02,
      (seconds >> 24) & 0xFF,
      (seconds >> 16) & 0xFF,
      (seconds >> 8) & 0xFF,
      seconds & 0xFF,
    ]);
  }

  static List<int> get transferDataRequestEventsFaults =>
      buildRequest(0x36, [0x03]);

  static List<int> get transferDataRequestDetailedSpeed =>
      buildRequest(0x36, [0x04]);

  static List<int> get transferDataRequestTechnicalData =>
      buildRequest(0x36, [0x05]);

  static List<int> transferDataRequestCardDownload(int slot) =>
      buildRequest(0x36, [0x06]);

  static List<int> get requestTransferExit => buildRequest(0x37);

  static List<int> acknowledgeSubMessage(int receivedSid, int counter) =>
      buildRequest(0x83, [
        receivedSid & 0xFF,
        (counter >> 8) & 0xFF,
        counter & 0xFF,
      ]);
}

class TachoRecordId {
  static const int vin = 0xF190;
  static const int vrn = 0xF97E;
  static const int registeringMemberState = 0xF97D;
  static const int vehicleRegDate = 0xF97F;

  static const int supplierIdentifier = 0xF18A;
  static const int ecuManufacturingDate = 0xF18B;
  static const int ecuSerialNumber = 0xF18C;
  static const int hwNumber = 0xF192;
  static const int hwVersion = 0xF193;
  static const int swNumber = 0xF194;
  static const int swVersion = 0xF195;
  static const int typeApproval = 0xF196;
  static const int calibrationDate = 0xF19B;
  static const int ecuInstallDate = 0xF19D;

  static const int vehicleSpeed = 0xF902;
  static const int currentDateTime = 0xF90B;
  static const int odometer = 0xF912;
  static const int tripDistance = 0xF913;

  static const int kConstant = 0xF918;
  static const int tyreCircumference = 0xF91C;
  static const int wConstant = 0xF91D;
  static const int tyreSize = 0xF921;
  static const int nextCalibrationDate = 0xF922;
  static const int speedLimit = 0xF92C;
  static const int teethOnPhonicWheel = 0xF91A;
  static const int pproos = 0xF91E;

  static const int utcMinuteOffset = 0xF90D;
  static const int utcHourOffset = 0xF90E;

  static const int resetHeartBeat = 0xF90C;
  static const int tco1Priority = 0xF90F;
  static const int tco1RepRate = 0xF920;
  static const int serviceComponentId = 0xF914;
  static const int serviceDelay = 0xF915;

  static const int prewarningCard1 = 0xF994;
  static const int prewarningTacho = 0xF995;
  static const int prewarningCalibration = 0xF996;
  static const int downloadPeriodCard = 0xF990;
  static const int downloadPeriodVU = 0xF991;

  static const int driver1Name = 0xF931;
  static const int driver2Name = 0xF932;

  static const int tachographCardSlot1 = 0xF930;
  static const int tachographCardSlot2 = 0xF933;

  static const int driver1WorkingState = 0xF903;
  static const int driver2WorkingState = 0xF904;
  static const int driver1TimeRelatedStates = 0xF906;
  static const int driver2TimeRelatedStates = 0xF909;
  static const int driverCardDriver1 = 0xF907;
  static const int driver1Identification = 0xF916;
  static const int driver2Identification = 0xF917;
  static const int driver1ContinuousDrivingTime = 0xF923;
  static const int driver2ContinuousDrivingTime = 0xF924;
  static const int driver1CumulativeBreakTime = 0xF925;
  static const int driver2CumulativeBreakTime = 0xF926;
  static const int driver1CurrentDurationOfActivity = 0xF927;
  static const int driver2CurrentDurationOfActivity = 0xF928;
  static const int driver1CurrentDailyDrivingTime = 0xF99A;
  static const int driver2CurrentDailyDrivingTime = 0xF988;
  static const int driver1CurrentWeeklyDrivingTime = 0xF99B;
  static const int driver2CurrentWeeklyDrivingTime = 0xF989;
  static const int driver1Remaining2WeeksDrivingTime = 0xF9B3;
  static const int driver2Remaining2WeeksDrivingTime = 0xF9B4;
  static const int driver1CardExpiryDate = 0xF99D;
  static const int driver2CardExpiryDate = 0xF98B;

  static const int driver1AdditionalInformation = 0xF9CD;
  static const int driver1DurationOfNextBreakRest = 0xF9B9;
  static const int driver1RemainingTimeOfCurrentBreakRest = 0xF9C0;
  static const int driver1RemainingTimeUntilNextBreakOrRest = 0xF9C2;
  static const int driver1EndOfLastDailyRestPeriod = 0xF997;
  static const int driver1EndOfLastWeeklyRestPeriod = 0xF998;
  static const int driver1OpenCompensationInTheLastWeek = 0xF9C7;
  static const int driver1OpenCompensationInWeekBeforeLast = 0xF9C9;
  static const int driver1OpenCompensationIn2ndWeekBeforeLast = 0xF9CB;
  static const int driver1MinimumDailyRest = 0xF9A3;
  static const int driver1MinimumWeeklyRest = 0xF9A4;

  static const int driver2AdditionalInformation = 0xF9CE;
  static const int driver2DurationOfNextBreakRest = 0xF9BF;
  static const int driver2RemainingTimeOfCurrentBreakRest = 0xF9C1;
  static const int driver2RemainingTimeUntilNextBreakOrRest = 0xF9C3;
  static const int driver2EndOfLastDailyRestPeriod = 0xF985;
  static const int driver2EndOfLastWeeklyRestPeriod = 0xF986;
  static const int driver2OpenCompensationInTheLastWeek = 0xF9C8;
  static const int driver2OpenCompensationInWeekBeforeLast = 0xF9CA;
  static const int driver2OpenCompensationIn2ndWeekBeforeLast = 0xF9CC;
  static const int driver2MinimumDailyRest = 0xF9A7;
  static const int driver2MinimumWeeklyRest = 0xF9A8;

  static const int driver1PreferredLanguage = 0xF981;
  static const int driver2PreferredLanguage = 0xF982;
  static const int driver1CardNextMandatoryDownloadDate = 0xF99E;

  static const int driver2CardNextMandatoryDownloadDate = 0xF98C;

  static const Map<int, String> _names = {
    vin: 'VehicleIdentificationNumber',
    currentDateTime: 'CurrentDateTime',
    odometer: 'HighResOdometer',
    tripDistance: 'HighResolutionTripDistance',
    kConstant: 'K-ConstantOfRecordingEquipment',
    tyreCircumference: 'L-TyreCircumference',
    wConstant: 'W-VehicleCharacteristicConstant',
    tyreSize: 'TyreSize',
    nextCalibrationDate: 'NextCalibrationDate',
    speedLimit: 'SpeedAuthorised',
    teethOnPhonicWheel: 'NumberOfTeethOnPhonicWheel',
    pproos: 'PulsesPerRevolutionOfOutputShaft',
    utcMinuteOffset: 'AdjustLocalMinuteOffset',
    utcHourOffset: 'AdjustLocalHourOffset',
    resetHeartBeat: 'ResetHeartBeat',
    tco1Priority: 'PriorityLevelOfTCO1Message',
    tco1RepRate: 'TransmissionRepetitionRateOfTCO1Message',
    serviceComponentId: 'ServiceComponentIdentification',
    serviceDelay: 'ServiceDelayCalendarTimeBased',
    prewarningCard1: 'PrewarningTimesCard1Download',
    prewarningTacho: 'PrewarningTimesTachoDownload',
    prewarningCalibration: 'PrewarningTimesCalibrationWarning',
    downloadPeriodCard: 'DownloadPeriodCard',
    downloadPeriodVU: 'DownloadPeriodVU',
    registeringMemberState: 'RegisteringMemberState',
    vrn: 'VehicleRegistrationNumber',
    vehicleRegDate: 'VehicleRegistrationDate',
    supplierIdentifier: 'SystemSupplierIdentifier',
    ecuManufacturingDate: 'ECUManufacturingDate',
    ecuSerialNumber: 'ECUSerialNumber',
    hwNumber: 'SystemSupplierECUHWNumber',
    hwVersion: 'SystemSupplierECUHWVersionNumber',
    swNumber: 'SystemSupplierECUSWNumber',
    swVersion: 'SystemSupplierECUSWVersionNumber',
    typeApproval: 'ExhaustRegulationOrTypeApprovalNumber',
    calibrationDate: 'CalibrationDate',
    ecuInstallDate: 'ECUInstallationDate',
    vehicleSpeed: 'TachographVehicleSpeed',
    driver1WorkingState: 'Driver1WorkingState',
    driver2WorkingState: 'Driver2WorkingState',
    driver1TimeRelatedStates: 'Driver1TimeRelatedStates',
    driver2TimeRelatedStates: 'Driver2TimeRelatedStates',
    driverCardDriver1: 'DriverCardDriver1',
    driver1Identification: 'Driver1Identification',
    driver2Identification: 'Driver2Identification',
    driver1ContinuousDrivingTime: 'Driver1ContinuousDrivingTime',
    driver2ContinuousDrivingTime: 'Driver2ContinuousDrivingTime',
    driver1CumulativeBreakTime: 'Driver1CumulativeBreakTime',
    driver2CumulativeBreakTime: 'Driver2CumulativeBreakTime',
    driver1CurrentDurationOfActivity: 'Driver1CurrentDurationOfActivity',
    driver2CurrentDurationOfActivity: 'Driver2CurrentDurationOfActivity',
    driver1CurrentDailyDrivingTime: 'Driver1CurrentDailyDrivingTime',
    driver2CurrentDailyDrivingTime: 'Driver2CurrentDailyDrivingTime',
    driver1CurrentWeeklyDrivingTime: 'Driver1CurrentWeeklyDrivingTime',
    driver2CurrentWeeklyDrivingTime: 'Driver2CurrentWeeklyDrivingTime',
    driver1Remaining2WeeksDrivingTime: 'Driver1Remaining2WeeksDrivingTime',
    driver2Remaining2WeeksDrivingTime: 'Driver2Remaining2WeeksDrivingTime',
    driver1CardExpiryDate: 'Driver1CardExpiryDate',
    driver2CardExpiryDate: 'Driver2CardExpiryDate',
    driver1AdditionalInformation: 'Driver1AdditionalInformation',
    driver2AdditionalInformation: 'Driver2AdditionalInformation',
    driver1DurationOfNextBreakRest: 'Driver1DurationOfNextBreakRest',
    driver2DurationOfNextBreakRest: 'Driver2DurationOfNextBreakRest',
    driver1RemainingTimeOfCurrentBreakRest:
        'Driver1RemainingTimeOfCurrentBreakRest',
    driver2RemainingTimeOfCurrentBreakRest:
        'Driver2RemainingTimeOfCurrentBreakRest',
    driver1RemainingTimeUntilNextBreakOrRest:
        'Driver1RemainingTimeUntilNextBreakOrRest',
    driver2RemainingTimeUntilNextBreakOrRest:
        'Driver2RemainingTimeUntilNextBreakOrRest',
    driver1EndOfLastDailyRestPeriod: 'Driver1EndOfLastDailyRestPeriod',
    driver2EndOfLastDailyRestPeriod: 'Driver2EndOfLastDailyRestPeriod',
    driver1EndOfLastWeeklyRestPeriod: 'Driver1EndOfLastWeeklyRestPeriod',
    driver2EndOfLastWeeklyRestPeriod: 'Driver2EndOfLastWeeklyRestPeriod',
    driver1OpenCompensationInTheLastWeek:
        'Driver1OpenCompensationInTheLastWeek',
    driver2OpenCompensationInTheLastWeek:
        'Driver2OpenCompensationInTheLastWeek',
    driver1OpenCompensationInWeekBeforeLast:
        'Driver1OpenCompensationInWeekBeforeLast',
    driver2OpenCompensationInWeekBeforeLast:
        'Driver2OpenCompensationInWeekBeforeLast',
    driver1OpenCompensationIn2ndWeekBeforeLast:
        'Driver1OpenCompensationIn2ndWeekBeforeLast',
    driver2OpenCompensationIn2ndWeekBeforeLast:
        'Driver2OpenCompensationIn2ndWeekBeforeLast',
    driver1MinimumDailyRest: 'Driver1MinimumDailyRest',
    driver2MinimumDailyRest: 'Driver2MinimumDailyRest',
    driver1MinimumWeeklyRest: 'Driver1MinimumWeeklyRest',
    driver2MinimumWeeklyRest: 'Driver2MinimumWeeklyRest',
    driver1PreferredLanguage: 'Driver1PreferredLanguage',
    driver2PreferredLanguage: 'Driver2PreferredLanguage',
    driver1CardNextMandatoryDownloadDate:
        'Driver1CardNextMandatoryDownloadDate',
    driver2CardNextMandatoryDownloadDate:
        'Driver2CardNextMandatoryDownloadDate',
    driver1Name: 'Driver1Name',
    driver2Name: 'Driver2Name',
    tachographCardSlot1: 'TachographCardSlot1',
    tachographCardSlot2: 'TachographCardSlot2',
  };

  static String nameOf(int recordId) {
    return _names[recordId] ??
        '0x${recordId.toRadixString(16).padLeft(4, '0').toUpperCase()}';
  }
}

class TachoRoutineId {
  static const int displayTest = 0x0150;
  static const int lcdNegativeMode = 0x0151;
  static const int printerTest = 0x0152;
  static const int hardwareTest = 0x0153;
  static const int smartCardReader = 0x0154;
  static const int buttonTestLoop = 0x0156;
  static const int batteryLevel = 0x0157;
  static const int dataMemoryIntegrity = 0x0158;
  static const int softwareIntegrity = 0x0159;
  static const int buzzer = 0x015A;
}

class DriverAdditionalInfo {
  final int remaining10hDrivingTimes;

  final int remainingReducedDailyRestPeriods;

  final bool hasUnknownPeriods;
  final bool cardDataInsufficient;
  final bool weeklyRestCalculationEnabled;
  final bool isMultiManning;
  final bool hasTimeOverlap;

  const DriverAdditionalInfo({
    required this.remaining10hDrivingTimes,
    required this.remainingReducedDailyRestPeriods,
    required this.hasUnknownPeriods,
    required this.cardDataInsufficient,
    required this.weeklyRestCalculationEnabled,
    required this.isMultiManning,
    required this.hasTimeOverlap,
  });
}

class RdbiResponseParser {
  static Uint8List? extractData(List<int> response, int recordId) {
    final ridH = (recordId >> 8) & 0xFF;
    final ridL = recordId & 0xFF;

    for (int i = 1; i < response.length - 2; i++) {
      if (response[i] == 0x62 &&
          response[i + 1] == ridH &&
          response[i + 2] == ridL) {
        final lenByte = response[i - 1];

        final payloadLength = lenByte - 3;
        final dataStart = i + 3;
        final dataEnd = dataStart + payloadLength;

        if (payloadLength > 0 && dataEnd <= response.length) {
          return Uint8List.fromList(response.sublist(dataStart, dataEnd));
        }
      }
    }
    return null;
  }

  static bool isNegativeResponse(List<int> response) {
    return response.length > 4 && response[4] == 0x7F;
  }

  static int? extractNrc(List<int> response) {
    if (response.length > 6 && response[4] == 0x7F) return response[6];
    return null;
  }

  static String describeNrc(int nrc) {
    switch (nrc) {
      case 0x10:
        return 'generalReject';
      case 0x11:
        return 'serviceNotSupported';
      case 0x12:
        return 'subFunctionNotSupported-invalidFormat';
      case 0x21:
        return 'busy-repeatRequest';
      case 0x22:
        return 'conditionsNotCorrectOrRequestSequenceError';
      case 0x24:
        return 'requestSequenceError';
      case 0x13:
        return 'incorrectMessageLength';
      case 0x31:
        return 'requestOutOfRange';
      case 0x33:
        return 'securityAccessDenied';
      case 0x35:
        return 'invalidKey';
      case 0x36:
        return 'exceedNumberOfAttempts';
      case 0x37:
        return 'requiredTimeDelayNotExpired';
      case 0x50:
        return 'uploadNotAccepted';
      case 0x78:
        return 'requestCorrectlyReceived-ResponsePending';
      case 0xFA:
        return 'dataNotAvailable';
      default:
        return 'unknown (0x${nrc.toRadixString(16).padLeft(2, '0').toUpperCase()})';
    }
  }

  static int parseInt32BE(Uint8List data) {
    if (data.length < 4) return 0;
    return (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
  }

  static int parseInt16BE(Uint8List data) {
    if (data.length < 2) return 0;
    return (data[0] << 8) | data[1];
  }

  static int parseSpeedKmh(Uint8List data) {
    if (data.length < 2) return 0;
    final raw = (data[0] << 8) | data[1];
    return (raw / 256).round();
  }

  static int parseDistanceMeters(Uint8List data) {
    if (data.length < 4) return 0;
    return parseInt32BE(data) * 5;
  }

  static const int _maxValidTimeValue = 64255;

  static Duration? parseMinutesOrNull(Uint8List? data) {
    if (data == null) return null;
    final raw = parseInt16BE(data);
    if (raw > _maxValidTimeValue) return null;
    return Duration(minutes: raw);
  }

  static String parseAscii(Uint8List data) {
    return String.fromCharCodes(
      data,
    ).replaceAll(RegExp(r'[\x00]+$'), '').trim();
  }

  static String parseDriverCardNumber(Uint8List data) {
    if (data.length < 19) return '';
    return parseAscii(data.sublist(3, 19));
  }

  static String parseDriverName(Uint8List data) {
    if (data.length < 72) return '';
    final surname = parseAscii(data.sublist(1, 36));
    final firstName = parseAscii(data.sublist(37, 72));
    final full = '$firstName $surname'.trim();
    return full;
  }

  static DateTime? parseCompactDate(Uint8List data) {
    if (data.length < 3) return null;
    final month = data[0];
    final day = data[1];
    final year = 1985 + data[2];
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static DriverAdditionalInfo? parseAdditionalInformation(Uint8List data) {
    if (data.length < 2) return null;
    final value = parseInt16BE(data);
    return DriverAdditionalInfo(
      remaining10hDrivingTimes: value & 0x07,
      remainingReducedDailyRestPeriods: (value >> 3) & 0x07,
      hasUnknownPeriods: ((value >> 6) & 0x03) == 1,
      cardDataInsufficient: ((value >> 8) & 0x03) == 1,
      weeklyRestCalculationEnabled: ((value >> 10) & 0x03) == 1,
      isMultiManning: ((value >> 12) & 0x03) == 1,
      hasTimeOverlap: ((value >> 14) & 0x03) == 1,
    );
  }

  static DateTime? parseDateTime(Uint8List data) {
    if (data.length < 6) return null;
    try {
      final minute = data[1];
      final hour = data[2];
      final dayEncoded = data[3];
      final month = data[4];
      final year = 1985 + data[5];
      final day = ((dayEncoded - 2) ~/ 4) + 1;
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }
}

class CardDownloadFrame {
  final int trep;
  final int subMessageCounter;
  final Uint8List payload;

  final bool isFinal;

  const CardDownloadFrame({
    required this.trep,
    required this.subMessageCounter,
    required this.payload,
    required this.isFinal,
  });
}

class CardDownloadResponseParser {
  static CardDownloadFrame? parseSubMessage(List<int> response) {
    for (int i = 1; i < response.length - 3; i++) {
      if (response[i] == 0x76) {
        final lenByte = response[i - 1];
        final trep = response[i + 1];
        final hasCounter = response[i + 2] == 0x00;
        final counter = hasCounter
            ? ((response[i + 2] << 8) | response[i + 3])
            : 0;

        final payloadLength = lenByte - (hasCounter ? 4 : 2);
        final dataStart = i + (hasCounter ? 4 : 2);
        final dataEnd = dataStart + payloadLength;

        if (payloadLength >= 0 && dataEnd <= response.length) {
          return CardDownloadFrame(
            trep: trep,
            subMessageCounter: counter,
            payload: Uint8List.fromList(response.sublist(dataStart, dataEnd)),
            isFinal: lenByte < 0xFF,
          );
        }
      }
    }
    return null;
  }

  static bool isVerifyBaudRateAccepted(List<int> response) {
    return response.contains(0xC7);
  }

  static bool isUploadRequestAccepted(List<int> response) {
    return response.contains(0x75);
  }

  static bool isTransferExitAccepted(List<int> response) {
    return response.contains(0x77);
  }
}

class DtcResponseParser {
  static Uint8List? extractPayload(List<int> response, int subFunction) {
    for (int i = 1; i < response.length - 1; i++) {
      if (response[i] == 0x59 && response[i + 1] == subFunction) {
        final lenByte = response[i - 1];
        final payloadLength = lenByte - 2;
        final dataStart = i + 2;
        final dataEnd = dataStart + payloadLength;
        if (payloadLength >= 0 && dataEnd <= response.length) {
          return Uint8List.fromList(response.sublist(dataStart, dataEnd));
        }
      }
    }
    return null;
  }
}

class DtcCodes {
  static const Map<String, String> _descriptions = {
    '002007': 'Sensör güç kaynağı: üst sınırın üzerinde',
    '002003': 'Sensör güç kaynağı: alt sınırın altında',
    '002004': 'Sensör güç kaynağı: sinyal yok',
    '000007': 'Takograf güç kaynağı: üst sınırın üzerinde',
    '000003': 'Takograf güç kaynağı: alt sınırın altında',
    '000004': 'Takograf güç kaynağı: sinyal yok',
    '000200': 'Sürücü Kartı 1 hatası',
    '000300': 'Sürücü Kartı 2 hatası',
    '000660': 'Yazıcıda kağıt kalmadı',
    '002180': 'Sensörden hız sinyali gelmiyor',
    '002280': 'Geçersiz hız sinyali veya veri hattı hatası',
    '002380': 'Hız sensörü — Kayıt Ünitesi arası veri hattı sinyali yok',
    '002452': 'Sensör / takograf imza uyuşmazlığı',
    '000800': 'Saat/tarih hatası',
    '000900': 'Kontak kapalı ama hız darbeleri algılanıyor',
    '000A70': 'CAN veri yolu dahili hatası',
    '000B78': 'CAN veri yolu kapalı (bus off)',
    '000D33': 'Kalibrasyon belleği okuma/yazma hatası',
    '000D40': 'Kalibrasyon hatası',
    '000700': 'Yazıcı hatası',
    '000400': 'Kart okuyucu 1 hatası',
    '000500': 'Kart okuyucu 2 hatası',
    '000F00': 'Düğme/tuş takımı hatası',
    '001030': 'Dahili ekran hatası',
    '002508': 'Sensör dahili hatası',
    '003000': 'Hız darbesi çıkışı (Kayıt Ünitesi) hatası',
    '000139': 'Kayıt ünitesi dahili hatası',
  };

  static String? describe(int high, int mid, int low) {
    final key = [
      high,
      mid,
      low,
    ].map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
    return _descriptions[key];
  }
}

class TachographLiveData {
  String vin;
  String vrn;
  String memberState;

  int speedKmh;
  int odometerMeters;
  DateTime? currentDateTime;

  int kConstant;
  int wConstant;
  int tyreCircumferenceMm;
  String tyreSize;
  int speedLimitKmh;
  DateTime? nextCalibrationDate;

  String hwNumber;
  String hwVersion;
  String swNumber;
  String swVersion;
  String typeApproval;

  int? dtcCount;
  String dtcRawHex;

  DateTime? vehicleRegDate;
  String supplierIdentifier;
  String ecuSerialNumber;
  DateTime? ecuManufacturingDate;
  DateTime? calibrationDate;
  DateTime? ecuInstallDate;
  int tripDistanceMeters;

  String driver1Name;
  String driver2Name;

  String driver1IssuingState;
  String driver1CardNumber;
  String driver2IssuingState;
  String driver2CardNumber;
  String driver1PreferredLanguage;
  String driver2PreferredLanguage;
  DateTime? driver1CardExpiryDate;
  DateTime? driver2CardExpiryDate;
  DateTime? driver1CardNextMandatoryDownloadDate;
  DateTime? driver2CardNextMandatoryDownloadDate;

  int? cardSlot1;
  int? cardSlot2;

  int? driver1TimeRelatedState;
  int? driver2TimeRelatedState;

  TachographLiveData({
    this.driver1Name = '',
    this.driver2Name = '',
    this.driver1IssuingState = '',
    this.driver1CardNumber = '',
    this.driver2IssuingState = '',
    this.driver2CardNumber = '',
    this.driver1PreferredLanguage = '',
    this.driver2PreferredLanguage = '',
    this.driver1CardExpiryDate,
    this.driver2CardExpiryDate,
    this.driver1CardNextMandatoryDownloadDate,
    this.driver2CardNextMandatoryDownloadDate,
    this.vin = '',
    this.vrn = '',
    this.memberState = '',
    this.speedKmh = 0,
    this.odometerMeters = 0,
    this.currentDateTime,
    this.kConstant = 0,
    this.wConstant = 0,
    this.tyreCircumferenceMm = 0,
    this.tyreSize = '',
    this.speedLimitKmh = 0,
    this.nextCalibrationDate,
    this.hwNumber = '',
    this.hwVersion = '',
    this.swNumber = '',
    this.swVersion = '',
    this.typeApproval = '',
    this.dtcCount,
    this.dtcRawHex = '',
    this.vehicleRegDate,
    this.supplierIdentifier = '',
    this.ecuSerialNumber = '',
    this.ecuManufacturingDate,
    this.calibrationDate,
    this.ecuInstallDate,
    this.tripDistanceMeters = 0,
    this.cardSlot1,
    this.cardSlot2,
    this.driver1TimeRelatedState,
    this.driver2TimeRelatedState,
  });

  double get tripDistanceKm => tripDistanceMeters / 1000.0;

  double get odometerKm => odometerMeters / 1000.0;

  int get tyreCircumferenceActualMm => tyreCircumferenceMm * 8;

  Map<String, dynamic> toJson() => {
    'driver1Name': driver1Name,
    'driver2Name': driver2Name,
    'driver1IssuingState': driver1IssuingState,
    'driver1CardNumber': driver1CardNumber,
    'driver2IssuingState': driver2IssuingState,
    'driver2CardNumber': driver2CardNumber,
    'driver1PreferredLanguage': driver1PreferredLanguage,
    'driver2PreferredLanguage': driver2PreferredLanguage,
    'driver1CardExpiryDate': driver1CardExpiryDate?.toIso8601String(),
    'driver2CardExpiryDate': driver2CardExpiryDate?.toIso8601String(),
    'driver1CardNextMandatoryDownloadDate': driver1CardNextMandatoryDownloadDate
        ?.toIso8601String(),
    'driver2CardNextMandatoryDownloadDate': driver2CardNextMandatoryDownloadDate
        ?.toIso8601String(),
    'vin': vin,
    'vrn': vrn,
    'memberState': memberState,
    'speedKmh': speedKmh,
    'odometerMeters': odometerMeters,
    'currentDateTime': currentDateTime?.toIso8601String(),
    'kConstant': kConstant,
    'wConstant': wConstant,
    'tyreCircumferenceMm': tyreCircumferenceMm,
    'tyreSize': tyreSize,
    'speedLimitKmh': speedLimitKmh,
    'nextCalibrationDate': nextCalibrationDate?.toIso8601String(),
    'hwNumber': hwNumber,
    'hwVersion': hwVersion,
    'swNumber': swNumber,
    'swVersion': swVersion,
    'typeApproval': typeApproval,
    'dtcCount': dtcCount,
    'dtcRawHex': dtcRawHex,
    'vehicleRegDate': vehicleRegDate?.toIso8601String(),
    'supplierIdentifier': supplierIdentifier,
    'ecuSerialNumber': ecuSerialNumber,
    'ecuManufacturingDate': ecuManufacturingDate?.toIso8601String(),
    'calibrationDate': calibrationDate?.toIso8601String(),
    'ecuInstallDate': ecuInstallDate?.toIso8601String(),
    'tripDistanceMeters': tripDistanceMeters,
    'cardSlot1': cardSlot1,
    'cardSlot2': cardSlot2,
    'driver1TimeRelatedState': driver1TimeRelatedState,
    'driver2TimeRelatedState': driver2TimeRelatedState,
  };

  static DateTime? _dateOrNull(dynamic iso) =>
      iso == null ? null : DateTime.tryParse(iso as String);

  factory TachographLiveData.fromJson(
    Map<String, dynamic> json,
  ) => TachographLiveData(
    driver1Name: json['driver1Name'] as String? ?? '',
    driver2Name: json['driver2Name'] as String? ?? '',
    driver1IssuingState: json['driver1IssuingState'] as String? ?? '',
    driver1CardNumber: json['driver1CardNumber'] as String? ?? '',
    driver2IssuingState: json['driver2IssuingState'] as String? ?? '',
    driver2CardNumber: json['driver2CardNumber'] as String? ?? '',
    driver1PreferredLanguage: json['driver1PreferredLanguage'] as String? ?? '',
    driver2PreferredLanguage: json['driver2PreferredLanguage'] as String? ?? '',
    driver1CardExpiryDate: _dateOrNull(json['driver1CardExpiryDate']),
    driver2CardExpiryDate: _dateOrNull(json['driver2CardExpiryDate']),
    driver1CardNextMandatoryDownloadDate: _dateOrNull(
      json['driver1CardNextMandatoryDownloadDate'],
    ),
    driver2CardNextMandatoryDownloadDate: _dateOrNull(
      json['driver2CardNextMandatoryDownloadDate'],
    ),
    vin: json['vin'] as String? ?? '',
    vrn: json['vrn'] as String? ?? '',
    memberState: json['memberState'] as String? ?? '',
    speedKmh: json['speedKmh'] as int? ?? 0,
    odometerMeters: json['odometerMeters'] as int? ?? 0,
    currentDateTime: _dateOrNull(json['currentDateTime']),
    kConstant: json['kConstant'] as int? ?? 0,
    wConstant: json['wConstant'] as int? ?? 0,
    tyreCircumferenceMm: json['tyreCircumferenceMm'] as int? ?? 0,
    tyreSize: json['tyreSize'] as String? ?? '',
    speedLimitKmh: json['speedLimitKmh'] as int? ?? 0,
    nextCalibrationDate: _dateOrNull(json['nextCalibrationDate']),
    hwNumber: json['hwNumber'] as String? ?? '',
    hwVersion: json['hwVersion'] as String? ?? '',
    swNumber: json['swNumber'] as String? ?? '',
    swVersion: json['swVersion'] as String? ?? '',
    typeApproval: json['typeApproval'] as String? ?? '',
    dtcCount: json['dtcCount'] as int?,
    dtcRawHex: json['dtcRawHex'] as String? ?? '',
    vehicleRegDate: _dateOrNull(json['vehicleRegDate']),
    supplierIdentifier: json['supplierIdentifier'] as String? ?? '',
    ecuSerialNumber: json['ecuSerialNumber'] as String? ?? '',
    ecuManufacturingDate: _dateOrNull(json['ecuManufacturingDate']),
    calibrationDate: _dateOrNull(json['calibrationDate']),
    ecuInstallDate: _dateOrNull(json['ecuInstallDate']),
    tripDistanceMeters: json['tripDistanceMeters'] as int? ?? 0,
    cardSlot1: json['cardSlot1'] as int?,
    cardSlot2: json['cardSlot2'] as int?,
    driver1TimeRelatedState: json['driver1TimeRelatedState'] as int?,
    driver2TimeRelatedState: json['driver2TimeRelatedState'] as int?,
  );
}
