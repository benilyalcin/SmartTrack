import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/bluetooth/vu/its_channel.dart';
import 'package:smarttrack_mine/core/services/its/appendix7.dart';

void main() {
  group('ItsChannel credits', () {
    test('opening grants 16 and the first grant back opens the channel', () {
      final ch = ItsChannel('t');
      expect(ch.requestOpen(), 16);
      expect(ch.isOpen, isFalse);

      expect(ch.onCreditsIndication([16]), isA<ItsCreditOpened>());
      expect(ch.isOpen, isTrue);
      expect(ch.creditsFromVu, 16);

      final more = ch.onCreditsIndication([4]);
      expect(more, isA<ItsCreditGranted>());
      expect(ch.creditsFromVu, 20);
    });

    test('0xFF refuses or tears the channel down', () {
      final ch = ItsChannel('t')..requestOpen();
      ch.onCreditsIndication([16]);
      expect(ch.onCreditsIndication([0xFF]), isA<ItsCreditRefused>());
      expect(ch.isOpen, isFalse);
      expect(ch.creditsFromVu, 0);
    });

    test('each packet sent spends a credit; none left, nothing goes', () {
      final ch = ItsChannel('t')..requestOpen();
      ch.onCreditsIndication([2]);
      expect(ch.send(List.filled(30, 0xAA), 10), isTrue);

      final p1 = ch.nextPacket(10)!;
      final p2 = ch.nextPacket(10)!;
      expect(p1.sublist(0, 2), [3, 1]);
      expect(p2.sublist(0, 2), [0, 2]);
      expect(ch.nextPacket(10), isNull);
      expect(ch.hasPendingSend, isTrue);

      ch.onCreditsIndication([1]);
      expect(ch.nextPacket(10)!.sublist(0, 2), [0, 3]);
      expect(ch.hasPendingSend, isFalse);
    });

    test('tops the unit up once its credits fall to the low water mark', () {
      final ch = ItsChannel('t')..requestOpen();
      ch.onCreditsIndication([16]);

      int? topUp;
      for (var i = 0; i < 12 && topUp == null; i++) {
        topUp = ch.onFifoIndication([1, 1, i]).creditTopUp;
      }
      expect(topUp, 12);
      expect(ch.creditsToVu, 16);
    });

    test('reassembles a message and drops one with a skipped packet', () {
      final ch = ItsChannel('t')..requestOpen();
      ch.onCreditsIndication([16]);

      expect(ch.onFifoIndication([2, 1, 0x80, 0xF0]).message, isNull);
      expect(ch.onFifoIndication([0, 2, 0xEE]).message, [0x80, 0xF0, 0xEE]);

      expect(ch.onFifoIndication([3, 1, 1]).message, isNull);
      final skipped = ch.onFifoIndication([0, 3, 3]);
      expect(skipped.message, isNull);
      expect(skipped.warning, isNotNull);
    });
  });

  group('Appendix7', () {
    test('TRTP follows the generation, detailed speed stays at v1 in v2', () {
      expect(
        Appendix7.trtpFor(VuTransfer.overview, DownloadGeneration.gen2v2),
        0x31,
      );
      expect(
        Appendix7.trtpFor(VuTransfer.detailedSpeed, DownloadGeneration.gen2v2),
        0x24,
      );
      expect(
        Appendix7.trtpFor(VuTransfer.cardDownload, DownloadGeneration.gen2v1),
        0x06,
      );
    });

    test('activities name a day as a TimeReal', () {
      expect(
        Appendix7.transferData(
          VuTransfer.activities,
          DownloadGeneration.gen1,
          daySeconds: 0x01020304,
        ),
        [0x36, 0x02, 0x01, 0x02, 0x03, 0x04],
      );
    });

    test('parseBlock tells counted blocks from uncounted ones', () {
      final single = Appendix7.parseBlock([0x01, 0xAA, 0xBB], counted: false)!;
      // Three bytes alone close the transfer.
      expect(single.isLast, isTrue);

      final uncounted = Appendix7.parseBlock([
        0x01,
        1,
        2,
        3,
        4,
      ], counted: false)!;
      expect(uncounted.counter, isNull);
      expect(uncounted.payload, [1, 2, 3, 4]);

      final first = Appendix7.parseBlock([
        0x01,
        0x00,
        0x01,
        ...List.filled(251, 7),
      ], counted: false)!;
      expect(first.counter, 1);
      expect(first.payload, hasLength(251));
    });
  });
}
