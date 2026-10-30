import '../../localization/localization.dart';
import '../eu_nation_codes.dart';

/// Remote HMI request construction, against the ATC's own
/// CalibrationProtocol::respondRhmiRoutine - a port of AvuItsTester's
/// Rhmi.kt, RhmiCrc32.kt and PlaceCodes.kt.
///
/// Two shapes of request exist. The routines usable before a client has an
/// identifier - open session, close session, pair - are bare. Everything
/// else carries a tail: the time the request was made, and a checksum over
/// everything in front of it together with the session identifier that
/// client holds. The identifier itself never goes on the wire.
class Rhmi {
  Rhmi._();

  static const int sidRoutineControl = 0x31;

  static const int ridManualEntry = 0xF200;
  static const int ridCardWithdrawal = 0xF201;
  static const int ridAcknowledgeWarnings = 0xF202;
  static const int ridEntryOfPlace = 0xF203;
  static const int ridEntryOfSpecificCondition = 0xF204;
  static const int ridSetActivity = 0xF205;
  static const int ridLoadUnload = 0xF206;
  static const int ridPrintout = 0xF210;
  static const int ridOpenSession = 0xF211;
  static const int ridCloseSession = 0xF212;
  static const int ridPairClient = 0xF213;
  static const int ridVerifySessionId = 0xF214;

  static const int routineStart = 0x01;
  static const int routineStop = 0x02;
  static const int routineRequestResults = 0x03;

  static const int clientInVehicle = 0;
  static const int clientCardSlot1 = 1;
  static const int clientCardSlot2 = 2;

  static const int transportPlain = 0x00;
  static const int sessionIdSize = 8;
  static const int tokenSize = 4;

  static const int optionGetInsertedCardType = 0x01;
  static const int optionGetPeriod = 0x02;

  static const int cardTypeDriver = 0x01;
  static const int cardTypeWorkshop = 0x02;

  /// DailyWorkPeriodEntryType for EntryOfPlace.
  static const int placeBegin = 0x00;
  static const int placeEnd = 0x01;

  /// SpecificConditionType, generation 2 values.
  static const int outOfScopeBegin = 0x01;
  static const int outOfScopeEnd = 0x02;
  static const int ferryTrainBegin = 0x03;
  static const int ferryTrainEnd = 0x04;

  /// ActivityType for SetActivity. Driving is not settable.
  static const int activityRest = 0x00;
  static const int activityAvailability = 0x01;
  static const int activityWork = 0x02;

  /// OperationType for LoadUnload.
  static const int operationLoad = 0x01;
  static const int operationUnload = 0x02;
  static const int operationLoadAndUnload = 0x03;

  /// routineControlOption of the warnings results.
  static const int warningsOverview = 0x01;
  static const int warningGet = 0x02;
  static const int warningNotAvailable = 0xFFFF;

  /// CurrentShiftPrintoutRequest of the card withdrawal.
  static const int shiftPrintoutNone = 0x00;
  static const int shiftPrintoutUtc = 0x01;
  static const int shiftPrintoutLocal = 0x02;

  static const int printoutGetPeriod = 0x01;
  static const int printoutStart = 0x02;
  static const int printoutNoManufacturer = 0xFF;

  static const int printoutNormalExit = 0x61;
  static const int printoutAbnormalExit = 0x63;
  static const int printoutOngoing = 0x78;
  static const int printoutNoStatus = 0xFF;
  static const int printoutTypeNotRemote = 0xFA;

  /// The tolerance the unit allows on RHMITimestamp.
  static const int timestampToleranceSeconds = 300;

  /// SmartCardSlot is CardSlotNumber: driver slot 0, co-driver slot 1. The
  /// screens count the slots 1 and 2, as they are marked on the unit.
  static int cardSlotNumber(int slot) => slot - 1;

  static String clientName(int client) => switch (client) {
    clientInVehicle => AppLocalizations.text('rhmi.client.vehicle'),
    clientCardSlot1 => AppLocalizations.text('rhmi.client.slot1'),
    clientCardSlot2 => AppLocalizations.text('rhmi.client.slot2'),
    _ => AppLocalizations.text('rhmi.client.other', {'n': client}),
  };

  /// A bare routine request: service, sub-function, routine identifier,
  /// then whatever follows.
  static List<int> routine(
    int subFunction,
    int routineId, [
    List<int> body = const [],
  ]) => [
    sidRoutineControl,
    subFunction,
    (routineId >> 8) & 0xFF,
    routineId & 0xFF,
    ...body,
  ];

  /// The same with the timestamp and checksum tail. [body] is everything
  /// between the routine identifier and the tail.
  static List<int> signedRoutine(
    int subFunction,
    int routineId,
    List<int> body,
    List<int> sessionId,
    int timestampSeconds,
  ) {
    if (sessionId.length != sessionIdSize) {
      throw ArgumentError('a session identifier is eight bytes');
    }
    final signed = [
      ...routine(subFunction, routineId, body),
      ...u32(timestampSeconds),
    ];
    return [...signed, ...u32(crc32(signed, sessionId))];
  }

  /// TransportChecksum: over the plain identifier followed by the token.
  static int transportChecksum(List<int> sessionId, List<int> token) =>
      crc32(sessionId, token);

  /// Recovers the plain session identifier from what PairRHMIclient
  /// returned: both halves are exclusive-ored with the whole token.
  static List<int> deobfuscate(List<int> transmitted, List<int> token) => [
    for (var i = 0; i < sessionIdSize; i++)
      transmitted[i] ^ token[i % tokenSize],
  ];

  /// The eight digits read off the unit display, two per byte; null for
  /// anything that is not eight digits.
  static List<int>? tokenFromDigits(String digits) {
    final t = digits.replaceAll(RegExp(r'\s'), '');
    if (t.length != tokenSize * 2 || !RegExp(r'^\d+$').hasMatch(t)) {
      return null;
    }
    return [
      for (var i = 0; i < tokenSize; i++)
        (int.parse(t[i * 2]) << 4) | int.parse(t[i * 2 + 1]),
    ];
  }

  /// The Remote HMI checksum: polynomial 0x04C11DB7 reflected, initial
  /// value zero and no final XOR - not the usual zip CRC32, which starts at
  /// 0xFFFFFFFF and inverts at the end. A request signed with that one comes
  /// back invalidKey with nothing to say why.
  static int crc32(List<int> first, [List<int> second = const []]) {
    var crc = 0;
    for (final run in [first, second]) {
      for (final byte in run) {
        crc ^= byte & 0xFF;
        for (var i = 0; i < 8; i++) {
          crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
        }
      }
    }
    return crc & 0xFFFFFFFF;
  }

  static List<int> u32(int v) => [
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ];

  static int readU32(List<int> d, int at) =>
      (d[at] << 24) | (d[at + 1] << 16) | (d[at + 2] << 8) | d[at + 3];

  static int readU16(List<int> d, int at) => (d[at] << 8) | d[at + 1];

  /// The response to PairRHMIclient. [data] follows the positive service
  /// identifier 0x71: sub-function, routine id, client, transport type,
  /// identifier, checksum.
  static RhmiPairingResponse? parsePairingResponse(List<int> data) {
    if (data.length < 17) return null;
    return RhmiPairingResponse(
      client: data[3],
      transportType: data[4],
      transmittedSessionId: data.sublist(5, 13),
      transportChecksum: readU32(data, 13),
    );
  }

  /// The manual entry period: option, routineInfo, two TimeReals, then the
  /// country and region of the end place.
  static ManualEntryPeriod? parseManualEntryPeriod(List<int> data) {
    if (data.length < 15) return null;
    return ManualEntryPeriod(
      routineInfo: data[4],
      periodBegin: readU32(data, 5),
      periodEnd: readU32(data, 9),
      endCountryCode: data[13],
      endRegionCode: data[14],
    );
  }

  /// PrintoutType, as far as this unit prints them: 0x01-0x08, named
  /// `rhmi.printout.<type>`.
  static List<(int, String)> get printoutTypes => [
    for (var type = 0x01; type <= 0x08; type++)
      (type, AppLocalizations.text('rhmi.printout.$type')),
  ];

  static bool printoutNeedsDate(int type) =>
      type == 0x01 || type == 0x02 || type == 0x05;

  static String printoutName(int type) =>
      printoutTypes.where((p) => p.$1 == type).firstOrNull?.$2 ??
      AppLocalizations.text('rhmi.printout.other', {'code': _hex(type)});

  static String _hex(int v) =>
      '0x${v.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  /// The EventFaultType codes with a name of their own, `rhmi.ef.<XX>`.
  static const Set<int> _namedEventFaults = {
    0x00,
    0x01,
    0x02,
    0x03,
    0x04,
    0x05,
    0x06,
    0x07,
    0x08,
    0x09,
    0x0A,
    0x0B,
    0x0C,
    0x0D,
    0x0E,
    0x30,
    0x31,
    0x32,
    0x33,
    0x34,
    0x35,
    0x36,
    0x37,
    0x38,
    0x39,
    0x40,
    0x81,
    0x82,
    0x83,
    0x86,
    0x87,
    0x88,
    0x92,
    0x93,
    0xAE,
  };

  /// EventFaultType for the codes a warning can carry.
  static String eventFaultName(int code) {
    if (code >= 0x10 && code <= 0x1F) {
      return AppLocalizations.text('rhmi.ef.security');
    }
    if (code >= 0x96 && code <= 0x9C) {
      return AppLocalizations.text('rhmi.ef.drivingTime');
    }
    if (_namedEventFaults.contains(code)) {
      final key = code.toRadixString(16).padLeft(2, '0').toUpperCase();
      return AppLocalizations.text('rhmi.ef.$key');
    }
    return AppLocalizations.text('rhmi.ef.other', {'code': _hex(code)});
  }

  /// NationNumeric, from the unit's own CountryInfo.cpp, with the
  /// distinguishing sign it is shown with. Zero is "no information
  /// available". The names are EuNationCodes', in the app language.
  static const List<(int, String)> _countrySigns = [
    (0x30, 'TR'),
    (0x01, 'A'),
    (0x02, 'AL'),
    (0x03, 'AND'),
    (0x04, 'ARM'),
    (0x05, 'AZ'),
    (0x06, 'B'),
    (0x07, 'BG'),
    (0x08, 'BIH'),
    (0x09, 'BY'),
    (0x0A, 'CH'),
    (0x0B, 'CY'),
    (0x0C, 'CZ'),
    (0x0D, 'D'),
    (0x0E, 'DK'),
    (0x0F, 'E'),
    (0x10, 'EST'),
    (0x11, 'F'),
    (0x12, 'FIN'),
    (0x13, 'FL'),
    (0x14, 'FO'),
    (0x15, 'UK'),
    (0x16, 'GE'),
    (0x17, 'GR'),
    (0x18, 'H'),
    (0x19, 'HR'),
    (0x1A, 'I'),
    (0x1B, 'IRL'),
    (0x1C, 'IS'),
    (0x1D, 'KZ'),
    (0x1E, 'L'),
    (0x1F, 'LT'),
    (0x20, 'LV'),
    (0x21, 'M'),
    (0x22, 'MC'),
    (0x23, 'MD'),
    (0x24, 'MK'),
    (0x25, 'N'),
    (0x26, 'NL'),
    (0x27, 'P'),
    (0x28, 'PL'),
    (0x29, 'RO'),
    (0x2A, 'RSM'),
    (0x2B, 'RUS'),
    (0x2C, 'S'),
    (0x2D, 'SK'),
    (0x2E, 'SLO'),
    (0x2F, 'TM'),
    (0x31, 'UA'),
    (0x32, 'V'),
    (0x34, 'MNE'),
    (0x35, 'SRB'),
    (0x36, 'UZ'),
    (0x37, 'TJ'),
    (0x38, 'KG'),
    (0x39, 'IL'),
    (0xFD, 'EC'),
    (0xFE, 'EUR'),
    (0xFF, 'WLD'),
  ];

  static List<(int, String)> get countries => [
    for (final (code, sign) in _countrySigns)
      (code, '$sign - ${EuNationCodes.label(code)}'),
  ];

  /// NationNumeric for Spain, the only country the region field applies to.
  static const int spain = 0x0F;

  /// RegionNumeric: Spanish autonomous communities and nothing else.
  static const List<(int, String)> regions = [
    (0x01, 'AN - Andalucía'),
    (0x02, 'AR - Aragón'),
    (0x03, 'AST - Asturias'),
    (0x04, 'C - Cantabria'),
    (0x05, 'CAT - Cataluña'),
    (0x06, 'CL - Castilla y León'),
    (0x07, 'CM - Castilla-La Mancha'),
    (0x08, 'CV - Valencia'),
    (0x09, 'EXT - Extremadura'),
    (0x0A, 'G - Galicia'),
    (0x0B, 'IB - Baleares'),
    (0x0C, 'IC - Canarias'),
    (0x0D, 'LR - La Rioja'),
    (0x0E, 'M - Madrid'),
    (0x0F, 'MU - Murcia'),
    (0x10, 'NA - Navarra'),
    (0x11, 'PV - País Vasco'),
  ];
}

/// RHMIsessionStatus, as the unit's RhmiSession::Status defines it.
enum RhmiSessionStatus {
  closedOpenPossible(0x00),
  closedUserDecisionPending(0x01),
  open(0x10),
  closedUserRejected(0x20),
  closedLocalHmiIsUsed(0x21),
  closedGeneralConditionsNotMet(0x2F);

  const RhmiSessionStatus(this.code);
  final int code;

  String get label => AppLocalizations.text('rhmi.session.$name');

  static RhmiSessionStatus? of(int code) =>
      values.where((s) => s.code == code).firstOrNull;
}

class RhmiPairingResponse {
  const RhmiPairingResponse({
    required this.client,
    required this.transportType,
    required this.transmittedSessionId,
    required this.transportChecksum,
  });

  final int client;
  final int transportType;
  final List<int> transmittedSessionId;
  final int transportChecksum;

  bool get isPlain => transportType == Rhmi.transportPlain;
}

class ManualEntryPeriod {
  const ManualEntryPeriod({
    required this.routineInfo,
    required this.periodBegin,
    required this.periodEnd,
    required this.endCountryCode,
    required this.endRegionCode,
  });

  final int routineInfo;
  final int periodBegin;
  final int periodEnd;
  final int endCountryCode;
  final int endRegionCode;

  bool get isEndPlacePresent => endCountryCode != 0;
}

/// One warning as GetActiveVUWarning gives it.
class VuWarning {
  const VuWarning(this.index, this.legalCode, this.status);
  final int index;
  final int legalCode;
  final int status;
}

/// The days a daily printout can be made for: midnight UTC of the first
/// and last, or zero.
class PrintoutPeriod {
  const PrintoutPeriod(this.type, this.oldest, this.newest);
  final int type;
  final int oldest;
  final int newest;
}
