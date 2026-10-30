import 'dart:typed_data';

class VuBlockRange {
  final int trep;
  final int start;
  final int end;

  const VuBlockRange({
    required this.trep,
    required this.start,
    required this.end,
  });

  int get length => end - start;
}

/// Generation 1 blocks (TREP 0x01-0x06). Gen2 downloads are framed by their
/// RecordArray headers instead and read by VuGen2Decoder.
class VuBlockFramer {
  VuBlockFramer._();

  /// The blocks of a Gen1 download. Each block's length follows from its
  /// structure (Annex 1B, appendix 7) - fixed fields and the record counts
  /// in front of each list - so the file is walked block by block. Only if
  /// that walk does not land exactly on the end of the file is every
  /// `76 0x` byte pair taken for a block start, as before; that guess also
  /// finds the pair inside a block's data (an activity day's change words,
  /// a signature), which once hid a whole detailed speed block.
  static List<VuBlockRange> locateBlocks(Uint8List data) =>
      walkBlocks(data) ?? _scanMarkers(data);

  /// The structural walk; null when the data is not a sequence of Gen1
  /// blocks from start to end.
  static List<VuBlockRange>? walkBlocks(Uint8List data) {
    final ranges = <VuBlockRange>[];
    var i = 0;
    while (i < data.length) {
      if (i + 2 > data.length || data[i] != 0x76) return null;
      final trep = data[i + 1];
      final start = i + 2;
      final end = _blockEnd(data, trep, start);
      if (end == null || end > data.length) return null;
      ranges.add(VuBlockRange(trep: trep, start: start, end: end));
      i = end;
    }
    return ranges.isEmpty ? null : ranges;
  }

  static const int _signature = 128;

  /// Where the block of [trep] that starts (after its two byte header) at
  /// [s] ends, or null for a TREP this walk does not know.
  static int? _blockEnd(Uint8List d, int trep, int s) {
    int? u8(int at) => at < d.length ? d[at] : null;
    int? u16(int at) => at + 1 < d.length ? (d[at] << 8) | d[at + 1] : null;

    switch (trep) {
      case 0x01: // Overview
        // Two certificates, VIN, registration, current time, downloadable
        // period, card slots status, download activity.
        var p = s + 194 + 194 + 17 + 15 + 4 + 8 + 1 + 58;
        final locks = u8(p);
        if (locks == null) return null;
        p += 1 + locks * 98;
        final controls = u8(p);
        if (controls == null) return null;
        p += 1 + controls * 31;
        return p + _signature;
      case 0x02: // Activities of one day
        var p = s + 4 + 3; // date, odometer at midnight
        final insertions = u16(p);
        if (insertions == null) return null;
        p += 2 + insertions * 129;
        final changes = u16(p);
        if (changes == null) return null;
        p += 2 + changes * 2;
        final places = u8(p);
        if (places == null) return null;
        p += 1 + places * 28;
        final conditions = u16(p);
        if (conditions == null) return null;
        p += 2 + conditions * 5;
        return p + _signature;
      case 0x03: // Events and faults
        var p = s;
        final faults = u8(p);
        if (faults == null) return null;
        p += 1 + faults * 82;
        final events = u8(p);
        if (events == null) return null;
        p += 1 + events * 83 + 9; // then the overspeeding control data
        final overspeeding = u8(p);
        if (overspeeding == null) return null;
        p += 1 + overspeeding * 31;
        final adjustments = u8(p);
        if (adjustments == null) return null;
        p += 1 + adjustments * 98;
        return p + _signature;
      case 0x04: // Detailed speed
        final minutes = u16(s);
        if (minutes == null) return null;
        return s + 2 + minutes * 64 + _signature;
      case 0x05: // Technical data
        var p = s + 116 + 20; // VU identification, paired sensor
        final calibrations = u8(p);
        if (calibrations == null) return null;
        p += 1 + calibrations * 167;
        return p + _signature;
    }
    return null;
  }

  static List<VuBlockRange> _scanMarkers(Uint8List data) {
    final markers = <int>[];
    for (var i = 0; i + 1 < data.length; i++) {
      if (data[i] == 0x76 && data[i + 1] >= 0x01 && data[i + 1] <= 0x06) {
        markers.add(i);
      }
    }
    final ranges = <VuBlockRange>[];
    for (var m = 0; m < markers.length; m++) {
      final trep = data[markers[m] + 1];
      final start = markers[m] + 2;
      final end = m + 1 < markers.length ? markers[m + 1] : data.length;
      ranges.add(VuBlockRange(trep: trep, start: start, end: end));
    }
    return ranges;
  }

  static List<Uint8List> slicesFor(
    Uint8List data,
    List<VuBlockRange> ranges,
    int trep,
  ) {
    return [
      for (final r in ranges)
        if (r.trep == trep) Uint8List.sublistView(data, r.start, r.end),
    ];
  }
}
