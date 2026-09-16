import 'dart:math';
import 'dart:typed_data';

import 'driving_time_calculator.dart';
import 'tachograph_parser.dart';

class DddSimulator {
  final Random _rnd;

  DddSimulator({Random? random}) : _rnd = random ?? Random();

  static const _firstNames = [
    'Ahmet',
    'Mehmet',
    'Mustafa',
    'Ali',
    'Hüseyin',
    'İbrahim',
    'Emre',
    'Kemal',
    'Serkan',
    'Yusuf',
  ];
  static const _lastNames = [
    'Yılmaz',
    'Kaya',
    'Demir',
    'Şahin',
    'Çelik',
    'Yıldız',
    'Aydın',
    'Özdemir',
    'Arslan',
    'Doğan',
  ];
  static const _plateCities = ['06', '34', '35', '16', '01', '42'];
  static const _plateLetters = ['ABC', 'KL', 'XYZ', 'MN', 'TR', 'DE'];

  Uint8List generate() {
    final out = BytesBuilder();

    final firstName = _pick(_firstNames);
    final lastName = _pick(_lastNames);
    final now = DateTime.now();

    _writeAscii(out, TachoTags.tagHolderFirstName, firstName);
    _writeAscii(out, TachoTags.tagHolderSurname, lastName);
    _writeAscii(out, TachoTags.tagCardHolderName, '$firstName $lastName');
    _writeAscii(out, TachoTags.tagCardNumber, _randomDigits(16));
    _writeAscii(out, TachoTags.tagCardIssuingMemberState, 'TUR');
    _writeAscii(out, TachoTags.tagLanguage, 'tr');
    _writeAscii(out, TachoTags.tagLicenseNumber, _randomDigits(9));
    _writeAscii(out, TachoTags.tagVehicleReg, _randomPlate());

    final birthYearsAgo = 22 + _rnd.nextInt(38);
    _writeEpoch(
      out,
      TachoTags.tagDateOfBirth,
      DateTime(
        now.year - birthYearsAgo,
        1 + _rnd.nextInt(12),
        1 + _rnd.nextInt(28),
      ),
    );

    final issuedDaysAgo = 30 + _rnd.nextInt(5 * 365 - 60);
    final issueDate = now.subtract(Duration(days: issuedDaysAgo));
    _writeEpoch(out, TachoTags.tagCardIssueDate, issueDate);
    _writeEpoch(
      out,
      TachoTags.tagCardExpiryDate,
      issueDate.add(const Duration(days: 5 * 365)),
    );

    _writeInt(
      out,
      TachoTags.tagOdometer,
      50000 + _rnd.nextInt(400000),
      byteLen: 4,
    );
    _writeInt(out, TachoTags.tagSpeed, _rnd.nextInt(91), byteLen: 1);

    final currentDriving = _rnd.nextInt(4 * 60 + 30);
    final dailyDriving = currentDriving + _rnd.nextInt(5 * 60);
    final weeklyDriving = dailyDriving + _rnd.nextInt(40 * 60);
    final biWeeklyDriving = weeklyDriving + _rnd.nextInt(50 * 60);
    _writeInt(out, TachoTags.tagDrivingTime, currentDriving, byteLen: 2);
    _writeInt(out, TachoTags.tagDailyDrivingTime, dailyDriving, byteLen: 2);
    _writeInt(out, TachoTags.tagWeeklyDrivingTime, weeklyDriving, byteLen: 2);
    _writeInt(
      out,
      TachoTags.tagBiWeeklyDrivingTime,
      biWeeklyDriving,
      byteLen: 2,
    );
    _writeInt(
      out,
      TachoTags.tagLastBreakDuration,
      _rnd.nextInt(46),
      byteLen: 2,
    );
    _writeInt(
      out,
      TachoTags.tagBreakRemaining,
      max(0, 270 - currentDriving),
      byteLen: 2,
    );

    _writeActivityLog(out, now);
    _writeRandomEventsAndFaults(out, now);

    return out.toBytes();
  }

  void _writeActivityLog(BytesBuilder out, DateTime now) {
    const weights = [
      ActivityType.driving,
      ActivityType.driving,
      ActivityType.rest,
      ActivityType.available,
      ActivityType.work,
    ];

    final segments = <List<int>>[];
    var cursor = now.subtract(const Duration(hours: 24));
    while (cursor.isBefore(now) && segments.length < 30) {
      final type = _pick(weights);
      final durationMin = 15 + _rnd.nextInt(4 * 60);
      var end = cursor.add(Duration(minutes: durationMin));
      if (end.isAfter(now)) end = now;

      segments.add([
        ActivityType.values.indexOf(type),
        ..._epochBytes(cursor),
        ..._epochBytes(end),
        0,
        DriverSlot.driver.index,
      ]);
      cursor = end;
    }

    if (segments.length % 9 == 0 && segments.isNotEmpty) {
      final last = segments.removeLast();
      final lastStart = _bytesToEpoch(last, 1);
      final mid = lastStart.add(
        Duration(
          minutes:
              (_bytesToEpoch(last, 5).difference(lastStart).inMinutes) ~/ 2,
        ),
      );
      segments.add([
        last[0],
        ..._epochBytes(lastStart),
        ..._epochBytes(mid),
        last[9],
        last[10],
      ]);
      segments.add([
        last[0],
        ..._epochBytes(mid),
        ..._epochBytes(_bytesToEpoch(last, 5)),
        last[9],
        last[10],
      ]);
    }

    final value = segments.expand((s) => s).toList();
    _writeTlv(out, TachoTags.tagActivityRecord, value);
  }

  void _writeRandomEventsAndFaults(BytesBuilder out, DateTime now) {
    final eventCodes = [
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x09,
      0x0A,
    ];
    final faultCodes = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06];

    final eventCount = _rnd.nextInt(4);
    for (var i = 0; i < eventCount; i++) {
      final ts = now.subtract(Duration(hours: _rnd.nextInt(72)));
      _writeTlv(out, TachoTags.tagEventCode, [
        _pick(eventCodes),
        ..._epochBytes(ts),
      ]);
    }
    final faultCount = _rnd.nextInt(3);
    for (var i = 0; i < faultCount; i++) {
      final ts = now.subtract(Duration(hours: _rnd.nextInt(72)));
      _writeTlv(out, TachoTags.tagFaultCode, [
        _pick(faultCodes),
        ..._epochBytes(ts),
      ]);
    }
  }

  T _pick<T>(List<T> options) => options[_rnd.nextInt(options.length)];

  String _randomDigits(int count) =>
      List.generate(count, (_) => _rnd.nextInt(10)).join();

  String _randomPlate() =>
      '${_pick(_plateCities)} ${_pick(_plateLetters)} ${100 + _rnd.nextInt(900)}';

  List<int> _epochBytes(DateTime dt) {
    final secs = dt.toUtc().millisecondsSinceEpoch ~/ 1000;
    return [
      (secs >> 24) & 0xFF,
      (secs >> 16) & 0xFF,
      (secs >> 8) & 0xFF,
      secs & 0xFF,
    ];
  }

  DateTime _bytesToEpoch(List<int> record, int offset) {
    final secs =
        (record[offset] << 24) |
        (record[offset + 1] << 16) |
        (record[offset + 2] << 8) |
        record[offset + 3];
    return DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true);
  }

  void _writeAscii(BytesBuilder out, int tag, String value) =>
      _writeTlv(out, tag, value.codeUnits);

  void _writeEpoch(BytesBuilder out, int tag, DateTime value) =>
      _writeTlv(out, tag, _epochBytes(value));

  void _writeInt(BytesBuilder out, int tag, int value, {required int byteLen}) {
    final bytes = <int>[];
    for (var i = byteLen - 1; i >= 0; i--) {
      bytes.add((value >> (8 * i)) & 0xFF);
    }
    _writeTlv(out, tag, bytes);
  }

  void _writeTlv(BytesBuilder out, int tag, List<int> value) {
    out.addByte(tag);
    if (value.length < 128) {
      out.addByte(value.length);
    } else {
      out.addByte(0x81);
      out.addByte(value.length & 0xFF);
    }
    out.add(value);
  }
}
