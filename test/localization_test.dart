import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/l10n/l10n.dart';

Map<String, String> strings(String code) {
  final json = jsonDecode(
    File('lib/l10n/app_$code.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return {
    for (final e in json.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

Set<String> placeholders(String text) =>
    RegExp(r'\{(\w+)[,}]').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  final english = strings('en');

  test('every language has the same messages and placeholders as English', () {
    for (final code in ['es', 'fr', 'de']) {
      final other = strings(code);
      expect(other.keys.toSet(), english.keys.toSet(), reason: code);
      for (final key in english.keys) {
        expect(other[key], isNotEmpty, reason: '$code $key');
        expect(
          placeholders(other[key]!),
          placeholders(english[key]!),
          reason: '$code $key',
        );
      }
    }
  });

  test('supported languages are English, Spanish, French and German', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      {'en', 'es', 'fr', 'de'},
    );
  });

  test('plurals follow each language', () {
    String left(String code, int n) =>
        lookupAppLocalizations(Locale(code)).recentlyDeletedDaysLeft(n);
    expect(left('en', 1), '1 day left');
    expect(left('en', 20), '20 days left');
    expect(left('es', 1), 'Queda 1 día');
    expect(left('es', 20), 'Quedan 20 días');
    // French treats zero as singular.
    expect(left('fr', 0), '0 jour restant');
    expect(left('fr', 2), '2 jours restants');
    expect(left('de', 1), 'Noch 1 Tag');
    expect(left('de', 3), 'Noch 3 Tage');
  });
}
