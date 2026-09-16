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

class VuBlockFramer {
  VuBlockFramer._();

  static List<VuBlockRange> locateBlocks(Uint8List data) {
    final markers = <int>[];
    for (var i = 0; i + 1 < data.length; i++) {
      if (data[i] == 0x76 && data[i + 1] >= 0x01 && data[i + 1] <= 0x06)
        markers.add(i);
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
