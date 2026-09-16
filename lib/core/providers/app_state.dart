import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ddd_file.dart';
import '../models/role_permissions.dart';
import '../models/vehicle_unit_data.dart';
import '../services/ddd_download_service.dart';
import '../services/ddd_file_repository.dart';
import '../services/ddd_public_export_service.dart';
import '../services/ddd_simulator.dart';
import '../services/dongle_download_result_service.dart';
import '../services/driving_time_calculator.dart';
import '../services/kline_protocol.dart';
import '../services/tachograph_parser.dart';
import '../services/violation_analyzer.dart';
import '../services/vu/vu_file_decoder.dart';

enum ComplianceNoticeSeverity { info, warning }

enum DddFetchKind { card, vehicleUnit, both }

class ComplianceNotice {
  final String id;
  final String message;
  final ComplianceNoticeSeverity severity;
  const ComplianceNotice({
    required this.id,
    required this.message,
    required this.severity,
  });
}

class CompensationDebt {
  final Duration owed;
  final Duration remaining;
  final String labelKey;
  const CompensationDebt({
    required this.owed,
    required this.remaining,
    required this.labelKey,
  });
}

class AppState extends ChangeNotifier {
  String _selectedLanguage = 'TR';
  bool _isBluetoothConnected = false;

  bool _bluetoothWarningDismissed = false;
  String _tachographMode = 'Sürücü';
  String _activeDriver = 'driver1';
  ThemeMode _themeMode = ThemeMode.system;
  bool _freeScreenMode = false;

  bool _autoFetchDddOnReconnect = true;
  AppRole _activeRole = AppRole.driver;

  String _vehiclePlate = '';
  String? _connectedDeviceName;
  TachographLiveData _tachographLiveData = TachographLiveData();

  bool _hasTachographData = false;

  String? _dataFailureReason;

  List<DddFile> _dddFiles = [];
  List<DddFile> _trashedDddFiles = [];
  DddFile? _activeDddFile;
  TachographDriverData? _currentParsedData;

  VehicleUnitData? _activeVuData;
  bool _isDownloadingDdd = false;

  List<TachographActivity> _manualEntries = [];

  List<TachographActivity> _liveActivityLog = [];
  ActivityType? _liveOpenSegmentType;
  DateTime? _liveOpenSegmentStart;

  List<TachographActivity> _liveActivityLog2 = [];
  ActivityType? _liveOpenSegmentType2;
  DateTime? _liveOpenSegmentStart2;

  static const _liveActivityLogRetention = Duration(days: 90);

  final DrivingTimeCalculator _calculator = DrivingTimeCalculator();
  final ViolationAnalyzer _violationAnalyzer = ViolationAnalyzer();
  Map<String, DrivingRuleResult> _drivingRules = {};
  Duration _totalBreakTime = Duration.zero;
  String _currentActivity = 'dashboard.noData';
  List<Violation> _violations = [];
  List<ActivityGap> _pendingGaps = [];

  Duration? _liveSessionDuration;
  DateTime? _driverCardExpiryDate;
  String? _driverCardNumber;

  Map<String, DrivingRuleResult> _drivingRules2 = {};
  Duration _totalBreakTime2 = Duration.zero;
  String _currentActivity2 = 'dashboard.noData';
  Duration? _liveSessionDuration2;
  int? _remaining10hDrivingTimes2;
  int? _remainingReducedDailyRestPeriods2;
  Duration? _nextBreakRestDuration2;
  Duration? _currentBreakRestRemaining2;
  Duration? _timeUntilNextBreakOrRest2;
  DateTime? _lastDailyRestEnd2;
  DateTime? _lastWeeklyRestEnd2;
  Duration? _compensationLastWeek2;
  Duration? _compensationWeekBeforeLast2;
  Duration? _compensation2ndWeekBeforeLast2;
  Duration? _minimumDailyRest2;
  Duration? _minimumWeeklyRest2;

  final Set<String> _unavailableFields2 = {};

  int? _remaining10hDrivingTimes;
  int? _remainingReducedDailyRestPeriods;
  Duration? _nextBreakRestDuration;
  Duration? _currentBreakRestRemaining;
  Duration? _timeUntilNextBreakOrRest;
  DateTime? _lastDailyRestEnd;
  DateTime? _lastWeeklyRestEnd;
  Duration? _compensationLastWeek;
  Duration? _compensationWeekBeforeLast;
  Duration? _compensation2ndWeekBeforeLast;
  Duration? _minimumDailyRest;
  Duration? _minimumWeeklyRest;

  final Set<String> _unavailableFields = {};

  DateTime? _lastKnownActivityTime;

  ActivityGap? _pendingRealGap;

  ComplianceNotice? _pendingComplianceNotice;
  final Set<String> _shownNoticeIds = {};

  String? _pendingContinuousLimitDialogMessage;

  AppState() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('tachographMode')) {
      _tachographMode = prefs.getString('tachographMode') ?? 'Sürücü';
    }
    if (prefs.containsKey('activeDriver')) {
      final stored = prefs.getString('activeDriver') ?? 'driver1';

      _activeDriver = switch (stored) {
        'Ahmet' => 'driver1',
        'Barış' => 'driver2',
        _ => stored,
      };
    }
    if (prefs.containsKey('activeRole')) {
      _activeRole = AppRoleCodec.fromCode(
        prefs.getString('activeRole') ?? 'Sürücü',
      );
    }
    if (prefs.containsKey('themeMode')) {
      _themeMode = switch (prefs.getString('themeMode')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    }
    if (prefs.containsKey('freeScreenMode')) {
      _freeScreenMode = prefs.getBool('freeScreenMode') ?? false;
    }
    if (prefs.containsKey('autoFetchDddOnReconnect')) {
      _autoFetchDddOnReconnect =
          prefs.getBool('autoFetchDddOnReconnect') ?? true;
    }

    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    final lastActivityIso = prefs.getString('lastKnownActivityTime');
    if (lastActivityIso != null) {
      _lastKnownActivityTime = DateTime.tryParse(lastActivityIso);
    }
    final manualJson = prefs.getString('manualActivityEntries');
    if (manualJson != null && manualJson.isNotEmpty) {
      _manualEntries = _decodeManualEntries(manualJson);
    }
    final liveLogJson = prefs.getString('liveActivityLog');
    if (liveLogJson != null && liveLogJson.isNotEmpty) {
      _liveActivityLog = _decodeLiveActivityLog(liveLogJson);
    }
    final liveSegmentTypeIndex = prefs.getInt('liveSegmentType');
    final liveSegmentStartIso = prefs.getString('liveSegmentStart');
    if (liveSegmentTypeIndex != null && liveSegmentStartIso != null) {
      final parsedStart = DateTime.tryParse(liveSegmentStartIso);

      if (parsedStart != null &&
          DateTime.now().difference(parsedStart) <= _openSegmentStaleCap) {
        _liveOpenSegmentType = ActivityType.values[liveSegmentTypeIndex];
        _liveOpenSegmentStart = parsedStart;
      } else {
        unawaited(prefs.remove('liveSegmentType'));
        unawaited(prefs.remove('liveSegmentStart'));
      }
    }

    final liveLog2Json = prefs.getString('liveActivityLog2');
    if (liveLog2Json != null && liveLog2Json.isNotEmpty) {
      _liveActivityLog2 = _decodeLiveActivityLog(liveLog2Json);
    }
    final liveSegmentType2Index = prefs.getInt('liveSegmentType2');
    final liveSegmentStart2Iso = prefs.getString('liveSegmentStart2');
    if (liveSegmentType2Index != null && liveSegmentStart2Iso != null) {
      final parsedStart2 = DateTime.tryParse(liveSegmentStart2Iso);
      if (parsedStart2 != null &&
          DateTime.now().difference(parsedStart2) <= _openSegmentStaleCap) {
        _liveOpenSegmentType2 = ActivityType.values[liveSegmentType2Index];
        _liveOpenSegmentStart2 = parsedStart2;
      } else {
        unawaited(prefs.remove('liveSegmentType2'));
        unawaited(prefs.remove('liveSegmentStart2'));
      }
    }

    final complianceJson = prefs.getString('liveComplianceSnapshot');
    if (complianceJson != null && complianceJson.isNotEmpty) {
      try {
        _restoreComplianceSnapshot(
          jsonDecode(complianceJson) as Map<String, dynamic>,
        );
      } catch (_) {}
    }

    final liveDataJson = prefs.getString('tachographLiveDataSnapshot');
    if (liveDataJson != null && liveDataJson.isNotEmpty) {
      try {
        _tachographLiveData = TachographLiveData.fromJson(
          jsonDecode(liveDataJson) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    if (prefs.containsKey('vehiclePlate')) {
      _vehiclePlate = prefs.getString('vehiclePlate') ?? '';
    }
    if (prefs.containsKey('hasTachographData')) {
      _hasTachographData = prefs.getBool('hasTachographData') ?? false;
    }
    notifyListeners();

    await loadDddFilesIndex();
    if (_dddFiles.isNotEmpty) {
      await setActiveDddFile(_dddFiles.first);
    } else {
      _recomputeDerivedState();
    }
  }

  String get selectedLanguage => _selectedLanguage;
  bool get isBluetoothConnected => _isBluetoothConnected;
  bool get bluetoothWarningDismissed => _bluetoothWarningDismissed;

  void dismissBluetoothWarning() {
    if (_bluetoothWarningDismissed) return;
    _bluetoothWarningDismissed = true;
    notifyListeners();
  }

  String get tachographMode => _tachographMode;
  String get activeDriver => _activeDriver;
  AppRole get activeRole => _activeRole;
  RolePermissions get rolePermissions => RolePermissions.forRole(_activeRole);

  String get currentActivity => _currentActivity;

  String get vehiclePlate => _vehiclePlate;
  String? get connectedDeviceName => _connectedDeviceName;
  TachographLiveData get tachographLiveData => _tachographLiveData;
  bool get hasTachographData => _hasTachographData;
  String? get dataFailureReason => _dataFailureReason;

  String get connectionStatus {
    if (!_isBluetoothConnected) return 'disconnected';
    return _hasTachographData ? 'connectedWithData' : 'connectedNoData';
  }

  List<DddFile> get dddFiles => List.unmodifiable(_dddFiles);
  List<DddFile> get trashedDddFiles => List.unmodifiable(_trashedDddFiles);
  DddFile? get activeDddFile => _activeDddFile;
  TachographDriverData? get currentParsedData => _currentParsedData;
  VehicleUnitData? get activeVuData => _activeVuData;
  bool get isDownloadingDdd => _isDownloadingDdd;

  Map<String, DrivingRuleResult> get drivingRules => _drivingRules;
  Duration get totalBreakTime => _totalBreakTime;
  List<Violation> get violations => List.unmodifiable(_violations);
  List<ActivityGap> get pendingGaps => List.unmodifiable(_pendingGaps);
  DateTime? get lastKnownActivityTime => _lastKnownActivityTime;
  ActivityGap? get pendingRealGap => _pendingRealGap;

  ComplianceNotice? get pendingComplianceNotice => _pendingComplianceNotice;

  void dismissComplianceNotice(String id) {
    if (_pendingComplianceNotice?.id == id) {
      _pendingComplianceNotice = null;
      notifyListeners();
    }
  }

  String? get pendingContinuousLimitDialogMessage =>
      _pendingContinuousLimitDialogMessage;

  void acknowledgeContinuousLimitDialog() {
    _pendingContinuousLimitDialogMessage = null;
    notifyListeners();
  }

  void _raiseComplianceNotice(
    String id,
    String message, {
    required ComplianceNoticeSeverity severity,
  }) {
    if (_shownNoticeIds.contains(id)) return;
    _shownNoticeIds.add(id);
    _pendingComplianceNotice = ComplianceNotice(
      id: id,
      message: message,
      severity: severity,
    );
  }

  void _clearComplianceNoticeEligibility(String id) =>
      _shownNoticeIds.remove(id);

  Duration? get liveSessionDuration => _liveSessionDuration;

  DateTime? get driverCardExpiryDate => _driverCardExpiryDate;
  String? get driverCardNumber => _driverCardNumber;

  int? get remaining10hDrivingTimes => _remaining10hDrivingTimes;
  int? get remainingReducedDailyRestPeriods =>
      _remainingReducedDailyRestPeriods;
  Duration? get nextBreakRestDuration => _nextBreakRestDuration;
  Duration? get currentBreakRestRemaining => _currentBreakRestRemaining;
  Duration? get timeUntilNextBreakOrRest => _timeUntilNextBreakOrRest;
  DateTime? get lastDailyRestEnd => _lastDailyRestEnd;
  DateTime? get lastWeeklyRestEnd => _lastWeeklyRestEnd;
  Duration? get compensationLastWeek => _compensationLastWeek;
  Duration? get compensationWeekBeforeLast => _compensationWeekBeforeLast;
  Duration? get compensation2ndWeekBeforeLast => _compensation2ndWeekBeforeLast;
  Duration? get minimumDailyRest => _minimumDailyRest;
  Duration? get minimumWeeklyRest => _minimumWeeklyRest;

  Map<String, DrivingRuleResult> get drivingRules2 => _drivingRules2;
  Duration get totalBreakTime2 => _totalBreakTime2;
  String get currentActivity2 => _currentActivity2;
  Duration? get liveSessionDuration2 => _liveSessionDuration2;
  int? get remaining10hDrivingTimes2 => _remaining10hDrivingTimes2;
  int? get remainingReducedDailyRestPeriods2 =>
      _remainingReducedDailyRestPeriods2;
  Duration? get nextBreakRestDuration2 => _nextBreakRestDuration2;
  Duration? get currentBreakRestRemaining2 => _currentBreakRestRemaining2;
  Duration? get timeUntilNextBreakOrRest2 => _timeUntilNextBreakOrRest2;
  DateTime? get lastDailyRestEnd2 => _lastDailyRestEnd2;
  DateTime? get lastWeeklyRestEnd2 => _lastWeeklyRestEnd2;
  Duration? get compensationLastWeek2 => _compensationLastWeek2;
  Duration? get compensationWeekBeforeLast2 => _compensationWeekBeforeLast2;
  Duration? get compensation2ndWeekBeforeLast2 =>
      _compensation2ndWeekBeforeLast2;
  Duration? get minimumDailyRest2 => _minimumDailyRest2;
  Duration? get minimumWeeklyRest2 => _minimumWeeklyRest2;

  bool get _isActiveDriver1 => _activeDriver == 'driver1';

  bool get isCrew => _tachographLiveData.cardSlot2 == 1;

  Map<String, DrivingRuleResult> get activeDrivingRules =>
      _isActiveDriver1 ? _drivingRules : _drivingRules2;
  Duration get activeTotalBreakTime =>
      _isActiveDriver1 ? _totalBreakTime : _totalBreakTime2;
  String get activeCurrentActivity =>
      _isActiveDriver1 ? _currentActivity : _currentActivity2;
  Duration? get activeLiveSessionDuration =>
      _isActiveDriver1 ? _liveSessionDuration : _liveSessionDuration2;
  int? get activeRemaining10hDrivingTimes =>
      _isActiveDriver1 ? _remaining10hDrivingTimes : _remaining10hDrivingTimes2;
  int? get activeRemainingReducedDailyRestPeriods => _isActiveDriver1
      ? _remainingReducedDailyRestPeriods
      : _remainingReducedDailyRestPeriods2;
  Duration? get activeNextBreakRestDuration =>
      _isActiveDriver1 ? _nextBreakRestDuration : _nextBreakRestDuration2;
  Duration? get activeCurrentBreakRestRemaining => _isActiveDriver1
      ? _currentBreakRestRemaining
      : _currentBreakRestRemaining2;
  Duration? get activeTimeUntilNextBreakOrRest =>
      _isActiveDriver1 ? _timeUntilNextBreakOrRest : _timeUntilNextBreakOrRest2;
  DateTime? get activeLastDailyRestEnd =>
      _isActiveDriver1 ? _lastDailyRestEnd : _lastDailyRestEnd2;
  DateTime? get activeLastWeeklyRestEnd =>
      _isActiveDriver1 ? _lastWeeklyRestEnd : _lastWeeklyRestEnd2;
  Duration? get activeCompensationLastWeek =>
      _isActiveDriver1 ? _compensationLastWeek : _compensationLastWeek2;
  Duration? get activeCompensationWeekBeforeLast => _isActiveDriver1
      ? _compensationWeekBeforeLast
      : _compensationWeekBeforeLast2;
  Duration? get activeCompensation2ndWeekBeforeLast => _isActiveDriver1
      ? _compensation2ndWeekBeforeLast
      : _compensation2ndWeekBeforeLast2;
  Duration? get activeMinimumDailyRest =>
      _isActiveDriver1 ? _minimumDailyRest : _minimumDailyRest2;
  Duration? get activeMinimumWeeklyRest =>
      _isActiveDriver1 ? _minimumWeeklyRest : _minimumWeeklyRest2;

  bool _isFieldUnavailable(String key) =>
      (_isActiveDriver1 ? _unavailableFields : _unavailableFields2).contains(
        key,
      );
  bool get activeDailyDrivingUnavailable => _isFieldUnavailable('dailyDriving');
  bool get activeWeeklyDrivingUnavailable =>
      _isFieldUnavailable('weeklyDriving');
  bool get activeMinimumDailyRestUnavailable =>
      _isFieldUnavailable('minDailyRest');
  bool get activeMinimumWeeklyRestUnavailable =>
      _isFieldUnavailable('minWeeklyRest');
  bool get activeCurrentBreakRestRemainingUnavailable =>
      _isFieldUnavailable('currentBreakRemaining');

  bool? get activeBreakSequenceIncomplete {
    if (!_isActiveDriver1) return null;
    if (_effectiveActivityLog.isEmpty) return null;
    return _calculator.hasIncompleteBreakAttempt(
      _effectiveActivityLog,
      DateTime.now(),
    );
  }

  Duration? get activeOpenRestElapsed {
    if (!_isActiveDriver1) return null;
    if (_liveOpenSegmentType != ActivityType.rest ||
        _liveOpenSegmentStart == null)
      return null;
    return DateTime.now().difference(_liveOpenSegmentStart!);
  }

  bool get activePendingFirstHalfExists {
    if (!_isActiveDriver1) return false;
    return _calculator.hasQualifyingPendingFirstHalf(
      _liveActivityLog,
      DateTime.now(),
    );
  }

  List<CompensationDebt> get activeCompensationDebts {
    final now = DateTime.now();
    final entries = <(Duration?, int, String)>[
      (activeCompensationLastWeek, 1, 'compliance.compensationLastWeek'),
      (
        activeCompensationWeekBeforeLast,
        2,
        'compliance.compensationWeekBeforeLast',
      ),
      (
        activeCompensation2ndWeekBeforeLast,
        3,
        'compliance.compensation2ndWeekBeforeLast',
      ),
    ];
    final debts = <CompensationDebt>[
      for (final (owed, weeksAgo, labelKey) in entries)
        if (owed != null && owed > Duration.zero)
          CompensationDebt(
            owed: owed,
            remaining: _calculator.compensationDeadlineRemaining(weeksAgo, now),
            labelKey: labelKey,
          ),
    ];
    debts.sort((a, b) => a.remaining.compareTo(b.remaining));
    return debts;
  }

  List<TachographActivity> get activityLog {
    final sorted = List<TachographActivity>.from(_effectiveActivityLog)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return List.unmodifiable(sorted);
  }

  void setLanguage(String lang) {
    if (_selectedLanguage != lang) {
      _selectedLanguage = lang;
      notifyListeners();
    }
  }

  ThemeMode get themeMode => _themeMode;
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('themeMode', switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    });
  }

  bool get freeScreenMode => _freeScreenMode;
  void setFreeScreenMode(bool enabled) {
    if (_freeScreenMode == enabled) return;
    _freeScreenMode = enabled;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('freeScreenMode', enabled);
    });
  }

  bool get autoFetchDddOnReconnect => _autoFetchDddOnReconnect;
  void setAutoFetchDddOnReconnect(bool enabled) {
    if (_autoFetchDddOnReconnect == enabled) return;
    _autoFetchDddOnReconnect = enabled;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('autoFetchDddOnReconnect', enabled);
    });
  }

  void setBluetoothConnected(bool connected, {String? deviceName}) {
    if (_isBluetoothConnected != connected ||
        _connectedDeviceName != deviceName) {
      _isBluetoothConnected = connected;
      if (!connected) {
        _connectedDeviceName = null;

        _bluetoothWarningDismissed = false;

        _dataFailureReason = null;
      } else if (deviceName != null) {
        _connectedDeviceName = deviceName;
      }
      notifyListeners();
    }
  }

  void setTachographDataStatus(bool success, {String? reason}) {
    _hasTachographData = success;
    _dataFailureReason = success ? null : reason;
    notifyListeners();
    if (success) {
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setBool('hasTachographData', true),
      );
    }
  }

  void setTachographMode(String mode) async {
    if (_tachographMode != mode) {
      _tachographMode = mode;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tachographMode', mode);
    }
    await downloadDddForCurrentCard();
  }

  void applyCardSlotMode(int? slot1Value) {
    if (slot1Value == null) return;
    const modeForSlot = {1: 'Sürücü', 2: 'Servis', 3: 'Kontrol', 4: 'Şirket'};
    final mode = modeForSlot[slot1Value] ?? 'Sürücü';
    if (mode == _tachographMode) return;
    setTachographMode(mode);
  }

  void setActiveDriver(String driver) async {
    if (_activeDriver != driver) {
      _activeDriver = driver;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activeDriver', driver);
    }
  }

  void setActiveRole(AppRole role) async {
    if (_activeRole != role) {
      _activeRole = role;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activeRole', role.code);
    }
  }

  void setVehiclePlate(String plate) {
    if (_vehiclePlate != plate) {
      _vehiclePlate = plate;
      notifyListeners();
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString('vehiclePlate', plate),
      );
    }
  }

  void setTachographLiveData(TachographLiveData data) {
    _tachographLiveData = data;

    if (data.vrn.isNotEmpty) {
      _vehiclePlate = data.vrn;
    } else if (data.vin.isNotEmpty) {
      _vehiclePlate = data.vin;
    }
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('tachographLiveDataSnapshot', jsonEncode(data.toJson()));
      prefs.setString('vehiclePlate', _vehiclePlate);
    });
  }

  void setLiveComplianceData({
    Duration? continuousDriving,
    Duration? cumulativeBreak,
    Duration? dailyDriving,
    Duration? weeklyDriving,
    Duration? remainingBiWeekly,
    Duration? currentSessionDuration,
    String? currentActivityKey,
    DateTime? cardExpiryDate,
    String? cardNumber,
    int? workingStateCode,
    int? remaining10hDrivingTimes,
    int? remainingReducedDailyRestPeriods,
    Duration? nextBreakRestDuration,
    Duration? currentBreakRestRemaining,
    Duration? timeUntilNextBreakOrRest,
    DateTime? lastDailyRestEnd,
    DateTime? lastWeeklyRestEnd,
    Duration? compensationLastWeek,
    Duration? compensationWeekBeforeLast,
    Duration? compensation2ndWeekBeforeLast,
    Duration? minimumDailyRest,
    Duration? minimumWeeklyRest,

    bool dailyDrivingUnavailable = false,
    bool weeklyDrivingUnavailable = false,
    bool minDailyRestUnavailable = false,
    bool minWeeklyRestUnavailable = false,
    bool currentBreakRestRemainingUnavailable = false,
  }) {
    if (workingStateCode != null) {
      _recordLiveActivitySample(workingStateCode, DateTime.now());
    }

    if (_activeDddFile != null && _activeDddFile!.isSimulated) {
      _activeDddFile = null;
      _currentParsedData = null;
      _recomputeDerivedState();
    }

    final mergedRules = Map<String, DrivingRuleResult>.of(_drivingRules);
    if (continuousDriving != null) {
      mergedRules['continuous'] = DrivingRuleResult(
        used: continuousDriving,
        limit: DrivingTimeCalculator.continuousDrivingLimit,
      );
    }
    if (dailyDriving != null) {
      mergedRules['daily'] = DrivingRuleResult(
        used: dailyDriving,
        limit: DrivingTimeCalculator.dailyDrivingLimit,
      );
    }
    if (weeklyDriving != null) {
      mergedRules['weekly'] = DrivingRuleResult(
        used: weeklyDriving,
        limit: DrivingTimeCalculator.weeklyDrivingLimit,
      );
    }
    if (remainingBiWeekly != null) {
      mergedRules['bi_weekly'] = DrivingRuleResult(
        used: DrivingTimeCalculator.biWeeklyDrivingLimit - remainingBiWeekly,
        limit: DrivingTimeCalculator.biWeeklyDrivingLimit,
      );
    }
    _drivingRules = mergedRules;
    if (cumulativeBreak != null) _totalBreakTime = cumulativeBreak;
    _violations = _violationAnalyzer.analyzeLiveRules(
      _drivingRules,
      DateTime.now(),
    );
    if (currentSessionDuration != null)
      _liveSessionDuration = currentSessionDuration;
    if (currentActivityKey != null) _currentActivity = currentActivityKey;
    if (cardExpiryDate != null) _driverCardExpiryDate = cardExpiryDate;
    if (cardNumber != null && cardNumber.isNotEmpty)
      _driverCardNumber = cardNumber;

    if (remaining10hDrivingTimes != null)
      _remaining10hDrivingTimes = remaining10hDrivingTimes;
    if (remainingReducedDailyRestPeriods != null)
      _remainingReducedDailyRestPeriods = remainingReducedDailyRestPeriods;
    if (nextBreakRestDuration != null)
      _nextBreakRestDuration = nextBreakRestDuration;
    if (currentBreakRestRemaining != null)
      _currentBreakRestRemaining = currentBreakRestRemaining;
    if (timeUntilNextBreakOrRest != null)
      _timeUntilNextBreakOrRest = timeUntilNextBreakOrRest;
    if (lastDailyRestEnd != null) _lastDailyRestEnd = lastDailyRestEnd;
    if (lastWeeklyRestEnd != null) _lastWeeklyRestEnd = lastWeeklyRestEnd;
    if (compensationLastWeek != null)
      _compensationLastWeek = compensationLastWeek;
    if (compensationWeekBeforeLast != null)
      _compensationWeekBeforeLast = compensationWeekBeforeLast;
    if (compensation2ndWeekBeforeLast != null)
      _compensation2ndWeekBeforeLast = compensation2ndWeekBeforeLast;
    if (minimumDailyRest != null) _minimumDailyRest = minimumDailyRest;
    if (minimumWeeklyRest != null) _minimumWeeklyRest = minimumWeeklyRest;

    _setFieldUnavailable(
      _unavailableFields,
      'dailyDriving',
      dailyDrivingUnavailable,
    );
    _setFieldUnavailable(
      _unavailableFields,
      'weeklyDriving',
      weeklyDrivingUnavailable,
    );
    _setFieldUnavailable(
      _unavailableFields,
      'minDailyRest',
      minDailyRestUnavailable,
    );
    _setFieldUnavailable(
      _unavailableFields,
      'minWeeklyRest',
      minWeeklyRestUnavailable,
    );
    _setFieldUnavailable(
      _unavailableFields,
      'currentBreakRemaining',
      currentBreakRestRemainingUnavailable,
    );

    _checkContinuousDrivingWarnings();
    _checkCrewMismatch();

    notifyListeners();
    unawaited(_persistComplianceSnapshot());
  }

  static void _setFieldUnavailable(
    Set<String> fields,
    String key,
    bool unavailable,
  ) {
    if (unavailable) {
      fields.add(key);
    } else {
      fields.remove(key);
    }
  }

  void _checkContinuousDrivingWarnings() {
    final used = _drivingRules['continuous']?.used;
    if (used == null) return;
    const preId = 'continuous-prewarning';
    const warnId = 'continuous-warning';

    if (used < const Duration(minutes: 1)) {
      _clearComplianceNoticeEligibility(preId);
      _shownNoticeIds.remove(warnId);
      return;
    }

    if (used >= DrivingTimeCalculator.continuousDrivingLimit) {
      if (!_shownNoticeIds.contains(warnId)) {
        _shownNoticeIds.add(warnId);
        final targetLabel = activePendingFirstHalfExists
            ? '30 dakika'
            : '45 dakika';
        _pendingContinuousLimitDialogMessage =
            'Kesintisiz sürüş süreniz yasal sınırı (4 sa 30 dk) '
            'aştı. Mola süreniz tamamlanmadan sürüşe devam etmeniz idari para cezasına yol açabilir '
            '(Karayolları Trafik Yönetmeliği Madde 98). Almanız gereken mola süresi: en az $targetLabel.';
      }
    } else if (used >= const Duration(hours: 4, minutes: 15)) {
      _raiseComplianceNotice(
        preId,
        'Kesintisiz sürüş süreniz 4 saat 15 dakikaya ulaştı — yakında mola vermeniz gerekiyor.',
        severity: ComplianceNoticeSeverity.info,
      );
    }
  }

  void _checkCrewMismatch() {
    const id = 'crew-mismatch';
    final mismatch =
        isCrew &&
        _currentActivity == 'dashboard.driving' &&
        _currentActivity2 == 'dashboard.rest';
    if (mismatch) {
      _raiseComplianceNotice(
        id,
        'Ekip modu: Ana sürücü sürüyor, yedek sürücü dinleniyor. Yedek sürücünün bu süre '
        'boyunca sürüşe yardımcı bir görev üstlenmediğinden emin olun — aksi halde bu süre '
        "\"dinlenme\" değil \"diğer çalışma\" sayılır.",
        severity: ComplianceNoticeSeverity.info,
      );
    } else {
      _clearComplianceNoticeEligibility(id);
    }
  }

  void setDriver2ComplianceData({
    Duration? continuousDriving,
    Duration? cumulativeBreak,
    Duration? dailyDriving,
    Duration? weeklyDriving,
    Duration? remainingBiWeekly,
    Duration? currentSessionDuration,
    String? currentActivityKey,
    int? workingStateCode,
    int? remaining10hDrivingTimes,
    int? remainingReducedDailyRestPeriods,
    Duration? nextBreakRestDuration,
    Duration? currentBreakRestRemaining,
    Duration? timeUntilNextBreakOrRest,
    DateTime? lastDailyRestEnd,
    DateTime? lastWeeklyRestEnd,
    Duration? compensationLastWeek,
    Duration? compensationWeekBeforeLast,
    Duration? compensation2ndWeekBeforeLast,
    Duration? minimumDailyRest,
    Duration? minimumWeeklyRest,
    bool dailyDrivingUnavailable = false,
    bool weeklyDrivingUnavailable = false,
    bool minDailyRestUnavailable = false,
    bool minWeeklyRestUnavailable = false,
    bool currentBreakRestRemainingUnavailable = false,
  }) {
    if (workingStateCode != null) {
      _recordLiveActivitySample2(workingStateCode, DateTime.now());
    }

    final mergedRules2 = Map<String, DrivingRuleResult>.of(_drivingRules2);
    if (continuousDriving != null) {
      mergedRules2['continuous'] = DrivingRuleResult(
        used: continuousDriving,
        limit: DrivingTimeCalculator.continuousDrivingLimit,
      );
    }
    if (dailyDriving != null) {
      mergedRules2['daily'] = DrivingRuleResult(
        used: dailyDriving,
        limit: DrivingTimeCalculator.dailyDrivingLimit,
      );
    }
    if (weeklyDriving != null) {
      mergedRules2['weekly'] = DrivingRuleResult(
        used: weeklyDriving,
        limit: DrivingTimeCalculator.weeklyDrivingLimit,
      );
    }
    if (remainingBiWeekly != null) {
      mergedRules2['bi_weekly'] = DrivingRuleResult(
        used: DrivingTimeCalculator.biWeeklyDrivingLimit - remainingBiWeekly,
        limit: DrivingTimeCalculator.biWeeklyDrivingLimit,
      );
    }
    _drivingRules2 = mergedRules2;
    if (cumulativeBreak != null) _totalBreakTime2 = cumulativeBreak;
    if (currentSessionDuration != null)
      _liveSessionDuration2 = currentSessionDuration;
    if (currentActivityKey != null) _currentActivity2 = currentActivityKey;

    if (remaining10hDrivingTimes != null)
      _remaining10hDrivingTimes2 = remaining10hDrivingTimes;
    if (remainingReducedDailyRestPeriods != null)
      _remainingReducedDailyRestPeriods2 = remainingReducedDailyRestPeriods;
    if (nextBreakRestDuration != null)
      _nextBreakRestDuration2 = nextBreakRestDuration;
    if (currentBreakRestRemaining != null)
      _currentBreakRestRemaining2 = currentBreakRestRemaining;
    if (timeUntilNextBreakOrRest != null)
      _timeUntilNextBreakOrRest2 = timeUntilNextBreakOrRest;
    if (lastDailyRestEnd != null) _lastDailyRestEnd2 = lastDailyRestEnd;
    if (lastWeeklyRestEnd != null) _lastWeeklyRestEnd2 = lastWeeklyRestEnd;
    if (compensationLastWeek != null)
      _compensationLastWeek2 = compensationLastWeek;
    if (compensationWeekBeforeLast != null)
      _compensationWeekBeforeLast2 = compensationWeekBeforeLast;
    if (compensation2ndWeekBeforeLast != null)
      _compensation2ndWeekBeforeLast2 = compensation2ndWeekBeforeLast;
    if (minimumDailyRest != null) _minimumDailyRest2 = minimumDailyRest;
    if (minimumWeeklyRest != null) _minimumWeeklyRest2 = minimumWeeklyRest;

    _setFieldUnavailable(
      _unavailableFields2,
      'dailyDriving',
      dailyDrivingUnavailable,
    );
    _setFieldUnavailable(
      _unavailableFields2,
      'weeklyDriving',
      weeklyDrivingUnavailable,
    );
    _setFieldUnavailable(
      _unavailableFields2,
      'minDailyRest',
      minDailyRestUnavailable,
    );
    _setFieldUnavailable(
      _unavailableFields2,
      'minWeeklyRest',
      minWeeklyRestUnavailable,
    );
    _setFieldUnavailable(
      _unavailableFields2,
      'currentBreakRemaining',
      currentBreakRestRemainingUnavailable,
    );

    _checkCrewMismatch();

    notifyListeners();
    unawaited(_persistComplianceSnapshot());
  }

  static const Map<String, Duration> _ruleLimits = {
    'continuous': DrivingTimeCalculator.continuousDrivingLimit,
    'daily': DrivingTimeCalculator.dailyDrivingLimit,
    'weekly': DrivingTimeCalculator.weeklyDrivingLimit,
    'bi_weekly': DrivingTimeCalculator.biWeeklyDrivingLimit,
  };

  Map<String, int> _encodeRules(Map<String, DrivingRuleResult> rules) =>
      rules.map((key, value) => MapEntry(key, value.used.inMilliseconds));

  Map<String, DrivingRuleResult> _decodeRules(Map<String, dynamic>? json) {
    if (json == null) return {};
    final result = <String, DrivingRuleResult>{};
    for (final entry in json.entries) {
      final limit = _ruleLimits[entry.key];
      if (limit == null) continue;
      result[entry.key] = DrivingRuleResult(
        used: Duration(milliseconds: entry.value as int),
        limit: limit,
      );
    }
    return result;
  }

  Duration? _durationOrNull(dynamic ms) =>
      ms == null ? null : Duration(milliseconds: ms as int);
  DateTime? _dateOrNull(dynamic iso) =>
      iso == null ? null : DateTime.tryParse(iso as String);

  Future<void> _persistComplianceSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final json = {
      'drivingRules': _encodeRules(_drivingRules),
      'totalBreakTimeMs': _totalBreakTime.inMilliseconds,
      'currentActivity': _currentActivity,
      'liveSessionDurationMs': _liveSessionDuration?.inMilliseconds,
      'driverCardExpiryDate': _driverCardExpiryDate?.toIso8601String(),
      'driverCardNumber': _driverCardNumber,
      'remaining10hDrivingTimes': _remaining10hDrivingTimes,
      'remainingReducedDailyRestPeriods': _remainingReducedDailyRestPeriods,
      'nextBreakRestDurationMs': _nextBreakRestDuration?.inMilliseconds,
      'currentBreakRestRemainingMs': _currentBreakRestRemaining?.inMilliseconds,
      'timeUntilNextBreakOrRestMs': _timeUntilNextBreakOrRest?.inMilliseconds,
      'lastDailyRestEnd': _lastDailyRestEnd?.toIso8601String(),
      'lastWeeklyRestEnd': _lastWeeklyRestEnd?.toIso8601String(),
      'compensationLastWeekMs': _compensationLastWeek?.inMilliseconds,
      'compensationWeekBeforeLastMs':
          _compensationWeekBeforeLast?.inMilliseconds,
      'compensation2ndWeekBeforeLastMs':
          _compensation2ndWeekBeforeLast?.inMilliseconds,
      'minimumDailyRestMs': _minimumDailyRest?.inMilliseconds,
      'minimumWeeklyRestMs': _minimumWeeklyRest?.inMilliseconds,

      'drivingRules2': _encodeRules(_drivingRules2),
      'totalBreakTime2Ms': _totalBreakTime2.inMilliseconds,
      'currentActivity2': _currentActivity2,
      'liveSessionDuration2Ms': _liveSessionDuration2?.inMilliseconds,
      'remaining10hDrivingTimes2': _remaining10hDrivingTimes2,
      'remainingReducedDailyRestPeriods2': _remainingReducedDailyRestPeriods2,
      'nextBreakRestDuration2Ms': _nextBreakRestDuration2?.inMilliseconds,
      'currentBreakRestRemaining2Ms':
          _currentBreakRestRemaining2?.inMilliseconds,
      'timeUntilNextBreakOrRest2Ms': _timeUntilNextBreakOrRest2?.inMilliseconds,
      'lastDailyRestEnd2': _lastDailyRestEnd2?.toIso8601String(),
      'lastWeeklyRestEnd2': _lastWeeklyRestEnd2?.toIso8601String(),
      'compensationLastWeek2Ms': _compensationLastWeek2?.inMilliseconds,
      'compensationWeekBeforeLast2Ms':
          _compensationWeekBeforeLast2?.inMilliseconds,
      'compensation2ndWeekBeforeLast2Ms':
          _compensation2ndWeekBeforeLast2?.inMilliseconds,
      'minimumDailyRest2Ms': _minimumDailyRest2?.inMilliseconds,
      'minimumWeeklyRest2Ms': _minimumWeeklyRest2?.inMilliseconds,
    };
    await prefs.setString('liveComplianceSnapshot', jsonEncode(json));
  }

  void _restoreComplianceSnapshot(Map<String, dynamic> json) {
    _drivingRules = _decodeRules(json['drivingRules'] as Map<String, dynamic>?);
    _totalBreakTime = Duration(
      milliseconds: json['totalBreakTimeMs'] as int? ?? 0,
    );
    _currentActivity = json['currentActivity'] as String? ?? _currentActivity;
    _liveSessionDuration = _durationOrNull(json['liveSessionDurationMs']);
    _driverCardExpiryDate = _dateOrNull(json['driverCardExpiryDate']);
    _driverCardNumber = json['driverCardNumber'] as String?;
    _remaining10hDrivingTimes = json['remaining10hDrivingTimes'] as int?;
    _remainingReducedDailyRestPeriods =
        json['remainingReducedDailyRestPeriods'] as int?;
    _nextBreakRestDuration = _durationOrNull(json['nextBreakRestDurationMs']);
    _currentBreakRestRemaining = _durationOrNull(
      json['currentBreakRestRemainingMs'],
    );
    _timeUntilNextBreakOrRest = _durationOrNull(
      json['timeUntilNextBreakOrRestMs'],
    );
    _lastDailyRestEnd = _dateOrNull(json['lastDailyRestEnd']);
    _lastWeeklyRestEnd = _dateOrNull(json['lastWeeklyRestEnd']);
    _compensationLastWeek = _durationOrNull(json['compensationLastWeekMs']);
    _compensationWeekBeforeLast = _durationOrNull(
      json['compensationWeekBeforeLastMs'],
    );
    _compensation2ndWeekBeforeLast = _durationOrNull(
      json['compensation2ndWeekBeforeLastMs'],
    );
    _minimumDailyRest = _durationOrNull(json['minimumDailyRestMs']);
    _minimumWeeklyRest = _durationOrNull(json['minimumWeeklyRestMs']);

    _drivingRules2 = _decodeRules(
      json['drivingRules2'] as Map<String, dynamic>?,
    );
    _totalBreakTime2 = Duration(
      milliseconds: json['totalBreakTime2Ms'] as int? ?? 0,
    );
    _currentActivity2 =
        json['currentActivity2'] as String? ?? _currentActivity2;
    _liveSessionDuration2 = _durationOrNull(json['liveSessionDuration2Ms']);
    _remaining10hDrivingTimes2 = json['remaining10hDrivingTimes2'] as int?;
    _remainingReducedDailyRestPeriods2 =
        json['remainingReducedDailyRestPeriods2'] as int?;
    _nextBreakRestDuration2 = _durationOrNull(json['nextBreakRestDuration2Ms']);
    _currentBreakRestRemaining2 = _durationOrNull(
      json['currentBreakRestRemaining2Ms'],
    );
    _timeUntilNextBreakOrRest2 = _durationOrNull(
      json['timeUntilNextBreakOrRest2Ms'],
    );
    _lastDailyRestEnd2 = _dateOrNull(json['lastDailyRestEnd2']);
    _lastWeeklyRestEnd2 = _dateOrNull(json['lastWeeklyRestEnd2']);
    _compensationLastWeek2 = _durationOrNull(json['compensationLastWeek2Ms']);
    _compensationWeekBeforeLast2 = _durationOrNull(
      json['compensationWeekBeforeLast2Ms'],
    );
    _compensation2ndWeekBeforeLast2 = _durationOrNull(
      json['compensation2ndWeekBeforeLast2Ms'],
    );
    _minimumDailyRest2 = _durationOrNull(json['minimumDailyRest2Ms']);
    _minimumWeeklyRest2 = _durationOrNull(json['minimumWeeklyRest2Ms']);

    _violations = _violationAnalyzer.analyzeLiveRules(
      _drivingRules,
      DateTime.now(),
    );
  }

  Future<void> loadDddFilesIndex() async {
    _dddFiles = await DddFileRepository.instance.listFiles();
    _trashedDddFiles = await DddFileRepository.instance.listTrashedFiles();
    notifyListeners();
  }

  Future<void> setActiveDddFile(DddFile file) async {
    _activeDddFile = file;
    final isVehicleUnit = file.downloadKind == 'vehicleUnit';
    final bytes = await DddFileRepository.instance.readFileBytes(file);
    if (bytes.isNotEmpty && !isVehicleUnit) {
      _currentParsedData = DddFileParser().parse(bytes);
    }
    if (isVehicleUnit && bytes.isNotEmpty) {
      _activeVuData = VuFileDecoder.decode(bytes);
    } else if (file.downloadKind == 'both') {
      final vuBytes = await DddFileRepository.instance.readSecondaryFileBytes(
        file,
      );
      _activeVuData = vuBytes.isNotEmpty ? VuFileDecoder.decode(vuBytes) : null;
    } else {
      _activeVuData = null;
    }
    _recomputeDerivedState();
  }

  Future<void> moveDddFilesToTrash(List<DddFile> files) async {
    final idsToTrash = files.map((f) => f.id).toSet();
    for (final f in files) {
      await DddFileRepository.instance.moveToTrash(f);
    }
    _dddFiles.removeWhere((f) => idsToTrash.contains(f.id));
    _trashedDddFiles.insertAll(
      0,
      files.map((f) => f.copyWith(isTrashed: true, trashedAt: DateTime.now())),
    );

    if (_activeDddFile != null && idsToTrash.contains(_activeDddFile!.id)) {
      if (_dddFiles.isNotEmpty) {
        await setActiveDddFile(_dddFiles.first);
      } else {
        _activeDddFile = null;
        _currentParsedData = null;
        _activeVuData = null;
        _recomputeDerivedState();
      }
    }
    notifyListeners();
  }

  Future<void> restoreDddFiles(List<DddFile> files) async {
    final idsToRestore = files.map((f) => f.id).toSet();
    for (final f in files) {
      await DddFileRepository.instance.restoreFromTrash(f);
    }
    _trashedDddFiles.removeWhere((f) => idsToRestore.contains(f.id));
    _dddFiles.insertAll(
      0,
      files.map((f) => f.copyWith(isTrashed: false, trashedAt: null)),
    );
    notifyListeners();
  }

  Future<void> permanentlyDeleteDddFiles(List<DddFile> files) async {
    final idsToDelete = files.map((f) => f.id).toSet();
    for (final f in files) {
      await DddFileRepository.instance.permanentlyDelete(f);
    }
    _trashedDddFiles.removeWhere((f) => idsToDelete.contains(f.id));
    notifyListeners();
  }

  Future<DddFile?> downloadDddForCurrentCard({
    SendAndReceive? sendAndReceive,
  }) async {
    if (sendAndReceive == null) return null;
    _isDownloadingDdd = true;
    notifyListeners();
    try {
      final result = await DddDownloadService.instance.downloadAll(
        sendAndReceive: sendAndReceive,
        cardSlot: _activeDriver == 'driver2' ? 2 : 1,
        includeVuBlocks: false,
      );
      final cardBytes = result.cardBytes;
      if (cardBytes == null) {
        return null;
      }
      final parsed = DddFileParser().parse(cardBytes);
      final saved = await DddFileRepository.instance.saveDownloadedFile(
        cardBytes,
        cardType: _tachographMode,
        isSimulated: false,
        cardHolderName: parsed.holderFullName,
      );

      await DddPublicExportService.exportToPublicStorage(
        cardBytes,
        fileName: 'smarttrack_kart_${saved.id}',
        subfolder: 'Kart',
      );

      _dddFiles.insert(0, saved);
      _activeDddFile = saved;
      _currentParsedData = parsed;

      _activeVuData = null;
      _recomputeDerivedState();
      return saved;
    } catch (e) {
      debugPrint('DDD download failed: $e');
      return null;
    } finally {
      _isDownloadingDdd = false;
      notifyListeners();
    }
  }

  Future<({DddFile? card, DddFile? vehicleUnit})>
  downloadRealDddFromTachograph({
    required SendAndReceive sendAndReceive,
    DddFetchKind kind = DddFetchKind.both,
    DateTime? activityRangeStart,
    DateTime? activityRangeEnd,
    bool includeEventsFaults = true,
    bool includeDetailedSpeed = true,
    bool includeTechnicalData = true,
    void Function(String message)? onProgress,
  }) async {
    _isDownloadingDdd = true;
    notifyListeners();
    try {
      final result = await DddDownloadService.instance.downloadAll(
        sendAndReceive: sendAndReceive,
        cardSlot: (kind == DddFetchKind.card || kind == DddFetchKind.both)
            ? (_activeDriver == 'driver2' ? 2 : 1)
            : null,
        includeVuBlocks:
            kind == DddFetchKind.vehicleUnit || kind == DddFetchKind.both,
        activityRangeStart: activityRangeStart,
        activityRangeEnd: activityRangeEnd,
        includeEventsFaults: includeEventsFaults,
        includeDetailedSpeed: includeDetailedSpeed,
        includeTechnicalData: includeTechnicalData,
        onProgress: onProgress,
      );
      return await saveRealDddBytes(
        cardBytes: result.cardBytes,
        vuBytes: result.vuBytes,
      );
    } catch (e) {
      debugPrint('Real DDD download failed: $e');
      return (card: null, vehicleUnit: null);
    } finally {
      _isDownloadingDdd = false;
      notifyListeners();
    }
  }

  Future<({DddFile? card, DddFile? vehicleUnit})> saveRealDddBytes({
    Uint8List? cardBytes,
    Uint8List? vuBytes,
  }) async {
    TachographDriverData? cardParsed;
    if (cardBytes != null) {
      try {
        cardParsed = DddFileParser().parse(cardBytes);
      } catch (e) {
        debugPrint(
          'DDP: Kart verisi indi ama ayrıştırılamadı, ham bayt yine de kaydediliyor — $e',
        );
      }
    }

    String vuLabel = '';
    VehicleUnitData? vuParsed;
    if (vuBytes != null) {
      try {
        vuParsed = VuFileDecoder.decode(vuBytes);
        vuLabel = vuParsed.vehicleRegistrationNumber.isNotEmpty
            ? vuParsed.vehicleRegistrationNumber
            : vuParsed.vin;
      } catch (e) {
        debugPrint(
          'DDP: Takograf verisi indi ama ayrıştırılamadı, ham bayt yine de kaydediliyor — $e',
        );
      }
    }

    if (cardBytes == null && vuBytes == null)
      return (card: null, vehicleUnit: null);

    DddFile? savedCard;
    DddFile? savedVu;
    final cardLabel = cardParsed?.holderFullName ?? '';

    if (cardBytes != null && vuBytes != null) {
      final combinedLabel = vuLabel.isNotEmpty
          ? '$cardLabel · $vuLabel'
          : cardLabel;
      final combined = await DddFileRepository.instance.saveDownloadedFile(
        cardBytes,
        cardType: _tachographMode,
        isSimulated: false,
        cardHolderName: combinedLabel,
        downloadKind: 'both',
        secondaryBytes: vuBytes,
      );

      _dddFiles.insert(0, combined);
      _activeDddFile = combined;
      _currentParsedData = cardParsed;
      _activeVuData = vuParsed;
      savedCard = combined;
      savedVu = combined;
      await _exportBestEffort(
        cardBytes,
        fileName: 'smarttrack_kart_${combined.id}',
        subfolder: 'Kart',
      );
      await _exportBestEffort(
        vuBytes,
        fileName: 'smarttrack_takograf_${combined.id}',
        subfolder: 'Takograf',
      );
    } else if (cardBytes != null) {
      savedCard = await DddFileRepository.instance.saveDownloadedFile(
        cardBytes,
        cardType: _tachographMode,
        isSimulated: false,
        cardHolderName: cardLabel,
        downloadKind: 'card',
      );
      _dddFiles.insert(0, savedCard);
      _activeDddFile = savedCard;
      _currentParsedData = cardParsed;
      _activeVuData = null;
      await _exportBestEffort(
        cardBytes,
        fileName: 'smarttrack_kart_${savedCard.id}',
        subfolder: 'Kart',
      );
    } else if (vuBytes != null) {
      savedVu = await DddFileRepository.instance.saveDownloadedFile(
        vuBytes,
        cardType: _tachographMode,
        isSimulated: false,
        cardHolderName: vuLabel,
        downloadKind: 'vehicleUnit',
      );
      _dddFiles.insert(0, savedVu);

      _activeVuData = vuParsed;
      await _exportBestEffort(
        vuBytes,
        fileName: 'smarttrack_takograf_${savedVu.id}',
        subfolder: 'Takograf',
      );
    }

    _recomputeDerivedState();
    return (card: savedCard, vehicleUnit: savedVu);
  }

  Future<({DddFile? card, DddFile? vehicleUnit})> saveDongleTestResultsAsDdd(
    List<DongleDownloadResult> results,
  ) async {
    final latestByTrep = <int, DongleDownloadResult>{};
    for (final r in results) {
      final existing = latestByTrep[r.trep];
      if (existing == null || r.timestamp.isAfter(existing.timestamp))
        latestByTrep[r.trep] = r;
    }

    final cardBytes = latestByTrep[0x06]?.bytes;
    final vuBuffer = BytesBuilder(copy: false);
    for (final trep in [0x01, 0x02, 0x03, 0x04, 0x05]) {
      final bytes = latestByTrep[trep]?.bytes;

      if (bytes != null) {
        vuBuffer.add([0x76, trep]);
        vuBuffer.add(bytes);
      }
    }
    final vuBytes = vuBuffer.takeBytes();

    return saveRealDddBytes(
      cardBytes: (cardBytes == null || cardBytes.isEmpty) ? null : cardBytes,
      vuBytes: vuBytes.isEmpty ? null : vuBytes,
    );
  }

  Future<void> _exportBestEffort(
    Uint8List bytes, {
    required String fileName,
    required String subfolder,
  }) async {
    try {
      await DddPublicExportService.exportToPublicStorage(
        bytes,
        fileName: fileName,
        subfolder: subfolder,
      );
    } catch (e) {
      debugPrint(
        'DDP: genel depolamaya kopyalanamadı (dosya zaten Dosyalar ekranında kayıtlı) — $e',
      );
    }
  }

  Future<DddFile> simulateDddForCurrentCard() async {
    final bytes = DddSimulator().generate();
    final parsed = DddFileParser().parse(bytes);
    final saved = await DddFileRepository.instance.saveDownloadedFile(
      bytes,
      cardType: _tachographMode,
      isSimulated: true,
      cardHolderName: parsed.holderFullName,
    );

    _dddFiles.insert(0, saved);
    _activeDddFile = saved;
    _currentParsedData = parsed;
    _recomputeDerivedState();
    notifyListeners();
    return saved;
  }

  Future<({DddFile? card, DddFile? vehicleUnit})> fetchSampleDdd(
    DddFetchKind kind,
  ) async {
    final random = Random();

    Uint8List? cardBytes;
    TachographDriverData? cardParsed;
    if (kind == DddFetchKind.card || kind == DddFetchKind.both) {
      final cardIndex = random.nextInt(3) + 1;
      cardBytes = (await rootBundle.load(
        'assets/ddd_samples/card/$cardIndex.ddd',
      )).buffer.asUint8List();
      cardParsed = DddFileParser().parse(cardBytes);
    }

    Uint8List? vuBytes;
    String vuLabel = '';
    if (kind == DddFetchKind.vehicleUnit || kind == DddFetchKind.both) {
      final vuIndex = random.nextInt(3) + 1;
      vuBytes = (await rootBundle.load(
        'assets/ddd_samples/tachograph/$vuIndex.ddd',
      )).buffer.asUint8List();

      final vuParsed = VuFileDecoder.decode(vuBytes);
      vuLabel = vuParsed.vehicleRegistrationNumber.isNotEmpty
          ? vuParsed.vehicleRegistrationNumber
          : vuParsed.vin;
    }

    DddFile? savedCard;
    DddFile? savedVu;

    if (kind == DddFetchKind.both) {
      final combinedLabel = vuLabel.isNotEmpty
          ? '${cardParsed!.holderFullName} · $vuLabel'
          : cardParsed!.holderFullName;
      final combined = await DddFileRepository.instance.saveDownloadedFile(
        cardBytes!,
        cardType: _tachographMode,
        isSimulated: false,
        cardHolderName: combinedLabel,
        downloadKind: 'both',
        secondaryBytes: vuBytes,
      );
      _dddFiles.insert(0, combined);
      _activeDddFile = combined;
      _currentParsedData = cardParsed;
      savedCard = combined;
      savedVu = combined;
    } else {
      if (cardBytes != null) {
        savedCard = await DddFileRepository.instance.saveDownloadedFile(
          cardBytes,
          cardType: _tachographMode,
          isSimulated: false,
          cardHolderName: cardParsed!.holderFullName,
          downloadKind: 'card',
        );
        _dddFiles.insert(0, savedCard);
        _activeDddFile = savedCard;
        _currentParsedData = cardParsed;
      }
      if (vuBytes != null) {
        savedVu = await DddFileRepository.instance.saveDownloadedFile(
          vuBytes,
          cardType: _tachographMode,
          isSimulated: false,
          cardHolderName: vuLabel,
          downloadKind: 'vehicleUnit',
        );
        _dddFiles.insert(0, savedVu);
      }
    }

    _recomputeDerivedState();
    notifyListeners();
    return (card: savedCard, vehicleUnit: savedVu);
  }

  Future<void> addManualActivityEntry(TachographActivity entry) async {
    _manualEntries.add(
      TachographActivity(
        type: entry.type,
        startTime: entry.startTime,
        endTime: entry.endTime,
        isManualEntry: true,
        note: entry.note,
      ),
    );
    await _persistManualEntries();
    _recomputeDerivedState();
  }

  Future<void> recordActivityCheckpoint() async {
    _lastKnownActivityTime = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'lastKnownActivityTime',
      _lastKnownActivityTime!.toIso8601String(),
    );
  }

  void checkForRealGap({
    Duration minGap = const Duration(minutes: 30),
    int? currentWorkingStateCode,
    Duration? currentActivityDuration,
  }) {
    final last = _lastKnownActivityTime;
    if (last == null) return;
    final now = DateTime.now();
    if (now.difference(last) < minGap) return;

    final gap = ActivityGap(start: last, end: now);
    final currentType = currentWorkingStateCode != null
        ? _activityTypeFromWorkingStateCode(currentWorkingStateCode)
        : null;

    final afterCurrentDuration = _tryFillGapFromCurrentDuration(
      gap,
      currentType,
      currentActivityDuration,
    );
    if (afterCurrentDuration == null) return;

    if (_tryFillGapFromRealCardData(afterCurrentDuration)) return;
    _pendingRealGap = afterCurrentDuration;
    notifyListeners();
  }

  ActivityGap? _tryFillGapFromCurrentDuration(
    ActivityGap gap,
    ActivityType? currentType,
    Duration? currentDuration,
  ) {
    if (currentType == null || currentDuration == null) return gap;
    final currentSegmentStart = gap.end.subtract(currentDuration);
    if (!currentSegmentStart.isBefore(gap.end)) return gap;

    final coveredStart = currentSegmentStart.isBefore(gap.start)
        ? gap.start
        : currentSegmentStart;
    _liveOpenSegmentType = currentType;
    _liveOpenSegmentStart = coveredStart;
    unawaited(_persistLiveSegmentState());

    if (!currentSegmentStart.isAfter(gap.start)) return null;

    return ActivityGap(start: gap.start, end: currentSegmentStart);
  }

  bool _tryFillGapFromRealCardData(ActivityGap gap) {
    final active = _activeDddFile;
    final parsed = _currentParsedData;
    if (active == null || active.isSimulated || parsed == null) return false;

    final covering = parsed.activityLog
        .where(
          (a) => a.startTime.isBefore(gap.end) && a.endTime.isAfter(gap.start),
        )
        .toList();
    if (!DrivingTimeCalculator.segmentsFullyCoverRange(
      covering,
      gap.start,
      gap.end,
    ))
      return false;

    for (final segment in covering) {
      _liveActivityLog.add(
        TachographActivity(
          type: segment.type,
          startTime: segment.startTime.isBefore(gap.start)
              ? gap.start
              : segment.startTime,
          endTime: segment.endTime.isAfter(gap.end) ? gap.end : segment.endTime,
        ),
      );
    }

    _closeOpenSegmentBefore(gap.start);
    _liveActivityLog.sort((a, b) => a.startTime.compareTo(b.startTime));
    unawaited(_persistLiveActivityLog());
    unawaited(_persistLiveSegmentState());
    return true;
  }

  void _closeOpenSegmentBefore(DateTime cutoff) {
    if (_liveOpenSegmentType != null &&
        _liveOpenSegmentStart != null &&
        _liveOpenSegmentStart!.isBefore(cutoff)) {
      _liveActivityLog.add(
        TachographActivity(
          type: _liveOpenSegmentType!,
          startTime: _liveOpenSegmentStart!,
          endTime: cutoff,
        ),
      );
    }
    _liveOpenSegmentType = null;
    _liveOpenSegmentStart = null;
  }

  Future<void> resolveRealGap(ActivityType type) async {
    final gap = _pendingRealGap;
    if (gap == null) return;
    await addManualActivityEntry(
      TachographActivity(type: type, startTime: gap.start, endTime: gap.end),
    );
    _pendingRealGap = null;

    _closeOpenSegmentBefore(gap.start);
    _liveActivityLog.sort((a, b) => a.startTime.compareTo(b.startTime));
    unawaited(_persistLiveActivityLog());
    await _persistLiveSegmentState();

    await recordActivityCheckpoint();
    notifyListeners();
  }

  Future<void> simulateTestReconnect({Duration? simulateAbsence}) async {
    setBluetoothConnected(true, deviceName: 'Test (Simüle)');
    if (simulateAbsence != null) {
      _lastKnownActivityTime = DateTime.now().subtract(simulateAbsence);
    }
    checkForRealGap();
    await recordActivityCheckpoint();
    notifyListeners();
  }

  static const _openSegmentStaleCap = Duration(hours: 24);

  List<TachographActivity> _dedupSameDateCardRecords(
    List<TachographActivity> log,
  ) {
    final bestCounterByDate = <DateTime, int>{};
    for (final a in log) {
      final counter = a.recordPresenceCounter;
      if (counter == null) continue;
      final day = DateTime(
        a.startTime.year,
        a.startTime.month,
        a.startTime.day,
      );
      final best = bestCounterByDate[day];
      if (best == null || counter > best) bestCounterByDate[day] = counter;
    }
    if (bestCounterByDate.isEmpty) return log;
    return log.where((a) {
      final counter = a.recordPresenceCounter;
      if (counter == null) return true;
      final day = DateTime(
        a.startTime.year,
        a.startTime.month,
        a.startTime.day,
      );
      return counter == bestCounterByDate[day];
    }).toList();
  }

  List<TachographActivity> get _effectiveActivityLog {
    final dddLog = (_activeDddFile != null && !_activeDddFile!.isSimulated)
        ? _dedupSameDateCardRecords(_currentParsedData?.activityLog ?? const [])
        : const <TachographActivity>[];
    final liveDays = _liveActivityLog
        .map(
          (a) => DateTime(a.startTime.year, a.startTime.month, a.startTime.day),
        )
        .toSet();
    final nonOverlappingDddLog = liveDays.isEmpty
        ? dddLog
        : dddLog
              .where(
                (a) => !liveDays.contains(
                  DateTime(
                    a.startTime.year,
                    a.startTime.month,
                    a.startTime.day,
                  ),
                ),
              )
              .toList();

    return [
      ...nonOverlappingDddLog,
      ..._liveActivityLogWithOpenSegment,
      ..._manualEntries,
    ];
  }

  List<TachographActivity> get _liveActivityLogWithOpenSegment {
    if (_liveOpenSegmentType == null || _liveOpenSegmentStart == null)
      return _liveActivityLog;
    final visibleEnd = _isBluetoothConnected
        ? DateTime.now()
        : (_lastKnownActivityTime ?? DateTime.now());
    if (!visibleEnd.isAfter(_liveOpenSegmentStart!)) return _liveActivityLog;
    return [
      ..._liveActivityLog,
      TachographActivity(
        type: _liveOpenSegmentType!,
        startTime:
            visibleEnd.difference(_liveOpenSegmentStart!) > _openSegmentStaleCap
            ? visibleEnd.subtract(_openSegmentStaleCap)
            : _liveOpenSegmentStart!,
        endTime: visibleEnd,
      ),
    ];
  }

  List<TachographActivity> get liveOnlyActivityLog {
    final sorted = List<TachographActivity>.from([
      ..._liveActivityLogWithOpenSegment,
      ..._manualEntries,
    ])..sort((a, b) => a.startTime.compareTo(b.startTime));
    return List.unmodifiable(sorted);
  }

  ActivityType? _activityTypeFromWorkingStateCode(int code) {
    switch (code) {
      case 0:
        return ActivityType.rest;
      case 1:
        return ActivityType.available;
      case 2:
        return ActivityType.work;
      case 3:
        return ActivityType.driving;
      default:
        return null;
    }
  }

  void _recordLiveActivitySample(int workingStateCode, DateTime sampleTime) {
    final type = _activityTypeFromWorkingStateCode(workingStateCode);
    if (type == null) return;

    if (_liveOpenSegmentType == null || _liveOpenSegmentStart == null) {
      _liveOpenSegmentType = type;
      _liveOpenSegmentStart = sampleTime;
      _persistLiveSegmentState();
      return;
    }
    if (type == _liveOpenSegmentType) return;

    _clearComplianceNoticeEligibility('short-break');
    final closedDuration = sampleTime.difference(_liveOpenSegmentStart!);
    if (_liveOpenSegmentType == ActivityType.rest &&
        type == ActivityType.driving &&
        closedDuration < const Duration(minutes: 15)) {
      _raiseComplianceNotice(
        'short-break',
        'Bu ${closedDuration.inMinutes} dakikalık duraklama resmi mola sayılmayabilir '
            '(en az 15 dakika gerekir) — kesintisiz sürüş sayacınız sıfırlanmadı.',
        severity: ComplianceNoticeSeverity.info,
      );
    }

    _liveActivityLog.add(
      TachographActivity(
        type: _liveOpenSegmentType!,
        startTime: _liveOpenSegmentStart!,
        endTime: sampleTime,
      ),
    );
    final cutoff = sampleTime.subtract(_liveActivityLogRetention);
    _liveActivityLog.removeWhere((a) => a.endTime.isBefore(cutoff));

    _liveOpenSegmentType = type;
    _liveOpenSegmentStart = sampleTime;
    _persistLiveActivityLog();
    _persistLiveSegmentState();
  }

  Future<void> _persistLiveActivityLog() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _liveActivityLog
          .map(
            (a) => {
              'type': a.type.index,
              'start': a.startTime.toIso8601String(),
              'end': a.endTime.toIso8601String(),
            },
          )
          .toList(),
    );
    await prefs.setString('liveActivityLog', encoded);
  }

  List<TachographActivity> _decodeLiveActivityLog(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded.map((e) {
      final map = e as Map<String, dynamic>;
      return TachographActivity(
        type: ActivityType.values[map['type'] as int],
        startTime: DateTime.parse(map['start'] as String),
        endTime: DateTime.parse(map['end'] as String),
      );
    }).toList();
  }

  Future<void> _persistLiveSegmentState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_liveOpenSegmentType == null || _liveOpenSegmentStart == null) {
      await prefs.remove('liveSegmentType');
      await prefs.remove('liveSegmentStart');
    } else {
      await prefs.setInt('liveSegmentType', _liveOpenSegmentType!.index);
      await prefs.setString(
        'liveSegmentStart',
        _liveOpenSegmentStart!.toIso8601String(),
      );
    }
  }

  void _recordLiveActivitySample2(int workingStateCode, DateTime sampleTime) {
    final type = _activityTypeFromWorkingStateCode(workingStateCode);
    if (type == null) return;

    if (_liveOpenSegmentType2 == null || _liveOpenSegmentStart2 == null) {
      _liveOpenSegmentType2 = type;
      _liveOpenSegmentStart2 = sampleTime;
      _persistLiveSegmentState2();
      return;
    }
    if (type == _liveOpenSegmentType2) return;

    _liveActivityLog2.add(
      TachographActivity(
        type: _liveOpenSegmentType2!,
        startTime: _liveOpenSegmentStart2!,
        endTime: sampleTime,
      ),
    );
    final cutoff = sampleTime.subtract(_liveActivityLogRetention);
    _liveActivityLog2.removeWhere((a) => a.endTime.isBefore(cutoff));

    _liveOpenSegmentType2 = type;
    _liveOpenSegmentStart2 = sampleTime;
    _persistLiveActivityLog2();
    _persistLiveSegmentState2();
  }

  Future<void> _persistLiveActivityLog2() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _liveActivityLog2
          .map(
            (a) => {
              'type': a.type.index,
              'start': a.startTime.toIso8601String(),
              'end': a.endTime.toIso8601String(),
            },
          )
          .toList(),
    );
    await prefs.setString('liveActivityLog2', encoded);
  }

  Future<void> _persistLiveSegmentState2() async {
    final prefs = await SharedPreferences.getInstance();
    if (_liveOpenSegmentType2 == null || _liveOpenSegmentStart2 == null) {
      await prefs.remove('liveSegmentType2');
      await prefs.remove('liveSegmentStart2');
    } else {
      await prefs.setInt('liveSegmentType2', _liveOpenSegmentType2!.index);
      await prefs.setString(
        'liveSegmentStart2',
        _liveOpenSegmentStart2!.toIso8601String(),
      );
    }
  }

  List<TachographActivity> get liveOnlyActivityLog2 {
    final sorted = List<TachographActivity>.from(
      _liveActivityLogWithOpenSegment2,
    )..sort((a, b) => a.startTime.compareTo(b.startTime));
    return List.unmodifiable(sorted);
  }

  List<TachographActivity> get _liveActivityLogWithOpenSegment2 {
    if (_liveOpenSegmentType2 == null || _liveOpenSegmentStart2 == null)
      return _liveActivityLog2;
    final visibleEnd = _isBluetoothConnected
        ? DateTime.now()
        : (_lastKnownActivityTime ?? DateTime.now());
    if (!visibleEnd.isAfter(_liveOpenSegmentStart2!)) return _liveActivityLog2;
    return [
      ..._liveActivityLog2,
      TachographActivity(
        type: _liveOpenSegmentType2!,
        startTime:
            visibleEnd.difference(_liveOpenSegmentStart2!) >
                _openSegmentStaleCap
            ? visibleEnd.subtract(_openSegmentStaleCap)
            : _liveOpenSegmentStart2!,
        endTime: visibleEnd,
      ),
    ];
  }

  static const _violationAnalysisWindow = Duration(days: 15);

  void _recomputeDerivedState() {
    final activities = _effectiveActivityLog;
    final now = DateTime.now();

    if (activities.isEmpty) {
      _drivingRules = {};
      _totalBreakTime = Duration.zero;
      _violations = [];
      _pendingGaps = [];
      notifyListeners();
      return;
    }

    final sorted = List<TachographActivity>.from(activities)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final windowStart = now.subtract(_violationAnalysisWindow);
    final recent = sorted.where((a) => a.endTime.isAfter(windowStart)).toList();

    _totalBreakTime = recent
        .where((a) => a.type == ActivityType.rest)
        .fold(Duration.zero, (prev, a) => prev + a.duration);

    _drivingRules = _calculator.calculate(recent, now);
    _violations = _violationAnalyzer.analyze(recent, now);
    _pendingGaps = _violationAnalyzer.detectGaps(recent);
    _currentActivity = _activityTypeToLocalizationKey(sorted.last.type);

    if (_currentParsedData != null &&
        _currentParsedData!.vehicleRegistration.isNotEmpty) {
      _vehiclePlate = _currentParsedData!.vehicleRegistration;
    }

    notifyListeners();
  }

  String _activityTypeToLocalizationKey(ActivityType type) {
    switch (type) {
      case ActivityType.driving:
        return 'dashboard.driving';
      case ActivityType.work:
        return 'dashboard.otherWork';
      case ActivityType.available:
        return 'dashboard.availability';
      case ActivityType.rest:
        return 'dashboard.rest';
      case ActivityType.unknown:
        return 'dashboard.noData';
    }
  }

  Future<void> _persistManualEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _manualEntries
          .map(
            (a) => {
              'type': a.type.index,
              'start': a.startTime.toIso8601String(),
              'end': a.endTime.toIso8601String(),
              'note': a.note,
            },
          )
          .toList(),
    );
    await prefs.setString('manualActivityEntries', encoded);
  }

  List<TachographActivity> _decodeManualEntries(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded.map((e) {
      final map = e as Map<String, dynamic>;
      return TachographActivity(
        type: ActivityType.values[map['type'] as int],
        startTime: DateTime.parse(map['start'] as String),
        endTime: DateTime.parse(map['end'] as String),
        isManualEntry: true,
        note: map['note'] as String?,
      );
    }).toList();
  }
}

class AppStateProvider extends StatefulWidget {
  final Widget child;
  const AppStateProvider({super.key, required this.child});

  static AppState of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<_InheritedAppState>();
    assert(provider != null, 'AppStateProvider not found in the widget tree');
    return provider!.state;
  }

  @override
  State<AppStateProvider> createState() => _AppStateProviderState();
}

class _AppStateProviderState extends State<AppStateProvider> {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    _appState.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedAppState(state: _appState, child: widget.child);
  }
}

class _InheritedAppState extends InheritedWidget {
  final AppState state;

  const _InheritedAppState({required this.state, required super.child});

  @override
  bool updateShouldNotify(_InheritedAppState oldWidget) => true;
}
