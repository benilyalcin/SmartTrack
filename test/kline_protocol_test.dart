import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/kline_protocol.dart';

Uint8List _driverNamePayload(String surname, String firstName) {
  final bytes = Uint8List(72);
  bytes[0] = 1;
  final surnameBytes = surname.codeUnits;
  bytes.setRange(1, 1 + surnameBytes.length, surnameBytes);
  bytes[36] = 1;
  final firstNameBytes = firstName.codeUnits;
  bytes.setRange(37, 37 + firstNameBytes.length, firstNameBytes);
  return bytes;
}

void main() {
  group('KLineFrame', () {
    test('checksum is the sum of preceding bytes mod 256', () {
      expect(KLineFrame.checksum([0x01, 0x02, 0x03]), 0x06);
      expect(KLineFrame.checksum([0xFF, 0xFF]), 0xFE);
    });

    test(
      'readById builds the documented [FMT TADDR SADDR LEN SID RIDH RIDL CS] frame',
      () {
        final frame = KLineFrame.readById(0xF190);
        expect(frame, [0x80, 0xEE, 0xF0, 0x03, 0x22, 0xF1, 0x90, 0x04]);
      },
    );

    test(
      'reportDtcCount/reportDtcList checksums are internally consistent',
      () {
        for (final frame in [
          KLineFrame.reportDtcCount,
          KLineFrame.reportDtcList,
        ]) {
          final body = frame.sublist(0, frame.length - 1);
          expect(
            frame.last,
            KLineFrame.checksum(body),
            reason: 'frame: $frame',
          );
        }
      },
    );

    test('startCommunication is the fixed fast-init frame (no LEN byte)', () {
      expect(KLineFrame.startCommunication, [0x81, 0xEE, 0xF0, 0x81, 0xE0]);
    });
  });

  group('RdbiResponseParser.extractData', () {
    test('finds the positive-response payload for a matching record ID', () {
      final response = [
        0x83,
        0xF0,
        0xEE,
        0x07,
        0x62,
        0xF1,
        0x90,
        0x54,
        0x45,
        0x53,
        0x54,
        0x00,
      ];
      final data = RdbiResponseParser.extractData(response, 0xF190);
      expect(data, isNotNull);
      expect(RdbiResponseParser.parseAscii(data!), 'TEST');
    });

    test('returns null when the record ID does not match', () {
      final response = [
        0x83,
        0xF0,
        0xEE,
        0x07,
        0x62,
        0xF1,
        0x90,
        0x54,
        0x45,
        0x53,
        0x54,
        0x00,
      ];
      expect(RdbiResponseParser.extractData(response, 0xF902), isNull);
    });

    test('returns null for an empty or too-short response', () {
      expect(RdbiResponseParser.extractData([], 0xF190), isNull);
      expect(RdbiResponseParser.extractData([0x62, 0xF1], 0xF190), isNull);
    });
  });

  group('RdbiResponseParser negative-response handling', () {
    test('isNegativeResponse detects SID 0x7F anywhere in the frame', () {
      final neg = [0x83, 0xF0, 0xEE, 0x03, 0x7F, 0x22, 0x33, 0x00];
      expect(RdbiResponseParser.isNegativeResponse(neg), isTrue);
      expect(
        RdbiResponseParser.isNegativeResponse([0x83, 0xF0, 0xEE, 0x62]),
        isFalse,
      );
    });

    test('extractNrc reads the NRC byte two positions after 0x7F', () {
      final neg = [0x83, 0xF0, 0xEE, 0x03, 0x7F, 0x22, 0x33, 0x00];
      expect(RdbiResponseParser.extractNrc(neg), 0x33);
      expect(RdbiResponseParser.describeNrc(0x33), 'securityAccessDenied');
    });

    test('extractNrc returns null when there is no negative response', () {
      expect(RdbiResponseParser.extractNrc([0x83, 0xF0, 0xEE, 0x62]), isNull);
    });
  });

  group('RdbiResponseParser numeric/time parsing', () {
    test('parseInt32BE / parseInt16BE read big-endian values', () {
      expect(
        RdbiResponseParser.parseInt32BE(
          Uint8List.fromList([0x00, 0x00, 0x01, 0x00]),
        ),
        256,
      );
      expect(
        RdbiResponseParser.parseInt16BE(Uint8List.fromList([0x01, 0x00])),
        256,
      );
    });

    test('parseMinutesOrNull parses a plain minute count', () {
      expect(
        RdbiResponseParser.parseMinutesOrNull(Uint8List.fromList([0x00, 0x1E])),
        const Duration(minutes: 30),
      );
    });

    test(
      'parseMinutesOrNull returns null for the null/reserved sentinel bands',
      () {
        expect(
          RdbiResponseParser.parseMinutesOrNull(
            Uint8List.fromList([0xFF, 0xFF]),
          ),
          isNull,
        );
        expect(RdbiResponseParser.parseMinutesOrNull(null), isNull);
      },
    );

    test(
      'parseMinutesOrNull accepts the boundary valid value and rejects just past it',
      () {
        expect(
          RdbiResponseParser.parseMinutesOrNull(
            Uint8List.fromList([0xFA, 0xFF]),
          ),
          const Duration(minutes: 64255),
        );
        expect(
          RdbiResponseParser.parseMinutesOrNull(
            Uint8List.fromList([0xFB, 0x00]),
          ),
          isNull,
        );
      },
    );
  });

  group('RdbiResponseParser string/name parsing', () {
    test('parseAscii trims trailing nulls and whitespace', () {
      expect(
        RdbiResponseParser.parseAscii(
          Uint8List.fromList([0x41, 0x42, 0x00, 0x00]),
        ),
        'AB',
      );
      expect(
        RdbiResponseParser.parseAscii(Uint8List.fromList([0x41, 0x20, 0x00])),
        'A',
      );
    });

    test(
      'parseDriverCardNumber reads bytes 3-18 after the 3-byte issuing state',
      () {
        final data = Uint8List.fromList(
          'TUR1234567890123456'.codeUnits.sublist(0, 19),
        );
        expect(
          RdbiResponseParser.parseDriverCardNumber(data),
          '1234567890123456',
        );
      },
    );

    test('parseDriverCardNumber returns empty for a too-short payload', () {
      expect(
        RdbiResponseParser.parseDriverCardNumber(
          Uint8List.fromList([0x54, 0x55, 0x52]),
        ),
        '',
      );
    });

    test(
      'parseDriverName combines first name + surname from the 72-byte record',
      () {
        final data = _driverNamePayload('YILMAZ', 'AHMET');
        expect(RdbiResponseParser.parseDriverName(data), 'AHMET YILMAZ');
      },
    );
  });

  group('RdbiResponseParser date parsing', () {
    test('parseCompactDate decodes [month, day, yearOffsetFrom1985]', () {
      final data = Uint8List.fromList([6, 15, 40]);
      expect(RdbiResponseParser.parseCompactDate(data), DateTime(2025, 6, 15));
    });

    test('parseCompactDate rejects an out-of-range day/month', () {
      expect(
        RdbiResponseParser.parseCompactDate(Uint8List.fromList([13, 15, 40])),
        isNull,
      );
      expect(
        RdbiResponseParser.parseCompactDate(Uint8List.fromList([6, 0, 40])),
        isNull,
      );
    });

    test('parseDateTime decodes the 8-byte TimeDate group', () {
      final data = Uint8List.fromList([0, 30, 14, 58, 6, 40, 0, 0]);
      expect(
        RdbiResponseParser.parseDateTime(data),
        DateTime(2025, 6, 15, 14, 30),
      );
    });
  });

  group('RdbiResponseParser.parseAdditionalInformation', () {
    test('decodes the packed remaining-10h and reduced-rest counters', () {
      final value = 2 | (3 << 3);
      final data = Uint8List.fromList([(value >> 8) & 0xFF, value & 0xFF]);
      final info = RdbiResponseParser.parseAdditionalInformation(data);
      expect(info, isNotNull);
      expect(info!.remaining10hDrivingTimes, 2);
      expect(info.remainingReducedDailyRestPeriods, 3);
      expect(info.hasUnknownPeriods, isFalse);
    });

    test('returns null for a too-short payload', () {
      expect(
        RdbiResponseParser.parseAdditionalInformation(
          Uint8List.fromList([0x01]),
        ),
        isNull,
      );
    });
  });

  group('DtcResponseParser + DtcCodes', () {
    test(
      'extractPayload isolates the DTC-List payload after SID/subfunction',
      () {
        final response = [
          0x83,
          0xF0,
          0xEE,
          0x0F,
          0x59,
          0x02,
          0x09,
          0x00,
          0x01,
          0x39,
          0x2F,
          0x00,
          0x0D,
          0x33,
          0x2F,
          0x00,
          0x20,
          0x04,
          0x2F,
          0x00,
        ];
        final payload = DtcResponseParser.extractPayload(response, 0x02);
        expect(payload, isNotNull);
        expect(payload!.length, 13);
        final dtcRecordCount = (payload.length - 1) ~/ 4;
        expect(dtcRecordCount, 3);
      },
    );

    test(
      'extractPayload returns null when the sub-function does not match',
      () {
        final response = [0x83, 0xF0, 0xEE, 0x04, 0x59, 0x01, 0x00, 0x00];
        expect(DtcResponseParser.extractPayload(response, 0x02), isNull);
      },
    );

    test('DtcCodes.describe matches the real DTCs captured from the field', () {
      expect(
        DtcCodes.describe(0x00, 0x01, 0x39),
        'Kayıt ünitesi dahili hatası',
      );
      expect(
        DtcCodes.describe(0x00, 0x0D, 0x33),
        'Kalibrasyon belleği okuma/yazma hatası',
      );
      expect(
        DtcCodes.describe(0x00, 0x20, 0x04),
        'Sensör güç kaynağı: sinyal yok',
      );
    });

    test(
      'DtcCodes.describe returns null for an unrecognized code rather than guessing',
      () {
        expect(DtcCodes.describe(0xFF, 0xFF, 0xFF), isNull);
      },
    );
  });

  group('CardDownloadResponseParser.parseSubMessage', () {
    test('a response final on its very first reply has no counter field', () {
      final response = [
        0x80,
        0xF0,
        0xEE,
        0x94,
        0x76,
        0x02,
        0x6A,
        0x3D,
        0xC1,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x02,
        0x20,
        0x00,
        0xA0,
        0x00,
        0x00,
        0x00,
        0x00,
        ...List.filled(153 - 24, 0),
      ];
      final frame = CardDownloadResponseParser.parseSubMessage(response);
      expect(frame, isNotNull);
      expect(frame!.trep, 0x02);
      expect(frame.subMessageCounter, 0);
      expect(frame.isFinal, isTrue);

      expect(frame.payload.take(4).toList(), [0x6A, 0x3D, 0xC1, 0x00]);
    });

    test(
      'a genuine multi-sub-message response still reads its real counter',
      () {
        final response = [
          0x80,
          0xF0,
          0xEE,
          0xFF,
          0x76,
          0x02,
          0x00,
          0x01,
          0x6A,
          0x3B,
          0x1E,
          0x00,
          0x04,
          0xAF,
          0x46,
          0x00,
          0x02,
          0x01,
          0x57,
          0x69,
          ...List.filled(260 - 20, 0),
        ];
        final frame = CardDownloadResponseParser.parseSubMessage(response);
        expect(frame, isNotNull);
        expect(frame!.subMessageCounter, 1);
        expect(frame.isFinal, isFalse);
        expect(frame.payload.take(4).toList(), [0x6A, 0x3B, 0x1E, 0x00]);
      },
    );

    test(
      'a later sub-message that happens to be final still reads its real counter',
      () {
        final response = [
          0x80,
          0xF0,
          0xEE,
          0xA7,
          0x76,
          0x02,
          0x00,
          0x02,
          0x4B,
          0x53,
          0x4B,
          0x33,
          0x35,
          0x20,
          0x20,
          0x20,
          0x20,
          0x20,
          ...List.filled(167 + 5 - 18, 0),
        ];
        final frame = CardDownloadResponseParser.parseSubMessage(response);
        expect(frame, isNotNull);
        expect(frame!.subMessageCounter, 2);
        expect(frame.isFinal, isTrue);
        expect(frame.payload.take(6).toList(), [
          0x4B,
          0x53,
          0x4B,
          0x33,
          0x35,
          0x20,
        ]);
      },
    );
  });
}
