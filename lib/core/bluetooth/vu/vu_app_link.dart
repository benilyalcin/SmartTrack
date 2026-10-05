import 'dart:async';

/// The AVU3 vehicle unit's own GATT service: the KWP2000 traffic that used to
/// go over Classic SPP now goes over this pair of characteristics.
///
/// Unlike the two regulated ITS services it carries no credits - the phone
/// writes without response and the unit notifies - but every write and every
/// notification starts with the same two byte packet header ITS uses, so a
/// message longer than one packet arrives whole.
class VuAppUuids {
  VuAppUuids._();

  static const String service = 'a1f3c62e-8d47-4b91-9e05-3c7a2f84d6b0';

  /// Phone to vehicle unit. Write or write without response.
  static const String rx = 'a1f3c62f-8d47-4b91-9e05-3c7a2f84d6b0';

  /// Vehicle unit to phone. Notify.
  static const String tx = 'a1f3c630-8d47-4b91-9e05-3c7a2f84d6b0';

  /// DefaultDeviceName in BluetoothMng.c, followed by the plate or the serial
  /// number. The advertising payload carries the flags and the local name and
  /// nothing else, so this is the only way to recognise a unit before
  /// connecting - a filter on the service UUID would match nothing.
  static const String namePrefix = 'TACHOGRAPH-';

  /// The controller's OUI, for a unit whose name the phone has not resolved.
  static const String macPrefix = '00:03:73';
}

/// The `[total][sequence]` header in front of every packet.
///
/// `total` is the packet count of the message in the first packet and 0 in
/// every other one; `sequence` counts from 1.
class VuAppPacketCodec {
  VuAppPacketCodec._();

  static const int headerSize = 2;

  /// ATT opcode and handle, which never belong to the payload.
  static const int attHeaderSize = 3;

  /// The KWP2000 length field is one byte: 255 bytes of service data plus the
  /// four header bytes and the checksum, plus slack the unit allows for.
  static const int maxMessageSize = 261;

  static int payloadSizeFor(int mtu) => mtu - attHeaderSize - headerSize;

  static List<List<int>> fragment(List<int> message, int payloadSize) {
    if (message.isEmpty) return const [];
    if (payloadSize < 1) {
      throw ArgumentError.value(
        payloadSize,
        'payloadSize',
        'must be at least 1',
      );
    }

    final total = (message.length + payloadSize - 1) ~/ payloadSize;
    if (total > 0xFF) {
      throw ArgumentError('${message.length} bytes do not fit in 255 packets');
    }

    final packets = <List<int>>[];
    for (var i = 0; i < total; i++) {
      final start = i * payloadSize;
      final end = (start + payloadSize).clamp(0, message.length);
      packets.add(<int>[
        i == 0 ? total : 0,
        i + 1,
        ...message.sublist(start, end),
      ]);
    }
    return packets;
  }
}

/// Puts notifications back together the way the vehicle unit does on its side
/// (BLE_AppService.c): a packet with sequence 1 always starts a new message and
/// drops whatever was half built, and a skipped sequence drops the message -
/// without credits that is the only check that catches a lost packet.
class VuAppReassembler {
  final List<int> _buffer = [];
  int _total = 0;
  int _nextSequence = 0;

  /// Why the last packet was dropped, or null when it was taken.
  String? lastWarning;

  /// Returns the complete message once its last packet has arrived.
  List<int>? onPacket(List<int> packet) {
    lastWarning = null;

    if (packet.length < VuAppPacketCodec.headerSize) {
      lastWarning = 'packet too short to carry a header';
      return null;
    }

    final total = packet[0];
    final sequence = packet[1];

    if (sequence == 1) {
      _reset();
      if (total == 0) {
        lastWarning = 'first packet announces 0 packets';
        return null;
      }
      _total = total;
    } else if (_total == 0 || sequence != _nextSequence) {
      lastWarning = _total == 0
          ? 'packet $sequence without a message open'
          : 'packet $sequence where $_nextSequence was due, message dropped';
      _reset();
      return null;
    }

    _buffer.addAll(packet.sublist(VuAppPacketCodec.headerSize));
    _nextSequence = sequence + 1;

    if (_buffer.length > VuAppPacketCodec.maxMessageSize) {
      lastWarning =
          'message longer than ${VuAppPacketCodec.maxMessageSize} bytes, dropped';
      _reset();
      return null;
    }

    if (sequence < _total) return null;

    final message = List<int>.from(_buffer);
    _reset();
    return message;
  }

  void _reset() {
    _buffer.clear();
    _total = 0;
    _nextSequence = 0;
  }
}

/// KWP2000 header handling the app service needs on top of `KLineFrame`.
///
/// The vehicle unit routes an app service message by the service identifier
/// at index 4 (MainThreadMobileApp::route), which assumes FMT 0x80 with the
/// length in its own byte. A frame with the length packed into FMT - such as
/// the `81 EE F0 81 E0` StartCommunication a K-line tester sends - would be
/// routed by its checksum, so every request is rewritten into the long form.
/// Responses are rewritten the same way, which keeps the index-based parsers
/// in kline_protocol.dart working whichever form the unit answered in.
class KwpFrame {
  KwpFrame._();

  static const int negativeResponse = 0x7F;
  static const int responsePending = 0x78;

  /// TransferData sub-messages are acknowledged with 0x83, and the unit's
  /// answer to an acknowledgement is the next 0x76 sub-message.
  static const int _acknowledgeSubMessage = 0x83;
  static const int _transferDataPositive = 0x76;

  static int _checksum(Iterable<int> bytes) =>
      bytes.fold<int>(0, (sum, b) => (sum + b) & 0xFF);

  /// Offset of the service identifier and the service data length, or null
  /// when [frame] is not a complete physically addressed frame.
  static ({int dataOffset, int length})? _layout(List<int> frame) {
    if (frame.length < 4) return null;

    final fmt = frame[0];
    if (fmt & 0x80 == 0) return null;

    final inline = fmt & 0x3F;
    final dataOffset = inline == 0 ? 4 : 3;
    final length = inline == 0 ? frame[3] : inline;

    if (length == 0 || frame.length < dataOffset + length + 1) return null;
    return (dataOffset: dataOffset, length: length);
  }

  /// [frame] with FMT 0x80 and a separate length byte, checksum recomputed.
  /// Null when it is not a frame at all. Trailing bytes are dropped.
  static List<int>? withLengthByte(List<int> frame) {
    final layout = _layout(frame);
    if (layout == null) return null;

    final out = <int>[
      frame[0] & 0xC0,
      frame[1],
      frame[2],
      layout.length,
      ...frame.sublist(layout.dataOffset, layout.dataOffset + layout.length),
    ];
    out.add(_checksum(out));
    return out;
  }

  static bool checksumValid(List<int> frame) {
    final layout = _layout(frame);
    if (layout == null) return false;

    final end = layout.dataOffset + layout.length;
    return frame[end] == _checksum(frame.take(end));
  }

  /// The service identifier of a long-form frame.
  static int? serviceId(List<int> frame) => frame.length > 4 ? frame[4] : null;

  /// The NRC of a long-form negative response.
  static int? negativeCode(List<int> frame) =>
      frame.length > 6 && frame[4] == negativeResponse ? frame[6] : null;

  /// Whether long-form [response] answers a request for [requestSid]: its
  /// positive response, a negative response naming it, or - for a sub-message
  /// acknowledgement - the next sub-message.
  static bool isResponseTo(int requestSid, List<int> response) {
    final sid = serviceId(response);
    if (sid == null) return false;

    if (sid == negativeResponse) {
      return response.length > 5 && response[5] == requestSid;
    }
    if (sid == (requestSid + 0x40) & 0xFF) return true;

    return requestSid == _acknowledgeSubMessage && sid == _transferDataPositive;
  }
}

/// Holds complete messages until a request takes them.
///
/// The vehicle unit answers one request at a time, so a single waiter is
/// enough; whatever arrives with nobody waiting stays queued until [clear].
class VuMessageMailbox {
  final List<List<int>> _messages = [];
  Completer<void>? _waiter;

  void put(List<int> message) {
    _messages.add(message);
    final waiter = _waiter;
    _waiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  void clear() => _messages.clear();

  /// The oldest message, or null when none arrives within [timeout].
  Future<List<int>?> take(Duration timeout) async {
    if (_messages.isNotEmpty) return _messages.removeAt(0);

    final waiter = Completer<void>();
    _waiter = waiter;
    try {
      await waiter.future.timeout(timeout);
    } on TimeoutException {
      if (identical(_waiter, waiter)) _waiter = null;
      return null;
    }
    return _messages.isEmpty ? null : _messages.removeAt(0);
  }
}
