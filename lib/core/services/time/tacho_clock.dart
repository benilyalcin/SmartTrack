/// The tachograph's clock, as seen from the phone.
///
/// Live samples are stamped with the unit's time, not the phone's: the
/// card records the unit writes are in unit time, so the two only line up
/// when the live data is too. The unit's CurrentDateTime is read now and
/// then (at the handshake); in between, the phone's clock plus the offset
/// seen at the last reading stands in for it. Until a first reading there
/// is no offset and the phone's own UTC time is used.
class TachoClock {
  TachoClock({DateTime Function()? phoneNow})
    : _phoneNow = phoneNow ?? DateTime.now;

  final DateTime Function() _phoneNow;

  /// Unit time minus phone time; null before a first reading.
  Duration? _offset;
  Duration? get offset => _offset;

  bool get isSynced => _offset != null;

  /// Takes a reading of the unit's clock, [tachoUtc], made at [readAt]
  /// phone time (now when left out).
  void sync(DateTime tachoUtc, {DateTime? readAt}) {
    _offset = tachoUtc.toUtc().difference((readAt ?? _phoneNow()).toUtc());
  }

  /// Puts back an offset kept from an earlier session.
  void restore(Duration? offset) => _offset = offset;

  /// Unit time now, in UTC.
  DateTime nowUtc() => toUnitTime(_phoneNow());

  /// The unit time at phone time [phoneTime], in UTC.
  DateTime toUnitTime(DateTime phoneTime) =>
      phoneTime.toUtc().add(_offset ?? Duration.zero);
}
