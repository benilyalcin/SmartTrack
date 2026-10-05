import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/bluetooth/vu/vu_app_link.dart';
import 'package:smarttrack_mine/core/services/kline_protocol.dart';

void main() {
  group('VuAppPacketCodec.fragment', () {
    test(
      'a 30 byte message at MTU 23 is two packets, total only in the first',
      () {
        final message = List<int>.generate(30, (i) => i);
        final packets = VuAppPacketCodec.fragment(
          message,
          VuAppPacketCodec.payloadSizeFor(23),
        );

        expect(VuAppPacketCodec.payloadSizeFor(23), 18);
        expect(packets, hasLength(2));
        expect(packets[0].sublist(0, 2), [2, 1]);
        expect(packets[0], hasLength(20));
        expect(packets[1].sublist(0, 2), [0, 2]);
        expect(packets[1], hasLength(14));
        expect([...packets[0].skip(2), ...packets[1].skip(2)], message);
      },
    );

    test('a short request at MTU 247 is one packet', () {
      final frame = KLineFrame.readById(TachoRecordId.vin);
      final packets = VuAppPacketCodec.fragment(
        frame,
        VuAppPacketCodec.payloadSizeFor(247),
      );

      expect(packets, [
        [1, 1, ...frame],
      ]);
    });
  });

  group('VuAppReassembler', () {
    test('round-trips what fragment produced', () {
      final message = List<int>.generate(261, (i) => i & 0xFF);
      final reassembler = VuAppReassembler();
      List<int>? out;
      for (final p in VuAppPacketCodec.fragment(message, 18)) {
        out = reassembler.onPacket(p);
      }
      expect(out, message);
    });

    test('sequence 1 starts over and drops the half built message', () {
      final reassembler = VuAppReassembler();
      expect(reassembler.onPacket([2, 1, 0xAA]), isNull);
      expect(reassembler.onPacket([1, 1, 0xBB]), [0xBB]);
    });

    test('a skipped sequence drops the message', () {
      final reassembler = VuAppReassembler();
      expect(reassembler.onPacket([3, 1, 0x01]), isNull);
      expect(reassembler.onPacket([0, 3, 0x03]), isNull);
      expect(reassembler.lastWarning, contains('dropped'));
      expect(reassembler.onPacket([0, 2, 0x02]), isNull);
      expect(reassembler.lastWarning, isNotNull);
    });

    test('drops a first packet announcing 0, a stray later packet and a '
        'packet without a header', () {
      final reassembler = VuAppReassembler();
      expect(reassembler.onPacket([0, 1, 0x01]), isNull);
      expect(reassembler.lastWarning, isNotNull);
      expect(reassembler.onPacket([0, 2, 0x01]), isNull);
      expect(reassembler.lastWarning, isNotNull);
      expect(reassembler.onPacket([1]), isNull);
      expect(reassembler.lastWarning, isNotNull);
    });

    test('drops a message longer than 261 bytes', () {
      final reassembler = VuAppReassembler();
      final packets = VuAppPacketCodec.fragment(List.filled(262, 0x55), 100);
      for (final p in packets) {
        expect(reassembler.onPacket(p), isNull);
      }
      expect(reassembler.lastWarning, contains('261'));
    });
  });

  group('KwpFrame', () {
    test('rewrites the K-line StartCommunication into the long form', () {
      final long = KwpFrame.withLengthByte(KLineFrame.startCommunication);

      expect(long, [0x80, 0xEE, 0xF0, 0x01, 0x81, 0xE0]);
      expect(KwpFrame.serviceId(long!), 0x81);
      expect(KwpFrame.checksumValid(long), isTrue);
    });

    test('leaves a long form frame as it is and drops trailing bytes', () {
      final frame = KLineFrame.readById(TachoRecordId.vin);
      expect(KwpFrame.withLengthByte([...frame, 0x00]), frame);
    });

    test('normalises a short form response so index based parsers work', () {
      // 7F 22 22: a personal identifier without the driver's consent.
      final short = <int>[0x83, 0xF0, 0xEE, 0x7F, 0x22, 0x22];
      short.add(short.fold<int>(0, (s, b) => (s + b) & 0xFF));

      expect(KwpFrame.checksumValid(short), isTrue);
      final long = KwpFrame.withLengthByte(short)!;
      expect(long.sublist(0, 7), [0x80, 0xF0, 0xEE, 0x03, 0x7F, 0x22, 0x22]);
      expect(RdbiResponseParser.extractNrc(long), 0x22);
      expect(KwpFrame.negativeCode(long), 0x22);
    });

    test('is null for something that is not a frame', () {
      expect(KwpFrame.withLengthByte([0x01, 0x02]), isNull);
      expect(KwpFrame.withLengthByte([0x80, 0xF0, 0xEE, 0x05, 0x62]), isNull);
      expect(
        KwpFrame.checksumValid([0x80, 0xF0, 0xEE, 0x01, 0xC1, 0x00]),
        isFalse,
      );
    });

    test('matches a response to its request by service identifier', () {
      List<int> response(List<int> body) {
        final f = <int>[0x80, 0xF0, 0xEE, body.length, ...body];
        return f..add(f.fold<int>(0, (s, b) => (s + b) & 0xFF));
      }

      expect(KwpFrame.isResponseTo(0x22, response([0x62, 0xF1, 0x90])), isTrue);
      expect(KwpFrame.isResponseTo(0x22, response([0x7F, 0x22, 0x31])), isTrue);
      expect(KwpFrame.isResponseTo(0x81, response([0xC1, 0xEA, 0x8F])), isTrue);
      // A late second StartCommunication answer is not an RDBI answer.
      expect(
        KwpFrame.isResponseTo(0x22, response([0xC1, 0xEA, 0x8F])),
        isFalse,
      );
      expect(
        KwpFrame.isResponseTo(0x22, response([0x7F, 0x81, 0x10])),
        isFalse,
      );
      // A sub-message acknowledgement is answered by the next sub-message.
      expect(KwpFrame.isResponseTo(0x83, response([0x76, 0x06, 0x01])), isTrue);
    });
  });

  group('VuMessageMailbox', () {
    test('hands over a message that arrives while waiting', () async {
      final mailbox = VuMessageMailbox();
      final taken = mailbox.take(const Duration(seconds: 1));
      mailbox.put([1, 2, 3]);
      expect(await taken, [1, 2, 3]);
    });

    test('keeps order, and clear forgets what nobody took', () async {
      final mailbox = VuMessageMailbox()
        ..put([1])
        ..put([2]);
      expect(await mailbox.take(Duration.zero), [1]);
      mailbox.clear();
      expect(await mailbox.take(const Duration(milliseconds: 10)), isNull);
    });
  });
}
