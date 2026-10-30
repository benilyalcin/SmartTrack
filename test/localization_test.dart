import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/localization/localization.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';

final _placeholder = RegExp(r'\{[A-Za-z]+\}');

List<String> _placeholders(String text) =>
    _placeholder.allMatches(text).map((m) => m.group(0)!).toList()..sort();

void main() {
  const added = ['RU', 'PL', 'RO', 'ES', 'UK'];

  test('every language has a name and the picker lists them all', () {
    expect(AppLocalizations.languages, hasLength(8));
    for (final lang in AppLocalizations.languages) {
      expect(AppLocalizations.languageNames[lang], isNotNull, reason: lang);
    }
  });

  for (final lang in added) {
    group(lang, () {
      final table = AppLocalizations.moreLanguage(lang)!;
      final known = AppLocalizations.keys.toSet();

      test('has no key the main map does not know', () {
        expect(table.keys.where((k) => !known.contains(k)), isEmpty);
      });

      test('keeps the placeholders of the English text', () {
        for (final MapEntry(:key, :value) in table.entries) {
          expect(
            _placeholders(value),
            _placeholders(AppLocalizations.getText('EN', key)),
            reason: '$lang $key',
          );
        }
      });

      test('translates every text for now', () {
        // Not a rule for later: a new key without a translation is shown in
        // English. This only checks nothing was left out today.
        expect(known.where((k) => !table.containsKey(k)), isEmpty);
      });
    });
  }

  test('a language without its own text falls back to English', () {
    expect(AppLocalizations.getText('RU', 'nav.settings'), 'Настройки');
    expect(AppLocalizations.getText('XX', 'nav.settings'), 'Settings');
    expect(AppLocalizations.getText('RU', 'no.such.key'), 'no.such.key');
  });

  test('dates read the way each language writes them', () {
    final date = DateTime(2026, 10, 19); // a Monday
    expect(AppLocalizations.formatDate('TR', date), '19 Ekim 2026, Pazartesi');
    expect(
      AppLocalizations.formatDate('RU', date),
      '19 октября 2026, понедельник',
    );
    expect(
      AppLocalizations.formatDate('PL', date),
      '19 października 2026, poniedziałek',
    );
    expect(
      AppLocalizations.formatDate('ES', date),
      '19 de octubre de 2026, lunes',
    );
    expect(AppLocalizations.weekdayShort('UK', 7), 'Нд');
  });

  test('the chosen language is kept across launches', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final first = AppState();
    await pumpEventQueue();
    first.setLanguage('PL');
    await pumpEventQueue();

    final second = AppState();
    await pumpEventQueue();
    expect(second.selectedLanguage, 'PL');
  });
}
