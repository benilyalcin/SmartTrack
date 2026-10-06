/// One ITS channel - download or diagnostics - as the Appendix 13 transport
/// protocol defines it, with no Bluetooth in it so the awkward parts can be
/// tested on their own. A port of AvuItsTester's ItsChannel.kt.
///
/// The channel decides and the link does the input and output: every method
/// returns what ought to go on the wire rather than putting it there.
///
/// Two independent credit counters, which is the part worth being careful
/// about. [creditsFromVu] is what the vehicle unit granted us, spent one per
/// FIFO write; [creditsToVu] is what we granted the vehicle unit, spent one
/// per FIFO indication. Running either to zero stalls that direction
/// silently, so both are topped up before they get there.
class ItsChannel {
  ItsChannel(this.name);

  final String name;

  /// ITS_CREDITS_GRANT in BLE_ItsService.c.
  static const int creditsGrant = 16;

  /// ITS_CREDITS_LOW_WATER: top the peer up before it runs dry mid-message.
  static const int creditsLowWater = 4;

  /// Refuses a connection and tears an open one down. Never acknowledged.
  static const int creditsRefuse = 0xFF;

  /// ITS_MAX_MESSAGE_SIZE: no KWP2000 frame, and so no message, is longer.
  static const int maxMessageSize = 261;

  static const int packetHeaderSize = 2;

  bool _isOpen = false;
  bool get isOpen => _isOpen;

  int _creditsFromVu = 0;
  int get creditsFromVu => _creditsFromVu;

  int _creditsToVu = 0;
  int get creditsToVu => _creditsToVu;

  bool _awaitingFirstGrant = false;

  List<int>? _txMessage;
  int _txOffset = 0;
  int _txTotalPackets = 0;
  int _txNextSequence = 0;

  final List<int> _rxBuffer = [];
  int _rxTotalPackets = 0;
  int _rxNextSequence = 0;

  /// The byte to write to the credits characteristic to ask for the channel.
  /// Granting credits is itself the connection request; the unit answers with
  /// its own grant to accept, or 0xFF to refuse.
  int requestOpen() {
    reset();
    _awaitingFirstGrant = true;
    _creditsToVu = creditsGrant;
    return creditsGrant;
  }

  /// The byte that closes the channel from our side.
  int get closeByte => creditsRefuse;

  /// What a credits indication meant, or null for an empty one.
  ItsCreditEvent? onCreditsIndication(List<int> value) {
    if (value.isEmpty) return null;
    final credits = value[0];

    if (credits == creditsRefuse) {
      reset();
      return const ItsCreditRefused();
    }

    // Granted credits add to what is left rather than replacing it.
    _creditsFromVu = (_creditsFromVu + credits).clamp(0, 0xFE);

    if (_awaitingFirstGrant) {
      _awaitingFirstGrant = false;
      _isOpen = true;
      return const ItsCreditOpened();
    }
    return ItsCreditGranted(credits, _creditsFromVu);
  }

  ItsFifoResult onFifoIndication(List<int> packet) {
    int? topUp;

    if (_creditsToVu > 0) _creditsToVu--;
    if (_creditsToVu <= creditsLowWater) {
      topUp = creditsGrant - _creditsToVu;
      _creditsToVu = creditsGrant;
    }

    if (packet.length < packetHeaderSize) {
      _resetReassembly();
      return ItsFifoResult(
        creditTopUp: topUp,
        warning: 'packet of ${packet.length} bytes is too short for a header',
      );
    }

    final total = packet[0];
    final sequence = packet[1];
    final payload = packet.sublist(packetHeaderSize);

    if (sequence == 1) {
      // Only the first packet carries the total, and it starts a new message
      // whatever state the last one was left in.
      _resetReassembly();
      if (total == 0) {
        return ItsFifoResult(
          creditTopUp: topUp,
          warning: 'first packet claims zero packets',
        );
      }
      _rxTotalPackets = total;
    } else {
      if (_rxTotalPackets == 0) {
        return ItsFifoResult(
          creditTopUp: topUp,
          warning: 'packet $sequence arrived with no message open',
        );
      }
      if (sequence != _rxNextSequence) {
        final expected = _rxNextSequence;
        _resetReassembly();
        return ItsFifoResult(
          creditTopUp: topUp,
          warning: 'expected packet $expected, got $sequence',
        );
      }
    }

    if (_rxBuffer.length + payload.length > maxMessageSize) {
      _resetReassembly();
      return ItsFifoResult(
        creditTopUp: topUp,
        warning: 'message longer than $maxMessageSize bytes',
      );
    }

    _rxBuffer.addAll(payload);
    _rxNextSequence = sequence + 1;

    if (sequence >= _rxTotalPackets) {
      final message = List<int>.from(_rxBuffer);
      _resetReassembly();
      return ItsFifoResult(message: message, creditTopUp: topUp);
    }
    return ItsFifoResult(creditTopUp: topUp);
  }

  /// True when the message was taken. One message at a time, as on the
  /// vehicle unit side.
  bool send(List<int> message, int payloadSize) {
    if (!_isOpen) return false;
    if (message.isEmpty || message.length > maxMessageSize) return false;
    if (_txMessage != null) return false;
    if (payloadSize <= 0) return false;

    _txMessage = message;
    _txOffset = 0;
    _txTotalPackets = (message.length + payloadSize - 1) ~/ payloadSize;
    _txNextSequence = 1;
    return true;
  }

  bool get hasPendingSend => _txMessage != null;

  /// The next packet to write, or null when there is nothing to send or no
  /// credit to send it with. A message out of credits is waiting on the
  /// vehicle unit, not on us, so null here is not an error.
  List<int>? nextPacket(int payloadSize) {
    final message = _txMessage;
    if (message == null) return null;
    if (_creditsFromVu == 0) return null;
    if (payloadSize <= 0) return null;

    final size = (message.length - _txOffset).clamp(0, payloadSize);
    final packet = <int>[
      _txNextSequence == 1 ? _txTotalPackets : 0,
      _txNextSequence,
      ...message.sublist(_txOffset, _txOffset + size),
    ];

    _creditsFromVu--;
    _txOffset += size;
    _txNextSequence++;

    if (_txOffset >= message.length) {
      _txMessage = null;
      _txOffset = 0;
      _txTotalPackets = 0;
      _txNextSequence = 0;
    }
    return packet;
  }

  void reset() {
    _isOpen = false;
    _awaitingFirstGrant = false;
    _creditsFromVu = 0;
    _creditsToVu = 0;
    _txMessage = null;
    _txOffset = 0;
    _txTotalPackets = 0;
    _txNextSequence = 0;
    _resetReassembly();
  }

  void _resetReassembly() {
    _rxBuffer.clear();
    _rxTotalPackets = 0;
    _rxNextSequence = 0;
  }
}

/// What a credits indication meant.
sealed class ItsCreditEvent {
  const ItsCreditEvent();
}

/// The channel is now usable.
class ItsCreditOpened extends ItsCreditEvent {
  const ItsCreditOpened();
}

/// The unit refused the channel or tore it down; it does not say why. The
/// reasons are in ITS_10, ITS_11 and Table 1: the front connector holds this
/// interface, or the inserted cards do not allow ITS at all.
class ItsCreditRefused extends ItsCreditEvent {
  const ItsCreditRefused();
}

/// More credits, nothing else to do.
class ItsCreditGranted extends ItsCreditEvent {
  const ItsCreditGranted(this.added, this.total);
  final int added;
  final int total;
}

/// What a FIFO indication produced: a finished message, a credit top-up to
/// write, a reason a packet was dropped - or none of them.
class ItsFifoResult {
  const ItsFifoResult({this.message, this.creditTopUp, this.warning});
  final List<int>? message;
  final int? creditTopUp;
  final String? warning;
}
