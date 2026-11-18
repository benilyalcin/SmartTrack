import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/sync_config.dart';
import '../models/activity_segment.dart';

/// Where [ActivityStore] keeps its JSON.
abstract class StoreBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PrefsStoreBackend implements StoreBackend {
  const PrefsStoreBackend();

  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

class MemoryStoreBackend implements StoreBackend {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Everything the merge engine works on, for both drivers.
class ActivityStoreState {
  const ActivityStoreState({
    this.segments = const [],
    this.syncStates = const {},
    this.corrections = const [],
  });

  /// All segments, superseded ones included, oldest first.
  final List<ActivitySegment> segments;
  final Map<String, SyncState> syncStates;
  final List<CorrectionLogEntry> corrections;

  SyncState syncOf(String driverId) =>
      syncStates[driverId] ?? SyncState(driverId: driverId);

  /// [driverId]'s segments still in force, oldest first.
  List<ActivitySegment> activeFor(String driverId) => [
    for (final s in segments)
      if (s.driverId == driverId && !s.isSuperseded) s,
  ];

  ActivityStoreState copyWith({
    List<ActivitySegment>? segments,
    Map<String, SyncState>? syncStates,
    List<CorrectionLogEntry>? corrections,
  }) => ActivityStoreState(
    segments: segments ?? this.segments,
    syncStates: syncStates ?? this.syncStates,
    corrections: corrections ?? this.corrections,
  );

  Map<String, dynamic> toJson() => {
    'segments': [for (final s in segments) s.toJson()],
    'sync': [for (final s in syncStates.values) s.toJson()],
    'corrections': [for (final c in corrections) c.toJson()],
  };

  factory ActivityStoreState.fromJson(Map<String, dynamic> json) {
    final sync = [
      for (final s in json['sync'] as List<dynamic>? ?? const [])
        SyncState.fromJson(s as Map<String, dynamic>),
    ];
    return ActivityStoreState(
      segments: [
        for (final s in json['segments'] as List<dynamic>? ?? const [])
          ActivitySegment.fromJson(s as Map<String, dynamic>),
      ]..sort((a, b) => a.startUtc.compareTo(b.startUtc)),
      syncStates: {for (final s in sync) s.driverId: s},
      corrections: [
        for (final c in json['corrections'] as List<dynamic>? ?? const [])
          CorrectionLogEntry.fromJson(c as Map<String, dynamic>),
      ],
    );
  }
}

/// Keeps the activity segments, sync states, correction log and live speed
/// samples, and writes them through [backend].
///
/// It only stores; what goes in is decided by the merge engine.
class ActivityStore {
  ActivityStore({
    this.backend = const PrefsStoreBackend(),
    this.config = SyncConfig.defaults,
  });

  static const stateKey = 'activityStore.v1';
  static const speedKey = 'speedSamples.v1';

  final StoreBackend backend;
  final SyncConfig config;

  ActivityStoreState _state = const ActivityStoreState();
  ActivityStoreState get state => _state;

  final List<SpeedSample> _speed = [];
  List<SpeedSample> get speedSamples => List.unmodifiable(_speed);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Whether there was a stored state; false on the very first start.
  bool _hadState = false;
  bool get hadStoredState => _hadState;

  Future<void> load() async {
    final raw = await backend.read(stateKey);
    if (raw != null && raw.isNotEmpty) {
      _state = ActivityStoreState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _hadState = true;
    }
    final speedRaw = await backend.read(speedKey);
    if (speedRaw != null && speedRaw.isNotEmpty) {
      _speed
        ..clear()
        ..addAll([
          for (final s in jsonDecode(speedRaw) as List<dynamic>)
            SpeedSample.fromJson(s as List<dynamic>),
        ]);
    }
    _loaded = true;
  }

  /// Replaces the state and writes it.
  Future<void> replace(ActivityStoreState next) async {
    _state = next;
    await backend.write(stateKey, jsonEncode(next.toJson()));
  }

  DateTime? _lastSpeedWrite;

  /// Adds a live speed reading and drops those older than
  /// [SyncConfig.speedRetention]. Writes at most once a minute: the
  /// samples are a convenience, not a record.
  Future<void> addSpeedSample(SpeedSample sample) async {
    _speed.add(sample);
    final cutoff = sample.tsUtc.subtract(config.speedRetention);
    _speed.removeWhere((s) => s.tsUtc.isBefore(cutoff));
    final last = _lastSpeedWrite;
    if (last == null ||
        sample.tsUtc.difference(last) >= const Duration(minutes: 1)) {
      _lastSpeedWrite = sample.tsUtc;
      await flushSpeed();
    }
  }

  Future<void> flushSpeed() => backend.write(
    speedKey,
    jsonEncode([for (final s in _speed) s.toJson()]),
  );

  /// The last speed reading at or before [at], if any.
  SpeedSample? lastSpeedAt(DateTime at) {
    for (var i = _speed.length - 1; i >= 0; i--) {
      if (!_speed[i].tsUtc.isAfter(at)) return _speed[i];
    }
    return null;
  }
}
