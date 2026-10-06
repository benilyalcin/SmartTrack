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
    clientInVehicle => 'Araç içi',
    clientCardSlot1 => 'Yuva 1 (sürücü)',
    clientCardSlot2 => 'Yuva 2 (yardımcı sürücü)',
    _ => 'İstemci $client',
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

  /// PrintoutType, as far as this unit prints them.
  static const List<(int, String)> printoutTypes = [
    (0x01, 'Sürücü aktiviteleri (kart), günlük'),
    (0x02, 'Yardımcı sürücü aktiviteleri (kart), günlük'),
    (0x03, 'Sürücü olay ve arızaları (kart)'),
    (0x04, 'Yardımcı sürücü olay ve arızaları (kart)'),
    (0x05, 'Sürücü aktiviteleri (VU), günlük'),
    (0x06, 'VU olay ve arızaları'),
    (0x07, 'Teknik veri'),
    (0x08, 'Hız aşımı'),
  ];

  static bool printoutNeedsDate(int type) =>
      type == 0x01 || type == 0x02 || type == 0x05;

  static String printoutName(int type) =>
      printoutTypes.where((p) => p.$1 == type).firstOrNull?.$2 ??
      'tip 0x${type.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  /// EventFaultType for the codes a warning can carry.
  static String eventFaultName(int code) {
    if (code >= 0x10 && code <= 0x1F) return 'güvenlik ihlali girişimi';
    if (code >= 0x96 && code <= 0x9C) return 'sürüş / dinlenme süresi uyarısı';
    return switch (code) {
      0x00 => 'ayrıntı yok',
      0x01 => 'geçersiz kart takıldı',
      0x02 => 'kart çakışması',
      0x03 => 'zaman çakışması',
      0x04 => 'uygun kart olmadan sürüş',
      0x05 => 'sürüş sırasında kart takıldı',
      0x06 => 'son kart oturumu düzgün kapanmadı',
      0x07 => 'hız aşımı',
      0x08 => 'güç kesintisi',
      0x09 => 'hareket verisi hatası',
      0x0A => 'araç hareketi çakışması',
      0x0B => 'zaman çakışması (GNSS / VU saati)',
      0x0C => 'uzak iletişim birimi hatası',
      0x0D => 'GNSS konum bilgisi yok',
      0x0E => 'harici GNSS birimi hatası',
      0x30 => 'kayıt cihazı arızası',
      0x31 => 'VU iç arızası',
      0x32 => 'yazıcı arızası',
      0x33 => 'ekran arızası',
      0x34 => 'indirme arızası',
      0x35 => 'sensör arızası',
      0x36 => 'dahili GNSS alıcısı',
      0x37 => 'harici GNSS birimi',
      0x38 => 'uzak iletişim birimi',
      0x39 => 'ITS arayüzü',
      0x40 => 'kart arızası',
      0x81 => 'hız aşımı ön uyarısı',
      0x82 => 'kart süresi doluyor',
      0x83 => 'kalibrasyon / servis zamanı',
      0x86 => 'yanlış kart tipi',
      0x87 => 'PIN bloke',
      0x88 => 'kayıt tutarsız',
      0x92 => 'kart indirme zamanı',
      0x93 => 'VU indirme zamanı',
      0xAE => 'kontakta kart yok',
      _ => 'kod 0x${code.toRadixString(16).padLeft(2, '0').toUpperCase()}',
    };
  }

  /// NationNumeric, from the unit's own CountryInfo.cpp. Zero is "no
  /// information available".
  static const List<(int, String)> countries = [
    (0x30, 'TR - Türkiye'),
    (0x01, 'A - Avusturya'),
    (0x02, 'AL - Arnavutluk'),
    (0x03, 'AND - Andorra'),
    (0x04, 'ARM - Ermenistan'),
    (0x05, 'AZ - Azerbaycan'),
    (0x06, 'B - Belçika'),
    (0x07, 'BG - Bulgaristan'),
    (0x08, 'BIH - Bosna-Hersek'),
    (0x09, 'BY - Belarus'),
    (0x0A, 'CH - İsviçre'),
    (0x0B, 'CY - Kıbrıs'),
    (0x0C, 'CZ - Çekya'),
    (0x0D, 'D - Almanya'),
    (0x0E, 'DK - Danimarka'),
    (0x0F, 'E - İspanya'),
    (0x10, 'EST - Estonya'),
    (0x11, 'F - Fransa'),
    (0x12, 'FIN - Finlandiya'),
    (0x13, 'FL - Lihtenştayn'),
    (0x14, 'FO - Faroe Adaları'),
    (0x15, 'UK - Birleşik Krallık'),
    (0x16, 'GE - Gürcistan'),
    (0x17, 'GR - Yunanistan'),
    (0x18, 'H - Macaristan'),
    (0x19, 'HR - Hırvatistan'),
    (0x1A, 'I - İtalya'),
    (0x1B, 'IRL - İrlanda'),
    (0x1C, 'IS - İzlanda'),
    (0x1D, 'KZ - Kazakistan'),
    (0x1E, 'L - Lüksemburg'),
    (0x1F, 'LT - Litvanya'),
    (0x20, 'LV - Letonya'),
    (0x21, 'M - Malta'),
    (0x22, 'MC - Monako'),
    (0x23, 'MD - Moldova'),
    (0x24, 'MK - Kuzey Makedonya'),
    (0x25, 'N - Norveç'),
    (0x26, 'NL - Hollanda'),
    (0x27, 'P - Portekiz'),
    (0x28, 'PL - Polonya'),
    (0x29, 'RO - Romanya'),
    (0x2A, 'RSM - San Marino'),
    (0x2B, 'RUS - Rusya'),
    (0x2C, 'S - İsveç'),
    (0x2D, 'SK - Slovakya'),
    (0x2E, 'SLO - Slovenya'),
    (0x2F, 'TM - Türkmenistan'),
    (0x31, 'UA - Ukrayna'),
    (0x32, 'V - Vatikan'),
    (0x34, 'MNE - Karadağ'),
    (0x35, 'SRB - Sırbistan'),
    (0x36, 'UZ - Özbekistan'),
    (0x37, 'TJ - Tacikistan'),
    (0x38, 'KG - Kırgızistan'),
    (0x39, 'IL - İsrail'),
    (0xFD, 'EC - Avrupa Topluluğu'),
    (0xFE, 'EUR - Avrupa\'nın geri kalanı'),
    (0xFF, 'WLD - Dünyanın geri kalanı'),
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
  closedOpenPossible(0x00, 'Kapalı, açılabilir'),
  closedUserDecisionPending(0x01, 'Takograf ekranında onay bekleniyor'),
  open(0x10, 'Açık'),
  closedUserRejected(0x20, 'Kapalı, bir kullanıcı reddetti'),
  closedLocalHmiIsUsed(0x21, 'Kapalı, takograf menüsü kullanımda'),
  closedGeneralConditionsNotMet(0x2F, 'Kapalı, koşullar sağlanmıyor');

  const RhmiSessionStatus(this.code, this.label);
  final int code;
  final String label;

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
