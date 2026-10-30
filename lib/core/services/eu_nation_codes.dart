import '../localization/localization.dart';

class EuNationCodes {
  EuNationCodes._();

  /// The codes with a name: 0-57 and 253-255. The names are `nation.<code>`
  /// in the localization map.
  static bool isKnown(int code) => (code >= 0 && code <= 57) || code >= 253;

  static String label(int code) => isKnown(code) && code <= 255
      ? AppLocalizations.text('nation.$code')
      : AppLocalizations.text('nation.unknown', {'code': code});
}
