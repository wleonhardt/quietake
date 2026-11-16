// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get recentlyDeletedTitle => 'Zuletzt gelöscht';

  @override
  String get recentlyDeletedEmpty => 'Nichts kürzlich gelöscht';

  @override
  String recentlyDeletedNote(int days) {
    return 'Gelöschte Aufnahmen bleiben $days Tage verschlüsselt auf diesem Telefon und werden dann endgültig entfernt.';
  }

  @override
  String get recentlyDeletedLoadFailed =>
      'Gelöschte Aufnahmen konnten nicht gelesen werden. Erneut versuchen';

  @override
  String recentlyDeletedDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Tage',
      one: 'Noch $count Tag',
    );
    return '$_temp0';
  }

  @override
  String get recentlyDeletedRestore => 'Wiederherstellen';

  @override
  String get recentlyDeletedDeleteNow => 'Jetzt löschen';

  @override
  String get recentlyDeletedDeleteNowTitle => 'Jetzt löschen?';

  @override
  String get recentlyDeletedDeleteNowBody =>
      'Diese Aufnahme wird dauerhaft von diesem Telefon und von Ihrem eingerichteten NAS entfernt. Sie kann nicht wiederhergestellt werden.';

  @override
  String get recentlyDeletedAllTitle => 'Alle jetzt löschen?';

  @override
  String recentlyDeletedAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Aufnahmen werden dauerhaft von diesem Telefon und von Ihrem eingerichteten NAS entfernt. Sie können nicht wiederhergestellt werden.',
      one:
          '$count Aufnahme wird dauerhaft von diesem Telefon und von Ihrem eingerichteten NAS entfernt. Sie kann nicht wiederhergestellt werden.',
    );
    return '$_temp0';
  }

  @override
  String get recentlyDeletedAllNow => 'Alle jetzt löschen';

  @override
  String get recentlyDeletedRestoreFailed =>
      'Wiederherstellung fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get recentlyDeletedDeleteFailed =>
      'Löschen konnte nicht abgeschlossen werden. Bitte erneut versuchen.';

  @override
  String get cancel => 'Abbrechen';
}
