import 'dart:typed_data';

import '../../models/vehicle_unit_data.dart';
import 'vu_byte_reader.dart';
import 'vu_field_codecs.dart';

class VuEventsDecoder {
  VuEventsDecoder._();

  static const int _eventRecordWidth = 83;
  static const int _faultRecordWidth = 82;
  static const int _overspeedRecordWidth = 31;

  static List<VuEventOrFault> decode(Uint8List block) {
    final result = <VuEventOrFault>[];
    final claimed = List<bool>.filled(block.length, false);

    void scan(int width, bool isFault) {
      for (var offset = 0; offset + width <= block.length; offset++) {
        if (claimed[offset]) continue;
        final record = _tryParseEventOrFault(block, offset, width, isFault);
        if (record == null) continue;
        result.add(record);
        for (var i = offset; i < offset + width; i++) {
          claimed[i] = true;
        }
      }
    }

    scan(_eventRecordWidth, false);
    scan(_faultRecordWidth, true);

    result.sort(
      (a, b) =>
          (b.beginTime ?? DateTime(0)).compareTo(a.beginTime ?? DateTime(0)),
    );
    return result;
  }

  static VuEventOrFault? _tryParseEventOrFault(
    Uint8List data,
    int offset,
    int width,
    bool isFault,
  ) {
    final reader = VuByteReader(data, offset);
    final type = reader.readUint8();
    final purpose = reader.readUint8();

    if (type == 0 || type > 30) return null;
    if (purpose > 10) return null;

    final beginTime = _timeReal(reader);
    if (beginTime == null) return null;
    final endTime = _timeReal(reader);
    if (endTime != null) {
      if (endTime.isBefore(beginTime)) return null;

      if (endTime.difference(beginTime).inDays > 400) return null;
    }

    final cardFields = <String>[];
    for (var i = 0; i < 4; i++) {
      final card = _tryReadFullCardNumber(reader);
      if (card == null) return null;
      cardFields.add(card);
    }

    final similarEventsNumber = isFault ? 0 : reader.readUint8();

    return VuEventOrFault(
      type: type,
      recordPurpose: purpose,
      isFault: isFault,
      beginTime: beginTime,
      endTime: endTime,
      driverCardNumber: cardFields[0],
      codriverCardNumber: cardFields[1],
      similarEventsNumber: similarEventsNumber,
    );
  }

  static List<VuOverspeedingEvent> decodeOverspeeding(Uint8List block) {
    final result = <VuOverspeedingEvent>[];
    final claimed = List<bool>.filled(block.length, false);
    for (
      var offset = 0;
      offset + _overspeedRecordWidth <= block.length;
      offset++
    ) {
      if (claimed[offset]) continue;
      final event = _tryParseOverspeed(block, offset);
      if (event == null) continue;
      result.add(event);
      for (var i = offset; i < offset + _overspeedRecordWidth; i++) {
        claimed[i] = true;
      }
    }
    result.sort(
      (a, b) =>
          (b.beginTime ?? DateTime(0)).compareTo(a.beginTime ?? DateTime(0)),
    );
    return result;
  }

  static VuOverspeedingEvent? _tryParseOverspeed(Uint8List data, int offset) {
    final reader = VuByteReader(data, offset);
    final type = reader.readUint8();
    final purpose = reader.readUint8();

    if (type != 7) return null;
    if (purpose > 10) return null;

    final beginTime = _timeReal(reader);
    if (beginTime == null) return null;
    final endTime = _timeReal(reader);
    if (endTime != null && endTime.isBefore(beginTime)) return null;

    final maxSpeed = reader.readUint8();
    final avgSpeed = reader.readUint8();

    if (maxSpeed < 70 || maxSpeed > 250 || avgSpeed > maxSpeed) return null;

    final card = _tryReadFullCardNumber(reader);
    if (card == null) return null;

    final similarEventsNumber = reader.readUint8();

    return VuOverspeedingEvent(
      beginTime: beginTime,
      endTime: endTime,
      maxSpeedKmh: maxSpeed,
      avgSpeedKmh: avgSpeed,
      driverCardNumber: card,
      similarEventsNumber: similarEventsNumber,
    );
  }

  static String? _tryReadFullCardNumber(VuByteReader reader) {
    final slice = reader.readBytes(18);
    if (slice.every((b) => b == 0)) return '';
    final numberSlice = Uint8List.sublistView(slice, 2, 18);
    if (!VuFieldCodecs.isCleanAsciiField(numberSlice)) return null;
    final text = VuFieldCodecs.cleanAsciiText(numberSlice);
    if (text.isNotEmpty && VuFieldCodecs.hasLongRun(text, 4)) return null;
    return text;
  }

  static DateTime? _timeReal(VuByteReader reader) {
    if (!reader.canRead(4)) return null;
    return reader.readTimeReal(minYear: 2015, maxYear: 2035);
  }
}
