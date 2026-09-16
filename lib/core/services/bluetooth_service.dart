import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart'
    as fcb;
import 'package:permission_handler/permission_handler.dart' as ph;
import '../bluetooth/config/bluetooth_config.dart';
import '../bluetooth/repositories/ble_connection_repository.dart';
import '../bluetooth/repositories/ble_scanner_repository.dart';
import '../exceptions/ble_connection_exception.dart';
import '../models/ddd_file.dart';
import '../providers/app_state.dart';
import 'background_keepalive_service.dart';
import 'ddd_download_service.dart';
import 'dongle_log_service.dart';
import 'dongle_trace_log_service.dart';
import 'kline_protocol.dart';
import 'trace_log_service.dart';

enum AppBluetoothType { le, classic }

class AppBluetoothDevice {
  final String id;
  final String name;
  final int rssi;
  final AppBluetoothType type;

  final bool isPaired;

  AppBluetoothDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.type,
    this.isPaired = false,
  });

  String get distanceEstimation {
    if (rssi >= -50) return "Çok Yakın (<1m)";
    if (rssi >= -70) return "Yakın (1-3m)";
    if (rssi >= -85) return "Orta (3-5m)";
    return "Uzak (>5m)";
  }

  String get displayName {
    if (name.isNotEmpty) return name;
    return "Bilinmeyen Cihaz ($id)";
  }
}

class AppBluetoothService {
  AppBluetoothService._();
  static final AppBluetoothService instance = AppBluetoothService._();

  static const String dongleDeviceId = '98:D3:71:FF:1B:B5';

  static const Duration _dongleInterMessageDelay = Duration(milliseconds: 400);

  final BleScannerRepository _bleScanner = createScannerService(
    BtTransport.ble,
  );
  final BleScannerRepository _classicScanner = createScannerService(
    BtTransport.classic,
  );
  final fcb.FlutterClassicBluetooth _classicBluetooth =
      fcb.FlutterClassicBluetooth();

  BleConnectionRepository? _activeConnection;
  StreamSubscription<BleConnectionState>? _connectionStateSubscription;
  Timer? _liveRefreshTimer;
  Timer? _speedRefreshTimer;

  bool _wrapKLineForDongle = false;

  String get _lineTag => _wrapKLineForDongle ? 'K-LINE' : 'UART';

  bool _refreshInFlight = false;

  int _consecutiveRefreshFailures = 0;
  static const _deadConnectionThreshold = 3;

  final StreamController<List<AppBluetoothDevice>> _scanResultsController =
      StreamController<List<AppBluetoothDevice>>.broadcast();
  Stream<List<AppBluetoothDevice>> get unifiedScanResults =>
      _scanResultsController.stream;

  StreamSubscription? _bleScanSubscription;
  StreamSubscription? _classicScanSubscription;

  final Map<String, AppBluetoothDevice> _discoveredDevices = {};

  Future<bool> ensurePermissions() async {
    final statuses = await [
      ph.Permission.bluetoothScan,
      ph.Permission.bluetoothConnect,
      ph.Permission.location,
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }

  Future<bool> startUnifiedScan() async {
    if (!await ensurePermissions()) return false;

    _discoveredDevices.clear();
    _scanResultsController.add([]);

    try {
      final paired = await _classicBluetooth.getPairedDevices();
      for (final device in paired) {
        _discoveredDevices['${device.address}-Classic'] = AppBluetoothDevice(
          id: device.address,
          name: device.name ?? device.alias ?? '',
          rssi: device.rssi ?? -50,
          type: AppBluetoothType.classic,
          isPaired: true,
        );
      }
      _emitResults();
    } catch (e) {
      debugPrint('getPairedDevices failed: $e');
    }

    _bleScanSubscription?.cancel();
    _bleScanSubscription = _bleScanner.scanResults.listen((results) {
      for (final r in results) {
        final key = '${r.deviceId}-LE';
        _discoveredDevices[key] = AppBluetoothDevice(
          id: r.deviceId,
          name: r.name,
          rssi: r.rssi,
          type: AppBluetoothType.le,
          isPaired: _discoveredDevices[key]?.isPaired ?? false,
        );
      }
      _emitResults();
    }, onError: (Object e) => debugPrint('BLE scan stream error: $e'));
    unawaited(
      _bleScanner.startScan(timeout: const Duration(seconds: 15)).catchError((
        Object e,
      ) {
        debugPrint('BLE scan failed: $e');
      }),
    );

    _classicScanSubscription?.cancel();
    _classicScanSubscription = _classicScanner.scanResults.listen((results) {
      for (final r in results) {
        final key = '${r.deviceId}-Classic';
        final wasPaired = _discoveredDevices[key]?.isPaired ?? false;
        _discoveredDevices[key] = AppBluetoothDevice(
          id: r.deviceId,
          name: r.name,
          rssi: r.rssi,
          type: AppBluetoothType.classic,
          isPaired: wasPaired,
        );
      }
      _emitResults();
    }, onError: (Object e) => debugPrint('Classic scan stream error: $e'));
    unawaited(
      _classicScanner
          .startScan(timeout: const Duration(seconds: 15))
          .catchError((Object e) {
            debugPrint('Classic scan failed: $e');
          }),
    );

    return true;
  }

  void _emitResults() {
    final list = _discoveredDevices.values.toList();
    list.sort((a, b) {
      if (a.isPaired != b.isPaired) return a.isPaired ? -1 : 1;
      return b.rssi.compareTo(a.rssi);
    });
    if (!_scanResultsController.isClosed) {
      _scanResultsController.add(list);
    }
  }

  void stopScan() {
    _bleScanner.stopScan();
    _bleScanSubscription?.cancel();
    _classicScanner.stopScan();
    _classicScanSubscription?.cancel();
  }

  Future<AppBluetoothDevice?> findDongle({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!await startUnifiedScan()) return null;
    try {
      final completer = Completer<AppBluetoothDevice?>();
      late final StreamSubscription sub;
      sub = unifiedScanResults.listen((results) {
        if (completer.isCompleted) return;
        for (final d in results) {
          if (d.id.toUpperCase() == dongleDeviceId) {
            completer.complete(d);
            return;
          }
        }
      });
      final found = await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );
      await sub.cancel();
      return found;
    } finally {
      stopScan();
    }
  }

  static const Duration _connectTimeout = Duration(seconds: 12);

  Future<void> connectToDevice(
    AppBluetoothDevice device,
    AppState appState,
    Function(bool) onConnectionChange,
  ) async {
    if (!await ensurePermissions()) {
      throw const BleConnectionException(
        message:
            'Bluetooth izni eksik. Lütfen uygulama ayarlarından Bluetooth ve Konum izinlerini kontrol edin.',
      );
    }

    final conn = createConnectionService(
      device.type == AppBluetoothType.le
          ? BtTransport.ble
          : BtTransport.classic,
    );
    _wrapKLineForDongle = device.id.toUpperCase() == dongleDeviceId;
    try {
      await conn
          .connect(device.id)
          .timeout(
            _connectTimeout,
            onTimeout: () => throw TimeoutException(
              'Cihaz yanıt vermiyor (zaman aşımı) — açık ve menzil içinde olduğundan emin olun',
            ),
          );
      _activeConnection = conn;
      onConnectionChange(true);

      unawaited(BackgroundKeepAliveService.start());

      await conn.setNotify('SPP_DATA', enable: true);

      var sawDisconnectBlip = false;
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = conn.connectionState.listen((state) {
        if (state == BleConnectionState.disconnected) {
          sawDisconnectBlip = true;
          _stopLiveRefresh();
          onConnectionChange(false);
          unawaited(BackgroundKeepAliveService.stop());
          _wrapKLineForDongle = false;
        } else if (state == BleConnectionState.connected && sawDisconnectBlip) {
          sawDisconnectBlip = false;
          onConnectionChange(true);
          unawaited(BackgroundKeepAliveService.start());
          _startLiveRefresh(conn, appState);
        }
      });

      _performTachographHandshake(conn, appState);
    } catch (e) {
      onConnectionChange(false);
      unawaited(BackgroundKeepAliveService.stop());
      try {
        await conn.dispose();
      } catch (_) {}
      rethrow;
    }
  }

  Future<({DddFile? card, DddFile? vehicleUnit})> downloadRealDddFromDongle(
    AppBluetoothDevice device,
    AppState appState, {
    DddFetchKind kind = DddFetchKind.both,
    DateTime? activityRangeStart,
    DateTime? activityRangeEnd,
    bool includeEventsFaults = true,
    bool includeDetailedSpeed = true,
    bool includeTechnicalData = true,
    void Function(String message)? onProgress,
  }) async {
    if (!await ensurePermissions()) {
      throw const BleConnectionException(
        message:
            'Bluetooth izni eksik. Lütfen uygulama ayarlarından Bluetooth ve Konum izinlerini kontrol edin.',
      );
    }

    final conn = createConnectionService(
      device.type == AppBluetoothType.le
          ? BtTransport.ble
          : BtTransport.classic,
    );
    final wasWrappingForDongle = _wrapKLineForDongle;
    _wrapKLineForDongle = true;
    ({SendAndReceive sendAndReceive, StreamSubscription rxSub})? transport;
    try {
      await conn
          .connect(device.id)
          .timeout(
            _connectTimeout,
            onTimeout: () =>
                throw TimeoutException('Cihaz yanıt vermiyor (zaman aşımı)'),
          );
      await conn.setNotify('SPP_DATA', enable: true);
      transport = _buildKLineTransport(conn, wirePrefix: 0x0D);

      appState.setBluetoothConnected(true, deviceName: device.displayName);

      return await appState.downloadRealDddFromTachograph(
        sendAndReceive: transport.sendAndReceive,
        kind: kind,
        activityRangeStart: activityRangeStart,
        activityRangeEnd: activityRangeEnd,
        includeEventsFaults: includeEventsFaults,
        includeDetailedSpeed: includeDetailedSpeed,
        includeTechnicalData: includeTechnicalData,
        onProgress: onProgress,
      );
    } finally {
      await transport?.rxSub.cancel();
      _wrapKLineForDongle = wasWrappingForDongle;
      appState.setBluetoothConnected(false);
      try {
        await conn.dispose();
      } catch (_) {}
    }
  }

  Future<void> performLegalOnlyDemo(AppBluetoothDevice device) async {
    if (!await ensurePermissions()) {
      throw const BleConnectionException(
        message:
            'Bluetooth izni eksik. Lütfen uygulama ayarlarından Bluetooth ve Konum izinlerini kontrol edin.',
      );
    }
    final conn = createConnectionService(
      device.type == AppBluetoothType.le
          ? BtTransport.ble
          : BtTransport.classic,
    );
    ({SendAndReceive sendAndReceive, StreamSubscription rxSub})? transport;
    try {
      await conn
          .connect(device.id)
          .timeout(
            _connectTimeout,
            onTimeout: () =>
                throw TimeoutException('Cihaz yanıt vermiyor (zaman aşımı)'),
          );
      await conn.setNotify('SPP_DATA', enable: true);
      transport = _buildKLineTransport(conn);
      final sendAndReceive = transport.sendAndReceive;

      await sendAndReceive(
        KLineFrame.startCommunication,
        waitMs: 600,
        label: 'StartComm',
      );

      for (final id in <int>[
        TachoRecordId.vin,
        TachoRecordId.currentDateTime,
        TachoRecordId.odometer,
        TachoRecordId.speedLimit,
      ]) {
        await sendAndReceive(
          KLineFrame.readById(id),
          waitMs: 600,
          label: TachoRecordId.nameOf(id),
        );
      }

      await sendAndReceive(
        KLineFrame.stopCommunication,
        waitMs: 400,
        label: 'StopComm',
      );
    } finally {
      await transport?.rxSub.cancel();
      try {
        await conn.dispose();
      } catch (_) {}
    }
  }

  ({SendAndReceive sendAndReceive, StreamSubscription rxSub})
  _buildKLineTransport(
    BleConnectionRepository conn, {
    int wirePrefix = 0x0C,
    bool Function()? shouldAbort,
  }) {
    final rxBuffer = <int>[];
    final rxSub = conn.notifyStream('SPP_DATA').listen((data) {
      rxBuffer.addAll(data);
    });

    Future<List<int>> sendAndReceive(
      List<int> cmd, {
      int waitMs = 800,
      String label = '',
      int? prefixOverride,
    }) async {
      if (shouldAbort?.call() ?? false) return const [];
      rxBuffer.clear();
      final resolvedLabel = _rdbiLabel(cmd, label) ?? label;

      final effectivePrefix = prefixOverride ?? wirePrefix;
      final wireBytes = _wrapKLineForDongle
          ? <int>[effectivePrefix, ...cmd]
          : cmd;
      final txHex = wireBytes
          .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
      _log('$_lineTag TX [$resolvedLabel]: $txHex');

      await conn.writeCharacteristic('SPP_DATA', wireBytes);

      const pollMs = 30;

      const quietSlicesRequired = 5;

      const maxPendingRetries = 15;

      const maxIncompleteExtensions = 10;
      var pendingRetries = 0;
      while (true) {
        var effectiveWaitMs = waitMs;
        var elapsed = 0;
        var lastLen = rxBuffer.length;
        var quietSlices = 0;
        var extended = false;
        var incompleteExtensions = 0;
        while (elapsed < effectiveWaitMs) {
          await Future.delayed(const Duration(milliseconds: pollMs));
          elapsed += pollMs;

          int? expectedTotal;
          if (rxBuffer.length >= 4) {
            expectedTotal = rxBuffer[3] + 5;
            if (rxBuffer.length >= expectedTotal) break;
          }

          final knownIncomplete =
              expectedTotal != null && rxBuffer.length < expectedTotal;
          if (rxBuffer.length == lastLen) {
            if (rxBuffer.isNotEmpty &&
                !knownIncomplete &&
                ++quietSlices >= quietSlicesRequired)
              break;
          } else {
            quietSlices = 0;
            lastLen = rxBuffer.length;
          }
          if (knownIncomplete &&
              elapsed >= effectiveWaitMs &&
              incompleteExtensions < maxIncompleteExtensions) {
            effectiveWaitMs += 150;
            incompleteExtensions++;
          } else if (!extended &&
              elapsed >= effectiveWaitMs &&
              rxBuffer.isNotEmpty &&
              quietSlices == 0) {
            effectiveWaitMs += 150;
            extended = true;
          }
        }

        if (RdbiResponseParser.extractNrc(rxBuffer) == 0x78 &&
            pendingRetries < maxPendingRetries) {
          pendingRetries++;
          _log(
            '$_lineTag [$resolvedLabel]: RESPONSE PENDING (0x78) — bekleniyor ($pendingRetries/$maxPendingRetries)',
          );
          rxBuffer.clear();
          continue;
        }
        break;
      }

      final rxHex = rxBuffer
          .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
      _log('$_lineTag RX [$resolvedLabel]: $rxHex');

      if (_wrapKLineForDongle) {
        await Future.delayed(_dongleInterMessageDelay);
      }

      return List<int>.from(rxBuffer);
    }

    return (sendAndReceive: sendAndReceive, rxSub: rxSub);
  }

  ({SendAndReceive sendAndReceive, StreamSubscription rxSub})?
  _downloadTestTransport;

  bool get downloadTestModeActive => _downloadTestTransport != null;

  void beginDongleDownloadTest() {
    final conn = _activeConnection;
    if (conn == null || !_wrapKLineForDongle) {
      throw StateError('Dongle bağlantısı aktif değil');
    }
    endDongleDownloadTest();
    _downloadTestTransport = _buildKLineTransport(conn, wirePrefix: 0x0D);
    DongleLogService.instance.add(
      '--- İndirme testi oturumu açıldı (0x0D ön ekli) ---',
    );
  }

  void endDongleDownloadTest() {
    if (_downloadTestTransport == null) return;
    _downloadTestTransport!.rxSub.cancel();
    _downloadTestTransport = null;
    DongleLogService.instance.add('--- İndirme testi oturumu kapatıldı ---');
  }

  Future<List<int>> sendDongleDownloadFrame(
    List<int> frame, {
    required String label,
    int waitMs = 2000,
    int? prefixByte,
  }) {
    final transport = _downloadTestTransport;
    if (transport == null) {
      throw StateError('İndirme testi oturumu açık değil — önce başlatın');
    }
    return transport.sendAndReceive(
      frame,
      waitMs: waitMs,
      label: label,
      prefixOverride: prefixByte,
    );
  }

  String? _rdbiLabel(List<int> cmd, String label) {
    if (cmd.length < 7 || cmd[0] != 0x80 || cmd[4] != 0x22) return null;
    final recordId = (cmd[5] << 8) | cmd[6];
    final name = TachoRecordId.nameOf(recordId);
    return label.startsWith('Refresh') ? 'Refresh-$name' : name;
  }

  void _log(String line) {
    if (_wrapKLineForDongle) DongleLogService.instance.add(line);
    debugPrint(line);
  }

  String? _logIfFailed(List<int> response, int recordId, String label) {
    if (RdbiResponseParser.extractData(response, recordId) != null) return null;
    final nrc = RdbiResponseParser.extractNrc(response);
    if (nrc != null) {
      _log(
        '$_lineTag [$label]: NEGATIVE RESPONSE, NRC=0x${nrc.toRadixString(16).padLeft(2, '0').toUpperCase()} (${RdbiResponseParser.describeNrc(nrc)})',
      );
      if (nrc == 0x33 || nrc == 0x35 || nrc == 0x36 || nrc == 0x37) {
        return 'Cihaz güvenlik erişimi istiyor (kalibrasyon/servis kartı gerekebilir)';
      }
      return 'Cihaz $label alanını reddetti (NRC 0x${nrc.toRadixString(16).padLeft(2, '0').toUpperCase()})';
    } else if (response.isEmpty) {
      _log(
        '$_lineTag [$label]: NO RESPONSE (empty — check wiring/adapter/baud)',
      );
      return 'Cihazdan yanıt gelmiyor (bağlantı/adaptör kontrol edin)';
    } else {
      _log(
        '$_lineTag [$label]: UNRECOGNIZED RESPONSE (no 0x62 match, no 0x7F)',
      );
      return 'Cihazdan tanınmayan yanıt geldi';
    }
  }

  String _traceValue(Object? value) {
    if (value == null) return '(yok)';
    if (value is String) return value.isEmpty ? '(boş)' : value;
    if (value is Duration)
      return '${value.inHours}s ${(value.inMinutes % 60).toString().padLeft(2, '0')}dk';
    if (value is DateTime) {
      final d = value;
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return value.toString();
  }

  String? _workingStateToActivityKey(int code) {
    switch (code) {
      case 0:
        return 'dashboard.rest';
      case 1:
        return 'dashboard.availability';
      case 2:
        return 'dashboard.otherWork';
      case 3:
        return 'dashboard.driving';
      default:
        return null;
    }
  }

  void _performTachographHandshake(
    BleConnectionRepository conn,
    AppState appState,
  ) async {
    try {
      final transport = _buildKLineTransport(conn);
      final sendAndReceive = transport.sendAndReceive;

      String? failureReason;

      void trace(String label, bool success, Object? value) {
        final line =
            '$_lineTag [$label] SONUÇ: ${success ? 'GERÇEK -> ${_traceValue(value)}' : 'YOK (cihaz yanıt vermedi)'}';
        if (_wrapKLineForDongle) {
          DongleTraceLogService.instance.add(line);
        } else {
          TraceLogService.instance.add(line);
        }
      }

      await sendAndReceive(
        KLineFrame.startCommunication,
        waitMs: 600,
        label: 'StartComm',
      );

      await sendAndReceive(
        KLineFrame.sessionStandard,
        waitMs: 600,
        label: 'DiagSession-Standard',
      );

      final vinResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.vin),
        waitMs: 1500,
        label: 'VIN',
      );
      final vinData = RdbiResponseParser.extractData(
        vinResp,
        TachoRecordId.vin,
      );
      failureReason ??= _logIfFailed(vinResp, TachoRecordId.vin, 'VIN');
      if (vinData != null) {
        appState.setVehiclePlate(RdbiResponseParser.parseAscii(vinData));
      }
      trace(
        'VIN',
        vinData != null,
        vinData != null ? RdbiResponseParser.parseAscii(vinData) : null,
      );

      final dtResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.currentDateTime),
        waitMs: 600,
        label: 'DateTime',
      );
      final dtData = RdbiResponseParser.extractData(
        dtResp,
        TachoRecordId.currentDateTime,
      );
      _logIfFailed(dtResp, TachoRecordId.currentDateTime, 'DateTime');
      DateTime? tachoTime;
      if (dtData != null) {
        tachoTime = RdbiResponseParser.parseDateTime(dtData);
      }
      trace('CurrentDateTime', dtData != null, tachoTime);

      final odoResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.odometer),
        waitMs: 600,
        label: 'Odometer',
      );
      final odoData = RdbiResponseParser.extractData(
        odoResp,
        TachoRecordId.odometer,
      );
      _logIfFailed(odoResp, TachoRecordId.odometer, 'Odometer');
      int odometerMeters = 0;
      if (odoData != null) {
        odometerMeters = RdbiResponseParser.parseDistanceMeters(odoData);
      }
      trace(
        'Odometer',
        odoData != null,
        odoData != null ? '$odometerMeters m' : null,
      );

      final spdResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.vehicleSpeed),
        waitMs: 600,
        label: 'Speed',
      );
      final spdData = RdbiResponseParser.extractData(
        spdResp,
        TachoRecordId.vehicleSpeed,
      );
      _logIfFailed(spdResp, TachoRecordId.vehicleSpeed, 'Speed');
      int speedKmh = 0;
      if (spdData != null) {
        speedKmh = RdbiResponseParser.parseSpeedKmh(spdData);
      }
      trace(
        'Speed',
        spdData != null,
        spdData != null ? '$speedKmh km/h' : null,
      );

      final kResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.kConstant),
        waitMs: 600,
        label: 'K-Const',
      );
      final kData = RdbiResponseParser.extractData(
        kResp,
        TachoRecordId.kConstant,
      );
      _logIfFailed(kResp, TachoRecordId.kConstant, 'K-Const');
      int kConst = 0;
      if (kData != null) {
        kConst = RdbiResponseParser.parseInt16BE(kData);
      }
      trace('K-Constant', kData != null, kData != null ? kConst : null);

      final tyreCircResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.tyreCircumference),
        waitMs: 600,
        label: 'TyreCirc',
      );
      final tyreCircData = RdbiResponseParser.extractData(
        tyreCircResp,
        TachoRecordId.tyreCircumference,
      );
      _logIfFailed(tyreCircResp, TachoRecordId.tyreCircumference, 'TyreCirc');
      int tyreCirc = 0;
      if (tyreCircData != null) {
        tyreCirc = RdbiResponseParser.parseInt16BE(tyreCircData);
      }
      trace(
        'TyreCircumference',
        tyreCircData != null,
        tyreCircData != null ? '$tyreCirc mm' : null,
      );

      final wResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.wConstant),
        waitMs: 600,
        label: 'W-Const',
      );
      final wData = RdbiResponseParser.extractData(
        wResp,
        TachoRecordId.wConstant,
      );
      _logIfFailed(wResp, TachoRecordId.wConstant, 'W-Const');
      int wConst = 0;
      if (wData != null) {
        wConst = RdbiResponseParser.parseInt16BE(wData);
      }
      trace('W-Constant', wData != null, wData != null ? wConst : null);

      final tyreSizeResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.tyreSize),
        waitMs: 600,
        label: 'TyreSize',
      );
      final tyreSizeData = RdbiResponseParser.extractData(
        tyreSizeResp,
        TachoRecordId.tyreSize,
      );
      _logIfFailed(tyreSizeResp, TachoRecordId.tyreSize, 'TyreSize');
      String tyreSize = '';
      if (tyreSizeData != null) {
        tyreSize = RdbiResponseParser.parseAscii(tyreSizeData);
      }
      trace(
        'TyreSize',
        tyreSizeData != null,
        tyreSize.isEmpty ? null : tyreSize,
      );

      final nextCalResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.nextCalibrationDate),
        waitMs: 600,
        label: 'NextCalDate',
      );
      final nextCalData = RdbiResponseParser.extractData(
        nextCalResp,
        TachoRecordId.nextCalibrationDate,
      );
      _logIfFailed(
        nextCalResp,
        TachoRecordId.nextCalibrationDate,
        'NextCalDate',
      );
      final nextCalibrationDate = nextCalData != null
          ? RdbiResponseParser.parseCompactDate(nextCalData)
          : null;
      trace('NextCalibrationDate', nextCalData != null, nextCalibrationDate);

      final spdLimResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.speedLimit),
        waitMs: 600,
        label: 'SpeedLim',
      );
      final spdLimData = RdbiResponseParser.extractData(
        spdLimResp,
        TachoRecordId.speedLimit,
      );
      _logIfFailed(spdLimResp, TachoRecordId.speedLimit, 'SpeedLim');
      int speedLimit = 0;
      if (spdLimData != null && spdLimData.isNotEmpty) {
        speedLimit = spdLimData[0];
      }
      trace(
        'SpeedLimit',
        spdLimData != null,
        spdLimData != null ? '$speedLimit km/h' : null,
      );

      final stateResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.registeringMemberState),
        waitMs: 600,
        label: 'MemberState',
      );
      final stateData = RdbiResponseParser.extractData(
        stateResp,
        TachoRecordId.registeringMemberState,
      );
      _logIfFailed(
        stateResp,
        TachoRecordId.registeringMemberState,
        'MemberState',
      );
      String memberState = '';
      if (stateData != null) {
        memberState = RdbiResponseParser.parseAscii(stateData);
      }
      trace(
        'MemberState',
        stateData != null,
        memberState.isEmpty ? null : memberState,
      );

      final vrnResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.vrn),
        waitMs: 800,
        label: 'VRN (Plaka)',
      );
      final vrnData = RdbiResponseParser.extractData(
        vrnResp,
        TachoRecordId.vrn,
      );
      failureReason ??= _logIfFailed(vrnResp, TachoRecordId.vrn, 'VRN (Plaka)');
      String vrn = '';
      if (vrnData != null) {
        vrn = RdbiResponseParser.parseAscii(vrnData);
      }
      trace('VRN', vrnData != null, vrn.isEmpty ? null : vrn);

      final d1NameResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1Name),
        waitMs: 600,
        label: 'Driver1Name',
      );
      final d1NameData = RdbiResponseParser.extractData(
        d1NameResp,
        TachoRecordId.driver1Name,
      );
      _logIfFailed(d1NameResp, TachoRecordId.driver1Name, 'Driver1Name');
      final driver1Name = d1NameData != null
          ? RdbiResponseParser.parseDriverName(d1NameData)
          : '';
      trace(
        'Driver1Name',
        d1NameData != null,
        driver1Name.isEmpty ? null : driver1Name,
      );

      final d2NameResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2Name),
        waitMs: 600,
        label: 'Driver2Name',
      );
      final d2NameData = RdbiResponseParser.extractData(
        d2NameResp,
        TachoRecordId.driver2Name,
      );
      _logIfFailed(d2NameResp, TachoRecordId.driver2Name, 'Driver2Name');
      final driver2Name = d2NameData != null
          ? RdbiResponseParser.parseDriverName(d2NameData)
          : '';
      trace(
        'Driver2Name',
        d2NameData != null,
        driver2Name.isEmpty ? null : driver2Name,
      );

      final d2IdResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2Identification),
        waitMs: 500,
        label: 'Driver2Identification',
      );
      final d2IdData = RdbiResponseParser.extractData(
        d2IdResp,
        TachoRecordId.driver2Identification,
      );
      _logIfFailed(
        d2IdResp,
        TachoRecordId.driver2Identification,
        'Driver2Identification',
      );
      final driver2IssuingState = (d2IdData != null && d2IdData.length >= 19)
          ? RdbiResponseParser.parseAscii(d2IdData.sublist(0, 3))
          : '';
      final driver2CardNumber = d2IdData != null
          ? RdbiResponseParser.parseDriverCardNumber(d2IdData)
          : '';
      trace(
        'Driver2Identification',
        d2IdData != null,
        d2IdData != null ? '$driver2IssuingState $driver2CardNumber' : null,
      );

      final d1LangResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1PreferredLanguage),
        waitMs: 500,
        label: 'Driver1Language',
      );
      final d1LangData = RdbiResponseParser.extractData(
        d1LangResp,
        TachoRecordId.driver1PreferredLanguage,
      );
      _logIfFailed(
        d1LangResp,
        TachoRecordId.driver1PreferredLanguage,
        'Driver1Language',
      );
      final driver1PreferredLanguage = d1LangData != null
          ? RdbiResponseParser.parseAscii(d1LangData)
          : '';
      trace(
        'Driver1PreferredLanguage',
        d1LangData != null,
        driver1PreferredLanguage.isEmpty ? null : driver1PreferredLanguage,
      );

      final d2LangResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2PreferredLanguage),
        waitMs: 500,
        label: 'Driver2Language',
      );
      final d2LangData = RdbiResponseParser.extractData(
        d2LangResp,
        TachoRecordId.driver2PreferredLanguage,
      );
      _logIfFailed(
        d2LangResp,
        TachoRecordId.driver2PreferredLanguage,
        'Driver2Language',
      );
      final driver2PreferredLanguage = d2LangData != null
          ? RdbiResponseParser.parseAscii(d2LangData)
          : '';
      trace(
        'Driver2PreferredLanguage',
        d2LangData != null,
        driver2PreferredLanguage.isEmpty ? null : driver2PreferredLanguage,
      );

      final d2CardExpResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2CardExpiryDate),
        waitMs: 500,
        label: 'Driver2CardExpiry',
      );
      final d2CardExpData = RdbiResponseParser.extractData(
        d2CardExpResp,
        TachoRecordId.driver2CardExpiryDate,
      );
      _logIfFailed(
        d2CardExpResp,
        TachoRecordId.driver2CardExpiryDate,
        'Driver2CardExpiry',
      );
      final driver2CardExpiryDate = d2CardExpData != null
          ? RdbiResponseParser.parseCompactDate(d2CardExpData)
          : null;
      trace(
        'Driver2CardExpiryDate',
        d2CardExpData != null,
        driver2CardExpiryDate,
      );

      final d1NextDlResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1CardNextMandatoryDownloadDate),
        waitMs: 500,
        label: 'Driver1NextDownload',
      );
      final d1NextDlData = RdbiResponseParser.extractData(
        d1NextDlResp,
        TachoRecordId.driver1CardNextMandatoryDownloadDate,
      );
      _logIfFailed(
        d1NextDlResp,
        TachoRecordId.driver1CardNextMandatoryDownloadDate,
        'Driver1NextDownload',
      );
      final driver1CardNextMandatoryDownloadDate = d1NextDlData != null
          ? RdbiResponseParser.parseCompactDate(d1NextDlData)
          : null;
      trace(
        'Driver1CardNextMandatoryDownloadDate',
        d1NextDlData != null,
        driver1CardNextMandatoryDownloadDate,
      );

      final d2NextDlResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2CardNextMandatoryDownloadDate),
        waitMs: 500,
        label: 'Driver2NextDownload',
      );
      final d2NextDlData = RdbiResponseParser.extractData(
        d2NextDlResp,
        TachoRecordId.driver2CardNextMandatoryDownloadDate,
      );
      _logIfFailed(
        d2NextDlResp,
        TachoRecordId.driver2CardNextMandatoryDownloadDate,
        'Driver2NextDownload',
      );
      final driver2CardNextMandatoryDownloadDate = d2NextDlData != null
          ? RdbiResponseParser.parseCompactDate(d2NextDlData)
          : null;
      trace(
        'Driver2CardNextMandatoryDownloadDate',
        d2NextDlData != null,
        driver2CardNextMandatoryDownloadDate,
      );

      final slot1Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.tachographCardSlot1),
        waitMs: 500,
        label: 'CardSlot1',
      );
      final slot1Data = RdbiResponseParser.extractData(
        slot1Resp,
        TachoRecordId.tachographCardSlot1,
      );
      _logIfFailed(slot1Resp, TachoRecordId.tachographCardSlot1, 'CardSlot1');
      final cardSlot1 = (slot1Data != null && slot1Data.isNotEmpty)
          ? slot1Data[0]
          : null;
      trace('TachographCardSlot1', slot1Data != null, cardSlot1);

      final slot2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.tachographCardSlot2),
        waitMs: 500,
        label: 'CardSlot2',
      );
      final slot2Data = RdbiResponseParser.extractData(
        slot2Resp,
        TachoRecordId.tachographCardSlot2,
      );
      _logIfFailed(slot2Resp, TachoRecordId.tachographCardSlot2, 'CardSlot2');
      final cardSlot2 = (slot2Data != null && slot2Data.isNotEmpty)
          ? slot2Data[0]
          : null;
      trace('TachographCardSlot2', slot2Data != null, cardSlot2);

      final workingStateResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1WorkingState),
        waitMs: 500,
        label: 'WorkingState',
      );
      final workingStateData = RdbiResponseParser.extractData(
        workingStateResp,
        TachoRecordId.driver1WorkingState,
      );
      _logIfFailed(
        workingStateResp,
        TachoRecordId.driver1WorkingState,
        'WorkingState',
      );
      final workingStateCode =
          workingStateData != null && workingStateData.isNotEmpty
          ? workingStateData[0] & 0x07
          : null;
      final currentActivityKey = workingStateCode != null
          ? _workingStateToActivityKey(workingStateCode)
          : null;
      trace(
        'Driver1WorkingState',
        workingStateData != null,
        currentActivityKey ?? workingStateCode,
      );

      final d1TrsResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1TimeRelatedStates),
        waitMs: 500,
        label: 'Driver1TimeRelatedStates',
      );
      final d1TrsData = RdbiResponseParser.extractData(
        d1TrsResp,
        TachoRecordId.driver1TimeRelatedStates,
      );
      _logIfFailed(
        d1TrsResp,
        TachoRecordId.driver1TimeRelatedStates,
        'Driver1TimeRelatedStates',
      );
      final driver1TimeRelatedState =
          (d1TrsData != null && d1TrsData.isNotEmpty)
          ? (d1TrsData[0] & 0x0F)
          : null;
      trace(
        'Driver1TimeRelatedStates',
        d1TrsData != null,
        driver1TimeRelatedState,
      );

      final d2TrsResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2TimeRelatedStates),
        waitMs: 500,
        label: 'Driver2TimeRelatedStates',
      );
      final d2TrsData = RdbiResponseParser.extractData(
        d2TrsResp,
        TachoRecordId.driver2TimeRelatedStates,
      );
      _logIfFailed(
        d2TrsResp,
        TachoRecordId.driver2TimeRelatedStates,
        'Driver2TimeRelatedStates',
      );
      final driver2TimeRelatedState =
          (d2TrsData != null && d2TrsData.isNotEmpty)
          ? (d2TrsData[0] & 0x0F)
          : null;
      trace(
        'Driver2TimeRelatedStates',
        d2TrsData != null,
        driver2TimeRelatedState,
      );

      final continuousResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1ContinuousDrivingTime),
        waitMs: 500,
        label: 'ContinuousDriving',
      );
      final continuousData = RdbiResponseParser.extractData(
        continuousResp,
        TachoRecordId.driver1ContinuousDrivingTime,
      );
      _logIfFailed(
        continuousResp,
        TachoRecordId.driver1ContinuousDrivingTime,
        'ContinuousDriving',
      );
      final continuousDriving = RdbiResponseParser.parseMinutesOrNull(
        continuousData,
      );
      trace(
        'Driver1ContinuousDrivingTime',
        continuousData != null,
        continuousData != null ? continuousDriving : null,
      );

      final cumBreakResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1CumulativeBreakTime),
        waitMs: 500,
        label: 'CumulativeBreak',
      );
      final cumBreakData = RdbiResponseParser.extractData(
        cumBreakResp,
        TachoRecordId.driver1CumulativeBreakTime,
      );
      _logIfFailed(
        cumBreakResp,
        TachoRecordId.driver1CumulativeBreakTime,
        'CumulativeBreak',
      );
      final cumulativeBreak = RdbiResponseParser.parseMinutesOrNull(
        cumBreakData,
      );
      trace(
        'Driver1CumulativeBreakTime',
        cumBreakData != null,
        cumBreakData != null ? cumulativeBreak : null,
      );

      final sessionDurResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1CurrentDurationOfActivity),
        waitMs: 500,
        label: 'SessionDuration',
      );
      final sessionDurData = RdbiResponseParser.extractData(
        sessionDurResp,
        TachoRecordId.driver1CurrentDurationOfActivity,
      );
      _logIfFailed(
        sessionDurResp,
        TachoRecordId.driver1CurrentDurationOfActivity,
        'SessionDuration',
      );
      final currentSessionDuration = RdbiResponseParser.parseMinutesOrNull(
        sessionDurData,
      );
      trace(
        'Driver1CurrentDurationOfActivity',
        sessionDurData != null,
        currentSessionDuration,
      );

      final dailyDrvResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1CurrentDailyDrivingTime),
        waitMs: 500,
        label: 'CurrentDailyDriving',
      );
      final dailyDrvData = RdbiResponseParser.extractData(
        dailyDrvResp,
        TachoRecordId.driver1CurrentDailyDrivingTime,
      );
      _logIfFailed(
        dailyDrvResp,
        TachoRecordId.driver1CurrentDailyDrivingTime,
        'CurrentDailyDriving',
      );
      final currentDailyDriving = RdbiResponseParser.parseMinutesOrNull(
        dailyDrvData,
      );
      trace(
        'Driver1CurrentDailyDrivingTime',
        dailyDrvData != null,
        currentDailyDriving,
      );

      final weeklyDrvResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1CurrentWeeklyDrivingTime),
        waitMs: 500,
        label: 'CurrentWeeklyDriving',
      );
      final weeklyDrvData = RdbiResponseParser.extractData(
        weeklyDrvResp,
        TachoRecordId.driver1CurrentWeeklyDrivingTime,
      );
      _logIfFailed(
        weeklyDrvResp,
        TachoRecordId.driver1CurrentWeeklyDrivingTime,
        'CurrentWeeklyDriving',
      );
      final currentWeeklyDriving = RdbiResponseParser.parseMinutesOrNull(
        weeklyDrvData,
      );
      trace(
        'Driver1CurrentWeeklyDrivingTime',
        weeklyDrvData != null,
        currentWeeklyDriving,
      );

      final rem2wResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1Remaining2WeeksDrivingTime),
        waitMs: 500,
        label: 'Remaining2Weeks',
      );
      final rem2wData = RdbiResponseParser.extractData(
        rem2wResp,
        TachoRecordId.driver1Remaining2WeeksDrivingTime,
      );
      _logIfFailed(
        rem2wResp,
        TachoRecordId.driver1Remaining2WeeksDrivingTime,
        'Remaining2Weeks',
      );
      final remainingBiWeekly = RdbiResponseParser.parseMinutesOrNull(
        rem2wData,
      );
      trace(
        'Driver1Remaining2WeeksDrivingTime',
        rem2wData != null,
        remainingBiWeekly,
      );

      final cardIdResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1Identification),
        waitMs: 500,
        label: 'DriverCardId',
      );
      final cardIdData = RdbiResponseParser.extractData(
        cardIdResp,
        TachoRecordId.driver1Identification,
      );
      _logIfFailed(
        cardIdResp,
        TachoRecordId.driver1Identification,
        'DriverCardId',
      );
      final driverCardNumber = cardIdData != null
          ? RdbiResponseParser.parseDriverCardNumber(cardIdData)
          : '';

      final driver1IssuingState =
          (cardIdData != null && cardIdData.length >= 19)
          ? RdbiResponseParser.parseAscii(cardIdData.sublist(0, 3))
          : '';
      trace(
        'Driver1Identification',
        cardIdData != null,
        cardIdData != null ? '$driver1IssuingState $driverCardNumber' : null,
      );

      final cardExpResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1CardExpiryDate),
        waitMs: 500,
        label: 'DriverCardExpiry',
      );
      final cardExpData = RdbiResponseParser.extractData(
        cardExpResp,
        TachoRecordId.driver1CardExpiryDate,
      );
      _logIfFailed(
        cardExpResp,
        TachoRecordId.driver1CardExpiryDate,
        'DriverCardExpiry',
      );
      final driverCardExpiryDate = cardExpData != null
          ? RdbiResponseParser.parseCompactDate(cardExpData)
          : null;
      trace('Driver1CardExpiryDate', cardExpData != null, driverCardExpiryDate);

      final hwNumResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.hwNumber),
        waitMs: 500,
        label: 'HW-Number',
      );
      final hwNumData = RdbiResponseParser.extractData(
        hwNumResp,
        TachoRecordId.hwNumber,
      );
      _logIfFailed(hwNumResp, TachoRecordId.hwNumber, 'HW-Number');
      final hwNumber = hwNumData != null
          ? RdbiResponseParser.parseAscii(hwNumData)
          : '';
      trace('HW-Number', hwNumData != null, hwNumber.isEmpty ? null : hwNumber);

      final hwVerResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.hwVersion),
        waitMs: 500,
        label: 'HW-Version',
      );
      final hwVerData = RdbiResponseParser.extractData(
        hwVerResp,
        TachoRecordId.hwVersion,
      );
      _logIfFailed(hwVerResp, TachoRecordId.hwVersion, 'HW-Version');
      final hwVersion = hwVerData != null
          ? RdbiResponseParser.parseAscii(hwVerData)
          : '';
      trace(
        'HW-Version',
        hwVerData != null,
        hwVersion.isEmpty ? null : hwVersion,
      );

      final swNumResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.swNumber),
        waitMs: 500,
        label: 'SW-Number',
      );
      final swNumData = RdbiResponseParser.extractData(
        swNumResp,
        TachoRecordId.swNumber,
      );
      _logIfFailed(swNumResp, TachoRecordId.swNumber, 'SW-Number');
      final swNumber = swNumData != null
          ? RdbiResponseParser.parseAscii(swNumData)
          : '';
      trace('SW-Number', swNumData != null, swNumber.isEmpty ? null : swNumber);

      final swVerResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.swVersion),
        waitMs: 500,
        label: 'SW-Version',
      );
      final swVerData = RdbiResponseParser.extractData(
        swVerResp,
        TachoRecordId.swVersion,
      );
      _logIfFailed(swVerResp, TachoRecordId.swVersion, 'SW-Version');
      final swVersion = swVerData != null
          ? RdbiResponseParser.parseAscii(swVerData)
          : '';
      trace(
        'SW-Version',
        swVerData != null,
        swVersion.isEmpty ? null : swVersion,
      );

      final typeApprResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.typeApproval),
        waitMs: 500,
        label: 'TypeApproval',
      );
      final typeApprData = RdbiResponseParser.extractData(
        typeApprResp,
        TachoRecordId.typeApproval,
      );
      _logIfFailed(typeApprResp, TachoRecordId.typeApproval, 'TypeApproval');
      final typeApproval = typeApprData != null
          ? RdbiResponseParser.parseAscii(typeApprData)
          : '';
      trace(
        'TypeApproval',
        typeApprData != null,
        typeApproval.isEmpty ? null : typeApproval,
      );

      final suppResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.supplierIdentifier),
        waitMs: 500,
        label: 'Supplier',
      );
      final suppData = RdbiResponseParser.extractData(
        suppResp,
        TachoRecordId.supplierIdentifier,
      );
      _logIfFailed(suppResp, TachoRecordId.supplierIdentifier, 'Supplier');
      final supplierIdentifier = suppData != null
          ? RdbiResponseParser.parseAscii(suppData)
          : '';
      trace(
        'SupplierIdentifier',
        suppData != null,
        supplierIdentifier.isEmpty ? null : supplierIdentifier,
      );

      final ecuSerResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.ecuSerialNumber),
        waitMs: 500,
        label: 'ECU-Serial',
      );
      final ecuSerData = RdbiResponseParser.extractData(
        ecuSerResp,
        TachoRecordId.ecuSerialNumber,
      );
      _logIfFailed(ecuSerResp, TachoRecordId.ecuSerialNumber, 'ECU-Serial');
      final ecuSerialNumber = ecuSerData != null
          ? RdbiResponseParser.parseAscii(ecuSerData)
          : '';
      trace(
        'ECU-SerialNumber',
        ecuSerData != null,
        ecuSerialNumber.isEmpty ? null : ecuSerialNumber,
      );

      final ecuMfgResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.ecuManufacturingDate),
        waitMs: 500,
        label: 'ECU-MfgDate',
      );
      final ecuMfgData = RdbiResponseParser.extractData(
        ecuMfgResp,
        TachoRecordId.ecuManufacturingDate,
      );
      _logIfFailed(
        ecuMfgResp,
        TachoRecordId.ecuManufacturingDate,
        'ECU-MfgDate',
      );
      final ecuManufacturingDate = ecuMfgData != null
          ? RdbiResponseParser.parseCompactDate(ecuMfgData)
          : null;
      trace('ECU-ManufacturingDate', ecuMfgData != null, ecuManufacturingDate);

      final calDateResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.calibrationDate),
        waitMs: 500,
        label: 'CalDate',
      );
      final calDateData = RdbiResponseParser.extractData(
        calDateResp,
        TachoRecordId.calibrationDate,
      );
      _logIfFailed(calDateResp, TachoRecordId.calibrationDate, 'CalDate');
      final calibrationDate = calDateData != null
          ? RdbiResponseParser.parseCompactDate(calDateData)
          : null;
      trace('CalibrationDate', calDateData != null, calibrationDate);

      final ecuInstResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.ecuInstallDate),
        waitMs: 500,
        label: 'ECU-InstallDate',
      );
      final ecuInstData = RdbiResponseParser.extractData(
        ecuInstResp,
        TachoRecordId.ecuInstallDate,
      );
      _logIfFailed(
        ecuInstResp,
        TachoRecordId.ecuInstallDate,
        'ECU-InstallDate',
      );
      final ecuInstallDate = ecuInstData != null
          ? RdbiResponseParser.parseCompactDate(ecuInstData)
          : null;
      trace('ECU-InstallDate', ecuInstData != null, ecuInstallDate);

      final vehRegResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.vehicleRegDate),
        waitMs: 500,
        label: 'VehRegDate',
      );
      final vehRegData = RdbiResponseParser.extractData(
        vehRegResp,
        TachoRecordId.vehicleRegDate,
      );
      _logIfFailed(vehRegResp, TachoRecordId.vehicleRegDate, 'VehRegDate');

      final vehicleRegDate = vehRegData != null
          ? RdbiResponseParser.parseDateTime(vehRegData)
          : null;
      trace('VehicleRegDate', vehRegData != null, vehicleRegDate);

      final tripResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.tripDistance),
        waitMs: 500,
        label: 'TripDistance',
      );
      final tripData = RdbiResponseParser.extractData(
        tripResp,
        TachoRecordId.tripDistance,
      );
      _logIfFailed(tripResp, TachoRecordId.tripDistance, 'TripDistance');
      final tripDistanceMeters = tripData != null
          ? RdbiResponseParser.parseDistanceMeters(tripData)
          : 0;
      trace(
        'TripDistance',
        tripData != null,
        tripData != null ? '$tripDistanceMeters m' : null,
      );

      final dtcCountResp = await sendAndReceive(
        KLineFrame.reportDtcCount,
        waitMs: 500,
        label: 'DTC-Count',
      );
      final dtcCountPayload = DtcResponseParser.extractPayload(
        dtcCountResp,
        0x01,
      );
      _log(
        dtcCountPayload != null
            ? '$_lineTag [DTC-Count]: OK'
            : '$_lineTag [DTC-Count]: no positive response',
      );
      int? dtcCount;
      if (dtcCountPayload != null && dtcCountPayload.length >= 4) {
        dtcCount = (dtcCountPayload[2] << 8) | dtcCountPayload[3];
      }
      trace('DTC-Count', dtcCountPayload != null, dtcCount);

      final dtcListResp = await sendAndReceive(
        KLineFrame.reportDtcList,
        waitMs: 500,
        label: 'DTC-List',
      );
      final dtcListPayload = DtcResponseParser.extractPayload(
        dtcListResp,
        0x02,
      );
      _log(
        dtcListPayload != null
            ? '$_lineTag [DTC-List]: OK'
            : '$_lineTag [DTC-List]: no positive response',
      );
      String dtcHex = '';
      if (dtcListPayload != null && dtcListPayload.length > 1) {
        dtcHex = dtcListPayload
            .sublist(1)
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');
      }
      trace('DTC-List', dtcListPayload != null, dtcHex.isEmpty ? null : dtcHex);

      if (dtcCount == null &&
          dtcListPayload != null &&
          dtcListPayload.length > 1) {
        dtcCount = (dtcListPayload.length - 1) ~/ 4;
      }

      await sendAndReceive(
        KLineFrame.stopCommunication,
        waitMs: 300,
        label: 'StopComm',
      );

      final liveData = TachographLiveData(
        driver1Name: driver1Name,
        driver2Name: driver2Name,
        driver1IssuingState: driver1IssuingState,
        driver1CardNumber: driverCardNumber,
        driver2IssuingState: driver2IssuingState,
        driver2CardNumber: driver2CardNumber,
        driver1PreferredLanguage: driver1PreferredLanguage,
        driver2PreferredLanguage: driver2PreferredLanguage,
        driver1CardExpiryDate: driverCardExpiryDate,
        driver2CardExpiryDate: driver2CardExpiryDate,
        driver1CardNextMandatoryDownloadDate:
            driver1CardNextMandatoryDownloadDate,
        driver2CardNextMandatoryDownloadDate:
            driver2CardNextMandatoryDownloadDate,
        vin: vinData != null ? RdbiResponseParser.parseAscii(vinData) : '',
        vrn: vrn,
        memberState: memberState,
        speedKmh: speedKmh,
        odometerMeters: odometerMeters,
        currentDateTime: tachoTime,
        kConstant: kConst,
        wConstant: wConst,
        tyreCircumferenceMm: tyreCirc,
        tyreSize: tyreSize,
        speedLimitKmh: speedLimit,
        nextCalibrationDate: nextCalibrationDate,
        hwNumber: hwNumber,
        hwVersion: hwVersion,
        swNumber: swNumber,
        swVersion: swVersion,
        typeApproval: typeApproval,
        dtcCount: dtcCount,
        dtcRawHex: dtcHex,
        supplierIdentifier: supplierIdentifier,
        ecuSerialNumber: ecuSerialNumber,
        ecuManufacturingDate: ecuManufacturingDate,
        calibrationDate: calibrationDate,
        ecuInstallDate: ecuInstallDate,
        vehicleRegDate: vehicleRegDate,
        tripDistanceMeters: tripDistanceMeters,
        cardSlot1: cardSlot1,
        cardSlot2: cardSlot2,
        driver1TimeRelatedState: driver1TimeRelatedState,
        driver2TimeRelatedState: driver2TimeRelatedState,
      );

      appState.setTachographLiveData(liveData);

      appState.applyCardSlotMode(cardSlot1);

      if (vrn.isNotEmpty) {
        appState.setVehiclePlate(vrn);
      } else if (vinData != null) {
        appState.setVehiclePlate(RdbiResponseParser.parseAscii(vinData));
      }

      final gotData =
          vinData != null ||
          vrn.isNotEmpty ||
          continuousData != null ||
          cumBreakData != null ||
          workingStateData != null ||
          dailyDrvData != null ||
          weeklyDrvData != null ||
          odoData != null ||
          spdData != null;
      appState.setTachographDataStatus(
        gotData,
        reason: gotData ? null : (failureReason ?? 'Cihazdan veri alınamadı'),
      );

      DddFile? dddOutcome;
      if (appState.autoFetchDddOnReconnect) {
        trace('DDD-Download', true, 'BAŞLADI');
        dddOutcome = await appState.downloadDddForCurrentCard(
          sendAndReceive: sendAndReceive,
        );
        trace(
          'DDD-Download',
          dddOutcome != null,
          dddOutcome != null ? 'TAMAMLANDI' : 'BAŞARISIZ/VERİ YOK',
        );
      } else {
        trace('DDD-Download', true, 'ATLANDI (ayar kapalı)');
      }

      if (gotData) {
        appState.checkForRealGap(
          currentWorkingStateCode: workingStateCode,
          currentActivityDuration: currentSessionDuration,
        );
        await appState.recordActivityCheckpoint();
      }

      if (gotData) {
        appState.setLiveComplianceData(
          continuousDriving: continuousDriving,
          cumulativeBreak: cumulativeBreak,
          dailyDriving: currentDailyDriving,
          weeklyDriving: currentWeeklyDriving,
          remainingBiWeekly: remainingBiWeekly,
          currentSessionDuration: currentSessionDuration,
          currentActivityKey: currentActivityKey,
          workingStateCode: workingStateCode,
          cardExpiryDate: driverCardExpiryDate,
          cardNumber: driverCardNumber,
          dailyDrivingUnavailable:
              dailyDrvData != null && currentDailyDriving == null,
          weeklyDrivingUnavailable:
              weeklyDrvData != null && currentWeeklyDriving == null,
        );
      }

      transport.rxSub.cancel();

      _startLiveRefresh(conn, appState);
    } catch (e) {
      _log('Tachograph Handshake Error: $e');
      appState.setTachographDataStatus(false, reason: 'Bağlantı hatası: $e');
    }
  }

  void _startLiveRefresh(BleConnectionRepository conn, AppState appState) {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      var waited = Duration.zero;
      while (_refreshInFlight) {
        if (downloadTestModeActive) return;
        if (waited >= const Duration(seconds: 10)) return;
        await Future.delayed(const Duration(milliseconds: 200));
        waited += const Duration(milliseconds: 200);
      }

      if (downloadTestModeActive) return;
      _refreshInFlight = true;
      _refreshLiveFields(
        conn,
        appState,
      ).whenComplete(() => _refreshInFlight = false);
    });

    _speedRefreshTimer?.cancel();
    _speedRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_refreshInFlight || downloadTestModeActive) return;
      _refreshInFlight = true;
      _refreshSpeedOnly(
        conn,
        appState,
      ).whenComplete(() => _refreshInFlight = false);
    });
  }

  void _stopLiveRefresh() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = null;
    _speedRefreshTimer?.cancel();
    _speedRefreshTimer = null;
    _refreshInFlight = false;
    _consecutiveRefreshFailures = 0;
  }

  void _recordRefreshOutcome(bool succeeded, AppState appState) {
    if (succeeded) {
      _consecutiveRefreshFailures = 0;
      return;
    }
    _consecutiveRefreshFailures++;
    if (_consecutiveRefreshFailures < _deadConnectionThreshold) return;
    _log(
      '$_lineTag Bağlantı $_deadConnectionThreshold ardışık döngüde hiç yanıt vermedi — kopmuş sayılıyor.',
    );
    _stopLiveRefresh();
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _activeConnection = null;
    unawaited(BackgroundKeepAliveService.stop());
    _wrapKLineForDongle = false;
    appState.setBluetoothConnected(false);
  }

  Future<void> _refreshSpeedOnly(
    BleConnectionRepository conn,
    AppState appState,
  ) async {
    try {
      final transport = _buildKLineTransport(
        conn,
        shouldAbort: () => downloadTestModeActive,
      );
      final sendAndReceive = transport.sendAndReceive;

      await sendAndReceive(
        KLineFrame.startCommunication,
        waitMs: 400,
        label: 'SpeedOnly-StartComm',
      );
      await sendAndReceive(
        KLineFrame.sessionStandard,
        waitMs: 400,
        label: 'SpeedOnly-DiagSession',
      );

      final spdResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.vehicleSpeed),
        waitMs: 400,
        label: 'SpeedOnly-Speed',
      );
      final spdData = RdbiResponseParser.extractData(
        spdResp,
        TachoRecordId.vehicleSpeed,
      );
      final spdKmh = spdData != null
          ? RdbiResponseParser.parseSpeedKmh(spdData)
          : null;

      final odoResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.odometer),
        waitMs: 400,
        label: 'SpeedOnly-Odometer',
      );
      final odoData = RdbiResponseParser.extractData(
        odoResp,
        TachoRecordId.odometer,
      );
      final odoMeters = odoData != null
          ? RdbiResponseParser.parseDistanceMeters(odoData)
          : null;

      await sendAndReceive(
        KLineFrame.stopCommunication,
        waitMs: 200,
        label: 'SpeedOnly-StopComm',
      );
      transport.rxSub.cancel();

      if (spdKmh == null && odoMeters == null) {
        _recordRefreshOutcome(false, appState);
        return;
      }
      if (spdKmh != null) appState.tachographLiveData.speedKmh = spdKmh;
      if (odoMeters != null)
        appState.tachographLiveData.odometerMeters = odoMeters;
      appState.setTachographLiveData(appState.tachographLiveData);
      _recordRefreshOutcome(true, appState);
    } catch (e) {
      debugPrint('Speed-only refresh error: $e');
      _recordRefreshOutcome(false, appState);
    }
  }

  Future<void> _refreshLiveFields(
    BleConnectionRepository conn,
    AppState appState,
  ) async {
    try {
      final transport = _buildKLineTransport(
        conn,
        shouldAbort: () => downloadTestModeActive,
      );
      final sendAndReceive = transport.sendAndReceive;

      void trace(String label, bool success, Object? value) {
        final line =
            '$_lineTag [$label] SONUÇ: ${success ? 'GERÇEK -> ${_traceValue(value)}' : 'YOK (cihaz yanıt vermedi)'}';
        if (_wrapKLineForDongle) {
          DongleTraceLogService.instance.add(line);
        } else {
          TraceLogService.instance.add(line);
        }
      }

      Future<void> refreshSpeedMidCycle(String label) async {
        final r = await sendAndReceive(
          KLineFrame.readById(TachoRecordId.vehicleSpeed),
          waitMs: 400,
          label: label,
        );
        final d = RdbiResponseParser.extractData(r, TachoRecordId.vehicleSpeed);
        final kmh = d != null ? RdbiResponseParser.parseSpeedKmh(d) : null;
        trace(label, d != null, kmh != null ? '$kmh km/h' : null);

        final odoLabel = '$label-Odo';
        final odoR = await sendAndReceive(
          KLineFrame.readById(TachoRecordId.odometer),
          waitMs: 400,
          label: odoLabel,
        );
        final odoD = RdbiResponseParser.extractData(
          odoR,
          TachoRecordId.odometer,
        );
        final odoM = odoD != null
            ? RdbiResponseParser.parseDistanceMeters(odoD)
            : null;
        trace(odoLabel, odoD != null, odoM != null ? '$odoM m' : null);

        if (kmh == null && odoM == null) return;
        if (kmh != null) appState.tachographLiveData.speedKmh = kmh;
        if (odoM != null) appState.tachographLiveData.odometerMeters = odoM;
        appState.setTachographLiveData(appState.tachographLiveData);
      }

      await sendAndReceive(
        KLineFrame.startCommunication,
        waitMs: 400,
        label: 'Refresh-StartComm',
      );

      await sendAndReceive(
        KLineFrame.sessionStandard,
        waitMs: 400,
        label: 'Refresh-DiagSession-Standard',
      );

      final spdResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.vehicleSpeed),
        waitMs: 400,
        label: 'Refresh-Speed',
      );
      final spdData = RdbiResponseParser.extractData(
        spdResp,
        TachoRecordId.vehicleSpeed,
      );
      final spdKmh = spdData != null
          ? RdbiResponseParser.parseSpeedKmh(spdData)
          : null;
      trace(
        'Refresh-Speed',
        spdData != null,
        spdKmh != null ? '$spdKmh km/h' : null,
      );

      final odoResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.odometer),
        waitMs: 400,
        label: 'Refresh-Odometer',
      );
      final odoData = RdbiResponseParser.extractData(
        odoResp,
        TachoRecordId.odometer,
      );
      final odoMeters = odoData != null
          ? RdbiResponseParser.parseDistanceMeters(odoData)
          : null;
      trace(
        'Refresh-Odometer',
        odoData != null,
        odoMeters != null ? '$odoMeters m' : null,
      );

      final tripResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.tripDistance),
        waitMs: 400,
        label: 'Refresh-TripDistance',
      );
      final tripData = RdbiResponseParser.extractData(
        tripResp,
        TachoRecordId.tripDistance,
      );
      final tripMeters = tripData != null
          ? RdbiResponseParser.parseDistanceMeters(tripData)
          : null;
      trace(
        'Refresh-TripDistance',
        tripData != null,
        tripMeters != null ? '$tripMeters m' : null,
      );

      final workingStateResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1WorkingState),
        waitMs: 400,
        label: 'Refresh-WorkingState',
      );
      final workingStateData = RdbiResponseParser.extractData(
        workingStateResp,
        TachoRecordId.driver1WorkingState,
      );
      final workingStateCode =
          workingStateData != null && workingStateData.isNotEmpty
          ? workingStateData[0] & 0x07
          : null;
      final currentActivityKey = workingStateCode != null
          ? _workingStateToActivityKey(workingStateCode)
          : null;
      trace(
        'Refresh-WorkingState',
        workingStateData != null,
        currentActivityKey ?? workingStateCode,
      );

      final d1TrsResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1TimeRelatedStates),
        waitMs: 400,
        label: 'Refresh-D1TimeRelatedStates',
      );
      final d1TrsData = RdbiResponseParser.extractData(
        d1TrsResp,
        TachoRecordId.driver1TimeRelatedStates,
      );
      final driver1TimeRelatedState =
          (d1TrsData != null && d1TrsData.isNotEmpty)
          ? (d1TrsData[0] & 0x0F)
          : null;
      trace(
        'Refresh-D1TimeRelatedStates',
        d1TrsData != null,
        driver1TimeRelatedState,
      );

      final d2TrsResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2TimeRelatedStates),
        waitMs: 400,
        label: 'Refresh-D2TimeRelatedStates',
      );
      final d2TrsData = RdbiResponseParser.extractData(
        d2TrsResp,
        TachoRecordId.driver2TimeRelatedStates,
      );
      final driver2TimeRelatedState =
          (d2TrsData != null && d2TrsData.isNotEmpty)
          ? (d2TrsData[0] & 0x0F)
          : null;
      trace(
        'Refresh-D2TimeRelatedStates',
        d2TrsData != null,
        driver2TimeRelatedState,
      );

      final continuousResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1ContinuousDrivingTime),
        waitMs: 400,
        label: 'Refresh-Continuous',
      );
      final continuousData = RdbiResponseParser.extractData(
        continuousResp,
        TachoRecordId.driver1ContinuousDrivingTime,
      );
      trace(
        'Refresh-Continuous',
        continuousData != null,
        RdbiResponseParser.parseMinutesOrNull(continuousData),
      );

      final cumBreakResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1CumulativeBreakTime),
        waitMs: 400,
        label: 'Refresh-CumBreak',
      );
      final cumBreakData = RdbiResponseParser.extractData(
        cumBreakResp,
        TachoRecordId.driver1CumulativeBreakTime,
      );
      trace(
        'Refresh-CumBreak',
        cumBreakData != null,
        RdbiResponseParser.parseMinutesOrNull(cumBreakData),
      );

      final sessionDurResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1CurrentDurationOfActivity),
        waitMs: 400,
        label: 'Refresh-SessionDur',
      );
      final sessionDurData = RdbiResponseParser.extractData(
        sessionDurResp,
        TachoRecordId.driver1CurrentDurationOfActivity,
      );
      trace(
        'Refresh-SessionDur',
        sessionDurData != null,
        RdbiResponseParser.parseMinutesOrNull(sessionDurData),
      );

      final dailyDrvResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1CurrentDailyDrivingTime),
        waitMs: 400,
        label: 'Refresh-DailyDrv',
      );
      final dailyDrvData = RdbiResponseParser.extractData(
        dailyDrvResp,
        TachoRecordId.driver1CurrentDailyDrivingTime,
      );
      trace(
        'Refresh-DailyDrv',
        dailyDrvData != null,
        RdbiResponseParser.parseMinutesOrNull(dailyDrvData),
      );

      final weeklyDrvResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1CurrentWeeklyDrivingTime),
        waitMs: 400,
        label: 'Refresh-WeeklyDrv',
      );
      final weeklyDrvData = RdbiResponseParser.extractData(
        weeklyDrvResp,
        TachoRecordId.driver1CurrentWeeklyDrivingTime,
      );
      trace(
        'Refresh-WeeklyDrv',
        weeklyDrvData != null,
        RdbiResponseParser.parseMinutesOrNull(weeklyDrvData),
      );

      final rem2wResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1Remaining2WeeksDrivingTime),
        waitMs: 400,
        label: 'Refresh-Rem2W',
      );
      final rem2wData = RdbiResponseParser.extractData(
        rem2wResp,
        TachoRecordId.driver1Remaining2WeeksDrivingTime,
      );
      trace(
        'Refresh-Rem2W',
        rem2wData != null,
        RdbiResponseParser.parseMinutesOrNull(rem2wData),
      );

      await refreshSpeedMidCycle('Refresh-Speed-Mid1');

      final workingState2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2WorkingState),
        waitMs: 400,
        label: 'Refresh-WorkingState2',
      );
      final workingState2Data = RdbiResponseParser.extractData(
        workingState2Resp,
        TachoRecordId.driver2WorkingState,
      );
      final workingState2Code =
          workingState2Data != null && workingState2Data.isNotEmpty
          ? workingState2Data[0] & 0x07
          : null;
      final currentActivityKey2 = workingState2Code != null
          ? _workingStateToActivityKey(workingState2Code)
          : null;
      trace(
        'Refresh-WorkingState2',
        workingState2Data != null,
        currentActivityKey2 ?? workingState2Code,
      );

      final continuous2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2ContinuousDrivingTime),
        waitMs: 400,
        label: 'Refresh-Continuous2',
      );
      final continuous2Data = RdbiResponseParser.extractData(
        continuous2Resp,
        TachoRecordId.driver2ContinuousDrivingTime,
      );
      trace(
        'Refresh-Continuous2',
        continuous2Data != null,
        RdbiResponseParser.parseMinutesOrNull(continuous2Data),
      );

      final cumBreak2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2CumulativeBreakTime),
        waitMs: 400,
        label: 'Refresh-CumBreak2',
      );
      final cumBreak2Data = RdbiResponseParser.extractData(
        cumBreak2Resp,
        TachoRecordId.driver2CumulativeBreakTime,
      );
      trace(
        'Refresh-CumBreak2',
        cumBreak2Data != null,
        RdbiResponseParser.parseMinutesOrNull(cumBreak2Data),
      );

      final sessionDur2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2CurrentDurationOfActivity),
        waitMs: 400,
        label: 'Refresh-SessionDur2',
      );
      final sessionDur2Data = RdbiResponseParser.extractData(
        sessionDur2Resp,
        TachoRecordId.driver2CurrentDurationOfActivity,
      );
      trace(
        'Refresh-SessionDur2',
        sessionDur2Data != null,
        RdbiResponseParser.parseMinutesOrNull(sessionDur2Data),
      );

      final dailyDrv2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2CurrentDailyDrivingTime),
        waitMs: 400,
        label: 'Refresh-DailyDrv2',
      );
      final dailyDrv2Data = RdbiResponseParser.extractData(
        dailyDrv2Resp,
        TachoRecordId.driver2CurrentDailyDrivingTime,
      );
      trace(
        'Refresh-DailyDrv2',
        dailyDrv2Data != null,
        RdbiResponseParser.parseMinutesOrNull(dailyDrv2Data),
      );

      final weeklyDrv2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2CurrentWeeklyDrivingTime),
        waitMs: 400,
        label: 'Refresh-WeeklyDrv2',
      );
      final weeklyDrv2Data = RdbiResponseParser.extractData(
        weeklyDrv2Resp,
        TachoRecordId.driver2CurrentWeeklyDrivingTime,
      );
      trace(
        'Refresh-WeeklyDrv2',
        weeklyDrv2Data != null,
        RdbiResponseParser.parseMinutesOrNull(weeklyDrv2Data),
      );

      final rem2w2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2Remaining2WeeksDrivingTime),
        waitMs: 400,
        label: 'Refresh-Rem2W2',
      );
      final rem2w2Data = RdbiResponseParser.extractData(
        rem2w2Resp,
        TachoRecordId.driver2Remaining2WeeksDrivingTime,
      );
      trace(
        'Refresh-Rem2W2',
        rem2w2Data != null,
        RdbiResponseParser.parseMinutesOrNull(rem2w2Data),
      );

      final slot1Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.tachographCardSlot1),
        waitMs: 400,
        label: 'Refresh-CardSlot1',
      );
      final slot1Data = RdbiResponseParser.extractData(
        slot1Resp,
        TachoRecordId.tachographCardSlot1,
      );
      final cardSlot1 = (slot1Data != null && slot1Data.isNotEmpty)
          ? slot1Data[0]
          : null;
      trace('Refresh-CardSlot1', slot1Data != null, cardSlot1);

      final slot2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.tachographCardSlot2),
        waitMs: 400,
        label: 'Refresh-CardSlot2',
      );
      final slot2Data = RdbiResponseParser.extractData(
        slot2Resp,
        TachoRecordId.tachographCardSlot2,
      );
      final cardSlot2 = (slot2Data != null && slot2Data.isNotEmpty)
          ? slot2Data[0]
          : null;
      trace('Refresh-CardSlot2', slot2Data != null, cardSlot2);

      await refreshSpeedMidCycle('Refresh-Speed-Mid2');

      final addlInfoResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1AdditionalInformation),
        waitMs: 400,
        label: 'Refresh-AdditionalInfo',
      );
      final addlInfoData = RdbiResponseParser.extractData(
        addlInfoResp,
        TachoRecordId.driver1AdditionalInformation,
      );
      final additionalInfo = RdbiResponseParser.parseAdditionalInformation(
        addlInfoData ?? Uint8List(0),
      );
      trace(
        'Refresh-AdditionalInfo',
        addlInfoData != null,
        additionalInfo != null
            ? '10h:${additionalInfo.remaining10hDrivingTimes} kısaltılmış:${additionalInfo.remainingReducedDailyRestPeriods}'
            : null,
      );

      final nextBreakResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1DurationOfNextBreakRest),
        waitMs: 400,
        label: 'Refresh-NextBreakDur',
      );
      final nextBreakData = RdbiResponseParser.extractData(
        nextBreakResp,
        TachoRecordId.driver1DurationOfNextBreakRest,
      );
      trace(
        'Refresh-NextBreakDur',
        nextBreakData != null,
        RdbiResponseParser.parseMinutesOrNull(nextBreakData),
      );

      final currentBreakRemResp = await sendAndReceive(
        KLineFrame.readById(
          TachoRecordId.driver1RemainingTimeOfCurrentBreakRest,
        ),
        waitMs: 400,
        label: 'Refresh-CurrentBreakRem',
      );
      final currentBreakRemData = RdbiResponseParser.extractData(
        currentBreakRemResp,
        TachoRecordId.driver1RemainingTimeOfCurrentBreakRest,
      );
      trace(
        'Refresh-CurrentBreakRem',
        currentBreakRemData != null,
        RdbiResponseParser.parseMinutesOrNull(currentBreakRemData),
      );

      final timeUntilBreakResp = await sendAndReceive(
        KLineFrame.readById(
          TachoRecordId.driver1RemainingTimeUntilNextBreakOrRest,
        ),
        waitMs: 400,
        label: 'Refresh-TimeUntilBreak',
      );
      final timeUntilBreakData = RdbiResponseParser.extractData(
        timeUntilBreakResp,
        TachoRecordId.driver1RemainingTimeUntilNextBreakOrRest,
      );
      trace(
        'Refresh-TimeUntilBreak',
        timeUntilBreakData != null,
        RdbiResponseParser.parseMinutesOrNull(timeUntilBreakData),
      );

      final lastDailyRestResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1EndOfLastDailyRestPeriod),
        waitMs: 400,
        label: 'Refresh-LastDailyRest',
      );
      final lastDailyRestData = RdbiResponseParser.extractData(
        lastDailyRestResp,
        TachoRecordId.driver1EndOfLastDailyRestPeriod,
      );
      trace(
        'Refresh-LastDailyRest',
        lastDailyRestData != null,
        lastDailyRestData != null
            ? RdbiResponseParser.parseDateTime(lastDailyRestData)
            : null,
      );

      final lastWeeklyRestResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1EndOfLastWeeklyRestPeriod),
        waitMs: 400,
        label: 'Refresh-LastWeeklyRest',
      );
      final lastWeeklyRestData = RdbiResponseParser.extractData(
        lastWeeklyRestResp,
        TachoRecordId.driver1EndOfLastWeeklyRestPeriod,
      );
      trace(
        'Refresh-LastWeeklyRest',
        lastWeeklyRestData != null,
        lastWeeklyRestData != null
            ? RdbiResponseParser.parseDateTime(lastWeeklyRestData)
            : null,
      );

      final compLastWeekResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1OpenCompensationInTheLastWeek),
        waitMs: 400,
        label: 'Refresh-CompLastWeek',
      );
      final compLastWeekData = RdbiResponseParser.extractData(
        compLastWeekResp,
        TachoRecordId.driver1OpenCompensationInTheLastWeek,
      );
      trace(
        'Refresh-CompLastWeek',
        compLastWeekData != null,
        RdbiResponseParser.parseMinutesOrNull(compLastWeekData),
      );

      final compWeekBeforeLastResp = await sendAndReceive(
        KLineFrame.readById(
          TachoRecordId.driver1OpenCompensationInWeekBeforeLast,
        ),
        waitMs: 400,
        label: 'Refresh-CompWeekBeforeLast',
      );
      final compWeekBeforeLastData = RdbiResponseParser.extractData(
        compWeekBeforeLastResp,
        TachoRecordId.driver1OpenCompensationInWeekBeforeLast,
      );
      trace(
        'Refresh-CompWeekBeforeLast',
        compWeekBeforeLastData != null,
        RdbiResponseParser.parseMinutesOrNull(compWeekBeforeLastData),
      );

      final comp2ndWeekBeforeLastResp = await sendAndReceive(
        KLineFrame.readById(
          TachoRecordId.driver1OpenCompensationIn2ndWeekBeforeLast,
        ),
        waitMs: 400,
        label: 'Refresh-Comp2ndWeekBeforeLast',
      );
      final comp2ndWeekBeforeLastData = RdbiResponseParser.extractData(
        comp2ndWeekBeforeLastResp,
        TachoRecordId.driver1OpenCompensationIn2ndWeekBeforeLast,
      );
      trace(
        'Refresh-Comp2ndWeekBeforeLast',
        comp2ndWeekBeforeLastData != null,
        RdbiResponseParser.parseMinutesOrNull(comp2ndWeekBeforeLastData),
      );

      final minDailyRestResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1MinimumDailyRest),
        waitMs: 400,
        label: 'Refresh-MinDailyRest',
      );
      final minDailyRestData = RdbiResponseParser.extractData(
        minDailyRestResp,
        TachoRecordId.driver1MinimumDailyRest,
      );
      trace(
        'Refresh-MinDailyRest',
        minDailyRestData != null,
        RdbiResponseParser.parseMinutesOrNull(minDailyRestData),
      );

      final minWeeklyRestResp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver1MinimumWeeklyRest),
        waitMs: 400,
        label: 'Refresh-MinWeeklyRest',
      );
      final minWeeklyRestData = RdbiResponseParser.extractData(
        minWeeklyRestResp,
        TachoRecordId.driver1MinimumWeeklyRest,
      );
      trace(
        'Refresh-MinWeeklyRest',
        minWeeklyRestData != null,
        RdbiResponseParser.parseMinutesOrNull(minWeeklyRestData),
      );

      await refreshSpeedMidCycle('Refresh-Speed-Mid3');

      final addlInfo2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2AdditionalInformation),
        waitMs: 400,
        label: 'Refresh-AdditionalInfo2',
      );
      final addlInfo2Data = RdbiResponseParser.extractData(
        addlInfo2Resp,
        TachoRecordId.driver2AdditionalInformation,
      );
      final additionalInfo2 = RdbiResponseParser.parseAdditionalInformation(
        addlInfo2Data ?? Uint8List(0),
      );
      trace(
        'Refresh-AdditionalInfo2',
        addlInfo2Data != null,
        additionalInfo2 != null
            ? '10h:${additionalInfo2.remaining10hDrivingTimes} kısaltılmış:${additionalInfo2.remainingReducedDailyRestPeriods}'
            : null,
      );

      final nextBreak2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2DurationOfNextBreakRest),
        waitMs: 400,
        label: 'Refresh-NextBreakDur2',
      );
      final nextBreak2Data = RdbiResponseParser.extractData(
        nextBreak2Resp,
        TachoRecordId.driver2DurationOfNextBreakRest,
      );
      trace(
        'Refresh-NextBreakDur2',
        nextBreak2Data != null,
        RdbiResponseParser.parseMinutesOrNull(nextBreak2Data),
      );

      final currentBreakRem2Resp = await sendAndReceive(
        KLineFrame.readById(
          TachoRecordId.driver2RemainingTimeOfCurrentBreakRest,
        ),
        waitMs: 400,
        label: 'Refresh-CurrentBreakRem2',
      );
      final currentBreakRem2Data = RdbiResponseParser.extractData(
        currentBreakRem2Resp,
        TachoRecordId.driver2RemainingTimeOfCurrentBreakRest,
      );
      trace(
        'Refresh-CurrentBreakRem2',
        currentBreakRem2Data != null,
        RdbiResponseParser.parseMinutesOrNull(currentBreakRem2Data),
      );

      final timeUntilBreak2Resp = await sendAndReceive(
        KLineFrame.readById(
          TachoRecordId.driver2RemainingTimeUntilNextBreakOrRest,
        ),
        waitMs: 400,
        label: 'Refresh-TimeUntilBreak2',
      );
      final timeUntilBreak2Data = RdbiResponseParser.extractData(
        timeUntilBreak2Resp,
        TachoRecordId.driver2RemainingTimeUntilNextBreakOrRest,
      );
      trace(
        'Refresh-TimeUntilBreak2',
        timeUntilBreak2Data != null,
        RdbiResponseParser.parseMinutesOrNull(timeUntilBreak2Data),
      );

      final lastDailyRest2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2EndOfLastDailyRestPeriod),
        waitMs: 400,
        label: 'Refresh-LastDailyRest2',
      );
      final lastDailyRest2Data = RdbiResponseParser.extractData(
        lastDailyRest2Resp,
        TachoRecordId.driver2EndOfLastDailyRestPeriod,
      );
      trace(
        'Refresh-LastDailyRest2',
        lastDailyRest2Data != null,
        lastDailyRest2Data != null
            ? RdbiResponseParser.parseDateTime(lastDailyRest2Data)
            : null,
      );

      final lastWeeklyRest2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2EndOfLastWeeklyRestPeriod),
        waitMs: 400,
        label: 'Refresh-LastWeeklyRest2',
      );
      final lastWeeklyRest2Data = RdbiResponseParser.extractData(
        lastWeeklyRest2Resp,
        TachoRecordId.driver2EndOfLastWeeklyRestPeriod,
      );
      trace(
        'Refresh-LastWeeklyRest2',
        lastWeeklyRest2Data != null,
        lastWeeklyRest2Data != null
            ? RdbiResponseParser.parseDateTime(lastWeeklyRest2Data)
            : null,
      );

      final compLastWeek2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2OpenCompensationInTheLastWeek),
        waitMs: 400,
        label: 'Refresh-CompLastWeek2',
      );
      final compLastWeek2Data = RdbiResponseParser.extractData(
        compLastWeek2Resp,
        TachoRecordId.driver2OpenCompensationInTheLastWeek,
      );
      trace(
        'Refresh-CompLastWeek2',
        compLastWeek2Data != null,
        RdbiResponseParser.parseMinutesOrNull(compLastWeek2Data),
      );

      final compWeekBeforeLast2Resp = await sendAndReceive(
        KLineFrame.readById(
          TachoRecordId.driver2OpenCompensationInWeekBeforeLast,
        ),
        waitMs: 400,
        label: 'Refresh-CompWeekBeforeLast2',
      );
      final compWeekBeforeLast2Data = RdbiResponseParser.extractData(
        compWeekBeforeLast2Resp,
        TachoRecordId.driver2OpenCompensationInWeekBeforeLast,
      );
      trace(
        'Refresh-CompWeekBeforeLast2',
        compWeekBeforeLast2Data != null,
        RdbiResponseParser.parseMinutesOrNull(compWeekBeforeLast2Data),
      );

      final comp2ndWeekBeforeLast2Resp = await sendAndReceive(
        KLineFrame.readById(
          TachoRecordId.driver2OpenCompensationIn2ndWeekBeforeLast,
        ),
        waitMs: 400,
        label: 'Refresh-Comp2ndWeekBeforeLast2',
      );
      final comp2ndWeekBeforeLast2Data = RdbiResponseParser.extractData(
        comp2ndWeekBeforeLast2Resp,
        TachoRecordId.driver2OpenCompensationIn2ndWeekBeforeLast,
      );
      trace(
        'Refresh-Comp2ndWeekBeforeLast2',
        comp2ndWeekBeforeLast2Data != null,
        RdbiResponseParser.parseMinutesOrNull(comp2ndWeekBeforeLast2Data),
      );

      final minDailyRest2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2MinimumDailyRest),
        waitMs: 400,
        label: 'Refresh-MinDailyRest2',
      );
      final minDailyRest2Data = RdbiResponseParser.extractData(
        minDailyRest2Resp,
        TachoRecordId.driver2MinimumDailyRest,
      );
      trace(
        'Refresh-MinDailyRest2',
        minDailyRest2Data != null,
        RdbiResponseParser.parseMinutesOrNull(minDailyRest2Data),
      );

      final minWeeklyRest2Resp = await sendAndReceive(
        KLineFrame.readById(TachoRecordId.driver2MinimumWeeklyRest),
        waitMs: 400,
        label: 'Refresh-MinWeeklyRest2',
      );
      final minWeeklyRest2Data = RdbiResponseParser.extractData(
        minWeeklyRest2Resp,
        TachoRecordId.driver2MinimumWeeklyRest,
      );
      trace(
        'Refresh-MinWeeklyRest2',
        minWeeklyRest2Data != null,
        RdbiResponseParser.parseMinutesOrNull(minWeeklyRest2Data),
      );

      await sendAndReceive(
        KLineFrame.stopCommunication,
        waitMs: 200,
        label: 'Refresh-StopComm',
      );
      transport.rxSub.cancel();

      if (spdData == null && odoData == null) {
        _recordRefreshOutcome(false, appState);
        return;
      }
      _recordRefreshOutcome(true, appState);

      if (!appState.hasTachographData) {
        appState.setTachographDataStatus(true);
      }

      await appState.recordActivityCheckpoint();

      if (continuousData != null || cumBreakData != null) {
        appState.setLiveComplianceData(
          continuousDriving: RdbiResponseParser.parseMinutesOrNull(
            continuousData,
          ),
          cumulativeBreak: RdbiResponseParser.parseMinutesOrNull(cumBreakData),
          dailyDriving: RdbiResponseParser.parseMinutesOrNull(dailyDrvData),
          weeklyDriving: RdbiResponseParser.parseMinutesOrNull(weeklyDrvData),
          remainingBiWeekly: RdbiResponseParser.parseMinutesOrNull(rem2wData),
          currentSessionDuration: RdbiResponseParser.parseMinutesOrNull(
            sessionDurData,
          ),
          currentActivityKey: currentActivityKey,
          workingStateCode: workingStateCode,
          remaining10hDrivingTimes: additionalInfo?.remaining10hDrivingTimes,
          remainingReducedDailyRestPeriods:
              additionalInfo?.remainingReducedDailyRestPeriods,
          nextBreakRestDuration: RdbiResponseParser.parseMinutesOrNull(
            nextBreakData,
          ),
          currentBreakRestRemaining: RdbiResponseParser.parseMinutesOrNull(
            currentBreakRemData,
          ),
          timeUntilNextBreakOrRest: RdbiResponseParser.parseMinutesOrNull(
            timeUntilBreakData,
          ),
          lastDailyRestEnd: lastDailyRestData != null
              ? RdbiResponseParser.parseDateTime(lastDailyRestData)
              : null,
          lastWeeklyRestEnd: lastWeeklyRestData != null
              ? RdbiResponseParser.parseDateTime(lastWeeklyRestData)
              : null,
          compensationLastWeek: RdbiResponseParser.parseMinutesOrNull(
            compLastWeekData,
          ),
          compensationWeekBeforeLast: RdbiResponseParser.parseMinutesOrNull(
            compWeekBeforeLastData,
          ),
          compensation2ndWeekBeforeLast: RdbiResponseParser.parseMinutesOrNull(
            comp2ndWeekBeforeLastData,
          ),
          minimumDailyRest: RdbiResponseParser.parseMinutesOrNull(
            minDailyRestData,
          ),
          minimumWeeklyRest: RdbiResponseParser.parseMinutesOrNull(
            minWeeklyRestData,
          ),
          dailyDrivingUnavailable:
              dailyDrvData != null &&
              RdbiResponseParser.parseMinutesOrNull(dailyDrvData) == null,
          weeklyDrivingUnavailable:
              weeklyDrvData != null &&
              RdbiResponseParser.parseMinutesOrNull(weeklyDrvData) == null,
          minDailyRestUnavailable:
              minDailyRestData != null &&
              RdbiResponseParser.parseMinutesOrNull(minDailyRestData) == null,
          minWeeklyRestUnavailable:
              minWeeklyRestData != null &&
              RdbiResponseParser.parseMinutesOrNull(minWeeklyRestData) == null,
          currentBreakRestRemainingUnavailable:
              currentBreakRemData != null &&
              RdbiResponseParser.parseMinutesOrNull(currentBreakRemData) ==
                  null,
        );
      }

      if (continuous2Data != null || cumBreak2Data != null) {
        appState.setDriver2ComplianceData(
          continuousDriving: RdbiResponseParser.parseMinutesOrNull(
            continuous2Data,
          ),
          cumulativeBreak: RdbiResponseParser.parseMinutesOrNull(cumBreak2Data),
          dailyDriving: RdbiResponseParser.parseMinutesOrNull(dailyDrv2Data),
          weeklyDriving: RdbiResponseParser.parseMinutesOrNull(weeklyDrv2Data),
          remainingBiWeekly: RdbiResponseParser.parseMinutesOrNull(rem2w2Data),
          currentSessionDuration: RdbiResponseParser.parseMinutesOrNull(
            sessionDur2Data,
          ),
          currentActivityKey: currentActivityKey2,
          workingStateCode: workingState2Code,
          remaining10hDrivingTimes: additionalInfo2?.remaining10hDrivingTimes,
          remainingReducedDailyRestPeriods:
              additionalInfo2?.remainingReducedDailyRestPeriods,
          nextBreakRestDuration: RdbiResponseParser.parseMinutesOrNull(
            nextBreak2Data,
          ),
          currentBreakRestRemaining: RdbiResponseParser.parseMinutesOrNull(
            currentBreakRem2Data,
          ),
          timeUntilNextBreakOrRest: RdbiResponseParser.parseMinutesOrNull(
            timeUntilBreak2Data,
          ),
          lastDailyRestEnd: lastDailyRest2Data != null
              ? RdbiResponseParser.parseDateTime(lastDailyRest2Data)
              : null,
          lastWeeklyRestEnd: lastWeeklyRest2Data != null
              ? RdbiResponseParser.parseDateTime(lastWeeklyRest2Data)
              : null,
          compensationLastWeek: RdbiResponseParser.parseMinutesOrNull(
            compLastWeek2Data,
          ),
          compensationWeekBeforeLast: RdbiResponseParser.parseMinutesOrNull(
            compWeekBeforeLast2Data,
          ),
          compensation2ndWeekBeforeLast: RdbiResponseParser.parseMinutesOrNull(
            comp2ndWeekBeforeLast2Data,
          ),
          minimumDailyRest: RdbiResponseParser.parseMinutesOrNull(
            minDailyRest2Data,
          ),
          minimumWeeklyRest: RdbiResponseParser.parseMinutesOrNull(
            minWeeklyRest2Data,
          ),
          dailyDrivingUnavailable:
              dailyDrv2Data != null &&
              RdbiResponseParser.parseMinutesOrNull(dailyDrv2Data) == null,
          weeklyDrivingUnavailable:
              weeklyDrv2Data != null &&
              RdbiResponseParser.parseMinutesOrNull(weeklyDrv2Data) == null,
          minDailyRestUnavailable:
              minDailyRest2Data != null &&
              RdbiResponseParser.parseMinutesOrNull(minDailyRest2Data) == null,
          minWeeklyRestUnavailable:
              minWeeklyRest2Data != null &&
              RdbiResponseParser.parseMinutesOrNull(minWeeklyRest2Data) == null,
          currentBreakRestRemainingUnavailable:
              currentBreakRem2Data != null &&
              RdbiResponseParser.parseMinutesOrNull(currentBreakRem2Data) ==
                  null,
        );
      }

      final current = appState.tachographLiveData;
      appState.setTachographLiveData(
        TachographLiveData(
          driver1Name: current.driver1Name,
          driver2Name: current.driver2Name,
          driver1IssuingState: current.driver1IssuingState,
          driver1CardNumber: current.driver1CardNumber,
          driver2IssuingState: current.driver2IssuingState,
          driver2CardNumber: current.driver2CardNumber,
          driver1PreferredLanguage: current.driver1PreferredLanguage,
          driver2PreferredLanguage: current.driver2PreferredLanguage,
          driver1CardExpiryDate: current.driver1CardExpiryDate,
          driver2CardExpiryDate: current.driver2CardExpiryDate,
          driver1CardNextMandatoryDownloadDate:
              current.driver1CardNextMandatoryDownloadDate,
          driver2CardNextMandatoryDownloadDate:
              current.driver2CardNextMandatoryDownloadDate,
          vin: current.vin,
          vrn: current.vrn,
          memberState: current.memberState,
          speedKmh: spdKmh ?? current.speedKmh,
          odometerMeters: odoData != null
              ? RdbiResponseParser.parseDistanceMeters(odoData)
              : current.odometerMeters,
          currentDateTime: current.currentDateTime,
          kConstant: current.kConstant,
          wConstant: current.wConstant,
          tyreCircumferenceMm: current.tyreCircumferenceMm,
          tyreSize: current.tyreSize,
          speedLimitKmh: current.speedLimitKmh,
          nextCalibrationDate: current.nextCalibrationDate,
          hwNumber: current.hwNumber,
          hwVersion: current.hwVersion,
          swNumber: current.swNumber,
          swVersion: current.swVersion,
          typeApproval: current.typeApproval,
          dtcCount: current.dtcCount,
          dtcRawHex: current.dtcRawHex,
          supplierIdentifier: current.supplierIdentifier,
          ecuSerialNumber: current.ecuSerialNumber,
          ecuManufacturingDate: current.ecuManufacturingDate,
          calibrationDate: current.calibrationDate,
          ecuInstallDate: current.ecuInstallDate,
          vehicleRegDate: current.vehicleRegDate,
          tripDistanceMeters: tripMeters ?? current.tripDistanceMeters,
          cardSlot1: cardSlot1 ?? current.cardSlot1,
          cardSlot2: cardSlot2 ?? current.cardSlot2,
          driver1TimeRelatedState:
              driver1TimeRelatedState ?? current.driver1TimeRelatedState,
          driver2TimeRelatedState:
              driver2TimeRelatedState ?? current.driver2TimeRelatedState,
        ),
      );

      appState.applyCardSlotMode(cardSlot1);
    } catch (e) {
      _log('Live refresh failed: $e');
      _recordRefreshOutcome(false, appState);
    }
  }

  Future<void> disconnect() async {
    _stopLiveRefresh();
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    unawaited(BackgroundKeepAliveService.stop());
    _wrapKLineForDongle = false;

    if (_activeConnection != null) {
      try {
        await _activeConnection!.dispose();
      } catch (e) {
        debugPrint('Disconnect error: $e');
      }
      _activeConnection = null;
    }
  }
}
