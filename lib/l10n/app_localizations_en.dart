// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get recentlyDeletedTitle => 'Recently deleted';

  @override
  String get recentlyDeletedEmpty => 'Nothing recently deleted';

  @override
  String recentlyDeletedNote(int days) {
    return 'Deleted captures stay encrypted on this phone for $days days, then are removed for good.';
  }

  @override
  String get recentlyDeletedLoadFailed =>
      'Could not read deleted captures. Retry';

  @override
  String recentlyDeletedDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get recentlyDeletedRestore => 'Restore';

  @override
  String get recentlyDeletedDeleteNow => 'Delete now';

  @override
  String get recentlyDeletedDeleteNowTitle => 'Delete now?';

  @override
  String get recentlyDeletedDeleteNowBody =>
      'This capture is permanently removed from this phone and your configured NAS. It cannot be restored.';

  @override
  String get recentlyDeletedAllTitle => 'Delete all now?';

  @override
  String recentlyDeletedAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count captures are permanently removed from this phone and your configured NAS. They cannot be restored.',
      one: '1 capture is permanently removed from this phone and your configured NAS. It cannot be restored.',
    );
    return '$_temp0';
  }

  @override
  String get recentlyDeletedAllNow => 'Delete all now';

  @override
  String get recentlyDeletedRestoreFailed => 'Could not restore. Please retry.';

  @override
  String get recentlyDeletedDeleteFailed =>
      'Could not finish deleting. Please retry.';

  @override
  String get cancel => 'Cancel';
}
