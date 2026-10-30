import 'dart:typed_data';

import '../../models/vehicle_unit_data.dart';
import 'vu_byte_reader.dart';
import 'vu_field_codecs.dart';

class VuOverviewDecoder {
  VuOverviewDecoder._();

  // Field offsets in a Gen1 overview block, after its `76 01` header: two
  // certificates of 194 bytes, then the vehicle's identity and times.
  static const int _vinAt = 388;
  static const int _vrnAt = 405; // nation, code page, 13 characters
  static const int _currentTimeAt = 420;
  static const int _periodAt = 424;
  static const int _gen1MinimumLength = 433 + 58 + 2 + 128;

  static ({String vin, String vrn, VuOverviewData? overview})? decode(
    Uint8List block,
  ) => _structured(block) ?? _searched(block);

  /// The fields where Annex 1B puts them. A unit with no VIN or plate yet -
  /// a bench unit, one never calibrated - holds question marks there; that
  /// is an empty VIN, not a reason to look for one elsewhere in the block,
  /// where a card number in the download activity passed for a VIN.
  static ({String vin, String vrn, VuOverviewData? overview})? _structured(
    Uint8List block,
  ) {
    if (block.length < _gen1MinimumLength) return null;
    DateTime? time(int at) {
      final t = VuByteReader(
        block,
        at,
      ).readTimeReal(minYear: 2000, maxYear: 2100);
      return t;
    }

    final current = time(_currentTimeAt);
    final periodStart = time(_periodAt);
    final periodEnd = time(_periodAt + 4);
    // Not an overview laid out as Gen1: let the search have it.
    if (current == null && periodStart == null && periodEnd == null) {
      return null;
    }
    return (
      vin: _identity(Uint8List.sublistView(block, _vinAt, _vinAt + 17)),
      vrn: _identity(Uint8List.sublistView(block, _vrnAt + 2, _vrnAt + 15)),
      overview: VuOverviewData(
        currentDateTime: current,
        downloadablePeriodStart: periodStart,
        downloadablePeriodEnd: periodEnd,
      ),
    );
  }

  /// Printable characters, trimmed; empty when the field is unset (spaces,
  /// zeros, 0xFF or question marks).
  static String _identity(Uint8List bytes) {
    final text = VuFieldCodecs.cleanAsciiText(bytes);
    if (text.isEmpty || text.split('').every((c) => c == '?')) return '';
    if (!VuFieldCodecs.isCleanAsciiField(bytes)) return '';
    return text;
  }

  static ({String vin, String vrn, VuOverviewData? overview})? _searched(
    Uint8List block,
  ) {
    final vin =
        _findVin(block, requireLetters: true) ??
        _findVin(block, requireLetters: false);
    if (vin == null) return null;

    final vrn = _tryReadFieldAt(block, vin.end + 1, 13) ?? '';

    final reader = VuByteReader(block, vin.end + 15);
    final currentDateTime = _timeRealBroad(reader);
    final periodStart = _timeRealBroad(reader);
    final periodEnd = _timeRealBroad(reader);
    final overview =
        (currentDateTime == null && periodStart == null && periodEnd == null)
        ? null
        : VuOverviewData(
            currentDateTime: currentDateTime,
            downloadablePeriodStart: periodStart,
            downloadablePeriodEnd: periodEnd,
          );

    return (vin: vin.text, vrn: vrn, overview: overview);
  }

  static _FieldMatch? _findVin(Uint8List data, {required bool requireLetters}) {
    const width = 17;
    for (var i = 0; i + 1 + width <= data.length; i++) {
      if (!VuFieldCodecs.identityCodepages.contains(data[i])) continue;
      final slice = Uint8List.sublistView(data, i + 1, i + 1 + width);
      if (!VuFieldCodecs.isAsciiUpperAlnum(slice)) continue;
      final text = VuFieldCodecs.cleanAsciiText(slice);
      final letters = text
          .split('')
          .where((c) => RegExp(r'[A-Za-z]').hasMatch(c))
          .length;
      final digits = text
          .split('')
          .where((c) => RegExp(r'[0-9]').hasMatch(c))
          .length;
      if (digits < 2) continue;
      if (requireLetters && letters < 2) continue;
      if (VuFieldCodecs.hasLongRun(text, 4)) continue;
      return _FieldMatch(text, i + 1 + width);
    }
    return null;
  }

  static String? _tryReadFieldAt(Uint8List data, int offset, int width) {
    if (offset + 1 + width > data.length) return null;
    if (!VuFieldCodecs.identityCodepages.contains(data[offset])) return null;
    final slice = Uint8List.sublistView(data, offset + 1, offset + 1 + width);
    if (!VuFieldCodecs.isCleanAsciiField(slice)) return null;
    final text = VuFieldCodecs.cleanAsciiText(slice);
    return text.length >= 3 ? text : null;
  }

  static DateTime? _timeRealBroad(VuByteReader reader) {
    if (!reader.canRead(4)) return null;
    return reader.readTimeReal(minYear: 2000, maxYear: 2100);
  }
}

class _FieldMatch {
  final String text;

  final int end;

  const _FieldMatch(this.text, this.end);
}
