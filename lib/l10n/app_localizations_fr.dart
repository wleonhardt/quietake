// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get recentlyDeletedTitle => 'Supprimés récemment';

  @override
  String get recentlyDeletedEmpty => 'Rien de supprimé récemment';

  @override
  String recentlyDeletedNote(int days) {
    return 'Les captures supprimées restent chiffrées sur ce téléphone pendant $days jours, puis sont supprimées définitivement.';
  }

  @override
  String get recentlyDeletedLoadFailed =>
      'Impossible de lire les captures supprimées. Réessayer';

  @override
  String recentlyDeletedDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours restants',
      one: '$count jour restant',
    );
    return '$_temp0';
  }

  @override
  String get recentlyDeletedRestore => 'Restaurer';

  @override
  String get recentlyDeletedDeleteNow => 'Supprimer maintenant';

  @override
  String get recentlyDeletedDeleteNowTitle => 'Supprimer maintenant ?';

  @override
  String get recentlyDeletedDeleteNowBody =>
      'Cette capture est supprimée définitivement de ce téléphone et de votre NAS configuré. Elle ne peut pas être restaurée.';

  @override
  String get recentlyDeletedAllTitle => 'Tout supprimer maintenant ?';

  @override
  String recentlyDeletedAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count captures sont supprimées définitivement de ce téléphone et de votre NAS configuré. Elles ne peuvent pas être restaurées.',
      one:
          '$count capture est supprimée définitivement de ce téléphone et de votre NAS configuré. Elle ne peut pas être restaurée.',
    );
    return '$_temp0';
  }

  @override
  String get recentlyDeletedAllNow => 'Tout supprimer maintenant';

  @override
  String get recentlyDeletedRestoreFailed =>
      'Impossible de restaurer. Veuillez réessayer.';

  @override
  String get recentlyDeletedDeleteFailed =>
      'Impossible de terminer la suppression. Veuillez réessayer.';

  @override
  String get cancel => 'Annuler';
}
