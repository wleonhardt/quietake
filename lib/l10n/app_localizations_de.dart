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
}
