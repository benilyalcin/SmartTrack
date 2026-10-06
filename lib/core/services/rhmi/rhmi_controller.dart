import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../bluetooth/vu/its_link.dart';
import '../bluetooth_service.dart';
import '../kline_protocol.dart';
import 'manual_entry.dart';
import 'rhmi.dart';
import 'rhmi_pairing_store.dart';

/// Drives Remote HMI over the ATC's ITS diagnostics channel - the RHMI half
/// of AvuItsTester's VuViewModel, so the order of an exchange lives in one
/// place rather than in the buttons that start it.
class RhmiController extends ChangeNotifier {
  RhmiController._();
  static final RhmiController instance = RhmiController._();

  int client = Rhmi.clientCardSlot1;
  List<RhmiPairing> pairings = const [];

  /// An obfuscated pairing waiting for the token from the unit display.
  RhmiPairingResponse? awaitingToken;
  RhmiSessionStatus? sessionStatus;
  int? cardType;
  ManualEntryPeriod? period;

  /// How far the unit clock runs ahead of this phone, once measured. Signed
  /// requests are stamped in the unit's time while it is set: the unit
  /// refuses anything more than five minutes off its own clock.
  int? clockOffsetSeconds;
  DateTime _clockMeasuredAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _clockMaxAge = Duration(minutes: 1);

  String? busy;
  String? message;

  /// Clients whose identifier the unit confirmed with F214 on this link.
  Set<int> verifiedClients = {};
  List<VuWarning>? warnings;
  PrintoutPeriod? printoutPeriod;

  String? _device;

  ItsLink? get _link => AppBluetoothService.instance.itsDiagnostics;

  bool get isConnected => _link != null;
  bool get isIdle => busy == null;
  bool get isSessionOpen => sessionStatus == RhmiSessionStatus.open;
  bool isPaired(int c) => pairings.any((p) => p.client == c);

  /// Picks up a connection to another unit, or a new one to the same:
  /// what was verified or open belonged to the last link.
  Future<void> syncDevice() async {
    final device = AppBluetoothService.instance.activeDeviceId;
    if (device == _device) return;
    _device = device;
    sessionStatus = null;
    verifiedClients = {};
    awaitingToken = null;
    period = null;
    cardType = null;
    warnings = null;
    printoutPeriod = null;
    clockOffsetSeconds = null;
    pairings = device == null
        ? const []
        : await RhmiPairingStore.instance.all(device);
    notifyListeners();
  }

  void setClient(int value) {
    client = value;
    message = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Plumbing
  // ---------------------------------------------------------------------

  int _now() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + (clockOffsetSeconds ?? 0);

  Future<void> _run(String what, Future<String> Function(ItsLink) block) async {
    final link = _link;
    if (link == null) {
      message = 'Bir ATC 8256\'ya bağlı değil.';
      notifyListeners();
      return;
    }
    if (busy != null) return;

    busy = what;
    message = null;
    notifyListeners();

    String outcome;
    try {
      if (!link.isOpen && !await link.open()) {
        outcome =
            'Diagnostik kanalı açılamadı: takograf reddetti ya da yanıt '
            'vermedi. Ön konektör kullanımda olabilir.';
      } else {
        outcome = await block(link);
      }
    } catch (e) {
      outcome = 'Başarısız: $e';
    }
    debugPrint('RHMI: $what -> $outcome');
    busy = null;
    message = outcome;
    notifyListeners();
  }

  /// The same, for requests that need an identifier to sign with.
  Future<void> _signed(
    String what,
    Future<String> Function(ItsLink, RhmiPairing) block, {
    bool needsSession = true,
    int? asClient,
  }) async {
    final device = _device;
    final pairing = device == null
        ? null
        : await RhmiPairingStore.instance.get(device, asClient ?? client);
    if (pairing == null) {
      message = '${Rhmi.clientName(asClient ?? client)} eşleştirilmemiş.';
      notifyListeners();
      return;
    }
    if (needsSession) {
      final notOpen = _sessionNotOpen();
      if (notOpen != null) {
        message = notOpen;
        notifyListeners();
        return;
      }
    }
    await _run(what, (link) async {
      // Before the request is built: the timestamp is signed into it.
      if (clockOffsetSeconds == null ||
          DateTime.now().difference(_clockMeasuredAt) > _clockMaxAge) {
        await _readClockOffset(link);
      }
      return block(link, pairing);
    });
  }

  String? _sessionNotOpen() => switch (sessionStatus) {
    RhmiSessionStatus.open => null,
    RhmiSessionStatus.closedUserDecisionPending =>
      'Oturum bekliyor: takograf ekranındaki soruyu yanıtlayın.',
    RhmiSessionStatus.closedUserRejected =>
      'Bir kullanıcı oturumu reddetti. Oturumu kapatıp yeniden açın.',
    null => 'Oturum durumu bilinmiyor: önce oturumu açın.',
    final s => 'Oturum açık değil (${s.label}). Önce oturumu açın.',
  };

  Future<List<int>?> _request(
    ItsLink link,
    List<int> data, {
    Duration timeout = const Duration(seconds: 15),
  }) => link.request(data, timeout: timeout);

  List<int> _signedRoutine(
    RhmiPairing pairing,
    int subFunction,
    int routineId,
    List<int> body,
  ) => Rhmi.signedRoutine(
    subFunction,
    routineId,
    body,
    pairing.sessionId,
    _now(),
  );

  static bool _isNegative(List<int> r) => r.length > 6 && r[4] == 0x7F;
  static int _nrc(List<int> r) => r[6];

  /// The service data after the positive service identifier.
  static List<int> _data(List<int> r) =>
      r.length > 5 ? r.sublist(5, 4 + r[3]) : const [];

  static String _hex2(int v) =>
      '0x${v.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  String _negative(List<int> r) {
    final nrc = _nrc(r);
    final base =
        'Reddedildi: ${RdbiResponseParser.describeNrc(nrc)} (${_hex2(nrc)})';
    return switch (nrc) {
      0x35 =>
        '$base\nTakograf bu telefonun kimliğini tanımıyor: eşleştirme '
            'kaybolmuş ya da yuvadaki kart değişmiş. Yeniden eşleştirin.',
      0x37 =>
        '$base\nYanlış imzalı bir istek nedeniyle takograf 10 sn boyunca RHMI '
            'isteklerini reddediyor. Bekleyip tekrar deneyin.',
      0x31 =>
        '$base\nGenellikle saat farkı: takograf ve telefon saati '
            '${Rhmi.timestampToleranceSeconds} sn\'den fazla farklı olabilir.',
      0x21 =>
        '$base\nTakografta başka bir RHMI işlemi sürüyor, tekrar deneyin.',
      _ => base,
    };
  }

  /// Reads F90B and how far the unit clock is from this phone. A plain read
  /// that needs no session or pairing.
  Future<int?> _readClockOffset(ItsLink link) async {
    final r = await _request(link, const [0x22, 0xF9, 0x0B]);
    if (r == null || _isNegative(r)) return null;
    final d = _data(r);
    if (d.length < 10 || d[0] != 0xF9 || d[1] != 0x0B) return null;

    final second = d[2] ~/ 4, minute = d[3], hour = d[4];
    final month = d[5], day = d[6] ~/ 4, year = d[7] + 1985;
    if (day == 0 || month == 0 || month > 12 || hour > 23 || minute > 59) {
      return null;
    }
    final unit =
        DateTime.utc(
          year,
          month,
          day,
          hour,
          minute,
          second,
        ).millisecondsSinceEpoch ~/
        1000;
    final offset = unit - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    clockOffsetSeconds = offset;
    _clockMeasuredAt = DateTime.now();
    return offset;
  }

  Future<void> checkClocks() => _run('Takograf saati okunuyor', (link) async {
    final drift = await _readClockOffset(link);
    if (drift == null) return 'Takograf saati okunamadı.';
    final dir = drift >= 0 ? 'ileride' : 'geride';
    final abs = drift.abs();
    return abs <= Rhmi.timestampToleranceSeconds
        ? 'Takograf saati telefondan $abs sn $dir; tolerans içinde.'
        : 'Takograf saati telefondan $abs sn $dir; tolerans dışında. İstekler '
              'takograf saatiyle imzalanacak.';
  });

  // ---------------------------------------------------------------------
  // Pairing
  // ---------------------------------------------------------------------

  /// PairRHMIclient. The unit draws a fresh identifier, returns it -
  /// obfuscated unless it is unactivated or in calibration mode - and shows
  /// a token on its display, so somebody has to be standing at the vehicle.
  Future<void> pairClient() => _run('Eşleştiriliyor', (link) async {
    final r = await _request(
      link,
      Rhmi.routine(Rhmi.routineStart, Rhmi.ridPairClient, [client]),
    );
    if (r == null) return 'Yanıt yok.';
    if (_isNegative(r)) return _negative(r);
    final pairing = Rhmi.parsePairingResponse(_data(r));
    if (pairing == null) return 'Eşleştirme yanıtı okunamadı.';

    if (pairing.isPlain) {
      await _store(client, pairing.transmittedSessionId);
      return 'Eşleştirildi (açık aktarım, kod gerekmedi).';
    }
    awaitingToken = pairing;
    return 'Takograf ekranındaki 8 haneli kodu girin.';
  });

  /// The second half of an obfuscated pairing: the token recovers the
  /// identifier, and the transport checksum proves it before anything is
  /// signed with it.
  Future<void> confirmToken(String digits) async {
    final pairing = awaitingToken;
    if (pairing == null) return;
    final token = Rhmi.tokenFromDigits(digits);
    if (token == null) {
      message = 'Kod 8 rakamdan oluşur.';
      notifyListeners();
      return;
    }
    final sessionId = Rhmi.deobfuscate(pairing.transmittedSessionId, token);
    if (Rhmi.transportChecksum(sessionId, token) != pairing.transportChecksum) {
      message = 'Kod yanlış (doğrulama tutmadı). Tekrar girin.';
      notifyListeners();
      return;
    }
    awaitingToken = null;
    await _store(pairing.client, sessionId);
    message = '${Rhmi.clientName(pairing.client)} eşleştirildi.';
    notifyListeners();
  }

  void cancelToken() {
    awaitingToken = null;
    message = 'Eşleştirme iptal edildi.';
    notifyListeners();
  }

  Future<void> forgetPairing() async {
    final device = _device;
    if (device == null) return;
    await RhmiPairingStore.instance.forget(device, client);
    pairings = await RhmiPairingStore.instance.all(device);
    verifiedClients = {...verifiedClients}..remove(client);
    awaitingToken = null;
    message =
        'Kimlik bu telefondan silindi. Takograf kendi kopyasını sonraki '
        'eşleştirmeye kadar tutar.';
    notifyListeners();
  }

  Future<void> _store(int c, List<int> sessionId) async {
    final device = _device;
    if (device == null) return;
    await RhmiPairingStore.instance.put(device, c, sessionId);
    pairings = await RhmiPairingStore.instance.all(device);
    verifiedClients = {...verifiedClients}..remove(c);
  }

  /// VerifyRHMIsessionId: whether the unit still holds the identifier this
  /// phone has. Run after a power cycle it proves the identifier reached
  /// flash.
  Future<void>
  verifySessionId() => _signed('Kimlik doğrulanıyor', needsSession: false, (
    link,
    pairing,
  ) async {
    final r = await _request(
      link,
      _signedRoutine(pairing, Rhmi.routineStart, Rhmi.ridVerifySessionId, [
        client,
      ]),
    );
    if (r == null) return 'Yanıt yok.';
    if (_isNegative(r)) {
      verifiedClients = {...verifiedClients}..remove(client);
      return _nrc(r) == 0x22
          ? '${_negative(r)}\nTakograf menüsü kullanımda; menüden çıkıp tekrar deneyin.'
          : _negative(r);
    }
    verifiedClients = {...verifiedClients, client};
    return 'Kimlik doğrulandı: takograf aynı kimliği tutuyor.';
  });

  // ---------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------

  /// OpenRHMIsession, then wait for the card holders to answer on the unit.
  /// A refusal the unit still holds from earlier is cleared and asked again
  /// once - it otherwise answers Open positively without asking anyone.
  Future<void> openSession() =>
      _run('Oturum açılıyor — takograf ekranında onaylayın', (link) async {
        final problem = await _requestOpen(link);
        if (problem != null) return problem;

        final first = await _readSessionStatus(link);
        if (first == null) return 'Durum okunamadı.';
        if (first == RhmiSessionStatus.closedUserRejected) {
          await _request(
            link,
            Rhmi.routine(Rhmi.routineStart, Rhmi.ridCloseSession),
          );
          final again = await _requestOpen(link);
          if (again != null) return again;
        }
        return _waitForDecision(link);
      });

  Future<String?> _requestOpen(ItsLink link) async {
    final r = await _request(
      link,
      Rhmi.routine(Rhmi.routineStart, Rhmi.ridOpenSession),
    );
    if (r == null) return 'Yanıt yok.';
    return _isNegative(r) ? _negative(r) : null;
  }

  Future<RhmiSessionStatus?> _readSessionStatus(ItsLink link) async {
    final r = await _request(
      link,
      Rhmi.routine(Rhmi.routineRequestResults, Rhmi.ridOpenSession),
    );
    if (r == null || _isNegative(r)) return null;
    final d = _data(r);
    if (d.length < 4) return null;
    sessionStatus = RhmiSessionStatus.of(d[3]);
    notifyListeners();
    return sessionStatus;
  }

  Future<String> _waitForDecision(ItsLink link) async {
    for (var i = 0; i < 45; i++) {
      final status = await _readSessionStatus(link);
      if (status == null) return 'Durum okunamadı.';
      if (status != RhmiSessionStatus.closedUserDecisionPending) {
        return _describeStatus(status);
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    return 'Bir buçuk dakikadır onay bekleniyor; takograf ekranında soru var mı?';
  }

  String _describeStatus(RhmiSessionStatus s) => switch (s) {
    RhmiSessionStatus.open => 'Oturum açık.',
    RhmiSessionStatus.closedOpenPossible => 'Oturum kapalı; açılabilir.',
    RhmiSessionStatus.closedUserDecisionPending =>
      'Takograf ekranındaki soruyu yanıtlayın.',
    RhmiSessionStatus.closedUserRejected =>
      'Reddedildi (ya da soru 25 sn içinde yanıtlanmadı). Kapatıp yeniden '
          'açın ve takografta Evet deyin.',
    RhmiSessionStatus.closedLocalHmiIsUsed =>
      'Takograf menüsü kullanımda; menüden çıkıp yeniden açın.',
    RhmiSessionStatus.closedGeneralConditionsNotMet =>
      'Geçerli bir sürücü ya da atölye kartı hazır değil; kart doğrulanınca '
          'yeniden açın.',
  };

  Future<void> refreshSessionStatus() =>
      _run('Oturum durumu okunuyor', (link) async {
        final s = await _readSessionStatus(link);
        return s == null ? 'Durum okunamadı.' : _describeStatus(s);
      });

  Future<void> closeSession() => _run('Oturum kapatılıyor', (link) async {
    final r = await _request(
      link,
      Rhmi.routine(Rhmi.routineStart, Rhmi.ridCloseSession),
    );
    sessionStatus = null;
    period = null;
    cardType = null;
    if (r == null) return 'Yanıt yok.';
    return _isNegative(r) ? _negative(r) : 'Oturum kapatıldı.';
  });

  // ---------------------------------------------------------------------
  // Manual entry, F200
  // ---------------------------------------------------------------------

  Future<void> getInsertedCardType(int slot) =>
      _signed('Kart tipi okunuyor', (link, pairing) async {
        final r = await _request(
          link,
          _signedRoutine(
            pairing,
            Rhmi.routineRequestResults,
            Rhmi.ridManualEntry,
            [Rhmi.optionGetInsertedCardType, Rhmi.cardSlotNumber(slot)],
          ),
        );
        if (r == null) return 'Yanıt yok.';
        if (_isNegative(r)) return _negative(r);
        final d = _data(r);
        if (d.length < 6) return 'Yanıt kısa.';
        cardType = d[5];
        return switch (d[5]) {
          Rhmi.cardTypeDriver => 'Sürücü kartı',
          Rhmi.cardTypeWorkshop => 'Atölye kartı',
          final t => 'Kart tipi ${_hex2(t)}',
        };
      });

  /// GetManualEntryPeriod. Only answered while the card insertion procedure
  /// is running on the unit - the only time the period exists.
  Future<void> getPeriod(int slot) =>
      _signed('Manuel giriş dönemi okunuyor', (link, pairing) async {
        final p = await _readPeriod(link, pairing, slot);
        if (p is String) return p;
        final usable = _usableMinutes(p as ManualEntryPeriod);
        return usable < 1
            ? 'Dönem bir dakikadan kısa; girilecek bir şey yok.'
            : 'Dönem $usable dakika.';
      });

  Future<Object> _readPeriod(
    ItsLink link,
    RhmiPairing pairing,
    int slot,
  ) async {
    final r = await _request(
      link,
      _signedRoutine(pairing, Rhmi.routineRequestResults, Rhmi.ridManualEntry, [
        Rhmi.optionGetPeriod,
        Rhmi.cardSlotNumber(slot),
      ]),
    );
    if (r == null) return 'Yanıt yok.';
    if (_isNegative(r)) {
      return _nrc(r) == 0x22
          ? '${_negative(r)}\nTakograf manuel giriş beklemiyor: yuva $slot için '
                'kart takma işlemi sürmüyor. Kartı takıp takograf boşluğu '
                'sorarken tekrar deneyin.'
          : _negative(r);
    }
    final p = Rhmi.parseManualEntryPeriod(_data(r));
    if (p == null) return 'Dönem yanıtı okunamadı.';
    period = p;
    return p;
  }

  static int _usableMinutes(ManualEntryPeriod p) =>
      (ManualEntry.truncateToMinute(p.periodEnd) -
          ManualEntry.truncateToMinute(p.periodBegin)) ~/
      60;

  /// Reads the period and sends the entry in one turn. The unit stops
  /// taking entries sixty seconds after the card goes in - nobody fills an
  /// editor in inside a minute - so what was prepared is moved onto the
  /// period that comes back, as offsets from the period it was written for.
  Future<void> sendManualEntry(
    int slot,
    List<ManualActivity> activities,
    List<ManualPlace> places, {
    required void Function(List<ManualActivity>, List<ManualPlace>) onRebased,
  }) => _signed('Manuel giriş gönderiliyor', (link, pairing) async {
    if (activities.isEmpty) return 'En az bir aktivite ekleyin.';
    final previous = period;
    if (previous == null) return 'Önce dönemi okuyun.';

    final p = await _readPeriod(link, pairing, slot);
    if (p is String) return p;
    final fresh = p as ManualEntryPeriod;

    final shift =
        ManualEntry.truncateToMinute(fresh.periodBegin) -
        ManualEntry.truncateToMinute(previous.periodBegin);
    final moved = [
      for (final a in activities)
        ManualActivity(a.startSeconds + shift, a.activity),
    ];
    final movedPlaces = [
      for (final pl in places)
        ManualPlace(
          pl.timeSeconds + shift,
          pl.entryType,
          pl.countryCode,
          pl.regionCode,
        ),
    ];
    onRebased(moved, movedPlaces);

    final invalid = ManualEntry.validate(moved, movedPlaces, fresh);
    if (invalid != null) {
      return 'Yeni dönem ${_usableMinutes(fresh)} dakika ve hazırlanan giriş '
          'sığmıyor: $invalid.';
    }

    final r = await _request(
      link,
      _signedRoutine(pairing, Rhmi.routineStart, Rhmi.ridManualEntry, [
        Rhmi.cardSlotNumber(slot),
        ...ManualEntry.build(moved, movedPlaces),
      ]),
    );
    if (r == null) return 'Yanıt yok.';
    if (!_isNegative(r)) {
      return 'Kabul edildi: ${moved.length} aktivite, ${movedPlaces.length} yer.';
    }
    return switch (_nrc(r)) {
      0x22 =>
        '${_negative(r)}\nTakograf artık giriş almıyor: kart takıldıktan '
            'sonraki bir dakika geçti, ya da takograf ekranından yanıt '
            'verilmeye başlandı. Kartı çıkarıp tekrar takın ve ilk dakikada '
            'gönderin.',
      0x31 =>
        'Reddedildi: requestOutOfRange (0x31)\nGiriş takografın kabul etmediği '
            'bir şey içeriyor: ülkesiz yer, dönemin son dakikasında bitiş '
            'yeri, sırasız yerler ya da dönem dışında aktivite.',
      _ => _negative(r),
    };
  });

  Future<void> stopManualEntry(int slot) =>
      _signed('Manuel giriş bitiriliyor', (link, pairing) async {
        final r = await _request(
          link,
          _signedRoutine(pairing, Rhmi.routineStop, Rhmi.ridManualEntry, [
            Rhmi.cardSlotNumber(slot),
          ]),
        );
        if (r == null) return 'Yanıt yok.';
        return _isNegative(r) ? _negative(r) : 'Manuel giriş bitirildi.';
      });

  // ---------------------------------------------------------------------
  // Live entries, F203-F206
  // ---------------------------------------------------------------------

  Future<void> enterPlace(int slot, int entryType, int country, int region) =>
      _userEntry(
        entryType == Rhmi.placeBegin ? 'Başlangıç yeri' : 'Bitiş yeri',
        Rhmi.ridEntryOfPlace,
        [Rhmi.cardSlotNumber(slot), entryType, country, region],
        'Yer kaydedildi (VU ve yuva $slot kartı).',
      );

  Future<void> enterSpecificCondition(int type) => _userEntry(
    'Özel durum',
    Rhmi.ridEntryOfSpecificCondition,
    [type],
    'Özel durum kaydedildi.',
  );

  Future<void> setActivity(int slot, int activity) => _userEntry(
    'Aktivite',
    Rhmi.ridSetActivity,
    [Rhmi.cardSlotNumber(slot), activity],
    'Aktivite değiştirildi (tuşa basılmış gibi).',
  );

  Future<void> loadUnload(int operation) => _userEntry(
    'Yükleme/boşaltma',
    Rhmi.ridLoadUnload,
    [operation],
    'İşlem kaydedildi.',
  );

  Future<void> _userEntry(
    String what,
    int routineId,
    List<int> body,
    String accepted,
  ) => _signed('$what gönderiliyor', (link, pairing) async {
    final r = await _request(
      link,
      _signedRoutine(pairing, Rhmi.routineStart, routineId, body),
    );
    if (r == null) return 'Yanıt yok.';
    if (!_isNegative(r)) return accepted;
    return _nrc(r) == 0x22
        ? '${_negative(r)}\nŞu an mümkün değil: yuvada kart yok, kart '
              'takılıyor/çıkarılıyor, araç hareket halinde, ya da aynı türden '
              'bir giriş bu dakika zaten yapıldı.'
        : _negative(r);
  });

  // ---------------------------------------------------------------------
  // Card withdrawal, F201
  // ---------------------------------------------------------------------

  /// DriverWorkshopCardWithdrawal: the unit answers at once and withdraws
  /// afterwards, as a long press of the slot key would. The session closes
  /// as the card leaves, and the slot's identifier goes with the card.
  Future<void> withdrawCard(
    int slot,
    int country,
    int region,
    int shiftPrintout,
    bool technicalPrintout,
  ) => _signed('Kart çıkarılıyor', (link, pairing) async {
    final r = await _request(
      link,
      _signedRoutine(pairing, Rhmi.routineStart, Rhmi.ridCardWithdrawal, [
        Rhmi.cardSlotNumber(slot),
        country,
        region,
        shiftPrintout,
        technicalPrintout ? 1 : 0,
      ]),
    );
    if (r == null) return 'Yanıt yok.';
    if (_isNegative(r)) {
      return switch (_nrc(r)) {
        0x21 =>
          '${_negative(r)}\nŞu an mümkün değil: diğer kart takılıyor/çıkarılıyor, '
              'gece yarısı işlemleri ya da yazıcı kullanımda.',
        0x22 =>
          '${_negative(r)}\nMümkün değil: yuvada kart yok ya da kart işleniyor, '
              'araç hareket halinde, ya da çıktı istendiyse kağıt yok.',
        0x31 =>
          '${_negative(r)}\nAralık dışı: ülke yok, bölge ülkeye uymuyor ya da '
              'saat farkı fazla.',
        _ => _negative(r),
      };
    }

    for (var i = 0; i < 90; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final s = await _readSessionStatus(link);
      if (s != null && s != RhmiSessionStatus.open) {
        return 'Kart çıkarıldı; oturum kapandı. Yuva $slot kimliği kartla '
            'gitti: sonraki takmada yeniden eşleştirin.';
      }
    }
    return 'Çıkarma kabul edildi, ama oturum üç dakikadır açık: kart henüz '
        'çıkmamış olabilir (çıktı, kağıt bitti).';
  });

  // ---------------------------------------------------------------------
  // Warnings, F202
  // ---------------------------------------------------------------------

  Future<void> readWarnings() => _signed('Uyarılar okunuyor', (link, p) async {
    final list = await _readWarningList(link, p);
    return list == null ? 'Uyarılar okunamadı.' : _describeWarnings(list);
  });

  Future<void> acknowledgeWarning(int index) => _signed('Uyarı onaylanıyor', (
    link,
    pairing,
  ) async {
    final r = await _request(
      link,
      _signedRoutine(pairing, Rhmi.routineStart, Rhmi.ridAcknowledgeWarnings, [
        (index >> 8) & 0xFF,
        index & 0xFF,
      ]),
    );
    if (r == null) return 'Yanıt yok.';
    if (_isNegative(r)) {
      return switch (_nrc(r)) {
        0x21 => '${_negative(r)}\nÖnceki onay sürüyor, tekrar deneyin.',
        0x31 => '${_negative(r)}\nUyarı artık takografta yok.',
        _ => _negative(r),
      };
    }
    // The unit acknowledges on its keypad thread, a moment after.
    await Future.delayed(const Duration(milliseconds: 500));
    final list = await _readWarningList(link, pairing);
    return 'Uyarı onaylandı.${list == null ? '' : '\n${_describeWarnings(list)}'}';
  });

  Future<List<VuWarning>?> _readWarningList(
    ItsLink link,
    RhmiPairing pairing,
  ) async {
    final overview = await _request(
      link,
      _signedRoutine(
        pairing,
        Rhmi.routineRequestResults,
        Rhmi.ridAcknowledgeWarnings,
        [Rhmi.warningsOverview],
      ),
    );
    if (overview == null || _isNegative(overview)) return null;
    final od = _data(overview);
    if (od.length < 8) return null;

    final list = <VuWarning>[];
    var index = Rhmi.readU16(od, 6);
    while (index != Rhmi.warningNotAvailable && list.length < 16) {
      final r = await _request(
        link,
        _signedRoutine(
          pairing,
          Rhmi.routineRequestResults,
          Rhmi.ridAcknowledgeWarnings,
          [Rhmi.warningGet, (index >> 8) & 0xFF, index & 0xFF],
        ),
      );
      if (r == null) return null;
      final d = _data(r);
      if (_isNegative(r) || d.length < 16) break;
      list.add(VuWarning(Rhmi.readU16(d, 4), d[6], d[11]));
      index = Rhmi.readU16(d, 14);
    }
    warnings = list;
    return list;
  }

  String _describeWarnings(List<VuWarning> list) => list.isEmpty
      ? 'Takografta bekleyen uyarı yok.'
      : '${list.length} uyarı bekliyor.';

  // ---------------------------------------------------------------------
  // Printout, F210
  // ---------------------------------------------------------------------

  Future<void> getPrintoutPeriod(int type) =>
      _signed('Çıktı günleri okunuyor', (link, pairing) async {
        final r = await _request(
          link,
          _signedRoutine(pairing, Rhmi.routineStart, Rhmi.ridPrintout, [
            Rhmi.printoutGetPeriod,
            type,
          ]),
        );
        if (r == null) return 'Yanıt yok.';
        if (_isNegative(r)) return _printoutRefused(r);
        final d = _data(r);
        if (d.length < 13) return 'Yanıt kısa.';
        final oldest = Rhmi.readU32(d, 5), newest = Rhmi.readU32(d, 9);
        printoutPeriod = PrintoutPeriod(type, oldest, newest);
        if (!Rhmi.printoutNeedsDate(type)) return 'Bu çıktı tarih istemez.';
        if (newest == 0) return 'Yazdırılacak gün yok.';
        return 'Günler: ${_utcDay(oldest)} – ${_utcDay(newest)}';
      });

  /// StartPrintout, then the status until it has ended - the unit answers
  /// the start at once and prints afterwards.
  Future<void> startPrintout(int type, int? daySeconds) =>
      _signed('Yazdırılıyor', (link, pairing) async {
        if (Rhmi.printoutNeedsDate(type) && daySeconds == null) {
          return 'Önce bir gün seçin.';
        }
        final r = await _request(
          link,
          _signedRoutine(pairing, Rhmi.routineStart, Rhmi.ridPrintout, [
            Rhmi.printoutStart,
            type,
            if (Rhmi.printoutNeedsDate(type)) ...Rhmi.u32(daySeconds!),
            Rhmi.printoutNoManufacturer,
            0x00,
          ]),
        );
        if (r == null) return 'Yanıt yok.';
        if (_isNegative(r)) return _printoutRefused(r);

        // A paper end can hold a printout well over a minute.
        for (var i = 0; i < 150; i++) {
          await Future.delayed(const Duration(seconds: 2));
          final status = await _readPrintoutStatus(link, pairing);
          if (status == null) return 'Başladı, ama durum okunamadı.';
          if (status.$1 != Rhmi.printoutOngoing) {
            return _describePrintout(status);
          }
        }
        return 'Başladı; beş dakikadır yazdırıyor.';
      });

  Future<void> printoutStatus() =>
      _signed('Çıktı durumu okunuyor', (link, pairing) async {
        final s = await _readPrintoutStatus(link, pairing);
        return s == null ? 'Durum okunamadı.' : _describePrintout(s);
      });

  Future<(int, int, int)?> _readPrintoutStatus(
    ItsLink link,
    RhmiPairing pairing,
  ) async {
    final r = await _request(
      link,
      _signedRoutine(
        pairing,
        Rhmi.routineRequestResults,
        Rhmi.ridPrintout,
        const [],
      ),
    );
    if (r == null || _isNegative(r)) return null;
    final d = _data(r);
    if (d.length < 9) return null;
    return (d[3], d[4], Rhmi.readU32(d, 5));
  }

  String _describePrintout((int, int, int) s) {
    final (info, type, end) = s;
    final what = type == Rhmi.printoutTypeNotRemote
        ? 'Takografta başlatılan çıktı'
        : Rhmi.printoutName(type);
    return switch (info) {
      Rhmi.printoutNormalExit => '$what tamamlandı.',
      Rhmi.printoutAbnormalExit =>
        '$what tamamlanmadı: yazıcı sıcak, düşük voltaj, kağıt bitti, iptal '
            'ya da yazıcı arızası.',
      Rhmi.printoutOngoing => '$what yazdırılıyor.',
      Rhmi.printoutNoStatus => 'Takograf açıldığından beri çıktı yok.',
      _ => 'Bilinmeyen çıktı durumu ${_hex2(info)} ($end).',
    };
  }

  String _printoutRefused(List<int> r) => switch (_nrc(r)) {
    0x21 => '${_negative(r)}\nTakografta bir çıktı zaten sürüyor.',
    0x22 =>
      '${_negative(r)}\nŞu an mümkün değil: oturum kapalı, ilgili yuvada '
          'geçerli kart yok, kart takma işlemi bitmemiş, araç hareket halinde '
          'ya da kağıt yok.',
    0x31 =>
      '${_negative(r)}\nO gün için kayıt yok, bu tip yazdırılmıyor ya da saat '
          'farkı fazla.',
    _ => _negative(r),
  };

  static String _utcDay(int seconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }
}
