import 'dart:typed_data';

import '../../models/vehicle_unit_data.dart';
import 'vu_byte_reader.dart';
import 'vu_field_codecs.dart';

class VuEventsDecoder {
  VuEventsDecoder._();

  static const int _eventRecordWidth = 83;
  static const int _faultRecordWidth = 82;
  static const int _overspeedRecordWidth = 31;

  /// The faults and events of a TREP 0x03 block. The block is read by its
  /// structure - a count in front of each list (Annex 1B) - and only when
  /// that does not add up to the block is it searched record by record.
  /// The search kept to event types up to 30, so it never found a fault:
  /// fault types run from 0x30 up.
  static List<VuEventOrFault> decode(Uint8List block) =>
      _structured(block)?.items ?? _search(block);

  static List<VuEventOrFault> _search(Uint8List block) {
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

  static List<VuOverspeedingEvent> decodeOverspeeding(Uint8List block) =>
      _structured(block)?.overspeeding ?? _searchOverspeeding(block);

  static List<VuOverspeedingEvent> _searchOverspeeding(Uint8List block) {
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

  static const int _signatureLength = 128;
  static const int _overspeedControlWidth = 9;
  static const int _timeAdjustmentWidth = 98;

  /// VuFaultData, VuEventData, VuOverSpeedingControlData,
  /// VuOverSpeedingEventData and VuTimeAdjustmentData in a row, then the
  /// signature. Null unless the counts account for the block exactly.
  static ({List<VuEventOrFault> items, List<VuOverspeedingEvent> overspeeding})?
  _structured(Uint8List b) {
    var p = 0;
    int? take(int width) {
      if (p >= b.length) return null;
      final n = b[p];
      if (p + 1 + n * width > b.length) return null;
      final first = p + 1;
      p = first + n * width;
      return n;
    }

    final faultsAt = p + 1;
    final faults = take(_faultRecordWidth);
    if (faults == null) return null;
    final eventsAt = p + 1;
    final events = take(_eventRecordWidth);
    if (events == null) return null;
    p += _overspeedControlWidth;
    final overspeedAt = p + 1;
    final overspeeding = take(_overspeedRecordWidth);
    if (overspeeding == null) return null;
    if (take(_timeAdjustmentWidth) == null) return null;
    if (p + _signatureLength != b.length) return null;

    final items = <VuEventOrFault>[
      for (var k = 0; k < faults; k++)
        _record(b, faultsAt + k * _faultRecordWidth, isFault: true),
      for (var k = 0; k < events; k++)
        _record(b, eventsAt + k * _eventRecordWidth, isFault: false),
    ];
    items.sort(
      (a, b) =>
          (b.beginTime ?? DateTime(0)).compareTo(a.beginTime ?? DateTime(0)),
    );
    final over = <VuOverspeedingEvent>[
      for (var k = 0; k < overspeeding; k++)
        _overspeedRecord(b, overspeedAt + k * _overspeedRecordWidth),
    ];
    over.sort(
      (a, b) =>
          (b.beginTime ?? DateTime(0)).compareTo(a.beginTime ?? DateTime(0)),
    );
    return (items: items, overspeeding: over);
  }

  /// One VuFaultRecord (82 bytes) or VuEventRecord (83, with the similar
  /// events number at the end), read as it stands.
  static VuEventOrFault _record(Uint8List b, int at, {required bool isFault}) {
    return VuEventOrFault(
      type: b[at],
      recordPurpose: b[at + 1],
      isFault: isFault,
      beginTime: _timeAt(b, at + 2),
      endTime: _timeAt(b, at + 6),
      driverCardNumber: _cardAt(b, at + 10),
      codriverCardNumber: _cardAt(b, at + 28),
      similarEventsNumber: isFault ? 0 : b[at + 82],
    );
  }

  static VuOverspeedingEvent _overspeedRecord(Uint8List b, int at) {
    return VuOverspeedingEvent(
      beginTime: _timeAt(b, at + 2),
      endTime: _timeAt(b, at + 6),
      maxSpeedKmh: b[at + 10],
      avgSpeedKmh: b[at + 11],
      driverCardNumber: _cardAt(b, at + 12),
      similarEventsNumber: b[at + 30],
    );
  }

  /// A TimeReal; null for the "not set" values 0 and 0xFFFFFFFF. A unit
  /// that lost power before its clock was set records 2000-01-01, and
  /// that stays as it is.
  static DateTime? _timeAt(Uint8List b, int at) {
    final seconds =
        (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
    if (seconds == 0 || seconds == 0xFFFFFFFF) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// The card number of a FullCardNumber (type, nation, 16 characters);
  /// empty when no card is recorded.
  static String _cardAt(Uint8List b, int at) {
    final slice = Uint8List.sublistView(b, at, at + 18);
    if (slice[0] == 0 || slice.every((x) => x == 0 || x == 0xFF)) return '';
    final number = Uint8List.sublistView(slice, 2, 18);
    if (!VuFieldCodecs.isCleanAsciiField(number)) return '';
    return VuFieldCodecs.cleanAsciiText(number);
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
