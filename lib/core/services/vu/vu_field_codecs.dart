import 'dart:convert';
import 'dart:typed_data';

class VuFieldCodecs {
  VuFieldCodecs._();

  static const List<int> identityCodepages = [0, 1, 2, 3];

  static const List<int> nameCodepages = [0, 1, 2, 3, 4, 5, 6, 7, 8];

  static bool isCleanAsciiField(Uint8List bytes) {
    for (final b in bytes) {
      if (b == 0x00 || b == 0xFF) continue;
      if (b < 0x20 || b >= 0x7F) return false;
    }
    return true;
  }

  static bool isCleanNameField(Uint8List bytes) {
    for (final b in bytes) {
      if (b == 0x00 || b == 0xFF) continue;
      if (b < 0x20) return false;
      if (b == 0x7F) return false;
      if (b >= 0x80 && b <= 0x9F) return false;
    }
    return true;
  }

  static bool isAsciiUpperAlnum(Uint8List bytes) {
    for (final b in bytes) {
      final isDigit = b >= 0x30 && b <= 0x39;
      final isUpper = b >= 0x41 && b <= 0x5A;
      if (!isDigit && !isUpper) return false;
    }
    return true;
  }

  static String cleanAsciiText(Uint8List bytes) => latin1
      .decode(bytes, allowInvalid: true)
      .replaceAll('\x00', '')
      .replaceAll('\xff', '')
      .trim();

  static String decodeCodepageText(int codepage, Uint8List bytes) {
    String text;
    if (codepage == 6) {
      final buffer = StringBuffer();
      for (final b in bytes) {
        switch (b) {
          case 0xD0:
            buffer.writeCharCode(0x011E);
          case 0xDD:
            buffer.writeCharCode(0x0130);
          case 0xDE:
            buffer.writeCharCode(0x015E);
          case 0xF0:
            buffer.writeCharCode(0x011F);
          case 0xFD:
            buffer.writeCharCode(0x0131);
          case 0xFE:
            buffer.writeCharCode(0x015F);
          default:
            buffer.writeCharCode(b);
        }
      }
      text = buffer.toString();
    } else {
      text = latin1.decode(bytes, allowInvalid: true);
    }
    return text.replaceAll('\x00', '').replaceAll('\xff', '').trim();
  }

  static bool hasLongRun(String s, int n) {
    var run = 1;
    for (var i = 1; i < s.length; i++) {
      run = s[i] == s[i - 1] ? run + 1 : 1;
      if (run >= n) return true;
    }
    return false;
  }

  static int? bcdDigits(int byte) {
    final hi = (byte >> 4) & 0xF;
    final lo = byte & 0xF;
    if (hi > 9 || lo > 9) return null;
    return hi * 10 + lo;
  }
}
