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

  @override
  String get lockUnlockReason => 'Unlock Quietake';

  @override
  String get lockBiometricUnavailable =>
      'Biometric unlock is unavailable. Use your passcode.';

  @override
  String get lockFailed =>
      'Could not unlock. Try again or use your recovery key.';

  @override
  String get lockMessage => 'Unlock your private vault.';

  @override
  String get passcodeLabel => 'Passcode';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get lockUseBiometrics => 'Use biometrics';

  @override
  String get lockForgot => 'Forgot passcode?';

  @override
  String get recoveryKeyLabel => 'Recovery key';

  @override
  String get recoveryKeyIntro =>
      'Keep this key in your password manager, separately from your encrypted files. You need both to recover your captures if you forget the passcode or lose this device. A NAS backup passphrase is another recovery option only if you have enabled it.';

  @override
  String recoveryFingerprint(String fingerprint) {
    return 'Fingerprint $fingerprint';
  }

  @override
  String get recoveryFingerprintNote =>
      'Save the fingerprint with the key. A new phone shows it so you can check the key you typed.';

  @override
  String get recoverySaved => 'I saved it';

  @override
  String get changePasscodeTitle => 'Change passcode';

  @override
  String get changePasscodeNote =>
      'Your captures and recovery key stay the same.';

  @override
  String get currentPasscodeLabel => 'Current passcode';

  @override
  String get newPasscodeLabel => 'New passcode';

  @override
  String get confirmNewPasscodeLabel => 'Confirm new passcode';

  @override
  String get passcodesDoNotMatch => 'Passcodes do not match';

  @override
  String get currentPasscodeIncorrect => 'Current passcode is incorrect';

  @override
  String get changePasscodeFailed => 'Could not change passcode. Try again.';

  @override
  String get changePasscodeBusy => 'Changing…';

  @override
  String get setupConfirmKeyTitle => 'Confirm recovery key';

  @override
  String get setupConfirmKeyBody =>
      'This phone has no captures yet, so the key cannot be checked against them. Compare this fingerprint with the one saved next to your recovery key.';

  @override
  String get setupNotMine => 'Not mine';

  @override
  String get setupMatches => 'Matches';

  @override
  String get setupCreateFailed =>
      'Could not create the vault. Check storage and try again.';

  @override
  String get setupRestoreFailed =>
      'Could not restore the vault. Check storage and try again.';

  @override
  String get setupRestoreTitle => 'Restore vault';

  @override
  String get setupCreateTitle => 'Set a passcode';

  @override
  String get setupRestoreMessage =>
      'Unlock your encrypted files with your saved recovery key.';

  @override
  String get setupTagline => 'Your camera. Your captures. Your control.';

  @override
  String setupPasscodeHelper(int count) {
    return 'At least $count characters';
  }

  @override
  String get confirmPasscodeLabel => 'Confirm passcode';

  @override
  String get restore => 'Restore';

  @override
  String get setupCreateVault => 'Create vault';

  @override
  String get setupStartNew => 'Start a new vault instead';

  @override
  String get setupHaveKey => 'I have a recovery key';

  @override
  String get setupRestoreZip => 'Restore an encrypted ZIP';

  @override
  String get setupRestoreNas => 'Restore from NAS with backup passphrase';

  @override
  String get privacyPolicy => 'Privacy policy';
}
