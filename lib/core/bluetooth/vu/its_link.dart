import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/kline_protocol.dart';
import '../services/vu_app_connection_service.dart';
import 'its_channel.dart';
import 'vu_app_link.dart';

enum ItsChannelStatus { closed, opening, open, refused }

/// One ITS channel on a live connection: [ItsChannel] does the bookkeeping,
/// this does the input and output on its FIFO and credits characteristics.
///
/// Like the app service, one request at a time: a second waits for the first
/// to be answered. Requests start at the service identifier; the KWP2000
/// header and checksum are added here, and answers come back in the long
/// form the parsers in kline_protocol.dart read.
class ItsLink {
  ItsLink._(this.conn, this.label, this.fifoUuid, this.creditsUuid)
    : channel = ItsChannel(label) {
    _fifoSub = conn.itsPackets(fifoUuid).listen(_onFifo);
    _creditsSub = conn.itsPackets(creditsUuid).listen(_onCredits);
  }

  /// Annex 7 data download.
  factory ItsLink.download(VuAppConnectionService conn) => ItsLink._(
    conn,
    'ITS-DDW',
    VuItsUuids.downloadFifo,
    VuItsUuids.downloadCredits,
  );

  /// Annex 8 diagnostics, which Remote HMI rides on.
  factory ItsLink.diagnostics(VuAppConnectionService conn) => ItsLink._(
    conn,
    'ITS-DIAG',
    VuItsUuids.diagnosticsFifo,
    VuItsUuids.diagnosticsCredits,
  );

  final VuAppConnectionService conn;
  final String label;
  final String fifoUuid;
  final String creditsUuid;
  final ItsChannel channel;

  final ValueNotifier<ItsChannelStatus> status = ValueNotifier(
    ItsChannelStatus.closed,
  );

  /// The answer to a channel request comes back as a credits indication.
  static const Duration _openTimeout = Duration(seconds: 5);
  static const int _maxPendingRetries = 15;

  late final StreamSubscription _fifoSub;
  late final StreamSubscription _creditsSub;

  Completer<void>? _opening;
  Completer<List<int>?>? _pending;

  /// Writes go out one after the other: credits top-ups and FIFO packets
  /// share the one GATT queue, and a message's packets must stay in order.
  Future<void> _writeChain = Future.value();
  Future<void> _requestChain = Future.value();

  bool get isAvailable => conn.hasIts(fifoUuid) && conn.hasIts(creditsUuid);
  bool get isOpen => channel.isOpen;

  /// Asks the unit for the channel by granting it credits - there is no
  /// other handshake. True once its own grant comes back; false on 0xFF or
  /// silence.
  Future<bool> open() async {
    if (channel.isOpen) return true;
    if (!isAvailable) {
      _log('ITS servisi yok, kanal açılamaz');
      return false;
    }

    status.value = ItsChannelStatus.opening;
    final opening = Completer<void>();
    _opening = opening;
    final credits = channel.requestOpen();
    _log('kanal isteniyor, ${ItsChannel.creditsGrant} credit veriliyor');
    _write(creditsUuid, [credits]);

    try {
      await opening.future.timeout(_openTimeout);
    } on TimeoutException {
      _log('kanal isteğine yanıt yok');
      channel.reset();
      status.value = ItsChannelStatus.closed;
      return false;
    } finally {
      _opening = null;
    }
    return channel.isOpen;
  }

  Future<void> close() async {
    if (!channel.isOpen) return;
    _log('kanal kapatılıyor (0xFF)');
    await _write(creditsUuid, [channel.closeByte]);
    channel.reset();
    status.value = ItsChannelStatus.closed;
    _completePending(null);
  }

  /// Sends one message - [applicationData] starts at the service identifier
  /// - and waits for its answer. Null on a timeout, a closed channel, or a
  /// channel the unit tore down while waiting.
  Future<List<int>?> request(
    List<int> applicationData, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final result = _requestChain.then(
      (_) => _exchange(applicationData, timeout),
    );
    _requestChain = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<int>?> _exchange(
    List<int> applicationData,
    Duration timeout,
  ) async {
    if (!channel.isOpen) {
      _log('kanal açık değil');
      return null;
    }

    final frame = KLineFrame.buildRequest(
      applicationData.first,
      applicationData.sublist(1),
    );
    final payloadSize = VuAppPacketCodec.payloadSizeFor(conn.mtu);
    if (!channel.send(frame, payloadSize)) {
      _log('kanal mesajı almadı');
      return null;
    }

    _log('TX ${_hex(frame)}');
    var pendingRetries = 0;
    _pending = Completer<List<int>?>();
    _pump();

    while (true) {
      final pending = _pending!;
      List<int>? raw;
      try {
        raw = await pending.future.timeout(timeout);
      } on TimeoutException {
        _log('${timeout.inSeconds} sn içinde yanıt yok');
        _pending = null;
        return null;
      }
      if (raw == null) {
        _pending = null;
        return null;
      }

      final response = KwpFrame.withLengthByte(raw);
      if (response == null) {
        _log('KWP2000 çerçevesi değil: ${_hex(raw)}');
        _pending = null;
        return null;
      }
      if (!KwpFrame.checksumValid(raw)) {
        _log('checksum tutmuyor: ${_hex(raw)}');
      }
      if (KwpFrame.negativeCode(response) == KwpFrame.responsePending &&
          pendingRetries < _maxPendingRetries) {
        pendingRetries++;
        _log('RESPONSE PENDING (0x78) — bekleniyor');
        _pending = Completer<List<int>?>();
        continue;
      }

      _log('RX ${_hex(raw)}');
      _pending = null;
      return response;
    }
  }

  void _onCredits(List<int> value) {
    final event = channel.onCreditsIndication(value);
    switch (event) {
      case ItsCreditOpened():
        _log('kanal açık, ${channel.creditsFromVu} credit alındı');
        status.value = ItsChannelStatus.open;
        _opening?.complete();
        _pump();
      case ItsCreditRefused():
        // 0xFF is both a refusal and a teardown: the front connector holds
        // the interface, or the inserted cards do not allow ITS.
        _log('takograf kanalı reddetti ya da kapattı (0xFF)');
        status.value = ItsChannelStatus.refused;
        _opening?.complete();
        _completePending(null);
      case ItsCreditGranted(:final added, :final total):
        _log('+$added credit, toplam $total');
        _pump();
      case null:
        _log('boş credit bildirimi');
    }
  }

  void _onFifo(List<int> packet) {
    final result = channel.onFifoIndication(packet);
    final topUp = result.creditTopUp;
    if (topUp != null) _write(creditsUuid, [topUp]);
    final warning = result.warning;
    if (warning != null) _log(warning);
    final message = result.message;
    if (message != null) _completePending(message);
  }

  void _completePending(List<int>? message) {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(message);
  }

  /// Writes every packet the credits allow; the rest go when the unit
  /// grants more.
  void _pump() {
    final payloadSize = VuAppPacketCodec.payloadSizeFor(conn.mtu);
    while (true) {
      final packet = channel.nextPacket(payloadSize);
      if (packet == null) break;
      _write(fifoUuid, packet);
    }
  }

  Future<void> _write(String uuid, List<int> value) {
    final write = _writeChain.then((_) => conn.writeIts(uuid, value));
    _writeChain = write.catchError((Object e) {
      _log('yazma başarısız ($e)');
    });
    return _writeChain;
  }

  Future<void> dispose() async {
    await _fifoSub.cancel();
    await _creditsSub.cancel();
    _completePending(null);
    channel.reset();
    status.value = ItsChannelStatus.closed;
  }

  void _log(String line) => debugPrint('$label: $line');

  static String _hex(List<int> bytes) => bytes
      .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}
