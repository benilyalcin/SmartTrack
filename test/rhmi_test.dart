import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/rhmi/manual_entry.dart';
import 'package:smarttrack_mine/core/services/rhmi/rhmi.dart';

// Vectors taken from AvuItsTester's RhmiCrc32Test.kt and ProtocolTest.kt.
void main() {
  group('Rhmi.crc32', () {
    test('empty input is zero', () => expect(Rhmi.crc32(const []), 0));

    test('differs from the ordinary CRC32 (0xCBF43926)', () {
      expect(Rhmi.crc32('123456789'.codeUnits), 0x2DFD2D88);
    });

    test('a request and the session identifier checksum as one run', () {
      const request = [0x31, 0x01, 0xF2, 0x14, 0x01, 0x61, 0x0A, 0x85, 0xE4];
      const sessionId = [0, 1, 2, 3, 4, 5, 6, 7];
      expect(Rhmi.crc32(request, sessionId), 0x89CFDD96);
      expect(Rhmi.crc32([...request, ...sessionId]), 0x89CFDD96);
    });
  });

  test("the specification's own SetActivity example", () {
    const sessionId = [0xB3, 0x3B, 0x56, 0x11, 0x53, 0x5A, 0x8D, 0xB1];
    final request = Rhmi.signedRoutine(
      Rhmi.routineStart,
      Rhmi.ridSetActivity,
      [Rhmi.cardSlotNumber(1), Rhmi.activityAvailability],
      sessionId,
      0x610A85E4,
    );
    expect(request, [
      0x31, 0x01, 0xF2, 0x05, 0x00, 0x01, 0x61, 0x0A, 0x85, 0xE4, //
      0x38, 0x07, 0xF4, 0x49,
    ]);
  });

  test('transport checksum, token digits and deobfuscation', () {
    const sessionId = [0, 1, 2, 3, 4, 5, 6, 7];
    expect(
      Rhmi.transportChecksum(sessionId, const [0x12, 0x34, 0x56, 0x78]),
      0x25B0FCEC,
    );

    final token = Rhmi.tokenFromDigits('12345678')!;
    expect(token, [0x12, 0x34, 0x56, 0x78]);
    final transmitted = Rhmi.deobfuscate(sessionId, token);
    expect(Rhmi.deobfuscate(transmitted, token), sessionId);

    expect(Rhmi.tokenFromDigits('1234567'), isNull);
    expect(Rhmi.tokenFromDigits('1234567A'), isNull);
  });

  group('ManualEntry', () {
    const period = ManualEntryPeriod(
      routineInfo: 0,
      periodBegin: 6000,
      periodEnd: 6600,
      endCountryCode: 0,
      endRegionCode: 0,
    );

    test('an activity may start at the beginning but not at the end', () {
      expect(
        ManualEntry.validate(
          const [ManualActivity(6000, ManualActivityType.rest)],
          const [],
          period,
        ),
        isNull,
      );
      expect(
        ManualEntry.validate(
          const [ManualActivity(6600, ManualActivityType.rest)],
          const [],
          period,
        ),
        isNotNull,
      );
    });

    test(
      'a place needs a country, and an end place not on the last minute',
      () {
        const act = [ManualActivity(6000, ManualActivityType.work)];
        expect(
          ManualEntry.validate(act, const [ManualPlace(6000, 0, 0, 0)], period),
          isNotNull,
        );
        expect(
          ManualEntry.validate(act, const [
            ManualPlace(6600, Rhmi.placeEnd, 0x30, 0),
          ], period),
          isNotNull,
        );
        expect(
          ManualEntry.validate(act, const [
            ManualPlace(6600, Rhmi.placeBegin, 0x30, 0),
          ], period),
          isNull,
        );
      },
    );

    test('builds counts and records, times truncated to the minute', () {
      expect(
        ManualEntry.build(
          const [ManualActivity(6030, ManualActivityType.available)],
          const [ManualPlace(6000, Rhmi.placeBegin, 0x30, 0)],
        ),
        [1, 0, 0, 0x17, 0x70, 1, 1, 0, 0, 0x17, 0x70, 0, 0x30, 0],
      );
    });
  });
}
