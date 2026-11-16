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

  @override
  String get lockUnlockReason => 'Déverrouiller Quietake';

  @override
  String get lockBiometricUnavailable =>
      'Le déverrouillage biométrique n\'est pas disponible. Utilisez votre code d\'accès.';

  @override
  String get lockFailed =>
      'Impossible de déverrouiller. Réessayez ou utilisez votre clé de récupération.';

  @override
  String get lockMessage => 'Déverrouillez votre coffre privé.';

  @override
  String get passcodeLabel => 'Code d\'accès';

  @override
  String get lockUnlock => 'Déverrouiller';

  @override
  String get lockUseBiometrics => 'Utiliser la biométrie';

  @override
  String get lockForgot => 'Code d\'accès oublié ?';

  @override
  String get recoveryKeyLabel => 'Clé de récupération';

  @override
  String get recoveryKeyIntro =>
      'Conservez cette clé dans votre gestionnaire de mots de passe, séparément de vos fichiers chiffrés. Il vous faut les deux pour récupérer vos captures si vous oubliez le code d\'accès ou perdez cet appareil. Une phrase secrète de sauvegarde NAS est une autre option de récupération, uniquement si vous l\'avez activée.';

  @override
  String recoveryFingerprint(String fingerprint) {
    return 'Empreinte $fingerprint';
  }

  @override
  String get recoveryFingerprintNote =>
      'Conservez l\'empreinte avec la clé. Un nouveau téléphone l\'affiche pour vous permettre de vérifier la clé saisie.';

  @override
  String get recoverySaved => 'Je l\'ai enregistrée';

  @override
  String get changePasscodeTitle => 'Changer le code d\'accès';

  @override
  String get changePasscodeNote =>
      'Vos captures et votre clé de récupération restent identiques.';

  @override
  String get currentPasscodeLabel => 'Code d\'accès actuel';

  @override
  String get newPasscodeLabel => 'Nouveau code d\'accès';

  @override
  String get confirmNewPasscodeLabel => 'Confirmer le nouveau code d\'accès';

  @override
  String get passcodesDoNotMatch => 'Les codes d\'accès ne correspondent pas';

  @override
  String get currentPasscodeIncorrect =>
      'Le code d\'accès actuel est incorrect';

  @override
  String get changePasscodeFailed =>
      'Impossible de changer le code d\'accès. Réessayez.';

  @override
  String get changePasscodeBusy => 'Modification…';

  @override
  String get setupConfirmKeyTitle => 'Confirmer la clé de récupération';

  @override
  String get setupConfirmKeyBody =>
      'Ce téléphone n\'a pas encore de captures, la clé ne peut donc pas être vérifiée avec elles. Comparez cette empreinte à celle conservée avec votre clé de récupération.';

  @override
  String get setupNotMine => 'Ce n\'est pas la mienne';

  @override
  String get setupMatches => 'Correspond';

  @override
  String get setupCreateFailed =>
      'Impossible de créer le coffre. Vérifiez le stockage et réessayez.';

  @override
  String get setupRestoreFailed =>
      'Impossible de restaurer le coffre. Vérifiez le stockage et réessayez.';

  @override
  String get setupRestoreTitle => 'Restaurer le coffre';

  @override
  String get setupCreateTitle => 'Définir un code d\'accès';

  @override
  String get setupRestoreMessage =>
      'Déverrouillez vos fichiers chiffrés avec votre clé de récupération enregistrée.';

  @override
  String get setupTagline =>
      'Votre appareil photo. Vos captures. Votre contrôle.';

  @override
  String setupPasscodeHelper(int count) {
    return 'Au moins $count caractères';
  }

  @override
  String get confirmPasscodeLabel => 'Confirmer le code d\'accès';

  @override
  String get restore => 'Restaurer';

  @override
  String get setupCreateVault => 'Créer le coffre';

  @override
  String get setupStartNew => 'Commencer plutôt un nouveau coffre';

  @override
  String get setupHaveKey => 'J\'ai une clé de récupération';

  @override
  String get setupRestoreZip => 'Restaurer un ZIP chiffré';

  @override
  String get setupRestoreNas =>
      'Restaurer depuis le NAS avec la phrase secrète de sauvegarde';

  @override
  String get privacyPolicy => 'Politique de confidentialité';
}
