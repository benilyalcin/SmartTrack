import 'rhmi.dart';

/// ManualEntryActivitiesAndPlaces - the body a StartRoutine on 0xF200
/// carries, built the way the unit's RhmiManualEntry::parse reads it: a count
/// of activity changes and that many five byte records, then a count of
/// places and that many seven byte records. A port of ManualEntryBuilder.kt.
class ManualEntry {
  ManualEntry._();

  static const int maxActivities = 40;
  static const int maxPlaces = 5;

  /// Every time in a manual entry is a whole minute; the unit truncates
  /// before comparing.
  static int truncateToMinute(int seconds) => seconds - seconds % 60;

  /// Why a body would not be accepted, checked here so a mistake shows in the
  /// app rather than as a bare requestOutOfRange. An activity may begin at
  /// the start of the period but not at its end: one beginning at the moment
  /// of insertion belongs to the present, not to the gap being filled in.
  static String? validate(
    List<ManualActivity> activities,
    List<ManualPlace> places,
    ManualEntryPeriod period,
  ) {
    if (activities.isEmpty) return 'en az bir aktivite gerekli';
    if (activities.length > maxActivities) {
      return 'en fazla $maxActivities aktivite';
    }
    if (places.length > maxPlaces) return 'en fazla $maxPlaces yer';

    final begin = truncateToMinute(period.periodBegin);
    final end = truncateToMinute(period.periodEnd);

    var previous = -1;
    for (var i = 0; i < activities.length; i++) {
      final start = truncateToMinute(activities[i].startSeconds);
      if (start < begin) return '${i + 1}. aktivite dönemden önce başlıyor';
      if (start >= end) {
        return '${i + 1}. aktivite dönem bitiminde ya da sonrasında';
      }
      if (i > 0 && start <= previous) {
        return '${i + 1}. aktivite öncekinden sonra başlamıyor';
      }
      previous = start;
    }

    var previousPlace = -1;
    var previousWasBegin = false;
    for (var i = 0; i < places.length; i++) {
      final place = places[i];
      final time = truncateToMinute(place.timeSeconds);
      if (time < begin) return '${i + 1}. yer dönemden önce';
      // Zero is "no information available", not a country.
      if (place.countryCode == 0) return '${i + 1}. yerin ülkesi yok';

      // A begin place may sit on the closing minute - where this period
      // starts is the moment of insertion. An end place may not.
      final limit = place.entryType == Rhmi.placeEnd ? end - 60 : end;
      if (time > limit) return '${i + 1}. yer dönemden sonra';

      if (i > 0) {
        if (time < previousPlace) return '${i + 1}. yer öncekinden önce';
        if (time == previousPlace &&
            !(previousWasBegin && place.entryType == Rhmi.placeEnd)) {
          return '${i + 1}. yer öncekiyle aynı dakikada';
        }
      }
      previousPlace = time;
      previousWasBegin = place.entryType == Rhmi.placeBegin;
    }
    return null;
  }

  static List<int> build(
    List<ManualActivity> activities,
    List<ManualPlace> places,
  ) => [
    activities.length,
    for (final a in activities) ...[
      ...Rhmi.u32(truncateToMinute(a.startSeconds)),
      a.activity.code,
    ],
    places.length,
    for (final p in places) ...[
      ...Rhmi.u32(truncateToMinute(p.timeSeconds)),
      p.entryType,
      p.countryCode,
      p.regionCode,
    ],
  ];
}

/// The activities a manual entry may carry. Driving is absent: the unit
/// refuses it, since driving is recorded by the motion sensor.
enum ManualActivityType {
  rest(0, 'Dinlenme / mola'),
  available(1, 'Hazır bulunma'),
  work(2, 'Diğer iş'),
  unknown(4, 'Bilinmiyor');

  const ManualActivityType(this.code, this.label);
  final int code;
  final String label;
}

class ManualActivity {
  const ManualActivity(this.startSeconds, this.activity);
  final int startSeconds;
  final ManualActivityType activity;
}

class ManualPlace {
  const ManualPlace(
    this.timeSeconds,
    this.entryType,
    this.countryCode,
    this.regionCode,
  );
  final int timeSeconds;
  final int entryType;
  final int countryCode;
  final int regionCode;
}
