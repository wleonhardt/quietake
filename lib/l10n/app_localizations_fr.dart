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
  String passcodeLockedSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Trop de codes d\'accès incorrects. Réessayez dans $count secondes.',
      one: 'Trop de codes d\'accès incorrects. Réessayez dans 1 seconde.',
    );
    return '$_temp0';
  }

  @override
  String passcodeLockedMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Trop de codes d\'accès incorrects. Réessayez dans $count minutes.',
      one: 'Trop de codes d\'accès incorrects. Réessayez dans 1 minute.',
    );
    return '$_temp0';
  }

  @override
  String passcodeTooShort(int count) {
    return 'Le code d\'accès doit comporter au moins $count caractères';
  }

  @override
  String get passcodeShow => 'Afficher le code d\'accès';

  @override
  String get passcodeHide => 'Masquer le code d\'accès';

  @override
  String get formWorking => 'Un instant…';

  @override
  String get lockUnlock => 'Déverrouiller';

  @override
  String get lockUseBiometrics => 'Utiliser la biométrie';

  @override
  String get lockForgot => 'Code d\'accès oublié ?';

  @override
  String get lockCamera => 'Appareil photo';

  @override
  String get lockedCameraSaved =>
      'Photo scellée. Elle apparaît dans votre bibliothèque après le déverrouillage.';

  @override
  String get lockedCameraFailed => 'Impossible d\'enregistrer la photo.';

  @override
  String get lockedCameraClose => 'Fermer l\'appareil photo';

  @override
  String lockedCapturesPublished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count photos prises depuis l\'écran verrouillé sont maintenant dans votre bibliothèque.',
      one: '1 photo prise depuis l\'écran verrouillé est maintenant dans votre bibliothèque.',
    );
    return '$_temp0';
  }

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
  String get recoveryShowText => 'Afficher en texte';

  @override
  String get recoveryShowWords => 'Afficher en mots';

  @override
  String get recoveryFormsNote =>
      'Les mots et le texte sont la même clé. Enregistrez l\'une des deux formes.';

  @override
  String get recoveryKeyFieldHelp => '21 mots ou la forme texte';

  @override
  String get recoveryKeyShow => 'Afficher la clé de récupération';

  @override
  String get recoveryKeyHide => 'Masquer la clé de récupération';

  @override
  String get recoveryWordsCount =>
      'Une clé de récupération compte 21 mots. Vérifiez qu\'il ne manque aucun mot et qu\'il n\'y en a pas en trop.';

  @override
  String recoveryWordsUnknown(int position) {
    return 'Le mot $position ne figure pas dans la liste de mots. Vérifiez son orthographe.';
  }

  @override
  String get recoveryWordsWrong =>
      'Un mot est incorrect ou mal placé. Vérifiez les 21 mots.';

  @override
  String get recoveryConfirmTitle => 'Vérifiez votre copie enregistrée';

  @override
  String recoveryConfirmBody(int position) {
    return 'Regardez la copie que vous avez enregistrée, pas ce téléphone. Saisissez le mot $position ou collez la clé entière.';
  }

  @override
  String recoveryConfirmField(int position) {
    return 'Mot $position';
  }

  @override
  String get recoveryConfirmAction => 'Confirmer';

  @override
  String get recoveryConfirmBack => 'Afficher de nouveau la clé';

  @override
  String recoveryConfirmWrong(int position) {
    return 'Ce n\'est pas le mot $position. Vérifiez votre copie enregistrée.';
  }

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
  String get camFlashOff => 'Flash désactivé';

  @override
  String get camFlashAuto => 'Flash automatique';

  @override
  String get camFlashOn => 'Flash activé';

  @override
  String get camFlashUnavailable => 'Cet appareil photo n’a pas de flash.';

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

  @override
  String get pickerCameraTitle => 'Étiquettes des nouvelles captures';

  @override
  String get pickerRemoveTitle => 'Retirer des étiquettes';

  @override
  String get pickerAddTitle => 'Ajouter des étiquettes';

  @override
  String get pickerCameraNote => 'Effacé au verrouillage ou en arrière-plan.';

  @override
  String pickerSelectionNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures',
      one: '1 capture',
    );
    return '$_temp0 · les autres étiquettes restent inchangées';
  }

  @override
  String get pickerCancel => 'Annuler la sélection d\'étiquettes';

  @override
  String get pickerNoTags => 'Aucune étiquette';

  @override
  String pickerAlreadyTagged(int tagged, int total) {
    return '$tagged sur $total déjà étiquetées';
  }

  @override
  String get pickerManage => 'Gérer les étiquettes';

  @override
  String get pickerStale =>
      'Une étiquette sélectionnée a changé. Vérifiez votre sélection.';

  @override
  String get pickerReview => 'Vérifier';

  @override
  String pickerUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Utiliser $count étiquettes',
      one: 'Utiliser 1 étiquette',
    );
    return '$_temp0';
  }

  @override
  String pickerAddCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter $count étiquettes',
      one: 'Ajouter 1 étiquette',
    );
    return '$_temp0';
  }

  @override
  String pickerRemoveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retirer $count étiquettes',
      one: 'Retirer 1 étiquette',
    );
    return '$_temp0';
  }

  @override
  String get galleryActions => 'Actions de la bibliothèque';

  @override
  String get galleryActionsClose => 'Fermer les actions de la bibliothèque';

  @override
  String get gallerySelectCaptures => 'Sélectionner des captures';

  @override
  String get gallerySearchEdit => 'Modifier la recherche';

  @override
  String get gallerySearchHint => 'Rechercher des noms et des étiquettes';

  @override
  String get galleryRemovedTag => 'Étiquette supprimée';

  @override
  String get galleryScopeAny =>
      'Toute la bibliothèque · N\'importe quelle étiquette';

  @override
  String get galleryScopeAll => 'Toute la bibliothèque · Toutes les étiquettes';

  @override
  String get galleryToday => 'Aujourd\'hui';

  @override
  String get galleryYesterday => 'Hier';

  @override
  String get galleryNoDate => 'Sans date';

  @override
  String get gallerySortNewest => 'Captures les plus récentes';

  @override
  String get gallerySortOldest => 'Captures les plus anciennes';

  @override
  String get gallerySortName => 'Ordre par nom';

  @override
  String get galleryTagMatching => 'Correspondance des étiquettes';

  @override
  String get galleryMatchAll => 'Toutes les étiquettes';

  @override
  String get galleryMatchAny => 'N\'importe quelle étiquette';

  @override
  String get galleryFavorites => 'Favoris';

  @override
  String get galleryResetView => 'Réinitialiser l\'affichage';

  @override
  String get galleryAddTag => 'Ajoutez une étiquette';

  @override
  String get galleryAddTagHint =>
      'Choisissez des étiquettes existantes ou recherchez des noms avec le texte ci-dessus.';

  @override
  String get galleryCancelSelection => 'Annuler la sélection';

  @override
  String galleryDeleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count captures ?',
      one: 'Supprimer 1 capture ?',
    );
    return '$_temp0';
  }

  @override
  String galleryDeleteKeepBody(int days) {
    return 'La sélection est déplacée dans « Supprimés récemment » et reste sur ce téléphone, chiffrée, pendant $days jours pour que vous puissiez la restaurer. La copie sur le NAS est conservée jusque-là.';
  }

  @override
  String get galleryDeleteMove => 'Déplacer dans « Supprimés récemment »';

  @override
  String gallerySelectedCount(int count) {
    return '$count sélectionnées';
  }

  @override
  String get gallerySelectAll => 'Sélectionner tous les résultats';

  @override
  String get galleryShareCopies => 'Partager des copies';

  @override
  String get galleryUnfavorite => 'Retirer des favoris';

  @override
  String get galleryFavorite => 'Favori';

  @override
  String get galleryNameCapture => 'Nommer la capture';

  @override
  String get galleryNasReadFailed =>
      'Impossible de lire les informations NAS enregistrées. Réessayez.';

  @override
  String get galleryImportTooltip => 'Importer des copies depuis Fichiers';

  @override
  String get gallerySyncCancel => 'Annuler la synchronisation';

  @override
  String get gallerySyncSetup => 'Configurer la sauvegarde';

  @override
  String get gallerySyncNow => 'Synchroniser avec le NAS';

  @override
  String get galleryCloseSearch => 'Fermer la recherche';

  @override
  String get gallerySearchTitle => 'Recherche';

  @override
  String get gallerySettings => 'Réglages';

  @override
  String get galleryOrgUnavailable =>
      'Organisation indisponible. Les originaux sont en sécurité. Réessayer';

  @override
  String get galleryOpenFailed => 'Impossible d\'ouvrir le coffre. Réessayer';

  @override
  String get galleryEmptyTitle => 'Votre bibliothèque commence ici';

  @override
  String get galleryEmptyMessage =>
      'Prenez une photo ou importez des copies depuis Fichiers.';

  @override
  String get galleryOpenCamera => 'Ouvrir l\'appareil photo';

  @override
  String get galleryImportCopies => 'Importer des copies';

  @override
  String get galleryNoMatchTitle => 'Aucune capture ne correspond';

  @override
  String get galleryNoMatchMessage =>
      'Effacez la recherche et les filtres pour voir toutes les captures.';

  @override
  String get galleryClearFilters => 'Effacer la recherche et les filtres';

  @override
  String galleryTileSelect(String label) {
    return 'Sélectionner $label';
  }

  @override
  String galleryTileOpen(String label) {
    return 'Ouvrir $label';
  }

  @override
  String get galleryTileFavorite => 'favori';

  @override
  String galleryTilePosition(int position, int total) {
    return '$position sur $total';
  }

  @override
  String galleryTileDuration(String time) {
    return 'durée $time';
  }

  @override
  String get galleryPreviewUnavailable => 'Aperçu indisponible';

  @override
  String get importIntro =>
      'Copiez des photos et des vidéos depuis Fichiers vers votre Bibliothèque. Les originaux restent inchangés, y compris la position et les autres métadonnées. Rien n\'est supprimé ni partagé.';

  @override
  String get importChooseFiles => 'Choisir des fichiers';

  @override
  String get importChooseFolder => 'Choisir un dossier';

  @override
  String get importSubfolders => 'Inclure les sous-dossiers';

  @override
  String get importSubfoldersBody =>
      'Lit aussi les photos et vidéos des dossiers contenus dans celui choisi.';

  @override
  String get importOpenShare => 'Ouvrir un partage chiffré';

  @override
  String get importSharePassphraseTitle => 'Phrase secrète de ce partage';

  @override
  String get importSharePassphraseLabel => 'Phrase secrète';

  @override
  String get importShareOpenButton => 'Ouvrir';

  @override
  String get importShareFailed =>
      'Impossible d\'ouvrir le partage. Vérifiez la phrase secrète et le fichier.';

  @override
  String get importSupportedTitle => 'Fichiers pris en charge et limites';

  @override
  String get importSupportedBody =>
      'JPEG, PNG ou MP4 lisible. Jusqu\'à 20 fichiers et 512 Mio au total ; photos jusqu\'à 32 Mio et 64 MP. Un dossier importe ses fichiers (pas les sous-dossiers), jusqu\'à 10 000, par lots de 20 ; choisissez à nouveau le même dossier pour reprendre. La lecture sur téléviseur dépend des codecs. Les imports utilisent la date d\'ajout. Les copies sélectionnées peuvent finir d\'être chiffrées pendant que Quietake est verrouillé. Un partage chiffré (.quietake-share) s\'ouvre avec sa phrase secrète ; ses photos et vidéos sont ensuite importées comme les autres fichiers.';

  @override
  String get importCancelling => 'Annulation après le fichier en cours…';

  @override
  String get importCancelRemaining => 'Annuler le reste';

  @override
  String importFolderCount(int handled, int total) {
    return '$handled fichiers sur $total';
  }

  @override
  String get importBusyPrevious =>
      'L\'import précédent se termine. Réessayez dans un instant.';

  @override
  String get importOpenFailed =>
      'Impossible d\'ouvrir l\'import. Vérifiez le stockage et réessayez.';

  @override
  String get importStoppedEarly =>
      'L\'import s\'est arrêté prématurément. Les copies indiquées comme importées sont enregistrées.';

  @override
  String get importCleanupFailed =>
      'Le nettoyage temporaire a échoué. Redémarrez Quietake avant de réessayer.';

  @override
  String get importFolderStopped =>
      'L\'import du dossier s\'est arrêté. Choisissez à nouveau le dossier pour continuer ; les fichiers terminés sont enregistrés.';

  @override
  String importImported(int count) {
    return '$count importées';
  }

  @override
  String importDuplicates(int count) {
    return '$count doublons ignorés';
  }

  @override
  String importAlreadyDone(int count) {
    return '$count déjà importées auparavant';
  }

  @override
  String importFailedCount(int count) {
    return '$count en échec';
  }

  @override
  String importNotStarted(int count) {
    return '$count non commencées';
  }

  @override
  String importSummaryEnd(String summary) {
    return '$summary.';
  }

  @override
  String importSummaryContinue(String summary) {
    return '$summary. Choisissez à nouveau le même dossier pour continuer.';
  }

  @override
  String get shareTitleOne => 'Partager une copie ?';

  @override
  String shareTitleMany(int count) {
    return 'Partager $count copies ?';
  }

  @override
  String get shareWarning =>
      'L\'app que vous choisissez reçoit des copies non chiffrées et peut les conserver.';

  @override
  String get shareStripTitle =>
      'Supprimer les métadonnées des copies de photos';

  @override
  String get shareStripOn =>
      'Les copies JPEG ne conservent que leur orientation : la position, l\'appareil, l\'heure, les commentaires et les miniatures sont supprimés. Les copies PNG sont recréées à partir de leurs pixels, sans métadonnées. Les copies vidéo restent inchangées.';

  @override
  String get shareStripOff =>
      'Les copies conservent toutes les métadonnées d\'origine, y compris la position si elle existe.';

  @override
  String shareLimits(int items, int mib) {
    return 'Jusqu\'à $items captures et $mib Mio par lot.';
  }

  @override
  String shareProgress(int prepared, int total) {
    return 'Préparation de $prepared sur $total';
  }

  @override
  String get shareFailed =>
      'Impossible de partager. Un autre partage est peut-être encore en cours. Réessayez.';

  @override
  String get shareChooseApp => 'Choisir une app';

  @override
  String get viewerShareFailed => 'Impossible de partager. Veuillez réessayer.';

  @override
  String get viewerDetails => 'Détails';

  @override
  String viewerType(String kind) {
    return 'Type : $kind';
  }

  @override
  String viewerCaptured(String when) {
    return 'Capturée : $when';
  }

  @override
  String get viewerUnknown => 'Inconnue';

  @override
  String viewerTags(String tags) {
    return 'Étiquettes : $tags';
  }

  @override
  String get viewerNone => 'Aucune';

  @override
  String viewerSize(int bytes) {
    return 'Taille chiffrée : $bytes octets';
  }

  @override
  String get viewerSizeUnavailable => 'Taille chiffrée : indisponible';

  @override
  String get viewerClose => 'Fermer';

  @override
  String viewerSetCover(String tag) {
    return 'Utiliser comme couverture de $tag';
  }

  @override
  String viewerCoverSet(String tag) {
    return 'Couverture de $tag mise à jour.';
  }

  @override
  String get viewerDeletePhotoTitle => 'Supprimer cette photo ?';

  @override
  String get viewerDeleteVideoTitle => 'Supprimer cette vidéo ?';

  @override
  String viewerDeleteKeepNas(int days) {
    return '« Supprimés récemment » la conserve sur ce téléphone, chiffrée, pendant $days jours pour que vous puissiez la restaurer. Votre copie NAS reste jusque-là. « Supprimer maintenant » la retire définitivement de ce téléphone et de votre NAS configuré.';
  }

  @override
  String viewerDeleteKeep(int days) {
    return '« Supprimés récemment » la conserve sur ce téléphone, chiffrée, pendant $days jours pour que vous puissiez la restaurer. « Supprimer maintenant » la retire définitivement de ce téléphone.';
  }

  @override
  String get viewerDeleteNasNow =>
      'Elle sera définitivement retirée de ce téléphone et de votre NAS configuré.';

  @override
  String get viewerDeleteNow =>
      'Elle sera définitivement retirée de ce téléphone.';

  @override
  String get viewerDeleteNasTail =>
      'Si le NAS est indisponible, la suppression se termine quand la synchronisation réussit.';

  @override
  String get viewerDeletePendingTail =>
      'Les suppressions en attente s\'appliquent si vous reconnectez une sauvegarde NAS.';

  @override
  String get viewerDeleteEnd =>
      'Les autres sauvegardes et les copies partagées ne sont pas affectées. La diffusion en cours s\'arrêtera.';

  @override
  String get viewerDelete => 'Supprimer';

  @override
  String get viewerRemoveFavorite => 'Retirer des favoris';

  @override
  String get viewerAddFavorite => 'Ajouter aux favoris';

  @override
  String get viewerSlideshowStart => 'Lancer le diaporama';

  @override
  String get viewerSlideshowStop => 'Arrêter le diaporama';

  @override
  String get viewerShare => 'Partager une copie';

  @override
  String get viewerDeletePhoto => 'Supprimer la photo';

  @override
  String get viewerDeleteVideo => 'Supprimer la vidéo';

  @override
  String get viewerHideControls => 'Masquer les commandes';

  @override
  String get viewerShowControls => 'Afficher les commandes';

  @override
  String viewerCasting(String device) {
    return 'diffusion vers $device';
  }

  @override
  String get viewerPhotoUnavailable => 'Photo indisponible. Réessayer';

  @override
  String get viewerPrivatePhoto => 'Photo privée';

  @override
  String get viewerResetFit => 'Ajuster à l\'écran';

  @override
  String get viewerVideoUnavailable => 'Vidéo indisponible. Réessayer';

  @override
  String get viewerReplay => 'Revoir la vidéo';

  @override
  String get viewerPlay => 'Lire la vidéo';

  @override
  String get viewerPause => 'Mettre la vidéo en pause';

  @override
  String get viewerVideoPosition => 'Position de la vidéo';

  @override
  String get viewerBack10 => 'Reculer de 10 secondes';

  @override
  String get viewerForward10 => 'Avancer de 10 secondes';

  @override
  String get viewerMute => 'Couper le son de la vidéo';

  @override
  String get viewerUnmute => 'Réactiver le son de la vidéo';

  @override
  String get lockNow => 'Verrouiller maintenant';

  @override
  String get brandTagline => 'Appareil photo privé';

  @override
  String get backupTitle => 'Vérifier la sauvegarde';

  @override
  String get backupIntro =>
      'Vérifie chaque fichier chiffré de votre sauvegarde NAS enregistrée avec la clé de ce coffre. Les grandes bibliothèques demandent du temps, des données et de l\'espace temporaire. Cette vérification ne modifie pas les originaux.';

  @override
  String get backupNeverChecked =>
      'Cette sauvegarde n\'a jamais été entièrement vérifiée. Vérifiez-la pour confirmer que vos copies sont lisibles.';

  @override
  String backupStale(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return 'La dernière vérification complète date d\'il y a $_temp0. Vérifiez à nouveau pour confirmer que vos copies sont toujours lisibles.';
  }

  @override
  String get backupCancelCheck => 'Annuler la vérification';

  @override
  String get backupCancelQueued => 'Annuler la vérification en attente';

  @override
  String get backupCheckSaved => 'Vérifier la sauvegarde enregistrée';

  @override
  String backupCheckedAt(String date, String time, String state) {
    return 'Vérifiée le $date à $time · $state';
  }

  @override
  String get backupUnchanged => 'Rien n\'a changé depuis';

  @override
  String get backupChanged => 'Modifiée depuis ; vérifiez à nouveau';

  @override
  String get backupKeepKey =>
      'Conservez votre clé de récupération séparément. Une vérification réussie ne teste pas la copie de la clé que vous avez enregistrée ailleurs.';

  @override
  String get backupLeaveNote =>
      'Vous pouvez quitter cet écran pendant la vérification. Les envois de captures attendent la fin de la vérification. Les vérifications s\'arrêtent si le processus de l\'app se ferme.';

  @override
  String get castSearchFailed =>
      'Impossible de rechercher des téléviseurs. Vérifiez le Wi-Fi et réessayez.';

  @override
  String castConnected(String device) {
    return 'Connecté à $device. Ouvrez une capture pour la diffuser.';
  }

  @override
  String get castTitle => 'Diffuser sur un téléviseur';

  @override
  String get castClose => 'Fermer le sélecteur de diffusion';

  @override
  String get castUnencrypted =>
      'Les médias sélectionnés sont diffusés sans chiffrement sur votre réseau local pendant la diffusion.';

  @override
  String get castLooking => 'Recherche de téléviseurs sur ce réseau';

  @override
  String get castNoneFound => 'Aucun téléviseur trouvé';

  @override
  String get castSameWifi =>
      'Le téléviseur est-il sur le même Wi-Fi que ce téléphone ?';

  @override
  String get castRetry => 'Réessayer';

  @override
  String castStop(String device) {
    return 'Arrêter la diffusion vers $device';
  }

  @override
  String get castCancelConnection => 'Annuler la connexion';

  @override
  String get castToTv => 'Diffuser sur le téléviseur';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsPrivacySection => 'Confidentialité et accès';

  @override
  String get settingsIdleLabel => 'Verrouiller après inactivité';

  @override
  String get settingsIdleOff => 'Désactivé';

  @override
  String settingsIdleMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get settingsIdleNote =>
      'L\'enregistrement et la lecture vidéo retardent le verrouillage automatique. Verrouiller maintenant enregistre une vidéo en cours, met la lecture en pause et arrête la diffusion.';

  @override
  String get settingsScreenshotsIos =>
      'Les aperçus du sélecteur d\'apps sont masqués. Les captures d\'écran iOS ne peuvent pas être bloquées.';

  @override
  String get settingsScreenshotsAndroid =>
      'Les captures d\'écran, l\'enregistrement d\'écran et les aperçus du sélecteur d\'apps sont protégés sur Android.';

  @override
  String get settingsPrivacySaveFailed =>
      'Impossible d\'enregistrer les réglages de confidentialité. Réessayez.';

  @override
  String get settingsPasscodeChanged => 'Code modifié';

  @override
  String get settingsBackupSection => 'Sauvegarde';

  @override
  String get settingsBackupIntro =>
      'Sauvegarde facultative des médias chiffrés vers votre propre partage WebDAV.';

  @override
  String get settingsUrlLabel => 'URL du dossier WebDAV';

  @override
  String get settingsUsername => 'Nom d\'utilisateur';

  @override
  String get settingsPassword => 'Mot de passe';

  @override
  String get settingsBackgroundTitle => 'Sauvegarder quand l\'app est fermée';

  @override
  String get settingsBackgroundBody =>
      'Android planifie les envois chiffrés lorsque le réseau et la batterie le permettent. Enregistrez et terminez d\'abord une synchronisation au premier plan. Un arrêt forcé suspend le travail jusqu\'à la réouverture de Quietake.';

  @override
  String get settingsMobileTitle => 'Autoriser les données mobiles';

  @override
  String get settingsMobileBody =>
      'Désactivé, seuls les réseaux non facturés au volume sont utilisés. Les vidéos volumineuses peuvent consommer beaucoup de données.';

  @override
  String get settingsBgChecking => 'Vérification du planificateur Android…';

  @override
  String get settingsBgScheduled =>
      'Planifiée lorsque le réseau et la batterie le permettent.';

  @override
  String get settingsBgUploading => 'Android envoie des copies chiffrées.';

  @override
  String get settingsBgTransferred =>
      'Le dernier passage en arrière-plan est terminé. La vérification complète de la sauvegarde est distincte.';

  @override
  String get settingsBgReconcile =>
      'Ouvrez le coffre et synchronisez pour vérifier cette sauvegarde avant la reprise des envois en arrière-plan.';

  @override
  String get settingsBgPending =>
      'Sauvegarde en arrière-plan en attente. Android réessaiera.';

  @override
  String get settingsBgOff =>
      'La sauvegarde en arrière-plan est désactivée ou attend sa première synchronisation réussie.';

  @override
  String get settingsBgUnavailable =>
      'Planificateur indisponible. La synchronisation au premier plan reste disponible.';

  @override
  String get settingsSave => 'Enregistrer les réglages de sauvegarde';

  @override
  String get settingsTest => 'Tester la connexion';

  @override
  String get settingsTesting => 'Test de la connexion…';

  @override
  String settingsConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return 'Connecté · $_temp0';
  }

  @override
  String settingsErrHttp(int status) {
    return 'Échec de la connexion (HTTP $status). Vérifiez l\'URL du dossier, le nom d\'utilisateur et le mot de passe.';
  }

  @override
  String get settingsErrReach =>
      'Impossible de joindre le NAS. Vérifiez l\'URL et le Wi-Fi.';

  @override
  String get settingsErrGeneric =>
      'Échec de la connexion. Vérifiez les informations enregistrées et réessayez.';

  @override
  String get settingsSaveFirst =>
      'Enregistrez les modifications de connexion avant de vérifier la sauvegarde.';

  @override
  String get settingsEnterDetails =>
      'Saisissez une URL de dossier, un nom d\'utilisateur et un mot de passe';

  @override
  String get settingsSaveFailed =>
      'Impossible d\'enregistrer les informations de connexion. Réessayez.';

  @override
  String get settingsDisconnectFailed =>
      'Impossible de déconnecter la sauvegarde NAS. Réessayez.';

  @override
  String get settingsWrongPasscode => 'Code incorrect. Réessayez.';

  @override
  String get settingsRecoveryReadFailed =>
      'Impossible de lire la clé de récupération. Réessayez.';

  @override
  String get settingsDisconnectTitle => 'Déconnecter la sauvegarde NAS ?';

  @override
  String get settingsClearTitle =>
      'Effacer les informations NAS enregistrées ?';

  @override
  String get settingsDisconnectBody =>
      'Arrête la sauvegarde automatique et supprime les informations de connexion enregistrées. Les captures restent sur votre téléphone et sur le NAS. Les suppressions en attente sur le NAS ne se termineront pas tant que vous n\'aurez pas reconnecté cette sauvegarde.';

  @override
  String get settingsDisconnectAction => 'Déconnecter';

  @override
  String get settingsClearAction => 'Effacer les informations';

  @override
  String get settingsDisconnectButton => 'Déconnecter la sauvegarde NAS';

  @override
  String get settingsClearButton => 'Effacer les informations NAS enregistrées';

  @override
  String get settingsRecoverySection => 'Récupération et export';

  @override
  String get settingsShowRecovery => 'Afficher la clé de récupération';

  @override
  String get settingsNasPassTitle => 'Phrase secrète de la sauvegarde NAS';

  @override
  String get settingsNasPassBody =>
      'Activez, modifiez ou désactivez la récupération sans votre clé de récupération';

  @override
  String get settingsPortableTitle => 'Sauvegarde chiffrée portable';

  @override
  String get settingsPortableBody =>
      'Enregistrez un ZIP dans Fichiers avec votre clé de récupération';

  @override
  String get settingsCameraSection => 'Appareil photo';

  @override
  String get settingsVideoLabel => 'Qualité vidéo';

  @override
  String get settingsVideoHelp =>
      'Une qualité plus élevée produit des fichiers plus volumineux.';

  @override
  String get settingsBurstLabel => 'Photos par rafale';

  @override
  String get settingsBurstHelp => 'Maintenez le déclencheur enfoncé.';

  @override
  String settingsBurstChoice(int count) {
    return '$count photos';
  }

  @override
  String get settingsStorageSection => 'Stockage';

  @override
  String get settingsStorageUnreadable => 'Impossible de lire le stockage.';

  @override
  String get settingsStorageCounting => 'Comptage des captures…';

  @override
  String get settingsStorageNone =>
      'Aucune capture sur ce téléphone pour le moment.';

  @override
  String settingsStorageSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures',
      one: '1 capture',
    );
    return '$_temp0, $size chiffrés sur ce téléphone.';
  }

  @override
  String settingsStorageTrashed(int count, int days) {
    return '$count dans Supprimés récemment, effacés définitivement après $days jours.';
  }

  @override
  String settingsSizeBytes(int value) {
    return '$value octets';
  }

  @override
  String settingsSizeKb(String value) {
    return '$value Ko';
  }

  @override
  String settingsSizeMb(String value) {
    return '$value Mo';
  }

  @override
  String get settingsBiometric => 'Déverrouiller par empreinte ou visage';

  @override
  String get settingsBiometricBody =>
      'Lorsque cette option est activée, ce téléphone conserve une copie de la clé du coffre dans son stockage sécurisé. Le code d\'accès fonctionne toujours.';

  @override
  String get settingsBiometricTurnOn => 'Activer';

  @override
  String get settingsBiometricFailed =>
      'Impossible de modifier le déverrouillage par empreinte ou visage.';

  @override
  String get settingsPlainIcon => 'Utiliser une icône et un nom discrets';

  @override
  String get settingsPlainIconBody =>
      'Affiche une icône grise nommée Outils à la place de Quietake. L\'app peut se fermer un instant lors du changement. Quietake reste visible dans la liste des apps et dans les réglages du système.';

  @override
  String get settingsPlainIconBodyIos =>
      'Affiche une autre icône grise. Le nom reste Quietake et iOS affiche un avis lors du changement. Quietake reste visible dans la liste des apps et dans les réglages du système.';

  @override
  String get settingsPlainIconFailed =>
      'Impossible de changer l\'icône de l\'app.';

  @override
  String get settingsKeepDeleted =>
      'Conserver les captures supprimées 30 jours';

  @override
  String get settingsKeepDeletedBody =>
      'Supprimer déplace d\'abord une capture dans Supprimés récemment. Elle reste chiffrée.';

  @override
  String get settingsLicenses => 'Licences';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsShow => 'Afficher';

  @override
  String get portableTitleRestore => 'Restaurer une sauvegarde chiffrée';

  @override
  String get portableTitleExport => 'Sauvegarde portable';

  @override
  String get portableIntroRestore =>
      'Restaurez uniquement dans un coffre neuf et vide. Votre clé de récupération ouvre le ZIP et les captures chiffrées. Les bibliothèques existantes ne peuvent pas être fusionnées.';

  @override
  String get portableIntroExport =>
      'Enregistrez un ZIP chiffré de vos captures et de leur organisation. Votre clé de récupération actuelle l\'ouvre ; conservez-la séparément. Aucun identifiant ni fichier de clé n\'est inclus.';

  @override
  String get portableChoose => 'Choisir le ZIP de sauvegarde';

  @override
  String get portableCheckOnly => 'Vérifier la sauvegarde uniquement';

  @override
  String get portableRestoreButton => 'Restaurer le coffre vide';

  @override
  String get portableCreateButton => 'Créer un ZIP chiffré';

  @override
  String get portableLimitsTitle => 'Limites et stockage de la sauvegarde';

  @override
  String get portableLimitsBody =>
      'Jusqu\'à 10 000 captures et 2 Gio par ZIP. La préparation nécessite un stockage temporaire privé. Les originaux du coffre restent inchangés. Aucun identifiant ni fichier de clé n\'est inclus.';

  @override
  String get portableCancelPrep => 'Annuler la préparation';

  @override
  String get portablePicking => 'Choisissez un ZIP chiffré dans Fichiers.';

  @override
  String get portablePickCancelled => 'Sélection annulée.';

  @override
  String get portablePicked =>
      'Sauvegarde sélectionnée. Saisissez sa clé de récupération et un nouveau code.';

  @override
  String get portableCopyFailed =>
      'Impossible de copier la sauvegarde. Vérifiez le stockage et réessayez.';

  @override
  String get portableStillFinishing =>
      'La sauvegarde précédente se termine. Réessayez dans un instant.';

  @override
  String get portableNeedKey =>
      'Choisissez une sauvegarde et saisissez sa clé de récupération.';

  @override
  String get portableNeedPasscode =>
      'Choisissez une sauvegarde et confirmez un code d\'au moins six caractères.';

  @override
  String get portablePreparing => 'Préparation de la sauvegarde chiffrée…';

  @override
  String portableChecking(int done, int total) {
    return 'Vérification des fichiers chiffrés : $done sur $total…';
  }

  @override
  String get portableChecked =>
      'Sauvegarde vérifiée : chaque fichier chiffré et le catalogue s\'authentifient avec cette clé. Rien n\'a été restauré. Choisissez à nouveau le fichier pour le restaurer.';

  @override
  String get portableRestored =>
      'Coffre restauré. Utilisez votre nouveau code une fois pour activer le déverrouillage biométrique.';

  @override
  String portableExporting(int done, int total) {
    return 'Préparation des fichiers chiffrés : $done sur $total…';
  }

  @override
  String get portableSaved =>
      'Sauvegarde chiffrée enregistrée. Conservez sa clé de récupération séparément.';

  @override
  String get portableSaveCancelled =>
      'Enregistrement annulé. Les originaux du coffre sont conservés.';

  @override
  String get portableBadKey =>
      'Saisissez la clé de récupération enregistrée pour cette sauvegarde.';

  @override
  String get portableCancelled =>
      'Annulé. Les originaux du coffre sont conservés.';

  @override
  String get portableFailed =>
      'Impossible de restaurer ou d\'enregistrer la sauvegarde. Vérifiez sa clé, le fichier, le stockage disponible et l\'exigence d\'un coffre vide.';

  @override
  String get nasTitleRestore => 'Restaurer depuis le NAS';

  @override
  String get nasTitleManage => 'Phrase secrète de la sauvegarde';

  @override
  String get nasIntroRestore =>
      'Utilisez la phrase secrète de sauvegarde distincte activée précédemment sur votre NAS. Le code court du téléphone ne peut pas récupérer cette sauvegarde. La restauration authentifie tous les fichiers dans un coffre vide, sans fusion. Votre NAS reste en lecture seule.';

  @override
  String get nasIntroManage =>
      'Protégez la récupération sur le NAS avec une phrase secrète forte et distincte. Toute personne disposant du fichier chiffré peut tenter des essais hors ligne. Préférez six mots aléatoires ; la longueur seule ne garantit pas la robustesse. Terminez d\'abord une synchronisation avec le NAS enregistré. Le NAS doit prendre en charge le verrouillage sûr des fichiers ; sinon, rien n\'est écrit.';

  @override
  String get nasUrlLabel => 'URL du dossier WebDAV HTTPS';

  @override
  String get nasUserLabel => 'Nom d\'utilisateur du NAS';

  @override
  String get nasPasswordLabel => 'Mot de passe du NAS';

  @override
  String get nasPinNew => 'Nouveau code local';

  @override
  String get nasPinCurrent => 'Code local actuel';

  @override
  String get nasPinConfirm => 'Confirmer le nouveau code local';

  @override
  String get nasPhraseLabel => 'Phrase secrète de la sauvegarde';

  @override
  String get nasPhraseConfirm => 'Confirmer la phrase secrète de la sauvegarde';

  @override
  String get nasGenerate => 'Générer six mots';

  @override
  String get nasHide => 'Masquer la phrase secrète';

  @override
  String get nasShow => 'Afficher la phrase secrète';

  @override
  String get nasWordsCredit =>
      'Mots : Electronic Frontier Foundation · CC BY 4.0';

  @override
  String get nasWordLicenses => 'Licences de la liste de mots';

  @override
  String get nasEnableButton => 'Activer ou modifier la phrase secrète';

  @override
  String get nasDisableButton =>
      'Désactiver la récupération par phrase secrète';

  @override
  String get nasFootRestore =>
      'Jusqu\'à 10 000 captures. Un espace temporaire privé est nécessaire. Déverrouillez ensuite avec votre nouveau code. L\'envoi en arrière-plan reste désactivé.';

  @override
  String get nasFootManage =>
      'Cela ne modifie que la protection de récupération. Cela ne change jamais le code du téléphone et ne rechiffre pas les captures. Supprimer la récupération actuelle ne révoque pas les anciens instantanés du serveur.';

  @override
  String get nasGenerateFailed =>
      'Impossible de générer une phrase secrète. Réessayez.';

  @override
  String get nasConfirmDisableTitle =>
      'Désactiver la récupération par phrase secrète ?';

  @override
  String get nasConfirmSaveTitle =>
      'Enregistrer la phrase secrète de la sauvegarde ?';

  @override
  String get nasConfirmDisableBody =>
      'Supprime le fichier de récupération actuel du dossier NAS enregistré. Les captures restent. D\'anciens instantanés du serveur peuvent encore accepter une phrase secrète antérieure. Conservez votre clé de récupération indépendante.';

  @override
  String get nasConfirmSaveBody =>
      'Crée ou remplace la récupération dans le dossier NAS enregistré. Conservez la nouvelle phrase secrète séparément. D\'anciens instantanés du serveur peuvent encore accepter une phrase antérieure ; cela ne renouvelle pas la clé de votre coffre.';

  @override
  String get nasDisableAction => 'Désactiver la récupération';

  @override
  String get nasSaveAction => 'Enregistrer la phrase secrète';

  @override
  String get nasSeparatePhrase =>
      'Utilisez une phrase secrète de sauvegarde distincte, pas votre code local.';

  @override
  String get nasNeedPasscode =>
      'Choisissez et confirmez un nouveau code d\'au moins six caractères.';

  @override
  String get nasNeedDetails =>
      'Saisissez le dossier, le nom d\'utilisateur et le mot de passe NAS enregistrés.';

  @override
  String get nasMismatch =>
      'Les phrases secrètes de sauvegarde ne correspondent pas.';

  @override
  String get nasCheckingRestore =>
      'Vérification de la sauvegarde NAS chiffrée…';

  @override
  String get nasCheckingSaved =>
      'Vérification de la récupération NAS enregistrée…';

  @override
  String get nasRestoredTitle => 'Coffre restauré';

  @override
  String get nasRestoredUnsaved =>
      'La connexion au NAS n\'a pas pu être enregistrée. Vos captures sont restaurées ; ajoutez de nouveau la connexion dans Réglages pour reprendre les sauvegardes.';

  @override
  String get nasContinue => 'Continuer';

  @override
  String get nasDisabledDone =>
      'Récupération par phrase secrète désactivée. Captures conservées.';

  @override
  String get nasSavedDone =>
      'Phrase secrète de sauvegarde enregistrée. Conservez-la séparément, ainsi que votre clé de récupération.';

  @override
  String get nasWrongCurrent => 'Code actuel incorrect. Réessayez.';

  @override
  String get nasCancelled => 'Annulé. Originaux conservés.';

  @override
  String get nasRestoreFailed =>
      'Impossible de restaurer. Vérifiez la connexion au NAS, la phrase secrète de sauvegarde et l\'exigence d\'un coffre vide. Originaux conservés.';

  @override
  String get nasChangeFailed =>
      'Impossible de modifier la récupération. Vérifiez la sauvegarde NAS enregistrée, le fichier de récupération pris en charge et la compatibilité du serveur. Synchronisez d\'abord, puis réessayez. Originaux conservés.';

  @override
  String get coverChooseTitle => 'Choisir la couverture';

  @override
  String get coverEmpty =>
      'Étiquetez d\'abord quelques captures, puis choisissez-en une comme couverture.';

  @override
  String get coverUse => 'Utiliser cette capture comme couverture';

  @override
  String get restoreGateFailed =>
      'Impossible de terminer la restauration interrompue de la sauvegarde. Les fichiers chiffrés préparés sont conservés. Vérifiez le stockage disponible, puis réessayez.';

  @override
  String get restoreGateRetry => 'Réessayer la restauration';

  @override
  String get restoreGateDiscard => 'Abandonner la restauration inachevée';

  @override
  String get restoreGateDiscardTitle =>
      'Abandonner la restauration inachevée ?';

  @override
  String get restoreGateDiscardBody =>
      'Cela supprime uniquement la copie en cours de préparation sur ce téléphone. Votre sauvegarde n’est pas modifiée et vous pouvez la restaurer à nouveau.';

  @override
  String get restoreGateDiscardConfirm => 'Abandonner';

  @override
  String get settingsCheckRecovery => 'Vérifier ma clé de récupération';

  @override
  String get recoveryCheckTitle => 'Vérifier la clé de récupération';

  @override
  String get recoveryCheckIntro =>
      'Saisissez la clé de récupération enregistrée ailleurs. Elle est comparée sur ce téléphone et n\'est jamais conservée.';

  @override
  String get recoveryCheckAction => 'Vérifier';

  @override
  String get recoveryCheckClose => 'Fermer';

  @override
  String get recoveryCheckNever => 'Jamais vérifiée.';

  @override
  String recoveryCheckLast(String date) {
    return 'Dernière concordance : $date.';
  }

  @override
  String recoveryCheckDue(String date) {
    return 'Dernière concordance : $date. Vérifiez de nouveau tous les quelques mois.';
  }

  @override
  String get recoveryCheckMatch =>
      'Elle correspond à la clé de récupération de votre coffre.';

  @override
  String get recoveryCheckMismatch =>
      'Cette clé ne correspond pas à ce coffre. Vérifiez où vous l\'avez enregistrée, puis réessayez.';

  @override
  String get recoveryCheckInvalid =>
      'Ce n\'est pas une clé de récupération valide. Vérifiez s\'il manque des caractères ou s\'il y en a en trop.';

  @override
  String get redactTitle => 'Masquer des parties de la photo';

  @override
  String get redactUndo => 'Annuler la dernière zone';

  @override
  String get redactDone => 'Terminé';

  @override
  String redactStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones seront masquées.',
      one: '1 zone sera masquée.',
      zero: 'Faites glisser sur la photo pour masquer une zone.',
    );
    return '$_temp0';
  }

  @override
  String get redactFailed =>
      'Impossible d\'ouvrir cette photo pour la modifier.';

  @override
  String get shareRedactButton => 'Masquer des parties de cette photo…';

  @override
  String shareRedactEdit(int count) {
    return 'Zones masquées : $count. Modifier…';
  }

  @override
  String get shareRedactNote =>
      'La copie partagée devient un PNG dont ces zones sont recouvertes de noir, sans métadonnées. L\'original reste inchangé dans votre coffre.';

  @override
  String get shareRedactButtonMany => 'Masquer des parties de ces photos…';

  @override
  String shareRedactEditMany(int areas, int photos) {
    String _temp0 = intl.Intl.pluralLogic(
      photos,
      locale: localeName,
      other: '$photos photos',
      one: '1 photo',
    );
    return 'Zones masquées : $areas dans $_temp0. Modifier…';
  }

  @override
  String get shareRedactNoteMany =>
      'Les photos avec des zones masquées sont partagées en copies PNG dont ces zones sont recouvertes de noir, sans métadonnées. Les originaux restent inchangés dans votre coffre.';

  @override
  String redactCell(int row, int column) {
    return 'Ligne $row, colonne $column';
  }

  @override
  String get redactSections => 'Ou masquez une section de la photo';

  @override
  String get settingsRenameRemote =>
      'Donner des noms aléatoires aux fichiers du NAS';

  @override
  String get settingsRenameRemoteNone =>
      'Aucun fichier du NAS n\'a besoin d\'un nouveau nom.';

  @override
  String get settingsRenameRemoteTitle => 'Renommer les fichiers du NAS ?';

  @override
  String settingsRenameRemoteBody(int count) {
    return '$count fichiers chiffrés du NAS reçoivent des noms aléatoires, leurs noms et heures n\'y apparaissent donc plus. Mettez d\'abord à jour Quietake sur les autres téléphones : les anciennes versions ne retrouvent pas les fichiers renommés. Vos originaux restent sur ce téléphone.';
  }

  @override
  String get settingsRenameRemoteAction => 'Renommer';

  @override
  String settingsRenameRemoteDone(int count) {
    return '$count fichiers renommés sur le NAS.';
  }

  @override
  String get settingsRenameRemoteFailed =>
      'Le renommage s\'est arrêté. Relancez-le pour continuer. Rien n\'a été perdu.';

  @override
  String get shareEncryptedTitle => 'Chiffrer avec une phrase secrète';

  @override
  String get shareEncryptedBody =>
      'Les copies sont réunies dans un seul fichier que seule une phrase secrète ouvre. Quietake l\'affiche une seule fois. Envoyez-la par un autre moyen que le fichier.';

  @override
  String get sharePassphraseTitle => 'Phrase secrète de ce partage';

  @override
  String get sharePassphraseBody =>
      'Notez-la ou envoyez-la séparément maintenant. Quietake ne la conserve pas et ne peut plus l\'afficher.';

  @override
  String get sharePassphraseContinue => 'Choisir l\'app';
}
