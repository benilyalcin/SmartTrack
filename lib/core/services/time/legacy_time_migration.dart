import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/sync_config.dart';
import 'backup_file_io.dart' if (dart.library.html) 'backup_file_web.dart';

/// One-off move of the stored timestamps to UTC.
///
/// Up to now the app wrote `DateTime.now()` with `toIso8601String()`, which
/// leaves no offset: the strings are phone local time. Those are read as
/// [legacyOffset] (Europe/Istanbul, UTC+3) and rewritten with a `Z`.
/// Tachograph times (rest ends, CurrentDateTime) were UTC fields parsed as
/// if local, so they only get the `Z` they always meant.
///
/// A string that already carries an offset is left alone, so running this
/// twice changes nothing. The original values are kept, in the preferences
/// and in a file, and [rollback] puts them back.
class LegacyTimeMigration {
  static const doneKey = 'migration.utcV1.done';
  static const rolledBackKey = 'migration.utcV1.rolledBack';
  static const backupKey = 'migration.utcV1.backup';

  /// Lists of records written in phone local time, and their time fields.
  static const _localLists = <String, List<String>>{
    'liveActivityLog': ['start', 'end'],
    'liveActivityLog2': ['start', 'end'],
    'manualActivityEntries': ['start', 'end'],
    'ddd_files_index': ['downloadedAt', 'trashedAt'],
  };

  /// Single timestamps written in phone local time.
  static const _localScalars = [
    'liveSegmentStart',
    'liveSegmentStart2',
    'lastKnownActivityTime',
  ];

  /// Objects holding tachograph (UTC) times that were parsed as local.
  static const _unitMaps = <String, List<String>>{
    'liveComplianceSnapshot': [
      'lastDailyRestEnd',
      'lastWeeklyRestEnd',
      'lastDailyRestEnd2',
      'lastWeeklyRestEnd2',
    ],
    'tachographLiveDataSnapshot': ['currentDateTime', 'vehicleRegDate'],
  };

  static Iterable<String> get keys => [
    ..._localLists.keys,
    ..._localScalars,
    ..._unitMaps.keys,
  ];

  static SharedPreferences? _ranOn;
  static Future<void>? _once;

  /// Runs the migration on the shared preferences, once: callers that come
  /// in while it runs wait for the same run rather than starting another,
  /// which would back up values half migrated.
  static Future<void> ensure() async {
    final prefs = await SharedPreferences.getInstance();
    if (!identical(prefs, _ranOn) || _once == null) {
      _ranOn = prefs;
      _once = () async {
        try {
          await run(prefs);
        } catch (e) {
          // A failed migration leaves the old values: they still read right
          // on a phone in the legacy zone.
          debugPrint('UTC migration failed: $e');
        }
      }();
    }
    return _once;
  }

  @visibleForTesting
  static void resetForTest() {
    _ranOn = null;
    _once = null;
  }

  /// Migrates [prefs] unless that was done or undone before. Returns the
  /// keys it changed.
  static Future<List<String>> run(
    SharedPreferences prefs, {
    Duration? legacyOffset,
    Future<String?> Function(String name, String contents) writeFile =
        writeBackupFile,
  }) async {
    if (prefs.getBool(doneKey) == true ||
        prefs.getBool(rolledBackKey) == true) {
      return const [];
    }

    final raw = <String, String>{
      for (final key in keys) key: ?prefs.getString(key),
    };
    final changed = convert(
      raw,
      legacyOffset: legacyOffset ?? SyncConfig.defaults.displayUtcOffset,
    );

    if (changed.isNotEmpty) {
      final originals = jsonEncode({for (final k in changed.keys) k: raw[k]});
      await prefs.setString(backupKey, originals);
      try {
        final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
          ':',
          '-',
        );
        await writeFile('prefs-before-utc-v1-$stamp.json', originals);
      } catch (e) {
        debugPrint('UTC migration backup file not written: $e');
      }
      for (final entry in changed.entries) {
        await prefs.setString(entry.key, entry.value);
      }
    }
    await prefs.setBool(doneKey, true);
    return changed.keys.toList();
  }

  /// Puts the values from before the migration back and keeps it from
  /// running again. False when there is nothing to put back.
  static Future<bool> rollback(SharedPreferences prefs) async {
    final backup = prefs.getString(backupKey);
    if (backup == null) return false;
    final originals = (jsonDecode(backup) as Map<String, dynamic>)
        .cast<String, String>();
    for (final entry in originals.entries) {
      await prefs.setString(entry.key, entry.value);
    }
    await prefs.remove(doneKey);
    await prefs.setBool(rolledBackKey, true);
    return true;
  }

  /// The new values of the keys in [raw] that need any change.
  @visibleForTesting
  static Map<String, String> convert(
    Map<String, String> raw, {
    required Duration legacyOffset,
  }) {
    String local(String s) => _toUtc(s, legacyOffset);
    String unit(String s) => _toUtc(s, Duration.zero);

    final out = <String, String>{};
    void put(String key, String value) {
      if (value != raw[key]) out[key] = value;
    }

    for (final MapEntry(key: key, value: fields) in _localLists.entries) {
      final value = raw[key];
      if (value == null || value.isEmpty) continue;
      final list = jsonDecode(value) as List<dynamic>;
      put(
        key,
        jsonEncode([for (final item in list) _mapFields(item, fields, local)]),
      );
    }
    for (final key in _localScalars) {
      final value = raw[key];
      if (value == null || value.isEmpty) continue;
      put(key, local(value));
    }
    for (final MapEntry(key: key, value: fields) in _unitMaps.entries) {
      final value = raw[key];
      if (value == null || value.isEmpty) continue;
      put(key, jsonEncode(_mapFields(jsonDecode(value), fields, unit)));
    }
    return out;
  }

  static Object? _mapFields(
    Object? item,
    List<String> fields,
    String Function(String) convert,
  ) {
    if (item is! Map<String, dynamic>) return item;
    return {
      for (final MapEntry(:key, :value) in item.entries)
        key: fields.contains(key) && value is String ? convert(value) : value,
    };
  }

  static final _hasOffset = RegExp(r'(Z|[+-]\d{2}(:?\d{2})?)$');

  /// [s] read as wall-clock time at [offset] from UTC, written in UTC. A
  /// string that already says its offset, or is no date, is returned as is.
  static String _toUtc(String s, Duration offset) {
    if (_hasOffset.hasMatch(s)) return s;
    final wall = DateTime.tryParse('${s}Z');
    if (wall == null) return s;
    return wall.subtract(offset).toIso8601String();
  }
}
