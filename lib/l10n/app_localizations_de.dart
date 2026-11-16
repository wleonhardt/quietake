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
  String get lockUnlock => 'Entsperren';

  @override
  String get lockUseBiometrics => 'Biometrie verwenden';

  @override
  String get lockForgot => 'Zugangscode vergessen?';

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
}
