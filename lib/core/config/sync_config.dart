/// Every threshold behind how live, card (DDD) and manual activity data are
/// merged, and when the single line to the unit is given to a card download.
///
/// Values marked `ASSUMPTION:` have not been measured on a real unit yet;
/// change them here once they are, nothing else hard codes them.
class SyncConfig {
  const SyncConfig({
    this.cardDownloadEstDuration = const Duration(minutes: 3),
    this.quietSpeedZeroFor = const Duration(minutes: 5),
    this.forcedQuietSpeedZeroFor = const Duration(minutes: 2),
    this.maxDddAge = const Duration(hours: 24),
    this.periodicSyncInterval = const Duration(hours: 6),
    this.shortGapThreshold = const Duration(minutes: 30),
    this.manualEntryAfter = const Duration(hours: 24),
    this.manualPromptLookback = const Duration(days: 7),
    this.speedRetention = const Duration(hours: 48),
    this.correctionNotifyThreshold = const Duration(minutes: 15),
    this.recordTolerance = const Duration(minutes: 1),
    this.dddLookbackDays = 28,
    this.vuDownloadEnabled = false,
    this.displayUtcOffset = const Duration(hours: 3),
    this.displayZoneName = 'Europe/Istanbul',
    this.abortLeavesUnitStable = true,
    this.cardRecordsReachLastChange = true,
    this.restOnlyWithoutMotionSignal = true,
  });

  static const SyncConfig defaults = SyncConfig();

  // ---- Card download ----

  /// How long one full driver card download takes.
  // ASSUMPTION: not measured yet; a Gen1 card over the ITS download service
  // is guessed at about three minutes.
  final Duration cardDownloadEstDuration;

  /// Whether the unit is left in a usable state when a card download is cut
  /// short with RequestTransferExit + StopCommunication.
  // ASSUMPTION: not tried on a unit yet. When false the scheduler never
  // aborts a download that has started; it lets it run to the end.
  final bool abortLeavesUnitStable;

  /// Whether the card's newest day holds records up to the last activity
  /// change before the download (and so the watermark can sit there).
  // ASSUMPTION: not checked on a unit yet. When false the newest card day
  // is not trusted at all and the watermark stays at its start.
  final bool cardRecordsReachLastChange;

  /// Without a way to see the vehicle move during a download (no location
  /// permission for the phone's GPS), a download only starts while the
  /// unit says rest/break: a stop alone could end at any moment.
  // ASSUMPTION: no live speed can be read from the unit during a card
  // download. The download is one TransferData whose blocks the unit
  // acknowledges in sequence (it answers NRC 0x24, requestSequenceError,
  // to requests out of order), so a ReadDataByIdentifier 0xF902 between
  // blocks would most likely break the transfer. Not tried on a unit yet.
  final bool restOnlyWithoutMotionSignal;

  /// Vehicle unit downloads need a company card; off until that is in place.
  final bool vuDownloadEnabled;

  /// Days asked for when there is no watermark yet (vehicle unit downloads
  /// only; a card download always reads the whole card).
  final int dddLookbackDays;

  // ---- Quiet windows ----

  /// How long the speed must have been 0 before a card download may start.
  /// Never shorter than [cardDownloadEstDuration], see
  /// [effectiveQuietSpeedZeroFor].
  final Duration quietSpeedZeroFor;

  /// The shorter stop that is enough once the card data is stale
  /// ([maxDddAge]).
  final Duration forcedQuietSpeedZeroFor;

  /// The speed-zero threshold in force: a stop shorter than a download is
  /// not a window worth starting one in.
  Duration get effectiveQuietSpeedZeroFor =>
      quietSpeedZeroFor > cardDownloadEstDuration
      ? quietSpeedZeroFor
      : cardDownloadEstDuration;

  // ---- Freshness ----

  /// Card data older than this makes the next download mandatory: it starts
  /// in the next quiet window, with [forcedQuietSpeedZeroFor].
  final Duration maxDddAge;

  /// While connected, a card download is queued this often.
  final Duration periodicSyncInterval;

  /// A loss of contact shorter than this queues no download of its own; the
  /// next periodic one covers it.
  final Duration shortGapThreshold;

  /// A stretch with no record at all becomes a question for the driver once
  /// no card download has covered it for this long.
  final Duration manualEntryAfter;

  /// The driver is only asked about stretches that ended within this long;
  /// older ones stay marked on the timeline. A card holds 28 days, and
  /// asking about every day off in them at once helps nobody.
  final Duration manualPromptLookback;

  // ---- Data ----

  /// Live speed samples are kept this long.
  final Duration speedRetention;

  /// A card record that replaces live or manual data by more than this is
  /// worth telling the driver about.
  final Duration correctionNotifyThreshold;

  /// Records are kept in whole minutes; a hole shorter than this is none.
  final Duration recordTolerance;

  // ---- Display ----

  /// The zone the UI shows times and calendar days in. Data stays in UTC.
  /// Türkiye has kept UTC+3 all year since 2016, so a fixed offset is
  /// enough without a time zone database.
  final Duration displayUtcOffset;
  final String displayZoneName;
}
