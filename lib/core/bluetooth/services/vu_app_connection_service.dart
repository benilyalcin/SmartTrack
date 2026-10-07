import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;

import '../../exceptions/ble_characteristic_exception.dart';
import '../../exceptions/ble_connection_exception.dart';
import '../../exceptions/vu_profile_mismatch_exception.dart';
import '../models/ble_gatt_service.dart';
import '../models/log_entry.dart';
import '../repositories/ble_connection_repository.dart' hide BleConnectionState;
import '../repositories/ble_connection_repository.dart' as repo;
import '../vu/vu_app_link.dart';
import '../vu/vu_link_profile.dart';

/// How far [VuAppConnectionService.connect] has got, for the connect screen.
enum VuLinkPhase {
  disconnected,
  connecting,
  discovering,

  /// Numeric Comparison: the same six digits are on the vehicle unit display
  /// and on the phone, and both have to be confirmed.
  bonding,
  subscribing,
  ready,
}

/// A link to a tachograph over the app service (see [VuAppUuids]): the ATC
/// 8256's own, or the BLE dongle in front of an STC 8255. Which one, and so
/// whether to bond first and whether to subscribe ITS as well, is [profile].
///
/// The rest of the app talks to a tachograph through one characteristic
/// alias, [kwpChannel], carried over from the Classic SPP days: a KWP2000
/// frame written there goes out as packets on App RX, and every complete
/// message reassembled from App TX comes back on its notify stream.
///
/// flutter_blue_plus already runs every GATT operation through one global
/// mutex and waits for the write callback even without response, which is the
/// single operation queue Android needs - so nothing here queues on its own
/// beyond keeping one message's packets together.
class VuAppConnectionService implements BleConnectionRepository {
  VuAppConnectionService({
    required this.profile,
    this.onPhase,
    this.checkProfile = true,
  });

  /// Refuse a device whose services say it is the other kind of tachograph
  /// (see [VuProfileMismatchException]). Off when the user has chosen to go
  /// on with their selection anyway.
  final bool checkProfile;

  /// What sits behind the app service, and so what is subscribed and how
  /// frames are framed (see [VuLinkProfile]).
  final VuLinkProfile profile;

  static const String kwpChannel = 'SPP_DATA';

  static const int _requestedMtu = 247;
  static const int _defaultMtu = 23;
  static const Duration _gattConnectTimeout = Duration(seconds: 15);

  /// The unit closes its pairing dialog after 25 s and its security manager
  /// gives up at 30 s, so waiting longer only delays the error.
  static const int _bondTimeoutSeconds = 30;

  /// How long [_bond] gives the pairing the unit asks for on connect to show
  /// up before asking for one itself. By then discovery and the MTU exchange
  /// are done, so a pairing Android started on the unit's request is
  /// normally under way already.
  static const Duration _unitPairingGrace = Duration(seconds: 3);

  /// Long enough to cover a pairing that starts during discovery (see
  /// [_discoverAcrossPairing]).
  static const int _discoverTimeoutSeconds = 45;

  /// On iOS pairing is not a separate step: the system asks for it when the
  /// authenticated CCCD is first written, so the subscription has to wait for
  /// the user as long as bonding would.
  static const int _subscribeTimeoutSeconds = 35;

  final void Function(VuLinkPhase phase)? onPhase;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;
  BluetoothCharacteristic? _tx;
  List<BleGattService> _services = const [];
  int _mtu = _defaultMtu;
  VuLinkPhase _phase = VuLinkPhase.disconnected;

  final VuAppReassembler _reassembler = VuAppReassembler();
  final _messages = StreamController<List<int>>.broadcast();
  final _stateController =
      StreamController<repo.BleConnectionState>.broadcast();
  final _logController = StreamController<LogEntry>.broadcast();

  StreamSubscription? _connStateSub;
  StreamSubscription? _txSub;

  StreamSubscription<BluetoothBondState>? _bondWatch;
  bool _pairingSeen = false;
  VuLinkPhase _phaseBeforePairing = VuLinkPhase.connecting;

  List<BluetoothService> _rawServices = const [];
  final Map<String, BluetoothCharacteristic> _itsChars = {};
  final List<StreamSubscription> _itsSubs = [];
  final Map<String, StreamController<List<int>>> _itsPackets = {};

  /// Each message's packets go out back to back, never interleaved with the
  /// next message's.
  Future<void> _writeChain = Future.value();

  VuLinkPhase get phase => _phase;
  int get mtu => _mtu;

  @override
  Stream<repo.BleConnectionState> get connectionState =>
      _stateController.stream;

  @override
  Stream<LogEntry> get logs => _logController.stream;

  @override
  Future<void> connect(String deviceId) async {
    _setPhase(VuLinkPhase.connecting);
    _stateController.add(repo.BleConnectionState.connecting);
    _log('$deviceId cihazına bağlanılıyor...', LogLevel.info);

    final device = BluetoothDevice.fromId(deviceId);
    _device = device;

    try {
      // The MTU is requested below, after discovery, the order AvuItsTester
      // uses; FBP's own request right after connecting would race it.
      await device.connect(timeout: _gattConnectTimeout, mtu: null);
      _watchPairing(device);

      _connStateSub?.cancel();
      _connStateSub = device.connectionState.skip(1).listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _log('Bağlantı koptu.', LogLevel.error);
          _setPhase(VuLinkPhase.disconnected);
          _stateController.add(repo.BleConnectionState.disconnected);
        } else if (state == BluetoothConnectionState.connected) {
          _stateController.add(repo.BleConnectionState.connected);
        }
      });

      _setPhase(VuLinkPhase.discovering);
      await _discover(device);

      // Before anything is bonded or subscribed: an ATC answers a dongle's
      // prefixed frames with "FMT not correct" on every message, and a
      // dongle has no ITS to subscribe.
      final deviceHasIts = VuItsUuids.characteristics.keys.any(
        (uuid) => _rawServices.any((s) => s.serviceUuid == Guid(uuid)),
      );
      if (checkProfile && deviceHasIts != profile.subscribeIts) {
        _log(
          'Cihaz seçilen profile uymuyor (ITS servisleri '
          '${deviceHasIts ? 'var' : 'yok'}).',
          LogLevel.error,
        );
        throw VuProfileMismatchException(deviceHasIts: deviceHasIts);
      }

      _mtu = await _negotiateMtu(device);
      _log(
        'MTU $_mtu, paket başına ${VuAppPacketCodec.payloadSizeFor(_mtu)} bayt.',
        LogLevel.info,
      );

      if (profile.bondFirst) await _bond(device);

      _setPhase(VuLinkPhase.subscribing);
      final tx = _tx!;
      _txSub?.cancel();
      _txSub = tx.onValueReceived.listen(_onPacket);
      await tx.setNotifyValue(true, timeout: _subscribeTimeoutSeconds);

      if (profile.subscribeIts) await _subscribeIts();

      await _bondWatch?.cancel();
      _bondWatch = null;
      _setPhase(VuLinkPhase.ready);
      _stateController.add(repo.BleConnectionState.connected);
      _log('Uygulama servisi hazır.', LogLevel.success);
    } catch (e) {
      _log('Bağlantı kurulamadı: $e', LogLevel.error);
      await _teardown();
      if (e is BleConnectionException) rethrow;
      throw BleConnectionException(message: _describe(e), cause: e);
    }
  }

  /// Pairing does not wait for [_bond]. When the phone still holds a bond
  /// the unit has forgotten, when the unit asks for security itself, or when
  /// a profile without [VuLinkProfile.bondFirst] writes an authenticated
  /// CCCD, Android starts it on its own - in the middle of discovery or of a
  /// subscription - and holds that step until the user has answered on both
  /// screens. Watching the bond state for the whole connect shows the code
  /// prompt whichever step it lands in, and tells discovery to look again.
  void _watchPairing(BluetoothDevice device) {
    _pairingSeen = false;
    _bondWatch?.cancel();
    if (!Platform.isAndroid) return;
    _bondWatch = device.bondState.listen((state) {
      // Every change, so a log shows who started each pairing and when.
      _log('Bağ durumu: ${state.name} (aşama: ${_phase.name}).', LogLevel.info);
      if (state == BluetoothBondState.bonding) {
        _pairingSeen = true;
        if (_phase != VuLinkPhase.bonding) {
          _phaseBeforePairing = _phase;
          _log('Eşleşme başladı ($_phaseBeforePairing).', LogLevel.info);
          _setPhase(VuLinkPhase.bonding);
        }
      } else if (_phase == VuLinkPhase.bonding) {
        _setPhase(_phaseBeforePairing);
      }
    });
  }

  /// Discovery that survives pairing starting underneath it (see
  /// [_watchPairing]): long enough for the user to answer, and asked again
  /// when the one that completes after the pairing comes back without the
  /// app service. FBP's own subscription to Service Changed is left out -
  /// it is a CCCD write of its own, after discovery, on a fixed 15 s
  /// timeout, which a pairing landing there would run out.
  Future<List<BluetoothService>> _discoverAcrossPairing(
    BluetoothDevice device,
  ) async {
    var raw = await device.discoverServices(
      subscribeToServicesChanged: false,
      timeout: _discoverTimeoutSeconds,
    );
    if (_pairingSeen && !_hasAppService(raw)) {
      _log('Eşleşme sonrası servisler yeniden aranıyor.', LogLevel.info);
      raw = await device.discoverServices(
        subscribeToServicesChanged: false,
        timeout: _discoverTimeoutSeconds,
      );
    }
    return raw;
  }

  static bool _hasAppService(List<BluetoothService> services) {
    final guid = Guid(VuAppUuids.service);
    return services.any((s) => s.serviceUuid == guid);
  }

  Future<void> _discover(BluetoothDevice device) async {
    final raw = await _discoverAcrossPairing(device);

    final serviceGuid = Guid(VuAppUuids.service);
    final rxGuid = Guid(VuAppUuids.rx);
    final txGuid = Guid(VuAppUuids.tx);

    _services = [
      for (final s in raw)
        BleGattService(
          uuid: s.serviceUuid.str.toUpperCase(),
          characteristics: [
            for (final c in s.characteristics)
              BleGattCharacteristic(
                uuid: c.characteristicUuid.str.toUpperCase(),
                canRead: c.properties.read,
                canWrite:
                    c.properties.write || c.properties.writeWithoutResponse,
                canNotify: c.properties.notify || c.properties.indicate,
              ),
          ],
        ),
    ];

    _rawServices = raw;
    final app = raw.where((s) => s.serviceUuid == serviceGuid).firstOrNull;
    _rx = app?.characteristics
        .where((c) => c.characteristicUuid == rxGuid)
        .firstOrNull;
    _tx = app?.characteristics
        .where((c) => c.characteristicUuid == txGuid)
        .firstOrNull;

    if (_rx == null || _tx == null) {
      throw const BleConnectionException(
        message:
            'Cihazda SmartTrack uygulama servisi bulunamadı. Takograf '
            'yazılımı bu servisi desteklemiyor olabilir.',
      );
    }
    _log('${raw.length} servis bulundu, uygulama servisi var.', LogLevel.info);
  }

  Future<int> _negotiateMtu(BluetoothDevice device) async {
    // iOS negotiates on its own and FBP reports the result.
    if (!Platform.isAndroid) return device.mtuNow;
    try {
      return await device.requestMtu(_requestedMtu);
    } catch (e) {
      _log(
        'MTU isteği başarısız ($e), varsayılan kullanılıyor.',
        LogLevel.error,
      );
      return device.mtuNow;
    }
  }

  /// The app characteristics need an authenticated link, and a CCCD written
  /// before bonding is refused - so on Android the bond comes first.
  ///
  /// The unit sends a Security Request as soon as a central connects, and
  /// Android pairs on that by itself. A createBond that lands while that
  /// pairing is still on its way is a second pairing request, and the unit
  /// pairs twice, with a new code on its display each time. So the unit's
  /// pairing is waited for, and one is asked for here only if none starts.
  Future<void> _bond(BluetoothDevice device) async {
    if (!Platform.isAndroid) return;

    var state = await device.bondState.first;
    if (state == BluetoothBondState.bonded) return;

    _setPhase(VuLinkPhase.bonding);
    try {
      if (state == BluetoothBondState.none) {
        state = await device.bondState
            .firstWhere((s) => s != BluetoothBondState.none)
            .timeout(
              _unitPairingGrace,
              onTimeout: () => BluetoothBondState.none,
            );
      }
      if (state == BluetoothBondState.bonding) {
        _log('Takografın başlattığı eşleşme bekleniyor.', LogLevel.info);
        state = await device.bondState
            .firstWhere((s) => s != BluetoothBondState.bonding)
            .timeout(const Duration(seconds: _bondTimeoutSeconds));
        if (state != BluetoothBondState.bonded) {
          throw StateError('Eşleşme sonucu: ${state.name}');
        }
      } else if (state == BluetoothBondState.none) {
        _log('Eşleşme başlatılıyor (Numeric Comparison).', LogLevel.info);
        await device.createBond(timeout: _bondTimeoutSeconds);
      }
    } catch (e) {
      throw BleConnectionException(
        message:
            'Eşleşme tamamlanmadı. Takograf ekranındaki 6 haneli kodu '
            'telefondakiyle karşılaştırıp 25 saniye içinde iki tarafta da '
            'onaylayın.',
        cause: e,
      );
    }
    _log('Eşleşme tamam.', LogLevel.success);
  }

  /// The ITS FIFOs and credits, by indication. Like App TX they are
  /// authenticated, so this only works after bonding. A unit without the
  /// ITS services is logged rather than refused: live data over the app
  /// service still works, only the ITS features will not.
  Future<void> _subscribeIts() async {
    for (final entry in VuItsUuids.characteristics.entries) {
      final service = _rawServices
          .where((s) => s.serviceUuid == Guid(entry.key))
          .firstOrNull;
      if (service == null) {
        _log('ITS servisi yok: ${entry.key}', LogLevel.error);
        continue;
      }
      for (final uuid in entry.value) {
        final char = service.characteristics
            .where((c) => c.characteristicUuid == Guid(uuid))
            .firstOrNull;
        if (char == null) {
          _log('ITS karakteristiği yok: $uuid', LogLevel.error);
          continue;
        }
        final ctrl = _itsPackets.putIfAbsent(
          uuid,
          () => StreamController<List<int>>.broadcast(),
        );
        _itsSubs.add(char.onValueReceived.listen(ctrl.add));
        await char.setNotifyValue(
          true,
          timeout: _subscribeTimeoutSeconds,
          forceIndications: true,
        );
        _itsChars[uuid] = char;
      }
    }
    _log(
      '${_itsChars.length} ITS karakteristiğine abone olundu.',
      LogLevel.info,
    );
  }

  /// Whether the ITS characteristic [uuid] (see [VuItsUuids]) is subscribed.
  bool hasIts(String uuid) => _itsChars.containsKey(uuid);

  /// Raw indications from an ITS FIFO or credits characteristic. The
  /// credit-based framing on top of them is the ITS channel's job.
  Stream<List<int>> itsPackets(String uuid) => _itsPackets
      .putIfAbsent(uuid, () => StreamController<List<int>>.broadcast())
      .stream;

  /// One write to an ITS FIFO or credits characteristic, with response as
  /// Appendix 13 requires.
  Future<void> writeIts(String uuid, List<int> value) async {
    final char = _itsChars[uuid];
    if (char == null) {
      throw BleCharacteristicException(
        message: 'ITS karakteristiği yok: $uuid',
      );
    }
    await char.write(value);
  }

  void _onPacket(List<int> packet) {
    final message = _reassembler.onPacket(packet);
    final warning = _reassembler.lastWarning;
    if (warning != null) _log('App TX: $warning', LogLevel.error);
    if (message != null && !_messages.isClosed) _messages.add(message);
  }

  @override
  Future<void> writeCharacteristic(String charUuid, List<int> data) {
    _requireKwpChannel(charUuid);
    final rx = _rx;
    if (rx == null || _phase != VuLinkPhase.ready) {
      return Future.error(
        const BleCharacteristicException(message: 'Bağlantı hazır değil.'),
      );
    }

    final packets = VuAppPacketCodec.fragment(
      data,
      VuAppPacketCodec.payloadSizeFor(_mtu),
    );
    final withoutResponse = rx.properties.writeWithoutResponse;

    final send = _writeChain.then((_) async {
      // The transport logs the frame itself; a second copy here only halved
      // how much history the log could hold.
      for (final packet in packets) {
        await rx.write(packet, withoutResponse: withoutResponse);
      }
    });
    _writeChain = send.catchError((_) {});

    return send.catchError((Object e) {
      throw BleCharacteristicException(message: 'Yazma başarısız.', cause: e);
    });
  }

  @override
  Stream<List<int>> notifyStream(String charUuid) {
    _requireKwpChannel(charUuid);
    return _messages.stream;
  }

  /// App TX is subscribed as part of [connect]; this exists for callers that
  /// still enable notifications themselves.
  @override
  Future<void> setNotify(String charUuid, {required bool enable}) async {
    _requireKwpChannel(charUuid);
  }

  @override
  Future<List<BleGattService>> discoverServices() async => _services;

  /// Neither app characteristic is readable; the unit answers a read with an
  /// empty value.
  @override
  Future<List<int>> readCharacteristic(String charUuid) =>
      Future.error(BleCharacteristicException(message: '$charUuid okunamaz.'));

  @override
  Future<void> disconnect() async {
    _stateController.add(repo.BleConnectionState.disconnecting);
    await _teardown();
    _stateController.add(repo.BleConnectionState.disconnected);
  }

  Future<void> _teardown() async {
    await _txSub?.cancel();
    _txSub = null;
    for (final sub in _itsSubs) {
      await sub.cancel();
    }
    _itsSubs.clear();
    _itsChars.clear();
    _rawServices = const [];
    await _connStateSub?.cancel();
    _connStateSub = null;
    await _bondWatch?.cancel();
    _bondWatch = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _rx = null;
    _tx = null;
    _setPhase(VuLinkPhase.disconnected);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _messages.close();
    for (final ctrl in _itsPackets.values) {
      await ctrl.close();
    }
    await _stateController.close();
    await _logController.close();
  }

  void _requireKwpChannel(String charUuid) {
    if (charUuid != kwpChannel) {
      throw BleCharacteristicException(
        message: 'Bilinmeyen kanal: $charUuid (yalnızca $kwpChannel)',
      );
    }
  }

  void _setPhase(VuLinkPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    onPhase?.call(phase);
  }

  void _log(String message, LogLevel level) {
    if (!_logController.isClosed) {
      _logController.add(LogEntry(message: message, level: level));
    }
  }

  String _describe(Object e) {
    if (e is FlutterBluePlusException) {
      return 'Takografa bağlanılamadı: ${e.description ?? e.function}. '
          'Kontağın açık ve cihazın menzilde olduğundan emin olun.';
    }
    if (e is TimeoutException) {
      return 'Takograf yanıt vermiyor (zaman aşımı). Kontağın açık olduğundan '
          'emin olun; kontak kapalıyken Bluetooth yayını yapılmaz.';
    }
    return 'Takografa bağlanılamadı ($e).';
  }
}
