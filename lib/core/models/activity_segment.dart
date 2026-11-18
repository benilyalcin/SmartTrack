import '../services/driving_time_calculator.dart';

/// Where a segment comes from, in order of trust: a card (DDD) record
/// always wins over a live sample, and a live sample over a manual entry.
enum SegmentSource { ddd, live, manual }

/// How far a segment can be relied on.
enum SegmentStatus {
  /// From a card file, up to its watermark.
  confirmed,

  /// Live or manual; a later card file can replace it.
  provisional,

  /// No record yet, but the unit keeps recording: the next card download
  /// fills it. Never asked about.
  pendingGap,

  /// No record, and none to come: the card covers it with nothing (card
  /// not inserted), or no card download has covered it for too long. The
  /// driver is asked about it.
  needsManual,
}

/// One stretch of one driver's day, in UTC.
class ActivitySegment {
  const ActivitySegment({
    required this.id,
    required this.driverId,
    required this.startUtc,
    required this.endUtc,
    required this.activityType,
    required this.source,
    required this.status,
    required this.createdAt,
    this.supersededBy,
    this.note,
    this.slot = DriverSlot.driver,
    this.isCrew = false,
    this.recordPresenceCounter,
  });

  final String id;

  /// 'driver1' or 'driver2', as AppState names the two slots.
  final String driverId;

  final DateTime startUtc;

  /// Null while it is still going on (the live segment open now).
  final DateTime? endUtc;

  /// [ActivityType.unknown] for gaps.
  final ActivityType activityType;

  final SegmentSource source;
  final SegmentStatus status;
  final DateTime createdAt;

  /// Set when a card record has replaced this one: what replaced it. The
  /// segment is kept, not deleted, so the change can be shown.
  final String? supersededBy;

  final String? note;
  final DriverSlot slot;
  final bool isCrew;
  final int? recordPresenceCounter;

  bool get isSuperseded => supersededBy != null;
  bool get isGap =>
      status == SegmentStatus.pendingGap || status == SegmentStatus.needsManual;

  /// The end, or [now] for a segment still going on.
  DateTime endOr(DateTime now) => endUtc ?? now;

  ActivitySegment copyWith({
    DateTime? startUtc,
    DateTime? endUtc,
    bool clearEnd = false,
    SegmentStatus? status,
    String? supersededBy,
    String? id,
  }) => ActivitySegment(
    id: id ?? this.id,
    driverId: driverId,
    startUtc: startUtc ?? this.startUtc,
    endUtc: clearEnd ? null : (endUtc ?? this.endUtc),
    activityType: activityType,
    source: source,
    status: status ?? this.status,
    createdAt: createdAt,
    supersededBy: supersededBy ?? this.supersededBy,
    note: note,
    slot: slot,
    isCrew: isCrew,
    recordPresenceCounter: recordPresenceCounter,
  );

  /// The shape the calculators, the analyzer and the pages work with.
  TachographActivity toActivity(DateTime now) => TachographActivity(
    type: activityType,
    startTime: startUtc,
    endTime: endOr(now),
    isManualEntry: source == SegmentSource.manual,
    note: note,
    slot: slot,
    isCrew: isCrew,
    recordPresenceCounter: recordPresenceCounter,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'driver': driverId,
    'start': startUtc.toUtc().toIso8601String(),
    'end': endUtc?.toUtc().toIso8601String(),
    'type': activityType.name,
    'source': source.name,
    'status': status.name,
    'created': createdAt.toUtc().toIso8601String(),
    if (supersededBy != null) 'supersededBy': supersededBy,
    if (note != null) 'note': note,
    if (slot != DriverSlot.driver) 'slot': slot.name,
    if (isCrew) 'crew': true,
    if (recordPresenceCounter != null) 'counter': recordPresenceCounter,
  };

  factory ActivitySegment.fromJson(Map<String, dynamic> json) =>
      ActivitySegment(
        id: json['id'] as String,
        driverId: json['driver'] as String,
        startUtc: DateTime.parse(json['start'] as String).toUtc(),
        endUtc: (json['end'] as String?) == null
            ? null
            : DateTime.parse(json['end'] as String).toUtc(),
        activityType: ActivityType.values.byName(json['type'] as String),
        source: SegmentSource.values.byName(json['source'] as String),
        status: SegmentStatus.values.byName(json['status'] as String),
        createdAt: DateTime.parse(json['created'] as String).toUtc(),
        supersededBy: json['supersededBy'] as String?,
        note: json['note'] as String?,
        slot: DriverSlot.values.byName(
          json['slot'] as String? ?? DriverSlot.driver.name,
        ),
        isCrew: json['crew'] as bool? ?? false,
        recordPresenceCounter: json['counter'] as int?,
      );
}

/// What is known about how far each driver's data has been confirmed.
class SyncState {
  const SyncState({
    required this.driverId,
    this.dddWatermarkUtc,
    this.lastDddDownloadAt,
    this.lastLiveSampleUtc,
  });

  final String driverId;

  /// The last moment a card file confirms: its last activity change. The
  /// activity under way from there on has no end in the file yet.
  final DateTime? dddWatermarkUtc;

  final DateTime? lastDddDownloadAt;
  final DateTime? lastLiveSampleUtc;

  SyncState copyWith({
    DateTime? dddWatermarkUtc,
    DateTime? lastDddDownloadAt,
    DateTime? lastLiveSampleUtc,
  }) => SyncState(
    driverId: driverId,
    dddWatermarkUtc: dddWatermarkUtc ?? this.dddWatermarkUtc,
    lastDddDownloadAt: lastDddDownloadAt ?? this.lastDddDownloadAt,
    lastLiveSampleUtc: lastLiveSampleUtc ?? this.lastLiveSampleUtc,
  );

  Map<String, dynamic> toJson() => {
    'driver': driverId,
    'watermark': dddWatermarkUtc?.toUtc().toIso8601String(),
    'lastDdd': lastDddDownloadAt?.toUtc().toIso8601String(),
    'lastLive': lastLiveSampleUtc?.toUtc().toIso8601String(),
  };

  factory SyncState.fromJson(Map<String, dynamic> json) => SyncState(
    driverId: json['driver'] as String,
    dddWatermarkUtc: _date(json['watermark']),
    lastDddDownloadAt: _date(json['lastDdd']),
    lastLiveSampleUtc: _date(json['lastLive']),
  );
}

/// A card record replacing a live or manual segment: kept so the app can
/// say what it corrected.
class CorrectionLogEntry {
  const CorrectionLogEntry({
    required this.at,
    required this.supersededId,
    required this.supersededSource,
    required this.supersededType,
    required this.startUtc,
    required this.endUtc,
    required this.dddSegmentIds,
    required this.differingTime,
    this.notified = false,
  });

  final DateTime at;
  final String supersededId;
  final SegmentSource supersededSource;
  final ActivityType supersededType;
  final DateTime startUtc;
  final DateTime endUtc;

  /// The card segments that now cover the stretch.
  final List<String> dddSegmentIds;

  /// How much of the stretch the card says was a different activity.
  final Duration differingTime;

  final bool notified;

  CorrectionLogEntry markNotified() => CorrectionLogEntry(
    at: at,
    supersededId: supersededId,
    supersededSource: supersededSource,
    supersededType: supersededType,
    startUtc: startUtc,
    endUtc: endUtc,
    dddSegmentIds: dddSegmentIds,
    differingTime: differingTime,
    notified: true,
  );

  Map<String, dynamic> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'id': supersededId,
    'source': supersededSource.name,
    'type': supersededType.name,
    'start': startUtc.toUtc().toIso8601String(),
    'end': endUtc.toUtc().toIso8601String(),
    'ddd': dddSegmentIds,
    'differMs': differingTime.inMilliseconds,
    'notified': notified,
  };

  factory CorrectionLogEntry.fromJson(Map<String, dynamic> json) =>
      CorrectionLogEntry(
        at: DateTime.parse(json['at'] as String).toUtc(),
        supersededId: json['id'] as String,
        supersededSource: SegmentSource.values.byName(json['source'] as String),
        supersededType: ActivityType.values.byName(json['type'] as String),
        startUtc: DateTime.parse(json['start'] as String).toUtc(),
        endUtc: DateTime.parse(json['end'] as String).toUtc(),
        dddSegmentIds: (json['ddd'] as List<dynamic>).cast<String>(),
        differingTime: Duration(milliseconds: json['differMs'] as int),
        notified: json['notified'] as bool? ?? false,
      );
}

/// One live speed reading.
class SpeedSample {
  const SpeedSample({required this.tsUtc, required this.kmh});

  final DateTime tsUtc;
  final int kmh;

  /// Kept as `[epoch ms, km/h]`: there can be thousands of them.
  List<int> toJson() => [tsUtc.millisecondsSinceEpoch, kmh];

  factory SpeedSample.fromJson(List<dynamic> json) => SpeedSample(
    tsUtc: DateTime.fromMillisecondsSinceEpoch(json[0] as int, isUtc: true),
    kmh: json[1] as int,
  );
}

DateTime? _date(Object? iso) =>
    iso is String ? DateTime.parse(iso).toUtc() : null;
