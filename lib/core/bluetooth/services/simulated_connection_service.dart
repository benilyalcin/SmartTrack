import 'dart:async';

import '../models/ble_gatt_service.dart';
import '../models/log_entry.dart';
import '../repositories/ble_connection_repository.dart';

class SimulatedConnectionService implements BleConnectionRepository {
  final _stateCtrl = StreamController<BleConnectionState>.broadcast();
  final _logCtrl = StreamController<LogEntry>.broadcast();
  final _sppDataCtrl = StreamController<List<int>>.broadcast();

  final Map<int, List<int>> _writtenValues = {};

  bool _dtcsCleared = false;

  @override
  Stream<BleConnectionState> get connectionState => _stateCtrl.stream;

  @override
  Stream<LogEntry> get logs => _logCtrl.stream;

  @override
  Future<void> connect(String deviceId) async {
    _dtcsCleared = false;
    _emit(BleConnectionState.connecting);
    _log('Simülasyon bağlantısı başlatılıyor...', LogLevel.info);
    await Future.delayed(const Duration(milliseconds: 400));
    _log('Cihaz keşfedildi: $deviceId', LogLevel.info);
    await Future.delayed(const Duration(milliseconds: 500));
    _log('GATT kanalı açıldı', LogLevel.info);
    await Future.delayed(const Duration(milliseconds: 300));
    _emit(BleConnectionState.connected);
    _log('Bağlantı başarılı ✓  [SİMÜLASYON MODU]', LogLevel.success);
  }

  @override
  Future<void> disconnect() async {
    _emit(BleConnectionState.disconnecting);
    await Future.delayed(const Duration(milliseconds: 200));
    _emit(BleConnectionState.disconnected);
    _log('Simülasyon bağlantısı kesildi', LogLevel.info);
  }

  @override
  Future<List<BleGattService>> discoverServices() async {
    await Future.delayed(const Duration(milliseconds: 150));
    _log('Servis keşfi tamamlandı (simüle)', LogLevel.info);
    return const [
      BleGattService(
        uuid: 'SIM-SERVICE-0001',
        characteristics: [
          BleGattCharacteristic(
            uuid: 'SPP_DATA',
            canRead: true,
            canWrite: true,
            canNotify: true,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<int>> readCharacteristic(String charUuid) async => [];

  @override
  Future<void> writeCharacteristic(String charUuid, List<int> data) async {
    final hex = data
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .toUpperCase();
    _log(hex, LogLevel.outgoing);
    await Future.delayed(const Duration(milliseconds: 60));

    if (charUuid == 'SPP_DATA') {
      final response = _buildKLineResponse(data);
      if (response != null) {
        final respHex = response
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ')
            .toUpperCase();
        _log(respHex, LogLevel.incoming);
        _sppDataCtrl.add(response);
      }
    }
  }

  @override
  Future<void> setNotify(String charUuid, {required bool enable}) async {}

  @override
  Stream<List<int>> notifyStream(String charUuid) {
    if (charUuid == 'SPP_DATA') return _sppDataCtrl.stream;
    return const Stream.empty();
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _stateCtrl.close();
    await _logCtrl.close();
    await _sppDataCtrl.close();
  }

  List<int>? _buildKLineResponse(List<int> req) {
    if (req.isEmpty) return null;
    final fmt = req[0];

    if (fmt == 0x00) return null;

    if (fmt == 0x81) return _fastInitResp(0x81);

    if (fmt == 0x80 && req.length >= 5) {
      final sid = req[4];
      final data = req.length > 6 ? req.sublist(5, req.length - 1) : <int>[];
      return _handleSid(sid, data);
    }

    return null;
  }

  List<int>? _handleSid(int sid, List<int> data) {
    switch (sid) {
      case 0x82:
        return _stdResp(0xC2, []);

      case 0x10:
        return _stdResp(0x50, data.isNotEmpty ? [data[0]] : []);

      case 0x3E:
        if (data.isNotEmpty && data[0] == 0x02) return null;
        return _stdResp(0x7E, [data.isNotEmpty ? data[0] : 0x01]);

      case 0x27:
        if (data.isEmpty) return null;
        if (data[0] == 0x7D) {
          return _stdResp(0x67, [0x7D, 0xA3, 0xF7, 0x2C, 0x51]);
        }
        if (data[0] == 0x7E) {
          return _stdResp(0x67, [0x7E]);
        }
        return null;

      case 0x22:
        if (data.length < 2) return null;
        final rid = (data[0] << 8) | data[1];
        final payload = _writtenValues[rid] ?? _getMockRdbiData(rid);
        if (payload == null) {
          return _stdResp(0x7F, [0x22, 0x31]);
        }
        return _stdResp(0x62, [data[0], data[1], ...payload]);

      case 0x2E:
        if (data.length < 2) return null;
        final wRid = (data[0] << 8) | data[1];
        _writtenValues[wRid] = data.sublist(2);
        return _stdResp(0x6E, [data[0], data[1]]);

      case 0x31:
        if (data.length < 3) return null;
        final sub = data[0];
        final ridH = data[1];
        final ridL = data[2];
        if (sub == 0x03) {
          return _stdResp(0x71, [sub, ridH, ridL, 0x01]);
        }
        return _stdResp(0x71, [sub, ridH, ridL]);

      case 0x19:
        if (data.isEmpty) return null;
        return _handleReadDtc(data[0]);

      case 0x14:
        _dtcsCleared = true;
        return _stdResp(0x54, []);

      case 0x2F:
        if (data.length < 2) return null;
        return _stdResp(0x6F, [data[0], data[1]]);

      default:
        return null;
    }
  }

  List<int>? _handleReadDtc(int sub) {
    if (sub == 0x01) {
      return _stdResp(0x59, [0x00, _dtcsCleared ? 0x00 : 0x02]);
    }
    if (sub == 0x02) {
      if (_dtcsCleared) return _stdResp(0x59, []);
      return _stdResp(0x59, [0x01, 0x00, 0x01, 0x08, 0x02, 0x00, 0x01, 0x01]);
    }
    return null;
  }

  List<int>? _getMockRdbiData(int rid) {
    switch (rid) {
      case 0xF190:
        return _ascii('WVWZZZ1JZ3W000001', 17);
      case 0xF97E:
        return _ascii('34ABC1234', 14);
      case 0xF97D:
        return _ascii('TUR', 3);
      case 0xF97F:
        return [0x00, 0x00, 0x00, 3, 4 * (10 - 1) + 2, 20, 0x7D, 0x7D];
      case 0xF912:
        return _u32(125430);
      case 0xF918:
        return _u16(6000);
      case 0xF91C:
        return _u16(2885 * 8);
      case 0xF91D:
        return _u16(6000);
      case 0xF921:
        return _ascii('295/80R22.5H', 15);
      case 0xF922:
        return [6, 4 * (15 - 1) + 2, 27];
      case 0xF92C:
        return [90, 0x00];
      case 0xF90B:
        final now = DateTime.now();
        return [
          0x00,
          now.minute,
          now.hour,
          now.month,
          4 * (now.day - 1) + 2,
          now.year % 100,
          0x80,
          0x7D,
        ];
      case 0xF902:
        return [0x00, 0x00];
      case 0xF18C:
        return _ascii('SN-2026-000123', 14);
      case 0xF192:
        return _ascii('STC8250-02', 11);
      case 0xF193:
        return _ascii('01.05', 5);
      case 0xF195:
        return _ascii('02.13', 5);
      case 0xF990:
        return [90];
      case 0xF991:
        return [30];
      case 0xF994:
        return [14];
      case 0xF995:
        return [14];
      case 0xF996:
        return [30];

      case 0xF18A:
        return _ascii('STONERIDGE-TR', 15);
      case 0xF194:
        return _ascii('SW-STC-0213', 11);
      case 0xF196:
        return _ascii('E1*2016/1230*00001', 20);

      case 0xF19D:
        return [0x20, 0x03, 0x15];
      case 0xF90C:
        return [0x01];
      case 0xF90D:
        return [0x7D];
      case 0xF90E:
        return [0x8C];
      case 0xF90F:
        return [0x00];
      case 0xF913:
        return _u32(1520);
      case 0xF91A:
        return [60];
      case 0xF91E:
        return _u16(4000);
      case 0xF920:
        return [0x00];

      case 0xFD00:
        return _u16(8000);
      case 0xFD01:
        return [0x01];
      case 0xFD02:
        return [200, 180, 150, 200, 200];
      case 0xFD03:
        return _u16(1);
      case 0xFD04:
        return [0x00];
      case 0xFD05:
        return [0xFF, 0x32 | 0x80];
      case 0xFD06:
        return [5];
      case 0xFD07:
        return [0x01, 0x00, 0x01, 0x00];
      case 0xFD08:
        return [1, 5];
      case 0xFD09:
        return [2, 5];
      case 0xFD0A:
        return [5, 0x01];
      case 0xFD0B:
        return [0x01];
      case 0xFD0C:
        return [0x02];
      case 0xFD0D:
        return [2];
      case 0xFD0E:
        return [0x01];
      case 0xFD0F:
        return [0x01];
      case 0xFD10:
        return [0x01];
      case 0xFD11:
        return [0x01];
      case 0xFD12:
        return [0x01];
      case 0xFD13:
        return [1];
      case 0xFD14:
        return [5];
      case 0xFD15:
        return [2];
      case 0xFD16:
        return [5];
      case 0xFD17:
        return [2];
      case 0xFD18:
        return [0x00];
      case 0xFD19:
        return _u16(1);

      case 0xFD1A:
        return [5];
      case 0xFD1B:
        return [2];
      case 0xFD1C:
        return [0x01];
      case 0xFD1D:
        return [0x01, 0x00];
      case 0xFD1E:
        return [0x01];
      case 0xFD1F:
        return [0x01];
      case 0xFD22:
        return [200, 180, 150, 200, 200];
      case 0xFD23:
        return [1];
      case 0xFD30:
        return [1, 2];
      case 0xFD31:
        return [0x01];
      case 0xFD32:
        return [1, 5];
      case 0xFD33:
        return [2];
      case 0xFD34:
        return [0x01];
      case 0xFD35:
        return [2, 5];
      case 0xFD36:
        return [2];
      case 0xFD3A:
        return [0x01];
      case 0xFD3B:
        return [0x01];
      case 0xFD3C:
        return [1];
      case 0xFD3D:
        return [0x01, 0x01];
      case 0xFD3E:
        return [0x00];
      case 0xFD41:
        return [0x01];
      case 0xFD50:
        return [0x01];
      case 0xFD51:
        return [0x01];
      case 0xFD53:
        return [0x00];

      default:
        return null;
    }
  }

  static List<int> _stdResp(int sid, List<int> payload) {
    final len = 1 + payload.length;
    final frame = [0x80, 0xF0, 0xEE, len, sid, ...payload];
    final cs = frame.fold(0, (s, b) => s + b) & 0xFF;
    return [...frame, cs];
  }

  static List<int> _fastInitResp(int sid) {
    final frame = [0xC1, 0xF0, 0xEE, sid];
    final cs = frame.fold(0, (s, b) => s + b) & 0xFF;
    return [...frame, cs];
  }

  static List<int> _ascii(String s, int len) {
    final bytes = List<int>.filled(len, 0x20);
    for (int i = 0; i < s.length && i < len; i++) {
      bytes[i] = s.codeUnitAt(i);
    }
    return bytes;
  }

  static List<int> _u16(int v) => [(v >> 8) & 0xFF, v & 0xFF];

  static List<int> _u32(int v) => [
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ];

  void _emit(BleConnectionState s) => _stateCtrl.add(s);
  void _log(String msg, LogLevel lvl) =>
      _logCtrl.add(LogEntry(message: msg, level: lvl));
}
