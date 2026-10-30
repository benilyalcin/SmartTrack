import '../../localization/localization.dart';
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
    String t(String key, [Map<String, Object?> args = const {}]) =>
        AppLocalizations.text('rhmi.me.$key', args);

    if (activities.isEmpty) return t('needActivity');
    if (activities.length > maxActivities) {
      return t('maxActivities', {'max': maxActivities});
    }
    if (places.length > maxPlaces) return t('maxPlaces', {'max': maxPlaces});

    final begin = truncateToMinute(period.periodBegin);
    final end = truncateToMinute(period.periodEnd);

    var previous = -1;
    for (var i = 0; i < activities.length; i++) {
      final start = truncateToMinute(activities[i].startSeconds);
      if (start < begin) return t('actBeforePeriod', {'n': i + 1});
      if (start >= end) return t('actAtEnd', {'n': i + 1});
      if (i > 0 && start <= previous) return t('actOrder', {'n': i + 1});
      previous = start;
    }

    var previousPlace = -1;
    var previousWasBegin = false;
    for (var i = 0; i < places.length; i++) {
      final place = places[i];
      final time = truncateToMinute(place.timeSeconds);
      if (time < begin) return t('placeBefore', {'n': i + 1});
      // Zero is "no information available", not a country.
      if (place.countryCode == 0) return t('placeNoCountry', {'n': i + 1});

      // A begin place may sit on the closing minute - where this period
      // starts is the moment of insertion. An end place may not.
      final limit = place.entryType == Rhmi.placeEnd ? end - 60 : end;
      if (time > limit) return t('placeAfter', {'n': i + 1});

      if (i > 0) {
        if (time < previousPlace) return t('placeOrder', {'n': i + 1});
        if (time == previousPlace &&
            !(previousWasBegin && place.entryType == Rhmi.placeEnd)) {
          return t('placeSameMinute', {'n': i + 1});
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
  rest(0),
  available(1),
  work(2),
  unknown(4);

  const ManualActivityType(this.code);
  final int code;

  String get label => AppLocalizations.text('rhmi.activity.$name');
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
