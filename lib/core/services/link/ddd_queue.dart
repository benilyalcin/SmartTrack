/// One piece of card data still to fetch.
enum DddJobKind {
  /// A whole driver card download. Cards are read whole: no per-day parts.
  card,

  /// One UTC day of vehicle unit activities. Only with
  /// SyncConfig.vuDownloadEnabled (needs a company card).
  vuDay,
}

class DddJob {
  const DddJob({required this.kind, required this.enqueuedAt, this.day});

  final DddJobKind kind;
  final DateTime enqueuedAt;

  /// The UTC day, for [DddJobKind.vuDay].
  final DateTime? day;

  String get key =>
      kind == DddJobKind.card ? 'card' : 'vu:${day!.toIso8601String()}';
}

/// The card data still to fetch, newest first: there is at most one card
/// job, and vehicle unit days are taken from today backwards.
class DddQueue {
  final List<DddJob> _jobs = [];

  List<DddJob> get jobs => List.unmodifiable(_jobs);
  bool get isEmpty => _jobs.isEmpty;
  bool get isNotEmpty => _jobs.isNotEmpty;
  bool get hasCardJob => _jobs.any((j) => j.kind == DddJobKind.card);

  /// Adds [job] unless the same is already waiting.
  bool add(DddJob job) {
    if (_jobs.any((j) => j.key == job.key)) return false;
    _jobs.add(job);
    _sort();
    return true;
  }

  /// The UTC days from [from] to [to], one vehicle unit job each.
  void addVuDays(DateTime from, DateTime to, DateTime now) {
    for (
      var d = DateTime.utc(from.year, from.month, from.day);
      !d.isAfter(to);
      d = DateTime.utc(d.year, d.month, d.day + 1)
    ) {
      add(DddJob(kind: DddJobKind.vuDay, enqueuedAt: now, day: d));
    }
  }

  DddJob? get next => _jobs.isEmpty ? null : _jobs.first;

  /// Takes [job] off once it is done.
  void complete(DddJob job) => _jobs.removeWhere((j) => j.key == job.key);

  /// Puts back an aborted [job]; it stays first in its place.
  void requeue(DddJob job) => add(job);

  void clear() => _jobs.clear();

  void _sort() => _jobs.sort((a, b) {
    // The card (the driver's own record) before vehicle unit days, then the
    // newest day first.
    if (a.kind != b.kind) return a.kind == DddJobKind.card ? -1 : 1;
    if (a.day != null && b.day != null) return b.day!.compareTo(a.day!);
    return a.enqueuedAt.compareTo(b.enqueuedAt);
  });
}
