import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../bluetooth/vu/its_link.dart';
import '../../localization/localization.dart';
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

  /// Every finished action, for the notice above the bottom bar: the unit
  /// does what was asked without saying so on the phone, so this does.
  final StreamController<RhmiOutcome> _outcomes =
      StreamController<RhmiOutcome>.broadcast();
  Stream<RhmiOutcome> get outcomes => _outcomes.stream;

  /// Set when the unit answered the current action negatively.
  bool _refused = false;

  /// Set when nothing usable came back for the current action, or the
  /// channel would not open - neither the unit's yes nor its no.
  bool _failedFlag = false;

  static String _t(String key, [Map<String, Object?> args = const {}]) =>
      AppLocalizations.text(key, args);

  /// A message for an outcome that is a failure rather than an answer.
  String _fail(String key, [Map<String, Object?> args = const {}]) {
    _failedFlag = true;
    return _t(key, args);
  }

  void _report(String text, RhmiOutcomeKind kind) {
    message = text;
    notifyListeners();
    _outcomes.add(RhmiOutcome(text, kind));
  }

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
      _report(_t('rhmi.notConnected'), RhmiOutcomeKind.notSent);
      return;
    }
    if (busy != null) return;

    busy = what;
    _refused = false;
    _failedFlag = false;
    message = null;
    notifyListeners();

    String outcome;
    try {
      if (!link.isOpen && !await link.open()) {
        outcome = _fail('rhmi.channelFailed');
      } else {
        outcome = await block(link);
      }
    } catch (e) {
      outcome = _fail('rhmi.failed', {'error': e});
    }
    debugPrint('RHMI: $what -> $outcome');
    busy = null;
    _report(
      outcome,
      _refused || _failedFlag ? RhmiOutcomeKind.refused : RhmiOutcomeKind.done,
    );
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
      _report(
        _t('rhmi.notPaired', {'client': Rhmi.clientName(asClient ?? client)}),
        RhmiOutcomeKind.notSent,
      );
      return;
    }
    if (needsSession) {
      final notOpen = _sessionNotOpen();
      if (notOpen != null) {
        _report(notOpen, RhmiOutcomeKind.notSent);
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
    RhmiSessionStatus.closedUserDecisionPending => _t('rhmi.sessionPending'),
    RhmiSessionStatus.closedUserRejected => _t('rhmi.sessionRejected'),
    null => _t('rhmi.sessionUnknown'),
    final s => _t('rhmi.sessionNotOpen', {'status': s.label}),
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

  /// The refusal itself: the unit's code, by its name.
  String _refusal(List<int> r) {
    _refused = true;
    final nrc = _nrc(r);
    return _t('rhmi.refused', {
      'nrc': RdbiResponseParser.describeNrc(nrc),
      'code': _hex2(nrc),
    });
  }

  String _negative(List<int> r) {
    final base = _refusal(r);
    return switch (_nrc(r)) {
      0x35 => '$base\n${_t('rhmi.nrc35')}',
      0x37 => '$base\n${_t('rhmi.nrc37')}',
      0x31 =>
        '$base\n${_t('rhmi.nrc31', {'seconds': Rhmi.timestampToleranceSeconds})}',
      0x21 => '$base\n${_t('rhmi.nrc21')}',
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

  Future<void> checkClocks() => _run(_t('rhmi.busyClock'), (link) async {
    final drift = await _readClockOffset(link);
    if (drift == null) return _fail('rhmi.clockUnreadable');
    final ahead = drift >= 0;
    final within = drift.abs() <= Rhmi.timestampToleranceSeconds;
    final key = ahead
        ? (within ? 'rhmi.clockAheadOk' : 'rhmi.clockAheadOut')
        : (within ? 'rhmi.clockBehindOk' : 'rhmi.clockBehindOut');
    return _t(key, {'seconds': drift.abs()});
  });

  // ---------------------------------------------------------------------
  // Pairing
  // ---------------------------------------------------------------------

  /// PairRHMIclient. The unit draws a fresh identifier, returns it -
  /// obfuscated unless it is unactivated or in calibration mode - and shows
  /// a token on its display, so somebody has to be standing at the vehicle.
  Future<void> pairClient() => _run(_t('rhmi.busyPairing'), (link) async {
    final r = await _request(
      link,
      Rhmi.routine(Rhmi.routineStart, Rhmi.ridPairClient, [client]),
    );
    if (r == null) return _fail('rhmi.noAnswer');
    if (_isNegative(r)) return _negative(r);
    final pairing = Rhmi.parsePairingResponse(_data(r));
    if (pairing == null) return _fail('rhmi.pairingUnreadable');

    if (pairing.isPlain) {
      await _store(client, pairing.transmittedSessionId);
      return _t('rhmi.pairedPlain');
    }
    awaitingToken = pairing;
    return _t('rhmi.enterToken');
  });

  /// The second half of an obfuscated pairing: the token recovers the
  /// identifier, and the transport checksum proves it before anything is
  /// signed with it.
  Future<void> confirmToken(String digits) async {
    final pairing = awaitingToken;
    if (pairing == null) return;
    final token = Rhmi.tokenFromDigits(digits);
    if (token == null) {
      message = _t('rhmi.tokenDigits');
      notifyListeners();
      return;
    }
    final sessionId = Rhmi.deobfuscate(pairing.transmittedSessionId, token);
    if (Rhmi.transportChecksum(sessionId, token) != pairing.transportChecksum) {
      message = _t('rhmi.tokenWrong');
      notifyListeners();
      return;
    }
    awaitingToken = null;
    await _store(pairing.client, sessionId);
    message = _t('rhmi.paired', {'client': Rhmi.clientName(pairing.client)});
    notifyListeners();
  }

  void cancelToken() {
    awaitingToken = null;
    message = _t('rhmi.pairingCancelled');
    notifyListeners();
  }

  Future<void> forgetPairing() async {
    final device = _device;
    if (device == null) return;
    await RhmiPairingStore.instance.forget(device, client);
    pairings = await RhmiPairingStore.instance.all(device);
    verifiedClients = {...verifiedClients}..remove(client);
    awaitingToken = null;
    message = _t('rhmi.pairingForgotten');
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
  Future<void> verifySessionId() => _signed(
    _t('rhmi.busyVerify'),
    needsSession: false,
    (link, pairing) async {
      final r = await _request(
        link,
        _signedRoutine(pairing, Rhmi.routineStart, Rhmi.ridVerifySessionId, [
          client,
        ]),
      );
      if (r == null) return _fail('rhmi.noAnswer');
      if (_isNegative(r)) {
        verifiedClients = {...verifiedClients}..remove(client);
        return _nrc(r) == 0x22
            ? '${_negative(r)}\n${_t('rhmi.menuInUseRetry')}'
            : _negative(r);
      }
      verifiedClients = {...verifiedClients, client};
      return _t('rhmi.verified');
    },
  );

  // ---------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------

  /// OpenRHMIsession, then wait for the card holders to answer on the unit.
  /// A refusal the unit still holds from earlier is cleared and asked again
  /// once - it otherwise answers Open positively without asking anyone.
  Future<void> openSession() => _run(_t('rhmi.busyOpen'), (link) async {
    final problem = await _requestOpen(link);
    if (problem != null) return problem;

    final first = await _readSessionStatus(link);
    if (first == null) return _fail('rhmi.statusUnreadable');
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
    if (r == null) return _fail('rhmi.noAnswer');
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
      if (status == null) return _fail('rhmi.statusUnreadable');
      if (status != RhmiSessionStatus.closedUserDecisionPending) {
        return _describeStatus(status);
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    return _t('rhmi.waitTimeout');
  }

  /// What to do about each state - `rhmi.status.<name>`.
  String _describeStatus(RhmiSessionStatus s) => _t('rhmi.status.${s.name}');

  Future<void> refreshSessionStatus() =>
      _run(_t('rhmi.busyStatus'), (link) async {
        final s = await _readSessionStatus(link);
        return s == null ? _fail('rhmi.statusUnreadable') : _describeStatus(s);
      });

  Future<void> closeSession() => _run(_t('rhmi.busyClose'), (link) async {
    final r = await _request(
      link,
      Rhmi.routine(Rhmi.routineStart, Rhmi.ridCloseSession),
    );
    sessionStatus = null;
    period = null;
    cardType = null;
    if (r == null) return _fail('rhmi.noAnswer');
    return _isNegative(r) ? _negative(r) : _t('rhmi.sessionClosed');
  });

  // ---------------------------------------------------------------------
  // Manual entry, F200
  // ---------------------------------------------------------------------

  Future<void> getInsertedCardType(int slot) =>
      _signed(_t('rhmi.busyCardType'), (link, pairing) async {
        final r = await _request(
          link,
          _signedRoutine(
            pairing,
            Rhmi.routineRequestResults,
            Rhmi.ridManualEntry,
            [Rhmi.optionGetInsertedCardType, Rhmi.cardSlotNumber(slot)],
          ),
        );
        if (r == null) return _fail('rhmi.noAnswer');
        if (_isNegative(r)) return _negative(r);
        final d = _data(r);
        if (d.length < 6) return _t('rhmi.shortAnswer');
        cardType = d[5];
        return switch (d[5]) {
          Rhmi.cardTypeDriver => _t('rhmi.cardDriver'),
          Rhmi.cardTypeWorkshop => _t('rhmi.cardWorkshop'),
          final t => _t('rhmi.cardOther', {'code': _hex2(t)}),
        };
      });

  /// GetManualEntryPeriod. Only answered while the card insertion procedure
  /// is running on the unit - the only time the period exists.
  Future<void> getPeriod(int slot) =>
      _signed(_t('rhmi.busyPeriod'), (link, pairing) async {
        final p = await _readPeriod(link, pairing, slot);
        if (p is String) return p;
        final usable = _usableMinutes(p as ManualEntryPeriod);
        return usable < 1
            ? _t('rhmi.periodTooShort')
            : _t('rhmi.periodMinutes', {'minutes': usable});
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
    if (r == null) return _fail('rhmi.noAnswer');
    if (_isNegative(r)) {
      return _nrc(r) == 0x22
          ? '${_negative(r)}\n${_t('rhmi.periodNotExpected', {'slot': slot})}'
          : _negative(r);
    }
    final p = Rhmi.parseManualEntryPeriod(_data(r));
    if (p == null) return _fail('rhmi.periodUnreadable');
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
  }) => _signed(_t('rhmi.busySendEntry'), (link, pairing) async {
    if (activities.isEmpty) return _t('rhmi.entryNeedsActivity');
    final previous = period;
    if (previous == null) return _t('rhmi.entryReadPeriodFirst');

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
      return _t('rhmi.entryDoesNotFit', {
        'minutes': _usableMinutes(fresh),
        'reason': invalid,
      });
    }

    final r = await _request(
      link,
      _signedRoutine(pairing, Rhmi.routineStart, Rhmi.ridManualEntry, [
        Rhmi.cardSlotNumber(slot),
        ...ManualEntry.build(moved, movedPlaces),
      ]),
    );
    if (r == null) return _fail('rhmi.noAnswer');
    if (!_isNegative(r)) {
      return _t('rhmi.entryAccepted', {
        'activities': moved.length,
        'places': movedPlaces.length,
      });
    }
    return switch (_nrc(r)) {
      0x22 => '${_negative(r)}\n${_t('rhmi.entryClosed')}',
      0x31 => '${_refusal(r)}\n${_t('rhmi.entryOutOfRange')}',
      _ => _negative(r),
    };
  });

  Future<void> stopManualEntry(int slot) =>
      _signed(_t('rhmi.busyStopEntry'), (link, pairing) async {
        final r = await _request(
          link,
          _signedRoutine(pairing, Rhmi.routineStop, Rhmi.ridManualEntry, [
            Rhmi.cardSlotNumber(slot),
          ]),
        );
        if (r == null) return _fail('rhmi.noAnswer');
        return _isNegative(r) ? _negative(r) : _t('rhmi.entryStopped');
      });

  // ---------------------------------------------------------------------
  // Live entries, F203-F206
  // ---------------------------------------------------------------------

  Future<void> enterPlace(int slot, int entryType, int country, int region) =>
      _userEntry(
        _t(
          entryType == Rhmi.placeBegin
              ? 'rhmi.whatPlaceBegin'
              : 'rhmi.whatPlaceEnd',
        ),
        Rhmi.ridEntryOfPlace,
        [Rhmi.cardSlotNumber(slot), entryType, country, region],
        _t('rhmi.placeSaved', {'slot': slot}),
      );

  Future<void> enterSpecificCondition(int type) => _userEntry(
    _t('rhmi.whatCondition'),
    Rhmi.ridEntryOfSpecificCondition,
    [type],
    _t('rhmi.conditionSaved'),
  );

  Future<void> setActivity(int slot, int activity) => _userEntry(
    _t('rhmi.whatActivity'),
    Rhmi.ridSetActivity,
    [Rhmi.cardSlotNumber(slot), activity],
    _t('rhmi.activitySaved'),
  );

  Future<void> loadUnload(int operation) => _userEntry(
    _t('rhmi.whatLoad'),
    Rhmi.ridLoadUnload,
    [operation],
    _t('rhmi.loadSaved'),
  );

  Future<void> _userEntry(
    String what,
    int routineId,
    List<int> body,
    String accepted,
  ) => _signed(_t('rhmi.busySending', {'what': what}), (link, pairing) async {
    final r = await _request(
      link,
      _signedRoutine(pairing, Rhmi.routineStart, routineId, body),
    );
    if (r == null) return _fail('rhmi.noAnswer');
    if (!_isNegative(r)) return accepted;
    return _nrc(r) == 0x22
        ? '${_negative(r)}\n${_t('rhmi.entryNotPossible')}'
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
  ) => _signed(_t('rhmi.busyWithdraw'), (link, pairing) async {
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
    if (r == null) return _fail('rhmi.noAnswer');
    if (_isNegative(r)) {
      return switch (_nrc(r)) {
        0x21 => '${_negative(r)}\n${_t('rhmi.withdraw21')}',
        0x22 => '${_negative(r)}\n${_t('rhmi.withdraw22')}',
        0x31 => '${_negative(r)}\n${_t('rhmi.withdraw31')}',
        _ => _negative(r),
      };
    }

    for (var i = 0; i < 90; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final s = await _readSessionStatus(link);
      if (s != null && s != RhmiSessionStatus.open) {
        return _t('rhmi.withdrawn', {'slot': slot});
      }
    }
    return _t('rhmi.withdrawPending');
  });

  // ---------------------------------------------------------------------
  // Warnings, F202
  // ---------------------------------------------------------------------

  Future<void> readWarnings() =>
      _signed(_t('rhmi.busyWarnings'), (link, p) async {
        final list = await _readWarningList(link, p);
        return list == null
            ? _fail('rhmi.warningsUnreadable')
            : _describeWarnings(list);
      });

  Future<void> acknowledgeWarning(int index) =>
      _signed(_t('rhmi.busyAck'), (link, pairing) async {
        final r = await _request(
          link,
          _signedRoutine(
            pairing,
            Rhmi.routineStart,
            Rhmi.ridAcknowledgeWarnings,
            [(index >> 8) & 0xFF, index & 0xFF],
          ),
        );
        if (r == null) return _fail('rhmi.noAnswer');
        if (_isNegative(r)) {
          return switch (_nrc(r)) {
            0x21 => '${_negative(r)}\n${_t('rhmi.ack21')}',
            0x31 => '${_negative(r)}\n${_t('rhmi.ack31')}',
            _ => _negative(r),
          };
        }
        // The unit acknowledges on its keypad thread, a moment after.
        await Future.delayed(const Duration(milliseconds: 500));
        final list = await _readWarningList(link, pairing);
        final done = _t('rhmi.acknowledged');
        return list == null ? done : '$done\n${_describeWarnings(list)}';
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
      ? _t('rhmi.noWarnings')
      : _t('rhmi.warningsPending', {'count': list.length});

  // ---------------------------------------------------------------------
  // Printout, F210
  // ---------------------------------------------------------------------

  Future<void> getPrintoutPeriod(int type) =>
      _signed(_t('rhmi.busyPrintDays'), (link, pairing) async {
        final r = await _request(
          link,
          _signedRoutine(pairing, Rhmi.routineStart, Rhmi.ridPrintout, [
            Rhmi.printoutGetPeriod,
            type,
          ]),
        );
        if (r == null) return _fail('rhmi.noAnswer');
        if (_isNegative(r)) return _printoutRefused(r);
        final d = _data(r);
        if (d.length < 13) return _t('rhmi.shortAnswer');
        final oldest = Rhmi.readU32(d, 5), newest = Rhmi.readU32(d, 9);
        printoutPeriod = PrintoutPeriod(type, oldest, newest);
        if (!Rhmi.printoutNeedsDate(type)) return _t('rhmi.printNoDate');
        if (newest == 0) return _t('rhmi.printNoDays');
        return _t('rhmi.printDays', {
          'from': _utcDay(oldest),
          'to': _utcDay(newest),
        });
      });

  /// StartPrintout, then the status until it has ended - the unit answers
  /// the start at once and prints afterwards.
  Future<void> startPrintout(int type, int? daySeconds) =>
      _signed(_t('rhmi.busyPrinting'), (link, pairing) async {
        if (Rhmi.printoutNeedsDate(type) && daySeconds == null) {
          return _t('rhmi.printPickDay');
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
        if (r == null) return _fail('rhmi.noAnswer');
        if (_isNegative(r)) return _printoutRefused(r);

        // A paper end can hold a printout well over a minute.
        for (var i = 0; i < 150; i++) {
          await Future.delayed(const Duration(seconds: 2));
          final status = await _readPrintoutStatus(link, pairing);
          if (status == null) return _fail('rhmi.printStartedUnknown');
          if (status.$1 != Rhmi.printoutOngoing) {
            return _describePrintout(status);
          }
        }
        return _t('rhmi.printLong');
      });

  Future<void> printoutStatus() => _signed(_t('rhmi.busyPrintStatus'), (
    link,
    pairing,
  ) async {
    final s = await _readPrintoutStatus(link, pairing);
    return s == null ? _fail('rhmi.statusUnreadable') : _describePrintout(s);
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
        ? _t('rhmi.printFromUnit')
        : Rhmi.printoutName(type);
    return switch (info) {
      Rhmi.printoutNormalExit => _t('rhmi.printDone', {'what': what}),
      Rhmi.printoutAbnormalExit => _t('rhmi.printAbnormal', {'what': what}),
      Rhmi.printoutOngoing => _t('rhmi.printOngoing', {'what': what}),
      Rhmi.printoutNoStatus => _t('rhmi.printNone'),
      _ => _t('rhmi.printUnknownStatus', {'code': _hex2(info), 'end': end}),
    };
  }

  String _printoutRefused(List<int> r) => switch (_nrc(r)) {
    0x21 => '${_negative(r)}\n${_t('rhmi.print21')}',
    0x22 => '${_negative(r)}\n${_t('rhmi.print22')}',
    0x31 => '${_negative(r)}\n${_t('rhmi.print31')}',
    _ => _negative(r),
  };

  static String _utcDay(int seconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }
}

enum RhmiOutcomeKind {
  /// The unit accepted and did it.
  done,

  /// The unit refused, or never answered.
  refused,

  /// Not sent: not paired, or no session open.
  notSent,
}

/// What one action came to, for the notice above the bottom bar.
class RhmiOutcome {
  const RhmiOutcome(this.text, this.kind);
  final String text;
  final RhmiOutcomeKind kind;
}
