import '../localization/localization.dart';

class EuEventFaultCodes {
  EuEventFaultCodes._();

  /// EventFaultType codes and the localization keys of their names.
  static const Map<int, String> eventLabels = {
    1: 'euEvent.invalidCard',
    2: 'euEvent.cardConflict',
    3: 'euEvent.timeOverlap',
    4: 'euEvent.drivingWithoutCard',
    5: 'euEvent.cardInsertedWhileDriving',
    6: 'euEvent.lastSessionNotClosed',
    7: 'euEvent.overSpeeding',
    8: 'euEvent.powerInterruption',
    9: 'euEvent.motionDataError',
    10: 'euEvent.vehicleMotionConflict',

    19: 'euEvent.sensorChanged',
  };

  static const Map<int, String> faultLabels = {
    48: 'euFault.vuNoDetail',
    49: 'euFault.vuInternal',
    50: 'euFault.printer',
    51: 'euFault.display',
    52: 'euFault.download',
    53: 'euFault.sensor',
    64: 'euFault.cardNoDetail',
  };

  static String eventLabel(int code) =>
      _label(eventLabels[code] ?? 'euEvent.unknown', code);

  static String faultLabel(int code) =>
      _label(faultLabels[code] ?? 'euFault.unknown', code);

  static String _label(String key, int code) => AppLocalizations.text(
    'eu.codeLabel',
    {'label': AppLocalizations.text(key), 'code': code},
  );
}
