import 'dart:typed_data';

class VuByteReader {
  final Uint8List data;
  int _pos;

  VuByteReader(this.data, [int start = 0]) : _pos = start;

  int get position => _pos;
  int get remaining => data.length - _pos;

  bool canRead(int n) => _pos + n <= data.length;

  int readUint8() {
    final v = data[_pos];
    _pos += 1;
    return v;
  }

  int readUint16() {
    final v = (data[_pos] << 8) | data[_pos + 1];
    _pos += 2;
    return v;
  }

  int readUint24() {
    final v = (data[_pos] << 16) | (data[_pos + 1] << 8) | data[_pos + 2];
    _pos += 3;
    return v;
  }

  int readUint32() {
    final v =
        (data[_pos] << 24) |
        (data[_pos + 1] << 16) |
        (data[_pos + 2] << 8) |
        data[_pos + 3];
    _pos += 4;
    return v;
  }

  int readRawEpochSeconds() => readUint32();

  void skip(int n) => _pos += n;

  Uint8List readBytes(int n) {
    final slice = Uint8List.sublistView(data, _pos, _pos + n);
    _pos += n;
    return slice;
  }

  DateTime? readTimeReal({int minYear = 2000, int maxYear = 2100}) {
    final seconds = readUint32();
    if (seconds <= 0) return null;
    final t = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    if (t.year < minYear || t.year > maxYear) return null;
    return t;
  }
}
