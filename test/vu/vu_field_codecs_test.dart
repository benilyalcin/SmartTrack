import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/vu/vu_field_codecs.dart';

void main() {
  group('VuFieldCodecs', () {
    test('isCleanAsciiField accepts printable ASCII and NUL/0xFF padding', () {
      expect(
        VuFieldCodecs.isCleanAsciiField(Uint8List.fromList('ABC123'.codeUnits)),
        isTrue,
      );
      expect(
        VuFieldCodecs.isCleanAsciiField(Uint8List.fromList([0x41, 0x00, 0xFF])),
        isTrue,
      );
      expect(
        VuFieldCodecs.isCleanAsciiField(Uint8List.fromList([0x01])),
        isFalse,
      );
    });

    test(
      'isCleanNameField allows Latin-1 diacritics but rejects control bytes',
      () {
        expect(
          VuFieldCodecs.isCleanNameField(Uint8List.fromList([0xDC, 0x41])),
          isTrue,
        );
        expect(
          VuFieldCodecs.isCleanNameField(Uint8List.fromList([0x7F])),
          isFalse,
        );
        expect(
          VuFieldCodecs.isCleanNameField(Uint8List.fromList([0x85])),
          isFalse,
        );
      },
    );

    test('isAsciiUpperAlnum rejects lowercase, padding and punctuation', () {
      expect(
        VuFieldCodecs.isAsciiUpperAlnum(
          Uint8List.fromList('WVW12345'.codeUnits),
        ),
        isTrue,
      );
      expect(
        VuFieldCodecs.isAsciiUpperAlnum(
          Uint8List.fromList('wvw12345'.codeUnits),
        ),
        isFalse,
      );
      expect(
        VuFieldCodecs.isAsciiUpperAlnum(Uint8List.fromList([0x00])),
        isFalse,
      );
    });

    test('hasLongRun finds a run of n+ identical characters', () {
      expect(VuFieldCodecs.hasLongRun('ZYYYYYYYXXWWWWWW', 4), isTrue);
      expect(VuFieldCodecs.hasLongRun('AB12CD34EF56', 4), isFalse);
    });

    test('decodeCodepageText maps codepage 6 Turkish characters correctly', () {
      final text = VuFieldCodecs.decodeCodepageText(
        6,
        Uint8List.fromList([0xDD, 0x73, 0x74, 0xFE]),
      );
      expect(text, 'İstş');
    });

    test('decodeCodepageText falls back to Latin-1 for other codepages', () {
      final text = VuFieldCodecs.decodeCodepageText(
        1,
        Uint8List.fromList('ABC'.codeUnits),
      );
      expect(text, 'ABC');
    });

    test(
      'bcdDigits decodes two packed BCD digits, rejects invalid nibbles',
      () {
        expect(VuFieldCodecs.bcdDigits(0x12), 12);
        expect(VuFieldCodecs.bcdDigits(0x0A), isNull);
      },
    );
  });
}
