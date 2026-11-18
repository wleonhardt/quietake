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

  @override
  String get lockUnlockReason => 'Quietake entsperren';

  @override
  String get lockBiometricUnavailable =>
      'Die biometrische Entsperrung ist nicht verfügbar. Verwenden Sie Ihren Zugangscode.';

  @override
  String get lockFailed =>
      'Entsperren fehlgeschlagen. Versuchen Sie es erneut oder verwenden Sie Ihren Wiederherstellungsschlüssel.';

  @override
  String get lockMessage => 'Entsperren Sie Ihren privaten Tresor.';

  @override
  String get passcodeLabel => 'Zugangscode';

  @override
  String passcodeLockedSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Zu viele falsche Zugangscodes. Versuchen Sie es in $count Sekunden erneut.',
      one: 'Zu viele falsche Zugangscodes. Versuchen Sie es in 1 Sekunde erneut.',
    );
    return '$_temp0';
  }

  @override
  String passcodeLockedMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Zu viele falsche Zugangscodes. Versuchen Sie es in $count Minuten erneut.',
      one:
          'Zu viele falsche Zugangscodes. Versuchen Sie es in 1 Minute erneut.',
    );
    return '$_temp0';
  }

  @override
  String passcodeTooShort(int count) {
    return 'Der Zugangscode braucht mindestens $count Zeichen';
  }

  @override
  String get passcodeShow => 'Zugangscode anzeigen';

  @override
  String get passcodeHide => 'Zugangscode verbergen';

  @override
  String get formWorking => 'Bitte warten…';

  @override
  String get lockUnlock => 'Entsperren';

  @override
  String get lockUseBiometrics => 'Biometrie verwenden';

  @override
  String get lockForgot => 'Zugangscode vergessen?';

  @override
  String get lockCamera => 'Kamera';

  @override
  String get lockedCameraSaved =>
      'Foto versiegelt. Es erscheint nach dem Entsperren in Ihrer Bibliothek.';

  @override
  String get lockedCameraFailed => 'Das Foto konnte nicht gespeichert werden.';

  @override
  String get lockedCameraClose => 'Kamera schließen';

  @override
  String lockedCapturesPublished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Fotos der Sperrbildschirm-Kamera sind jetzt in Ihrer Bibliothek.',
      one: '1 Foto der Sperrbildschirm-Kamera ist jetzt in Ihrer Bibliothek.',
    );
    return '$_temp0';
  }

  @override
  String get recoveryKeyLabel => 'Wiederherstellungsschlüssel';

  @override
  String get recoveryKeyIntro =>
      'Bewahren Sie diesen Schlüssel in Ihrem Passwortmanager auf, getrennt von Ihren verschlüsselten Dateien. Sie benötigen beide, um Ihre Aufnahmen wiederherzustellen, wenn Sie den Zugangscode vergessen oder dieses Gerät verlieren. Eine NAS-Backup-Passphrase ist nur dann eine weitere Wiederherstellungsoption, wenn Sie sie aktiviert haben.';

  @override
  String recoveryFingerprint(String fingerprint) {
    return 'Fingerabdruck $fingerprint';
  }

  @override
  String get recoveryFingerprintNote =>
      'Speichern Sie den Fingerabdruck zusammen mit dem Schlüssel. Ein neues Telefon zeigt ihn an, damit Sie den eingegebenen Schlüssel prüfen können.';

  @override
  String get recoverySaved => 'Ich habe ihn gespeichert';

  @override
  String get recoveryShowText => 'Als Text anzeigen';

  @override
  String get recoveryShowWords => 'Als Wörter anzeigen';

  @override
  String get recoveryFormsNote =>
      'Die Wörter und der Text sind derselbe Schlüssel. Speichern Sie eine der beiden Formen.';

  @override
  String get recoveryKeyFieldHelp => '21 Wörter oder die Textform';

  @override
  String get recoveryKeyShow => 'Wiederherstellungsschlüssel anzeigen';

  @override
  String get recoveryKeyHide => 'Wiederherstellungsschlüssel verbergen';

  @override
  String get recoveryWordsCount =>
      'Ein Wiederherstellungsschlüssel hat 21 Wörter. Prüfen Sie, ob ein Wort fehlt oder zu viel ist.';

  @override
  String recoveryWordsUnknown(int position) {
    return 'Wort $position steht nicht in der Wortliste. Prüfen Sie die Schreibweise.';
  }

  @override
  String get recoveryWordsWrong =>
      'Ein Wort ist falsch oder steht an der falschen Stelle. Prüfen Sie die 21 Wörter.';

  @override
  String get recoveryConfirmTitle => 'Gespeicherte Kopie prüfen';

  @override
  String recoveryConfirmBody(int position) {
    return 'Sehen Sie in Ihrer gespeicherten Kopie nach, nicht auf diesem Telefon. Geben Sie Wort $position ein oder fügen Sie den ganzen Schlüssel ein.';
  }

  @override
  String recoveryConfirmField(int position) {
    return 'Wort $position';
  }

  @override
  String get recoveryConfirmAction => 'Bestätigen';

  @override
  String get recoveryConfirmBack => 'Schlüssel erneut anzeigen';

  @override
  String recoveryConfirmWrong(int position) {
    return 'Das ist nicht Wort $position. Prüfen Sie Ihre gespeicherte Kopie.';
  }

  @override
  String get changePasscodeTitle => 'Zugangscode ändern';

  @override
  String get changePasscodeNote =>
      'Ihre Aufnahmen und Ihr Wiederherstellungsschlüssel bleiben unverändert.';

  @override
  String get currentPasscodeLabel => 'Aktueller Zugangscode';

  @override
  String get newPasscodeLabel => 'Neuer Zugangscode';

  @override
  String get confirmNewPasscodeLabel => 'Neuen Zugangscode bestätigen';

  @override
  String get passcodesDoNotMatch => 'Die Zugangscodes stimmen nicht überein';

  @override
  String get currentPasscodeIncorrect => 'Der aktuelle Zugangscode ist falsch';

  @override
  String get changePasscodeFailed =>
      'Zugangscode konnte nicht geändert werden. Versuchen Sie es erneut.';

  @override
  String get changePasscodeBusy => 'Wird geändert…';

  @override
  String get setupConfirmKeyTitle => 'Wiederherstellungsschlüssel bestätigen';

  @override
  String get setupConfirmKeyBody =>
      'Dieses Telefon hat noch keine Aufnahmen, daher kann der Schlüssel nicht damit geprüft werden. Vergleichen Sie diesen Fingerabdruck mit dem, der neben Ihrem Wiederherstellungsschlüssel gespeichert ist.';

  @override
  String get setupNotMine => 'Nicht meiner';

  @override
  String get setupMatches => 'Stimmt überein';

  @override
  String get setupCreateFailed =>
      'Der Tresor konnte nicht erstellt werden. Prüfen Sie den Speicher und versuchen Sie es erneut.';

  @override
  String get setupRestoreFailed =>
      'Der Tresor konnte nicht wiederhergestellt werden. Prüfen Sie den Speicher und versuchen Sie es erneut.';

  @override
  String get setupRestoreTitle => 'Tresor wiederherstellen';

  @override
  String get setupCreateTitle => 'Zugangscode festlegen';

  @override
  String get setupRestoreMessage =>
      'Entsperren Sie Ihre verschlüsselten Dateien mit Ihrem gespeicherten Wiederherstellungsschlüssel.';

  @override
  String get setupTagline => 'Ihre Kamera. Ihre Aufnahmen. Ihre Kontrolle.';

  @override
  String setupPasscodeHelper(int count) {
    return 'Mindestens $count Zeichen';
  }

  @override
  String get confirmPasscodeLabel => 'Zugangscode bestätigen';

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get setupCreateVault => 'Tresor erstellen';

  @override
  String get setupStartNew => 'Stattdessen einen neuen Tresor anlegen';

  @override
  String get setupHaveKey => 'Ich habe einen Wiederherstellungsschlüssel';

  @override
  String get setupRestoreZip => 'Verschlüsseltes ZIP wiederherstellen';

  @override
  String get setupRestoreNas =>
      'Vom NAS mit Backup-Passphrase wiederherstellen';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get camUnavailable =>
      'Kamera nicht verfügbar. Prüfen Sie die Kameraberechtigung in den Einstellungen.';

  @override
  String get camTagsOpenFailed =>
      'Private Tags konnten nicht geöffnet werden. Versuchen Sie es erneut über die Bibliothek.';

  @override
  String get camOrientationFailed =>
      'Die Kameraausrichtung konnte nicht aktualisiert werden.';

  @override
  String get camPendingSave =>
      'Aufnahme wartet auf sicheres Speichern. Schaffen Sie Speicherplatz und sperren und entsperren Sie dann erneut, um es noch einmal zu versuchen.';

  @override
  String camRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen wiederhergestellt',
      one: '1 Aufnahme wiederhergestellt',
    );
    return '$_temp0.';
  }

  @override
  String get camRecoveredVideoNote =>
      'Unterbrochene Videos können unvollständig sein oder sich auf einem Fernseher nicht abspielen lassen.';

  @override
  String get camPendingCheckFailed =>
      'Ausstehende Aufnahmen konnten nicht geprüft werden. Schaffen Sie Speicherplatz und öffnen Sie die Kamera erneut.';

  @override
  String get camNone => 'Keine Kamera';

  @override
  String get camFocusLockFailed =>
      'Fokus und Belichtung konnten mit dieser Kamera nicht gesperrt werden.';

  @override
  String get camRecordStartFailed =>
      'Die Aufnahme konnte nicht gestartet werden. Versuchen Sie es erneut.';

  @override
  String get camRecordStopFailed =>
      'Die Aufnahme konnte nicht beendet werden. Versuchen Sie es erneut.';

  @override
  String get camNoFrames =>
      'Es wurden keine Videobilder aufgenommen. Versuchen Sie es erneut.';

  @override
  String get camPendingNoTags =>
      'Aufnahme wartet auf sicheres Speichern. Tags wurden nicht angewendet; prüfen Sie die Bibliothek nach der Wiederherstellung.';

  @override
  String get camSaveFailed =>
      'Die Aufnahme konnte nicht gespeichert werden. Versuchen Sie es erneut.';

  @override
  String camSavedPhotos(int count) {
    return '$count Fotos sicher gespeichert';
  }

  @override
  String get camSwitchFailed =>
      'Die Kamera konnte nicht gewechselt werden. Versuchen Sie es erneut.';

  @override
  String get camMicDenied =>
      'Erlauben Sie den Mikrofonzugriff in den Einstellungen, um Videos aufzunehmen. Fotos sind weiterhin möglich.';

  @override
  String get camVideoStartFailed =>
      'Das Video konnte nicht gestartet werden. Prüfen Sie die Kamera- und Mikrofonberechtigungen in den Einstellungen.';

  @override
  String get camSaving => 'Wird sicher gespeichert…';

  @override
  String get camSaved => 'Sicher gespeichert';

  @override
  String get camTagsNotApplied =>
      'Tags wurden nicht angewendet; ordnen Sie sie in der Bibliothek zu.';

  @override
  String get camNotCastReady =>
      'Dieses Video lässt sich möglicherweise nicht auf Ihrem Fernseher abspielen.';

  @override
  String get camPreview => 'Kameravorschau';

  @override
  String get camPreviewHint =>
      'Tippen zum Fokussieren. Gedrückt halten, um Fokus und Belichtung zu sperren.';

  @override
  String get camFocusLocked => 'Fokus und Belichtung gesperrt';

  @override
  String camRecTimer(String time) {
    return 'REC $time';
  }

  @override
  String get camStartingVideo => 'Video wird gestartet…';

  @override
  String get camCastFailed =>
      'Übertragung nicht möglich. Versuchen Sie es erneut.';

  @override
  String camCasting(String device) {
    return 'Übertragung auf $device';
  }

  @override
  String get camChooseTags => 'Tags für neue Aufnahmen wählen';

  @override
  String get camTags => 'Tags';

  @override
  String camTagCount(int count) {
    return '$count Tags';
  }

  @override
  String get camFlashOff => 'Blitz aus';

  @override
  String get camFlashAuto => 'Blitz automatisch';

  @override
  String get camFlashOn => 'Blitz an';

  @override
  String get camFlashUnavailable => 'Diese Kamera hat keinen Blitz.';

  @override
  String get camTimerOff => 'Timer aus';

  @override
  String camTimerSeconds(int seconds) {
    return 'Timer $seconds Sekunden';
  }

  @override
  String get camGridHide => 'Raster ausblenden';

  @override
  String get camGridShow => 'Raster einblenden';

  @override
  String get camSwitchRear => 'Zur Rückkamera wechseln';

  @override
  String get camSwitchFront => 'Zur Frontkamera wechseln';

  @override
  String get camStopRecording => 'Aufnahme beenden';

  @override
  String get camRecordVideo => 'Video aufnehmen';

  @override
  String get camStop => 'Stopp';

  @override
  String get camVideo => 'Video';

  @override
  String get camTakePhoto => 'Foto aufnehmen';

  @override
  String get camCancelTimer => 'Timer abbrechen';

  @override
  String get camPhoto => 'Foto';

  @override
  String get camOpenLibrary => 'Bibliothek öffnen';

  @override
  String get camLibrary => 'Bibliothek';

  @override
  String camTakeBurst(int count) {
    return '$count Fotos aufnehmen';
  }

  @override
  String get save => 'Speichern';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get tagsMoments => 'Momente';

  @override
  String get tagsSortName => 'Nach Name sortieren';

  @override
  String get tagsSortCount => 'Nach meisten Aufnahmen sortieren';

  @override
  String get tagsCreate => 'Tag erstellen';

  @override
  String get tagsFind => 'Tags suchen';

  @override
  String get tagsCountFailed =>
      'Aufnahmen konnten nicht gezählt werden. Erneut versuchen';

  @override
  String get tagsUntagged => 'Ohne Tag';

  @override
  String tagsCaptureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen',
      one: '1 Aufnahme',
    );
    return '$_temp0';
  }

  @override
  String get tagsNoMatch => 'Keine passenden Tags';

  @override
  String get tagsNone => 'Noch keine Tags';

  @override
  String get tagsNoMatchHint =>
      'Versuchen Sie einen anderen Namen oder erstellen Sie diesen.';

  @override
  String get tagsNoneHint =>
      'Tags gruppieren Aufnahmen in der gesamten Bibliothek.';

  @override
  String tagsCreateNamed(String name) {
    return '„$name“ erstellen';
  }

  @override
  String get tagsCreateFirst => 'Ersten Tag erstellen';

  @override
  String get tagsOptions => 'Tag-Optionen';

  @override
  String get tagsRename => 'Umbenennen';

  @override
  String get tagsRenameTitle => 'Tag umbenennen';

  @override
  String get tagsSetCover => 'Titelbild festlegen';

  @override
  String get tagsClearCover => 'Titelbild entfernen';

  @override
  String get tagsMergeInto => 'Zusammenführen mit…';

  @override
  String get tagsDelete => 'Tag löschen';

  @override
  String get tagsDeleteTitle => 'Tag löschen?';

  @override
  String tagsDeleteBody(String name) {
    return '„$name“ von allen Aufnahmen entfernen? Fotos und Videos bleiben in Ihrem Tresor.';
  }

  @override
  String get tagsMergeTitle => 'Tags zusammenführen?';

  @override
  String tagsMergeBody(String source, String target, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen verwenden',
      one: '1 Aufnahme verwendet',
    );
    return '„$source“ mit „$target“ zusammenführen? $_temp0 dann den verbleibenden Tag. Der Quell-Tag wird entfernt. Fotos, Videos und andere Tags bleiben unverändert.';
  }

  @override
  String get tagsMergeConfirm => 'Tags zusammenführen';

  @override
  String get mergeChoose => 'Tag zum Behalten wählen';

  @override
  String get mergeCancel => 'Zusammenführen abbrechen';

  @override
  String get mergeFindDestination => 'Ziel-Tag suchen';

  @override
  String get libraryNameLabel => 'Name';

  @override
  String get librarySaveFailed => 'Speichern fehlgeschlagen. Erneut versuchen.';

  @override
  String get libraryUpdateFailed =>
      'Die private Bibliothek konnte nicht aktualisiert werden. Erneut versuchen.';

  @override
  String get momentsLoadFailed =>
      'Aufnahmen konnten nicht gelesen werden. Erneut versuchen';

  @override
  String get momentsEmpty => 'Noch keine Aufnahmen mit Datum';

  @override
  String get viewTitle => 'Ansicht';

  @override
  String get viewAll => 'Alle';

  @override
  String get viewPhotos => 'Fotos';

  @override
  String get viewVideos => 'Videos';

  @override
  String get viewFavoritesOnly => 'Nur Favoriten';

  @override
  String get viewSort => 'Sortieren';

  @override
  String get viewNewest => 'Neueste zuerst';

  @override
  String get viewOldest => 'Älteste zuerst';

  @override
  String get viewName => 'Name';

  @override
  String get viewApply => 'Ansicht anwenden';

  @override
  String viewShowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen anzeigen',
      one: '1 Aufnahme anzeigen',
    );
    return '$_temp0';
  }

  @override
  String get viewReset => 'Zurücksetzen';

  @override
  String get pickerCameraTitle => 'Tags für neue Aufnahmen';

  @override
  String get pickerRemoveTitle => 'Tags entfernen';

  @override
  String get pickerAddTitle => 'Tags hinzufügen';

  @override
  String get pickerCameraNote =>
      'Wird beim Sperren oder im Hintergrund gelöscht.';

  @override
  String pickerSelectionNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen',
      one: '1 Aufnahme',
    );
    return '$_temp0 · andere Tags bleiben unverändert';
  }

  @override
  String get pickerCancel => 'Tag-Auswahl abbrechen';

  @override
  String get pickerNoTags => 'Keine Tags';

  @override
  String pickerAlreadyTagged(int tagged, int total) {
    return '$tagged von $total bereits mit Tag';
  }

  @override
  String get pickerManage => 'Tags verwalten';

  @override
  String get pickerStale =>
      'Ein ausgewählter Tag wurde geändert. Prüfen Sie Ihre Auswahl.';

  @override
  String get pickerReview => 'Prüfen';

  @override
  String pickerUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tags verwenden',
      one: '1 Tag verwenden',
    );
    return '$_temp0';
  }

  @override
  String pickerAddCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tags hinzufügen',
      one: '1 Tag hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String pickerRemoveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tags entfernen',
      one: '1 Tag entfernen',
    );
    return '$_temp0';
  }

  @override
  String get galleryActions => 'Bibliotheksaktionen';

  @override
  String get galleryActionsClose => 'Bibliotheksaktionen schließen';

  @override
  String get gallerySelectCaptures => 'Aufnahmen auswählen';

  @override
  String get gallerySearchEdit => 'Suche bearbeiten';

  @override
  String get gallerySearchHint => 'Namen und Tags durchsuchen';

  @override
  String get galleryRemovedTag => 'Entfernter Tag';

  @override
  String get galleryScopeAny => 'Gesamte Bibliothek · Beliebiger Tag';

  @override
  String get galleryScopeAll => 'Gesamte Bibliothek · Alle Tags';

  @override
  String get gallerySortNewest => 'Neueste Aufnahmen';

  @override
  String get gallerySortOldest => 'Älteste Aufnahmen';

  @override
  String get gallerySortName => 'Namensreihenfolge';

  @override
  String get galleryTagMatching => 'Tag-Abgleich';

  @override
  String get galleryMatchAll => 'Alle Tags';

  @override
  String get galleryMatchAny => 'Beliebiger Tag';

  @override
  String get galleryFavorites => 'Favoriten';

  @override
  String get galleryResetView => 'Ansicht zurücksetzen';

  @override
  String get galleryAddTag => 'Tag hinzufügen';

  @override
  String get galleryAddTagHint =>
      'Wählen Sie vorhandene Tags oder suchen Sie mit dem Text oben nach Namen.';

  @override
  String get galleryCancelSelection => 'Auswahl abbrechen';

  @override
  String galleryDeleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen löschen?',
      one: '1 Aufnahme löschen?',
    );
    return '$_temp0';
  }

  @override
  String galleryDeleteKeepBody(int days) {
    return 'Die Auswahl wird in „Zuletzt gelöscht“ verschoben und bleibt $days Tage verschlüsselt auf diesem Telefon, damit Sie sie wiederherstellen können. Eine NAS-Kopie bleibt bis dahin erhalten.';
  }

  @override
  String get galleryDeleteMove => 'In „Zuletzt gelöscht“ verschieben';

  @override
  String gallerySelectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get gallerySelectAll => 'Alle Ergebnisse auswählen';

  @override
  String get galleryShareCopies => 'Kopien teilen';

  @override
  String get galleryUnfavorite => 'Aus Favoriten entfernen';

  @override
  String get galleryFavorite => 'Favorit';

  @override
  String get galleryNameCapture => 'Aufnahme benennen';

  @override
  String get galleryNasReadFailed =>
      'Gespeicherte NAS-Angaben konnten nicht gelesen werden. Versuchen Sie es erneut.';

  @override
  String get galleryImportTooltip => 'Kopien aus Dateien importieren';

  @override
  String get gallerySyncCancel => 'Synchronisierung abbrechen';

  @override
  String get gallerySyncSetup => 'Backup einrichten';

  @override
  String get gallerySyncNow => 'Mit NAS synchronisieren';

  @override
  String get galleryCloseSearch => 'Suche schließen';

  @override
  String get gallerySearchTitle => 'Suche';

  @override
  String get gallerySettings => 'Einstellungen';

  @override
  String get galleryOrgUnavailable =>
      'Organisation nicht verfügbar. Die Originale sind sicher. Erneut versuchen';

  @override
  String get galleryOpenFailed =>
      'Tresor konnte nicht geöffnet werden. Erneut versuchen';

  @override
  String get galleryEmptyTitle => 'Ihre Bibliothek beginnt hier';

  @override
  String get galleryEmptyMessage =>
      'Machen Sie ein Foto oder importieren Sie Kopien aus Dateien.';

  @override
  String get galleryOpenCamera => 'Kamera öffnen';

  @override
  String get galleryImportCopies => 'Kopien importieren';

  @override
  String get galleryNoMatchTitle => 'Keine passenden Aufnahmen';

  @override
  String get galleryNoMatchMessage =>
      'Löschen Sie Suche und Filter, um alle Aufnahmen zu sehen.';

  @override
  String get galleryClearFilters => 'Suche und Filter löschen';

  @override
  String galleryTileSelect(String label) {
    return '$label auswählen';
  }

  @override
  String galleryTileOpen(String label) {
    return '$label öffnen';
  }

  @override
  String get galleryTileFavorite => 'Favorit';

  @override
  String galleryTilePosition(int position, int total) {
    return '$position von $total';
  }

  @override
  String galleryTileDuration(String time) {
    return 'Dauer $time';
  }

  @override
  String get galleryPreviewUnavailable => 'Vorschau nicht verfügbar';

  @override
  String get importIntro =>
      'Kopieren Sie Fotos und Videos aus Dateien in Ihre Bibliothek. Die Originale bleiben unverändert, einschließlich Standort und anderer Metadaten. Es wird nichts gelöscht oder geteilt.';

  @override
  String get importChooseFiles => 'Dateien auswählen';

  @override
  String get importChooseFolder => 'Ordner auswählen';

  @override
  String get importSubfolders => 'Unterordner einbeziehen';

  @override
  String get importSubfoldersBody =>
      'Liest auch Fotos und Videos in Ordnern innerhalb des gewählten Ordners.';

  @override
  String get importOpenShare => 'Verschlüsselte Freigabe öffnen';

  @override
  String get importSharePassphraseTitle => 'Passphrase für diese Freigabe';

  @override
  String get importSharePassphraseLabel => 'Passphrase';

  @override
  String get importShareOpenButton => 'Öffnen';

  @override
  String get importShareFailed =>
      'Die Freigabe konnte nicht geöffnet werden. Prüfe die Passphrase und die Datei.';

  @override
  String get importSupportedTitle => 'Unterstützte Dateien und Grenzen';

  @override
  String get importSupportedBody =>
      'JPEG, PNG oder abspielbares MP4. Bis zu 20 Dateien und insgesamt 512 MiB; Fotos bis 32 MiB und 64 MP. Ein Ordner importiert seine Dateien (keine Unterordner), bis zu 10.000, jeweils 20 auf einmal; wählen Sie denselben Ordner erneut, um fortzufahren. Die Wiedergabe auf dem Fernseher hängt von den Codecs ab. Importe verwenden das Hinzufügedatum. Ausgewählte Kopien können noch verschlüsselt werden, während Quietake gesperrt ist. Eine verschlüsselte Freigabe (.quietake-share) wird mit ihrer Passphrase geöffnet; ihre Fotos und Videos werden danach wie andere Dateien importiert.';

  @override
  String get importCancelling => 'Abbruch nach der aktuellen Datei…';

  @override
  String get importCancelRemaining => 'Rest abbrechen';

  @override
  String importFolderCount(int handled, int total) {
    return '$handled von $total Dateien';
  }

  @override
  String get importBusyPrevious =>
      'Der vorherige Import wird beendet. Versuchen Sie es gleich noch einmal.';

  @override
  String get importOpenFailed =>
      'Import konnte nicht geöffnet werden. Prüfen Sie den Speicher und versuchen Sie es erneut.';

  @override
  String get importStoppedEarly =>
      'Der Import wurde vorzeitig beendet. Als importiert aufgeführte Kopien sind gespeichert.';

  @override
  String get importCleanupFailed =>
      'Die temporäre Bereinigung ist fehlgeschlagen. Starten Sie Quietake neu, bevor Sie es erneut versuchen.';

  @override
  String get importFolderStopped =>
      'Der Ordnerimport wurde beendet. Wählen Sie den Ordner erneut, um fortzufahren; fertige Dateien sind gespeichert.';

  @override
  String importImported(int count) {
    return '$count importiert';
  }

  @override
  String importDuplicates(int count) {
    return '$count Duplikate übersprungen';
  }

  @override
  String importAlreadyDone(int count) {
    return '$count bereits früher importiert';
  }

  @override
  String importFailedCount(int count) {
    return '$count fehlgeschlagen';
  }

  @override
  String importNotStarted(int count) {
    return '$count nicht gestartet';
  }

  @override
  String importSummaryEnd(String summary) {
    return '$summary.';
  }

  @override
  String importSummaryContinue(String summary) {
    return '$summary. Wählen Sie denselben Ordner erneut, um fortzufahren.';
  }

  @override
  String get shareTitleOne => 'Eine Kopie teilen?';

  @override
  String shareTitleMany(int count) {
    return '$count Kopien teilen?';
  }

  @override
  String get shareWarning =>
      'Die von Ihnen gewählte App erhält unverschlüsselte Kopien und kann sie behalten.';

  @override
  String get shareStripTitle => 'Metadaten aus Fotokopien entfernen';

  @override
  String get shareStripOn =>
      'JPEG-Kopien behalten nur ihre Ausrichtung: Standort, Kamera, Zeit, Kommentare und Vorschaubilder werden entfernt. PNG-Kopien werden aus ihren Bildpunkten ohne Metadaten neu erstellt. Videokopien bleiben unverändert.';

  @override
  String get shareStripOff =>
      'Kopien behalten alle ursprünglichen Metadaten, einschließlich des Standorts, falls vorhanden.';

  @override
  String shareLimits(int items, int mib) {
    return 'Bis zu $items Aufnahmen und $mib MiB pro Stapel.';
  }

  @override
  String shareProgress(int prepared, int total) {
    return '$prepared von $total werden vorbereitet';
  }

  @override
  String get shareFailed =>
      'Teilen nicht möglich. Möglicherweise wird noch eine andere Freigabe beendet. Versuchen Sie es erneut.';

  @override
  String get shareChooseApp => 'App auswählen';

  @override
  String get viewerShareFailed =>
      'Teilen nicht möglich. Bitte versuchen Sie es erneut.';

  @override
  String get viewerDetails => 'Details';

  @override
  String viewerType(String kind) {
    return 'Typ: $kind';
  }

  @override
  String viewerCaptured(String when) {
    return 'Aufgenommen: $when';
  }

  @override
  String get viewerUnknown => 'Unbekannt';

  @override
  String viewerTags(String tags) {
    return 'Tags: $tags';
  }

  @override
  String get viewerNone => 'Keine';

  @override
  String viewerSize(int bytes) {
    return 'Verschlüsselte Größe: $bytes Byte';
  }

  @override
  String get viewerSizeUnavailable => 'Verschlüsselte Größe: nicht verfügbar';

  @override
  String get viewerClose => 'Schließen';

  @override
  String viewerSetCover(String tag) {
    return 'Als Titelbild von $tag verwenden';
  }

  @override
  String viewerCoverSet(String tag) {
    return 'Titelbild von $tag aktualisiert.';
  }

  @override
  String get viewerDeletePhotoTitle => 'Dieses Foto löschen?';

  @override
  String get viewerDeleteVideoTitle => 'Dieses Video löschen?';

  @override
  String viewerDeleteKeepNas(int days) {
    return '„Zuletzt gelöscht“ behält sie $days Tage verschlüsselt auf diesem Telefon, damit Sie sie wiederherstellen können. Ihre NAS-Kopie bleibt bis dahin erhalten. „Jetzt löschen“ entfernt sie dauerhaft von diesem Telefon und von Ihrem konfigurierten NAS.';
  }

  @override
  String viewerDeleteKeep(int days) {
    return '„Zuletzt gelöscht“ behält sie $days Tage verschlüsselt auf diesem Telefon, damit Sie sie wiederherstellen können. „Jetzt löschen“ entfernt sie dauerhaft von diesem Telefon.';
  }

  @override
  String get viewerDeleteNasNow =>
      'Sie wird dauerhaft von diesem Telefon und von Ihrem konfigurierten NAS entfernt.';

  @override
  String get viewerDeleteNow =>
      'Sie wird dauerhaft von diesem Telefon entfernt.';

  @override
  String get viewerDeleteNasTail =>
      'Ist das NAS nicht erreichbar, wird das Löschen abgeschlossen, sobald die Synchronisierung gelingt.';

  @override
  String get viewerDeletePendingTail =>
      'Ausstehende Löschungen werden angewendet, wenn Sie ein NAS-Backup erneut verbinden.';

  @override
  String get viewerDeleteEnd =>
      'Andere Backups und geteilte Kopien bleiben unberührt. Eine aktive Übertragung wird beendet.';

  @override
  String get viewerDelete => 'Löschen';

  @override
  String get viewerRemoveFavorite => 'Favorit entfernen';

  @override
  String get viewerAddFavorite => 'Zu Favoriten hinzufügen';

  @override
  String get viewerSlideshowStart => 'Diashow starten';

  @override
  String get viewerSlideshowStop => 'Diashow beenden';

  @override
  String get viewerShare => 'Kopie teilen';

  @override
  String get viewerDeletePhoto => 'Foto löschen';

  @override
  String get viewerDeleteVideo => 'Video löschen';

  @override
  String get viewerHideControls => 'Steuerelemente ausblenden';

  @override
  String get viewerShowControls => 'Steuerelemente einblenden';

  @override
  String viewerCasting(String device) {
    return 'Übertragung auf $device';
  }

  @override
  String get viewerPhotoUnavailable => 'Foto nicht verfügbar. Erneut versuchen';

  @override
  String get viewerPrivatePhoto => 'Privates Foto';

  @override
  String get viewerResetFit => 'Auf Bildschirm anpassen';

  @override
  String get viewerVideoUnavailable =>
      'Video nicht verfügbar. Erneut versuchen';

  @override
  String get viewerReplay => 'Video erneut abspielen';

  @override
  String get viewerPlay => 'Video abspielen';

  @override
  String get viewerPause => 'Video pausieren';

  @override
  String get viewerVideoPosition => 'Videoposition';

  @override
  String get viewerBack10 => '10 Sekunden zurück';

  @override
  String get viewerForward10 => '10 Sekunden vor';

  @override
  String get viewerMute => 'Video stummschalten';

  @override
  String get viewerUnmute => 'Videoton einschalten';

  @override
  String get lockNow => 'Jetzt sperren';

  @override
  String get brandTagline => 'Private Kamera';

  @override
  String get backupTitle => 'Backup prüfen';

  @override
  String get backupIntro =>
      'Prüft jede verschlüsselte Datei in Ihrem gespeicherten NAS-Backup mit dem Schlüssel dieses Tresors. Große Bibliotheken benötigen Zeit, Daten und temporären Speicherplatz. Diese Prüfung verändert die Originale nicht.';

  @override
  String get backupNeverChecked =>
      'Dieses Backup wurde noch nie vollständig geprüft. Prüfen Sie es, um sicherzustellen, dass Ihre Kopien lesbar sind.';

  @override
  String backupStale(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tagen',
      one: '1 Tag',
    );
    return 'Die letzte vollständige Prüfung war vor $_temp0. Prüfen Sie erneut, um sicherzustellen, dass Ihre Kopien noch lesbar sind.';
  }

  @override
  String get backupCancelCheck => 'Prüfung abbrechen';

  @override
  String get backupCancelQueued => 'Wartende Prüfung abbrechen';

  @override
  String get backupCheckSaved => 'Gespeichertes Backup prüfen';

  @override
  String backupCheckedAt(String date, String time, String state) {
    return 'Geprüft am $date um $time · $state';
  }

  @override
  String get backupUnchanged => 'Seitdem unverändert';

  @override
  String get backupChanged => 'Seitdem geändert; erneut prüfen';

  @override
  String get backupKeepKey =>
      'Bewahren Sie Ihren Wiederherstellungsschlüssel getrennt auf. Eine erfolgreiche Prüfung testet nicht die Kopie des Schlüssels, die Sie anderswo gespeichert haben.';

  @override
  String get backupLeaveNote =>
      'Sie können diesen Bildschirm während der Prüfung verlassen. Aufnahme-Uploads warten, bis die Prüfung beendet ist. Prüfungen werden beendet, wenn der App-Prozess geschlossen wird.';

  @override
  String get castSearchFailed =>
      'Fernseher konnten nicht gesucht werden. Prüfen Sie das WLAN und versuchen Sie es erneut.';

  @override
  String castConnected(String device) {
    return 'Mit $device verbunden. Öffnen Sie eine Aufnahme, um sie zu übertragen.';
  }

  @override
  String get castTitle => 'Auf einen Fernseher übertragen';

  @override
  String get castClose => 'Auswahl für Übertragung schließen';

  @override
  String get castUnencrypted =>
      'Ausgewählte Medien werden während der Übertragung unverschlüsselt über Ihr lokales Netzwerk gestreamt.';

  @override
  String get castLooking => 'Suche nach Fernsehern in diesem Netzwerk';

  @override
  String get castNoneFound => 'Keine Fernseher gefunden';

  @override
  String get castSameWifi =>
      'Ist der Fernseher im selben WLAN wie dieses Telefon?';

  @override
  String get castRetry => 'Erneut versuchen';

  @override
  String castStop(String device) {
    return 'Übertragung auf $device beenden';
  }

  @override
  String get castCancelConnection => 'Verbindung abbrechen';

  @override
  String get castToTv => 'Auf Fernseher übertragen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsPrivacySection => 'Datenschutz & Zugriff';

  @override
  String get settingsIdleLabel => 'Nach Inaktivität sperren';

  @override
  String get settingsIdleOff => 'Aus';

  @override
  String settingsIdleMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes Minuten',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String get settingsIdleNote =>
      'Aufnahme und Videowiedergabe verzögern die Inaktivitätssperre. Jetzt sperren speichert eine laufende Aufnahme, pausiert die Wiedergabe und beendet die Übertragung.';

  @override
  String get settingsScreenshotsIos =>
      'Vorschauen im App-Umschalter sind ausgeblendet. Screenshots unter iOS lassen sich nicht blockieren.';

  @override
  String get settingsScreenshotsAndroid =>
      'Screenshots, Bildschirmaufzeichnung und Vorschauen im App-Umschalter sind unter Android geschützt.';

  @override
  String get settingsPrivacySaveFailed =>
      'Datenschutzeinstellungen konnten nicht gespeichert werden. Versuchen Sie es erneut.';

  @override
  String get settingsPasscodeChanged => 'Code geändert';

  @override
  String get settingsBackupSection => 'Backup';

  @override
  String get settingsBackupIntro =>
      'Optionales Backup verschlüsselter Medien auf Ihre eigene WebDAV-Freigabe.';

  @override
  String get settingsUrlLabel => 'WebDAV-Ordner-URL';

  @override
  String get settingsUsername => 'Benutzername';

  @override
  String get settingsPassword => 'Passwort';

  @override
  String get settingsBackgroundTitle => 'Backup bei geschlossener App';

  @override
  String get settingsBackgroundBody =>
      'Android plant verschlüsselte Uploads, wenn Netzwerk und Akku es erlauben. Speichern Sie zuerst und schließen Sie eine Synchronisierung im Vordergrund ab. Beim Beenden erzwingen pausiert die Arbeit, bis Sie Quietake erneut öffnen.';

  @override
  String get settingsMobileTitle => 'Mobile Daten erlauben';

  @override
  String get settingsMobileBody =>
      'Aus nutzt nur Netzwerke ohne Datenlimit. Große Videos können viel Datenvolumen verbrauchen.';

  @override
  String get settingsBgChecking => 'Android-Planer wird geprüft …';

  @override
  String get settingsBgScheduled =>
      'Geplant, sobald Netzwerk und Akku es erlauben.';

  @override
  String get settingsBgUploading => 'Android lädt verschlüsselte Kopien hoch.';

  @override
  String get settingsBgTransferred =>
      'Der letzte Hintergrunddurchlauf ist abgeschlossen. Die vollständige Backup-Prüfung erfolgt separat.';

  @override
  String get settingsBgReconcile =>
      'Öffnen Sie den Tresor und synchronisieren Sie, um dieses Backup zu prüfen, bevor Hintergrund-Uploads fortgesetzt werden.';

  @override
  String get settingsBgPending =>
      'Hintergrund-Backup ausstehend. Android versucht es erneut.';

  @override
  String get settingsBgOff =>
      'Das Hintergrund-Backup ist aus oder wartet auf die erste erfolgreiche Synchronisierung.';

  @override
  String get settingsBgUnavailable =>
      'Planer nicht verfügbar. Die Synchronisierung im Vordergrund bleibt verfügbar.';

  @override
  String get settingsSave => 'Backup-Einstellungen speichern';

  @override
  String get settingsTest => 'Verbindung testen';

  @override
  String get settingsTesting => 'Verbindung wird getestet …';

  @override
  String settingsConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
    );
    return 'Verbunden · $_temp0';
  }

  @override
  String settingsErrHttp(int status) {
    return 'Verbindung fehlgeschlagen (HTTP $status). Prüfen Sie Ordner-URL, Benutzername und Passwort.';
  }

  @override
  String get settingsErrReach =>
      'NAS nicht erreichbar. Prüfen Sie die URL und das WLAN.';

  @override
  String get settingsErrGeneric =>
      'Verbindung fehlgeschlagen. Prüfen Sie die gespeicherten Angaben und versuchen Sie es erneut.';

  @override
  String get settingsSaveFirst =>
      'Speichern Sie Verbindungsänderungen, bevor Sie das Backup prüfen.';

  @override
  String get settingsEnterDetails =>
      'Geben Sie eine Ordner-URL, einen Benutzernamen und ein Passwort ein';

  @override
  String get settingsSaveFailed =>
      'Verbindungsdaten konnten nicht gespeichert werden. Versuchen Sie es erneut.';

  @override
  String get settingsDisconnectFailed =>
      'NAS-Backup konnte nicht getrennt werden. Versuchen Sie es erneut.';

  @override
  String get settingsWrongPasscode => 'Falscher Code. Versuchen Sie es erneut.';

  @override
  String get settingsRecoveryReadFailed =>
      'Der Wiederherstellungsschlüssel konnte nicht gelesen werden. Versuchen Sie es erneut.';

  @override
  String get settingsDisconnectTitle => 'NAS-Backup trennen?';

  @override
  String get settingsClearTitle => 'Gespeicherte NAS-Angaben löschen?';

  @override
  String get settingsDisconnectBody =>
      'Beendet das automatische Backup und entfernt die gespeicherten Verbindungsdaten. Aufnahmen bleiben auf Ihrem Telefon und dem NAS. Ausstehende NAS-Löschungen werden erst abgeschlossen, wenn Sie dieses Backup erneut verbinden.';

  @override
  String get settingsDisconnectAction => 'Trennen';

  @override
  String get settingsClearAction => 'Angaben löschen';

  @override
  String get settingsDisconnectButton => 'NAS-Backup trennen';

  @override
  String get settingsClearButton => 'Gespeicherte NAS-Angaben löschen';

  @override
  String get settingsRecoverySection => 'Wiederherstellung & Export';

  @override
  String get settingsShowRecovery => 'Wiederherstellungsschlüssel anzeigen';

  @override
  String get settingsNasPassTitle => 'Passphrase für das NAS-Backup';

  @override
  String get settingsNasPassBody =>
      'Wiederherstellung ohne Ihren Wiederherstellungsschlüssel aktivieren, ändern oder deaktivieren';

  @override
  String get settingsPortableTitle => 'Portables verschlüsseltes Backup';

  @override
  String get settingsPortableBody =>
      'Speichern Sie mit Ihrem Wiederherstellungsschlüssel eine ZIP-Datei in Dateien';

  @override
  String get settingsCameraSection => 'Kamera';

  @override
  String get settingsVideoLabel => 'Videoqualität';

  @override
  String get settingsVideoHelp => 'Höhere Qualität erzeugt größere Dateien.';

  @override
  String get settingsBurstLabel => 'Fotos pro Serie';

  @override
  String get settingsBurstHelp => 'Auslöser gedrückt halten.';

  @override
  String settingsBurstChoice(int count) {
    return '$count Fotos';
  }

  @override
  String get settingsStorageSection => 'Speicher';

  @override
  String get settingsStorageUnreadable =>
      'Speicher konnte nicht gelesen werden.';

  @override
  String get settingsStorageCounting => 'Aufnahmen werden gezählt …';

  @override
  String get settingsStorageNone => 'Noch keine Aufnahmen auf diesem Telefon.';

  @override
  String settingsStorageSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen',
      one: '1 Aufnahme',
    );
    return '$_temp0, $size verschlüsselt auf diesem Telefon.';
  }

  @override
  String settingsStorageTrashed(int count, int days) {
    return '$count in Zuletzt gelöscht, werden nach $days Tagen endgültig entfernt.';
  }

  @override
  String settingsSizeBytes(int value) {
    return '$value Bytes';
  }

  @override
  String settingsSizeKb(String value) {
    return '$value KB';
  }

  @override
  String settingsSizeMb(String value) {
    return '$value MB';
  }

  @override
  String get settingsBiometric => 'Mit Fingerabdruck oder Gesicht entsperren';

  @override
  String get settingsBiometricBody =>
      'Wenn aktiviert, bewahrt dieses Telefon eine Kopie des Tresorschlüssels in seinem sicheren Speicher auf. Der Zugangscode funktioniert immer.';

  @override
  String get settingsBiometricTurnOn => 'Aktivieren';

  @override
  String get settingsBiometricFailed =>
      'Entsperren mit Fingerabdruck oder Gesicht konnte nicht geändert werden.';

  @override
  String get settingsPlainIcon => 'Schlichtes Symbol und Namen verwenden';

  @override
  String get settingsPlainIconBody =>
      'Zeigt ein graues Symbol mit dem Namen Werkzeuge statt Quietake. Die App kann beim Wechseln kurz schließen. Quietake bleibt in der App-Liste und in den Systemeinstellungen sichtbar.';

  @override
  String get settingsPlainIconBodyIos =>
      'Zeigt ein anderes graues Symbol. Der Name bleibt Quietake, und iOS zeigt beim Wechsel einen Hinweis. Quietake bleibt in der App-Liste und in den Systemeinstellungen sichtbar.';

  @override
  String get settingsPlainIconFailed =>
      'Das App-Symbol konnte nicht geändert werden.';

  @override
  String get settingsKeepDeleted => 'Gelöschte Aufnahmen 30 Tage aufbewahren';

  @override
  String get settingsKeepDeletedBody =>
      'Löschen verschiebt eine Aufnahme zunächst nach Zuletzt gelöscht. Sie bleibt verschlüsselt.';

  @override
  String get settingsLicenses => 'Lizenzen';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsShow => 'Anzeigen';

  @override
  String get portableTitleRestore => 'Verschlüsseltes Backup wiederherstellen';

  @override
  String get portableTitleExport => 'Portables Backup';

  @override
  String get portableIntroRestore =>
      'Stellen Sie nur in einem neuen, leeren Tresor wieder her. Ihr Wiederherstellungsschlüssel öffnet das ZIP und die verschlüsselten Aufnahmen. Bestehende Bibliotheken lassen sich nicht zusammenführen.';

  @override
  String get portableIntroExport =>
      'Speichern Sie ein verschlüsseltes ZIP Ihrer Aufnahmen und ihrer Organisation. Ihr vorhandener Wiederherstellungsschlüssel öffnet es; bewahren Sie ihn getrennt auf. Zugangsdaten und Schlüsseldateien sind nicht enthalten.';

  @override
  String get portableChoose => 'Backup-ZIP auswählen';

  @override
  String get portableCheckOnly => 'Backup nur prüfen';

  @override
  String get portableRestoreButton => 'Leeren Tresor wiederherstellen';

  @override
  String get portableCreateButton => 'Verschlüsseltes ZIP erstellen';

  @override
  String get portableLimitsTitle => 'Backup-Grenzen und Speicher';

  @override
  String get portableLimitsBody =>
      'Bis zu 10.000 Aufnahmen und 2 GiB pro ZIP. Die Vorbereitung benötigt privaten temporären Speicher. Die Originale im Tresor bleiben unverändert. Zugangsdaten und Schlüsseldateien sind nicht enthalten.';

  @override
  String get portableCancelPrep => 'Vorbereitung abbrechen';

  @override
  String get portablePicking =>
      'Wählen Sie in Dateien ein verschlüsseltes ZIP aus.';

  @override
  String get portablePickCancelled => 'Auswahl abgebrochen.';

  @override
  String get portablePicked =>
      'Backup ausgewählt. Geben Sie den Wiederherstellungsschlüssel und einen neuen Code ein.';

  @override
  String get portableCopyFailed =>
      'Backup konnte nicht kopiert werden. Prüfen Sie den Speicher und versuchen Sie es erneut.';

  @override
  String get portableStillFinishing =>
      'Das vorherige Backup wird noch abgeschlossen. Versuchen Sie es gleich erneut.';

  @override
  String get portableNeedKey =>
      'Wählen Sie ein Backup und geben Sie dessen Wiederherstellungsschlüssel ein.';

  @override
  String get portableNeedPasscode =>
      'Wählen Sie ein Backup und bestätigen Sie einen Code mit mindestens sechs Zeichen.';

  @override
  String get portablePreparing => 'Verschlüsseltes Backup wird vorbereitet …';

  @override
  String portableChecking(int done, int total) {
    return 'Verschlüsselte Dateien werden geprüft: $done von $total …';
  }

  @override
  String get portableChecked =>
      'Backup geprüft: Jede verschlüsselte Datei und der Katalog werden mit diesem Schlüssel authentifiziert. Es wurde nichts wiederhergestellt. Wählen Sie die Datei erneut aus, um sie wiederherzustellen.';

  @override
  String get portableRestored =>
      'Tresor wiederhergestellt. Verwenden Sie Ihren neuen Code einmal, um die biometrische Entsperrung zu aktivieren.';

  @override
  String portableExporting(int done, int total) {
    return 'Verschlüsselte Dateien werden vorbereitet: $done von $total …';
  }

  @override
  String get portableSaved =>
      'Verschlüsseltes Backup gespeichert. Bewahren Sie den Wiederherstellungsschlüssel getrennt auf.';

  @override
  String get portableSaveCancelled =>
      'Speichern abgebrochen. Die Originale im Tresor bleiben erhalten.';

  @override
  String get portableBadKey =>
      'Geben Sie den für dieses Backup gespeicherten Wiederherstellungsschlüssel ein.';

  @override
  String get portableCancelled =>
      'Abgebrochen. Die Originale im Tresor bleiben erhalten.';

  @override
  String get portableFailed =>
      'Backup konnte nicht wiederhergestellt oder gespeichert werden. Prüfen Sie Schlüssel, Datei, verfügbaren Speicher und die Voraussetzung eines leeren Tresors.';

  @override
  String get nasTitleRestore => 'Vom NAS wiederherstellen';

  @override
  String get nasTitleManage => 'Backup-Passphrase';

  @override
  String get nasIntroRestore =>
      'Verwenden Sie die separate Backup-Passphrase, die Sie zuvor auf Ihrem NAS aktiviert haben. Der kurze Telefon-Code kann dieses Backup nicht wiederherstellen. Die Wiederherstellung authentifiziert alle Dateien in einem leeren Tresor; es wird nichts zusammengeführt. Ihr NAS bleibt schreibgeschützt.';

  @override
  String get nasIntroManage =>
      'Schützen Sie die NAS-Wiederherstellung mit einer separaten, starken Passphrase. Jeder, der die verschlüsselte Datei besitzt, kann offline Vermutungen ausprobieren. Bevorzugen Sie sechs zufällige Wörter; Länge allein beweist keine Stärke. Schließen Sie zuerst eine Synchronisierung mit dem gespeicherten NAS ab. Das NAS muss sicheres Dateisperren unterstützen; andernfalls wird nichts geschrieben.';

  @override
  String get nasUrlLabel => 'HTTPS-WebDAV-Ordner-URL';

  @override
  String get nasUserLabel => 'NAS-Benutzername';

  @override
  String get nasPasswordLabel => 'NAS-Passwort';

  @override
  String get nasPinNew => 'Neuer lokaler Code';

  @override
  String get nasPinCurrent => 'Aktueller lokaler Code';

  @override
  String get nasPinConfirm => 'Neuen lokalen Code bestätigen';

  @override
  String get nasPhraseLabel => 'Backup-Passphrase';

  @override
  String get nasPhraseConfirm => 'Backup-Passphrase bestätigen';

  @override
  String get nasGenerate => 'Sechs Wörter erzeugen';

  @override
  String get nasHide => 'Passphrase ausblenden';

  @override
  String get nasShow => 'Passphrase anzeigen';

  @override
  String get nasWordsCredit =>
      'Wörter: Electronic Frontier Foundation · CC BY 4.0';

  @override
  String get nasWordLicenses => 'Lizenzen der Wortliste';

  @override
  String get nasEnableButton => 'Passphrase aktivieren oder ändern';

  @override
  String get nasDisableButton =>
      'Wiederherstellung per Passphrase deaktivieren';

  @override
  String get nasFootRestore =>
      'Bis zu 10.000 Aufnahmen. Privater temporärer Speicherplatz ist erforderlich. Entsperren Sie anschließend mit Ihrem neuen Code. Der Hintergrund-Upload bleibt aus.';

  @override
  String get nasFootManage =>
      'Dies ändert nur den Wiederherstellungsschutz. Es ändert nie den Telefon-Code und verschlüsselt keine Aufnahmen neu. Das Entfernen der aktuellen Wiederherstellung widerruft keine alten Server-Snapshots.';

  @override
  String get nasGenerateFailed =>
      'Passphrase konnte nicht erzeugt werden. Versuchen Sie es erneut.';

  @override
  String get nasConfirmDisableTitle =>
      'Wiederherstellung per Passphrase deaktivieren?';

  @override
  String get nasConfirmSaveTitle => 'Backup-Passphrase speichern?';

  @override
  String get nasConfirmDisableBody =>
      'Entfernt die aktuelle Wiederherstellungsdatei aus dem gespeicherten NAS-Ordner. Aufnahmen bleiben erhalten. Alte Server-Snapshots akzeptieren möglicherweise noch eine frühere Passphrase. Bewahren Sie Ihren unabhängigen Wiederherstellungsschlüssel auf.';

  @override
  String get nasConfirmSaveBody =>
      'Erstellt oder ersetzt die Wiederherstellung im gespeicherten NAS-Ordner. Bewahren Sie die neue Passphrase getrennt auf. Alte Server-Snapshots akzeptieren möglicherweise noch eine frühere Passphrase; der Schlüssel Ihres Tresors wird dadurch nicht gewechselt.';

  @override
  String get nasDisableAction => 'Wiederherstellung deaktivieren';

  @override
  String get nasSaveAction => 'Passphrase speichern';

  @override
  String get nasSeparatePhrase =>
      'Verwenden Sie eine separate Backup-Passphrase, nicht Ihren lokalen Code.';

  @override
  String get nasNeedPasscode =>
      'Wählen und bestätigen Sie einen neuen Code mit mindestens sechs Zeichen.';

  @override
  String get nasNeedDetails =>
      'Geben Sie Ihren gespeicherten NAS-Ordner, Benutzernamen und das Passwort ein.';

  @override
  String get nasMismatch => 'Die Backup-Passphrasen stimmen nicht überein.';

  @override
  String get nasCheckingRestore => 'Verschlüsseltes NAS-Backup wird geprüft …';

  @override
  String get nasCheckingSaved =>
      'Gespeicherte NAS-Wiederherstellung wird geprüft …';

  @override
  String get nasRestoredTitle => 'Tresor wiederhergestellt';

  @override
  String get nasRestoredUnsaved =>
      'Die NAS-Verbindung konnte nicht gespeichert werden. Ihre Aufnahmen sind wiederhergestellt; fügen Sie die Verbindung in den Einstellungen erneut hinzu, um Backups fortzusetzen.';

  @override
  String get nasContinue => 'Weiter';

  @override
  String get nasDisabledDone =>
      'Wiederherstellung per Passphrase deaktiviert. Aufnahmen bleiben erhalten.';

  @override
  String get nasSavedDone =>
      'Backup-Passphrase gespeichert. Bewahren Sie sie und Ihren Wiederherstellungsschlüssel getrennt auf.';

  @override
  String get nasWrongCurrent =>
      'Falscher aktueller Code. Versuchen Sie es erneut.';

  @override
  String get nasCancelled => 'Abgebrochen. Originale bleiben erhalten.';

  @override
  String get nasRestoreFailed =>
      'Wiederherstellung fehlgeschlagen. Prüfen Sie die NAS-Verbindung, die Backup-Passphrase und die Voraussetzung eines leeren Tresors. Originale bleiben erhalten.';

  @override
  String get nasChangeFailed =>
      'Wiederherstellung konnte nicht geändert werden. Prüfen Sie das gespeicherte NAS-Backup, die unterstützte Wiederherstellungsdatei und die Serverkompatibilität. Synchronisieren Sie zuerst und versuchen Sie es dann erneut. Originale bleiben erhalten.';

  @override
  String get coverChooseTitle => 'Titelbild wählen';

  @override
  String get coverEmpty =>
      'Versehen Sie zuerst einige Aufnahmen mit dem Tag und wählen Sie dann eine als Titelbild.';

  @override
  String get coverUse => 'Diese Aufnahme als Titelbild verwenden';

  @override
  String get restoreGateFailed =>
      'Die unterbrochene Backup-Wiederherstellung konnte nicht abgeschlossen werden. Vorbereitete verschlüsselte Dateien bleiben erhalten. Prüfen Sie den verfügbaren Speicher und versuchen Sie es erneut.';

  @override
  String get restoreGateRetry => 'Wiederherstellung wiederholen';

  @override
  String get restoreGateDiscard => 'Unvollständige Wiederherstellung verwerfen';

  @override
  String get restoreGateDiscardTitle =>
      'Unvollständige Wiederherstellung verwerfen?';

  @override
  String get restoreGateDiscardBody =>
      'Dies entfernt nur die Kopie, die auf diesem Telefon vorbereitet wurde. Ihr Backup wird nicht verändert, und Sie können es erneut wiederherstellen.';

  @override
  String get restoreGateDiscardConfirm => 'Verwerfen';

  @override
  String get settingsCheckRecovery =>
      'Meinen Wiederherstellungsschlüssel prüfen';

  @override
  String get recoveryCheckTitle => 'Wiederherstellungsschlüssel prüfen';

  @override
  String get recoveryCheckIntro =>
      'Geben Sie den Wiederherstellungsschlüssel ein, den Sie anderswo gespeichert haben. Er wird auf diesem Telefon verglichen und nie gespeichert.';

  @override
  String get recoveryCheckAction => 'Prüfen';

  @override
  String get recoveryCheckClose => 'Schließen';

  @override
  String get recoveryCheckNever => 'Noch nie geprüft.';

  @override
  String recoveryCheckLast(String date) {
    return 'Zuletzt übereinstimmend: $date.';
  }

  @override
  String recoveryCheckDue(String date) {
    return 'Zuletzt übereinstimmend: $date. Prüfe den Schlüssel alle paar Monate erneut.';
  }

  @override
  String get recoveryCheckMatch =>
      'Er stimmt mit dem Wiederherstellungsschlüssel Ihres Tresors überein.';

  @override
  String get recoveryCheckMismatch =>
      'Dieser Schlüssel passt nicht zu diesem Tresor. Prüfen Sie, wo Sie ihn gespeichert haben, und versuchen Sie es erneut.';

  @override
  String get recoveryCheckInvalid =>
      'Das ist kein gültiger Wiederherstellungsschlüssel. Prüfen Sie, ob Zeichen fehlen oder zu viel sind.';

  @override
  String get redactTitle => 'Teile des Fotos verbergen';

  @override
  String get redactUndo => 'Letzten Bereich rückgängig machen';

  @override
  String get redactDone => 'Fertig';

  @override
  String redactStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bereiche werden verborgen.',
      one: '1 Bereich wird verborgen.',
      zero: 'Ziehen Sie über das Foto, um einen Bereich zu verbergen.',
    );
    return '$_temp0';
  }

  @override
  String get redactFailed =>
      'Dieses Foto konnte nicht zur Bearbeitung geöffnet werden.';

  @override
  String get shareRedactButton => 'Teile dieses Fotos verbergen …';

  @override
  String shareRedactEdit(int count) {
    return 'Verborgene Bereiche: $count. Ändern …';
  }

  @override
  String get shareRedactNote =>
      'Die geteilte Kopie wird ein PNG mit schwarz abgedeckten Bereichen und ohne Metadaten. Das Original bleibt in Ihrem Tresor unverändert.';

  @override
  String get shareRedactButtonMany => 'Teile dieser Fotos verbergen…';

  @override
  String shareRedactEditMany(int areas, int photos) {
    String _temp0 = intl.Intl.pluralLogic(
      photos,
      locale: localeName,
      other: '$photos Fotos',
      one: '1 Foto',
    );
    return 'Verborgene Bereiche: $areas in $_temp0. Ändern…';
  }

  @override
  String get shareRedactNoteMany =>
      'Fotos mit verborgenen Bereichen werden als PNG-Kopien geteilt, mit schwarz abgedeckten Bereichen und ohne Metadaten. Die Originale bleiben in Ihrem Tresor unverändert.';

  @override
  String redactCell(int row, int column) {
    return 'Zeile $row, Spalte $column';
  }

  @override
  String get redactSections => 'Oder einen Abschnitt des Fotos verbergen';

  @override
  String get settingsRenameRemote => 'NAS-Dateien zufällige Namen geben';

  @override
  String get settingsRenameRemoteNone =>
      'Keine Datei auf dem NAS braucht einen neuen Namen.';

  @override
  String get settingsRenameRemoteTitle => 'Dateien auf dem NAS umbenennen?';

  @override
  String settingsRenameRemoteBody(int count) {
    return '$count verschlüsselte Dateien auf dem NAS erhalten zufällige Namen, sodass ihre Namen und Zeiten dort nicht mehr sichtbar sind. Aktualisiere zuerst Quietake auf allen anderen Handys: ältere Versionen finden umbenannte Dateien nicht. Deine Originale bleiben auf diesem Handy.';
  }

  @override
  String get settingsRenameRemoteAction => 'Umbenennen';

  @override
  String settingsRenameRemoteDone(int count) {
    return '$count Dateien auf dem NAS umbenannt.';
  }

  @override
  String get settingsRenameRemoteFailed =>
      'Das Umbenennen wurde angehalten. Starte es erneut, um fortzufahren. Es ging nichts verloren.';

  @override
  String get shareEncryptedTitle => 'Mit Passphrase verschlüsseln';

  @override
  String get shareEncryptedBody =>
      'Die Kopien kommen in eine Datei, die nur eine Passphrase öffnet. Quietake zeigt die Passphrase einmal an. Sende sie auf einem anderen Weg als die Datei.';

  @override
  String get sharePassphraseTitle => 'Passphrase für diese Freigabe';

  @override
  String get sharePassphraseBody =>
      'Schreibe sie jetzt auf oder sende sie getrennt. Quietake speichert sie nicht und kann sie nicht erneut zeigen.';

  @override
  String get sharePassphraseContinue => 'App wählen';
}
