import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;

import '../../exceptions/ble_characteristic_exception.dart';
import '../../exceptions/ble_connection_exception.dart';
import '../models/ble_gatt_service.dart';
import '../models/log_entry.dart';
import '../repositories/ble_connection_repository.dart' hide BleConnectionState;
import '../repositories/ble_connection_repository.dart' as repo;
import '../vu/vu_app_link.dart';

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

/// A link to an AVU3 vehicle unit over its app service (see [VuAppUuids]).
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
  VuAppConnectionService({this.onPhase});

  static const String kwpChannel = 'SPP_DATA';

  static const int _requestedMtu = 247;
  static const int _defaultMtu = 23;
  static const Duration _gattConnectTimeout = Duration(seconds: 15);

  /// The unit closes its pairing dialog after 25 s and its security manager
  /// gives up at 30 s, so waiting longer only delays the error.
  static const int _bondTimeoutSeconds = 30;

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

      _mtu = await _negotiateMtu(device);
      _log(
        'MTU $_mtu, paket başına ${VuAppPacketCodec.payloadSizeFor(_mtu)} bayt.',
        LogLevel.info,
      );

      await _bond(device);

      _setPhase(VuLinkPhase.subscribing);
      final tx = _tx!;
      _txSub?.cancel();
      _txSub = tx.onValueReceived.listen(_onPacket);
      await tx.setNotifyValue(true, timeout: _subscribeTimeoutSeconds);

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

  /// Discovery that survives pairing starting underneath it.
  ///
  /// Pairing does not always wait for [_bond]: when the phone still holds a
  /// bond the unit has forgotten, or the unit asks for security on its own,
  /// Android starts it right after connecting and holds discovery until the
  /// user has answered on both screens. A 15 s discovery timeout then fires
  /// a second or two before the user is done and tears the link down - and
  /// the discovery that finally completes after the pairing can come back
  /// empty, so it is asked for once more.
  Future<List<BluetoothService>> _discoverAcrossPairing(
    BluetoothDevice device,
  ) async {
    var pairingSeen = false;
    StreamSubscription<BluetoothBondState>? bondSub;
    if (Platform.isAndroid) {
      bondSub = device.bondState.listen((state) {
        if (state == BluetoothBondState.bonding) {
          pairingSeen = true;
          _log('Keşif sırasında eşleşme başladı.', LogLevel.info);
          _setPhase(VuLinkPhase.bonding);
        } else if (pairingSeen) {
          _setPhase(VuLinkPhase.discovering);
        }
      });
    }

    try {
      var raw = await device.discoverServices(timeout: _discoverTimeoutSeconds);
      if (pairingSeen && !_hasAppService(raw)) {
        _log('Eşleşme sonrası servisler yeniden aranıyor.', LogLevel.info);
        raw = await device.discoverServices(timeout: 15);
      }
      return raw;
    } finally {
      await bondSub?.cancel();
    }
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
  Future<void> _bond(BluetoothDevice device) async {
    if (!Platform.isAndroid) return;

    final state = await device.bondState.first;
    if (state == BluetoothBondState.bonded) return;

    _setPhase(VuLinkPhase.bonding);
    _log('Eşleşme başlatılıyor (Numeric Comparison).', LogLevel.info);
    try {
      await device.createBond(timeout: _bondTimeoutSeconds);
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
    await _connStateSub?.cancel();
    _connStateSub = null;
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
