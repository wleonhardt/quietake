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

  @override
  String get camUnavailable =>
      'Appareil photo indisponible. Vérifiez l\'autorisation de l\'appareil photo dans les Réglages.';

  @override
  String get camTagsOpenFailed =>
      'Impossible d\'ouvrir les étiquettes privées. Réessayez depuis la Bibliothèque.';

  @override
  String get camOrientationFailed =>
      'Impossible de mettre à jour l\'orientation de l\'appareil photo.';

  @override
  String get camPendingSave =>
      'Capture en attente d\'enregistrement sécurisé. Libérez de l\'espace, puis verrouillez et déverrouillez pour réessayer.';

  @override
  String camRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures récupérées',
      one: '1 capture récupérée',
    );
    return '$_temp0.';
  }

  @override
  String get camRecoveredVideoNote =>
      'Les vidéos interrompues peuvent être incomplètes ou ne pas se lire sur un téléviseur.';

  @override
  String get camPendingCheckFailed =>
      'Impossible de vérifier les captures en attente. Libérez de l\'espace et rouvrez l\'appareil photo.';

  @override
  String get camNone => 'Aucun appareil photo';

  @override
  String get camFocusLockFailed =>
      'Impossible de verrouiller la mise au point et l\'exposition sur cet appareil photo.';

  @override
  String get camRecordStartFailed =>
      'Impossible de démarrer l\'enregistrement. Réessayez.';

  @override
  String get camRecordStopFailed =>
      'Impossible d\'arrêter l\'enregistrement. Réessayez.';

  @override
  String get camNoFrames =>
      'Aucune image vidéo n\'a été enregistrée. Réessayez.';

  @override
  String get camPendingNoTags =>
      'Capture en attente d\'enregistrement sécurisé. Les étiquettes n\'ont pas été appliquées ; vérifiez la Bibliothèque après la récupération.';

  @override
  String get camSaveFailed =>
      'Impossible d\'enregistrer la capture. Réessayez.';

  @override
  String camSavedPhotos(int count) {
    return '$count photos enregistrées en toute sécurité';
  }

  @override
  String get camSwitchFailed =>
      'Impossible de changer d\'appareil photo. Réessayez.';

  @override
  String get camMicDenied =>
      'Autorisez l\'accès au microphone dans les Réglages pour enregistrer des vidéos. Les photos restent disponibles.';

  @override
  String get camVideoStartFailed =>
      'Impossible de démarrer la vidéo. Vérifiez les autorisations de l\'appareil photo et du microphone dans les Réglages.';

  @override
  String get camSaving => 'Enregistrement sécurisé…';

  @override
  String get camSaved => 'Enregistré en toute sécurité';

  @override
  String get camTagsNotApplied =>
      'Les étiquettes n\'ont pas été appliquées ; organisez-les dans la Bibliothèque.';

  @override
  String get camNotCastReady =>
      'Cette vidéo peut ne pas se lire sur votre téléviseur.';

  @override
  String get camPreview => 'Aperçu de l\'appareil photo';

  @override
  String get camPreviewHint =>
      'Touchez pour faire la mise au point. Maintenez pour verrouiller la mise au point et l\'exposition.';

  @override
  String get camFocusLocked => 'Mise au point et exposition verrouillées';

  @override
  String camRecTimer(String time) {
    return 'REC $time';
  }

  @override
  String get camStartingVideo => 'Démarrage de la vidéo…';

  @override
  String get camCastFailed => 'Impossible de diffuser. Réessayez.';

  @override
  String camCasting(String device) {
    return 'Diffusion vers $device';
  }

  @override
  String get camChooseTags => 'Choisir les étiquettes des nouvelles captures';

  @override
  String get camTags => 'Étiquettes';

  @override
  String camTagCount(int count) {
    return '$count étiquettes';
  }

  @override
  String get camTimerOff => 'Minuteur désactivé';

  @override
  String camTimerSeconds(int seconds) {
    return 'Minuteur de $seconds secondes';
  }

  @override
  String get camGridHide => 'Masquer la grille';

  @override
  String get camGridShow => 'Afficher la grille';

  @override
  String get camSwitchRear => 'Passer à l\'appareil photo arrière';

  @override
  String get camSwitchFront => 'Passer à l\'appareil photo avant';

  @override
  String get camStopRecording => 'Arrêter l\'enregistrement';

  @override
  String get camRecordVideo => 'Enregistrer une vidéo';

  @override
  String get camStop => 'Arrêter';

  @override
  String get camVideo => 'Vidéo';

  @override
  String get camTakePhoto => 'Prendre une photo';

  @override
  String get camCancelTimer => 'Annuler le minuteur';

  @override
  String get camPhoto => 'Photo';

  @override
  String get camOpenLibrary => 'Ouvrir la Bibliothèque';

  @override
  String get camLibrary => 'Bibliothèque';

  @override
  String camTakeBurst(int count) {
    return 'Prendre $count photos';
  }

  @override
  String get save => 'Enregistrer';

  @override
  String get tagsTitle => 'Étiquettes';

  @override
  String get tagsMoments => 'Moments';

  @override
  String get tagsSortName => 'Trier par nom';

  @override
  String get tagsSortCount => 'Trier par nombre de captures';

  @override
  String get tagsCreate => 'Créer une étiquette';

  @override
  String get tagsFind => 'Rechercher des étiquettes';

  @override
  String get tagsCountFailed => 'Impossible de compter les captures. Réessayer';

  @override
  String get tagsUntagged => 'Sans étiquette';

  @override
  String tagsCaptureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures',
      one: '1 capture',
    );
    return '$_temp0';
  }

  @override
  String get tagsNoMatch => 'Aucune étiquette correspondante';

  @override
  String get tagsNone => 'Aucune étiquette pour l\'instant';

  @override
  String get tagsNoMatchHint => 'Essayez un autre nom ou créez celle-ci.';

  @override
  String get tagsNoneHint =>
      'Les étiquettes regroupent les captures dans toute la Bibliothèque.';

  @override
  String tagsCreateNamed(String name) {
    return 'Créer « $name »';
  }

  @override
  String get tagsCreateFirst => 'Créer la première étiquette';

  @override
  String get tagsOptions => 'Options de l\'étiquette';

  @override
  String get tagsRename => 'Renommer';

  @override
  String get tagsRenameTitle => 'Renommer l\'étiquette';

  @override
  String get tagsSetCover => 'Définir la couverture';

  @override
  String get tagsClearCover => 'Retirer la couverture';

  @override
  String get tagsMergeInto => 'Fusionner avec…';

  @override
  String get tagsDelete => 'Supprimer l\'étiquette';

  @override
  String get tagsDeleteTitle => 'Supprimer l\'étiquette ?';

  @override
  String tagsDeleteBody(String name) {
    return 'Retirer « $name » de toutes les captures ? Les photos et les vidéos restent dans votre coffre.';
  }

  @override
  String get tagsMergeTitle => 'Fusionner les étiquettes ?';

  @override
  String tagsMergeBody(String source, String target, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures utiliseront',
      one: '1 capture utilisera',
    );
    return 'Fusionner « $source » avec « $target » ? $_temp0 l\'étiquette restante. L\'étiquette d\'origine est supprimée. Les photos, les vidéos et les autres étiquettes restent inchangées.';
  }

  @override
  String get tagsMergeConfirm => 'Fusionner les étiquettes';

  @override
  String get mergeChoose => 'Choisissez l\'étiquette à conserver';

  @override
  String get mergeCancel => 'Annuler la fusion';

  @override
  String get mergeFindDestination => 'Rechercher l\'étiquette de destination';

  @override
  String get libraryNameLabel => 'Nom';

  @override
  String get librarySaveFailed => 'Impossible d\'enregistrer. Réessayez.';

  @override
  String get libraryUpdateFailed =>
      'Impossible de mettre à jour la bibliothèque privée. Réessayez.';

  @override
  String get momentsLoadFailed => 'Impossible de lire les captures. Réessayer';

  @override
  String get momentsEmpty => 'Aucune capture datée pour l\'instant';

  @override
  String get viewTitle => 'Affichage';

  @override
  String get viewAll => 'Tout';

  @override
  String get viewPhotos => 'Photos';

  @override
  String get viewVideos => 'Vidéos';

  @override
  String get viewFavoritesOnly => 'Favoris uniquement';

  @override
  String get viewSort => 'Trier';

  @override
  String get viewNewest => 'Plus récentes d\'abord';

  @override
  String get viewOldest => 'Plus anciennes d\'abord';

  @override
  String get viewName => 'Nom';

  @override
  String get viewApply => 'Appliquer l\'affichage';

  @override
  String viewShowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Afficher $count captures',
      one: 'Afficher 1 capture',
    );
    return '$_temp0';
  }

  @override
  String get viewReset => 'Réinitialiser';
}
