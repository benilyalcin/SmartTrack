import 'dart:typed_data';

import '../../models/vehicle_unit_data.dart';
import 'vu_byte_reader.dart';
import 'vu_field_codecs.dart';

class VuOverviewDecoder {
  VuOverviewDecoder._();

  static ({String vin, String vrn, VuOverviewData? overview})? decode(
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
