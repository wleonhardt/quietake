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

  @override
  String get camUnavailable =>
      'Camera unavailable. Check camera permission in Settings.';

  @override
  String get camTagsOpenFailed =>
      'Could not open private tags. Retry from Library.';

  @override
  String get camOrientationFailed => 'Could not update camera orientation.';

  @override
  String get camPendingSave =>
      'Capture waiting for secure save. Free storage, then lock and unlock to retry.';

  @override
  String camRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures',
      one: '1 capture',
    );
    return 'Recovered $_temp0.';
  }

  @override
  String get camRecoveredVideoNote =>
      'Interrupted videos may be incomplete or may not play on a TV.';

  @override
  String get camPendingCheckFailed =>
      'Could not check pending captures. Free storage and reopen the camera.';

  @override
  String get camNone => 'No camera';

  @override
  String get camFocusLockFailed =>
      'Could not lock focus and exposure on this camera.';

  @override
  String get camRecordStartFailed => 'Could not start recording. Try again.';

  @override
  String get camRecordStopFailed => 'Could not stop recording. Try again.';

  @override
  String get camNoFrames => 'No video frames were recorded. Try again.';

  @override
  String get camPendingNoTags =>
      'Capture waiting for secure save. Tags were not applied; check Library after recovery.';

  @override
  String get camSaveFailed => 'Could not save capture. Try again.';

  @override
  String camSavedPhotos(int count) {
    return 'Saved $count photos securely';
  }

  @override
  String get camSwitchFailed => 'Could not switch camera. Try again.';

  @override
  String get camMicDenied =>
      'Allow microphone access in Settings to record video. Photos are still available.';

  @override
  String get camVideoStartFailed =>
      'Could not start video. Check camera and microphone permissions in Settings.';

  @override
  String get camSaving => 'Saving securely…';

  @override
  String get camSaved => 'Saved securely';

  @override
  String get camTagsNotApplied => 'Tags were not applied; organize in Library.';

  @override
  String get camNotCastReady => 'This video may not play on your TV.';

  @override
  String get camPreview => 'Camera preview';

  @override
  String get camPreviewHint =>
      'Tap to focus. Press and hold to lock focus and exposure.';

  @override
  String get camFocusLocked => 'Focus and exposure locked';

  @override
  String camRecTimer(String time) {
    return 'REC $time';
  }

  @override
  String get camStartingVideo => 'Starting video…';

  @override
  String get camCastFailed => 'Could not cast. Try again.';

  @override
  String camCasting(String device) {
    return 'Casting to $device';
  }

  @override
  String get camChooseTags => 'Choose tags for new captures';

  @override
  String get camTags => 'Tags';

  @override
  String camTagCount(int count) {
    return '$count tags';
  }

  @override
  String get camTimerOff => 'Timer off';

  @override
  String camTimerSeconds(int seconds) {
    return 'Timer $seconds seconds';
  }

  @override
  String get camGridHide => 'Hide grid';

  @override
  String get camGridShow => 'Show grid';

  @override
  String get camSwitchRear => 'Switch to rear camera';

  @override
  String get camSwitchFront => 'Switch to front camera';

  @override
  String get camStopRecording => 'Stop recording';

  @override
  String get camRecordVideo => 'Record video';

  @override
  String get camStop => 'Stop';

  @override
  String get camVideo => 'Video';

  @override
  String get camTakePhoto => 'Take photo';

  @override
  String get camCancelTimer => 'Cancel timer';

  @override
  String get camPhoto => 'Photo';

  @override
  String get camOpenLibrary => 'Open Library';

  @override
  String get camLibrary => 'Library';

  @override
  String camTakeBurst(int count) {
    return 'Take $count photos';
  }

  @override
  String get save => 'Save';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get tagsMoments => 'Moments';

  @override
  String get tagsSortName => 'Sort by name';

  @override
  String get tagsSortCount => 'Sort by most captures';

  @override
  String get tagsCreate => 'Create tag';

  @override
  String get tagsFind => 'Find tags';

  @override
  String get tagsCountFailed => 'Could not count captures. Retry';

  @override
  String get tagsUntagged => 'Untagged';

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
  String get tagsNoMatch => 'No matching tags';

  @override
  String get tagsNone => 'No tags yet';

  @override
  String get tagsNoMatchHint => 'Try another name or create this one.';

  @override
  String get tagsNoneHint => 'Tags group captures across the Library.';

  @override
  String tagsCreateNamed(String name) {
    return 'Create \'$name\'';
  }

  @override
  String get tagsCreateFirst => 'Create first tag';

  @override
  String get tagsOptions => 'Tag options';

  @override
  String get tagsRename => 'Rename';

  @override
  String get tagsRenameTitle => 'Rename tag';

  @override
  String get tagsSetCover => 'Set cover';

  @override
  String get tagsClearCover => 'Clear cover';

  @override
  String get tagsMergeInto => 'Merge into…';

  @override
  String get tagsDelete => 'Delete tag';

  @override
  String get tagsDeleteTitle => 'Delete tag?';

  @override
  String tagsDeleteBody(String name) {
    return 'Remove “$name” from all captures? Photos and videos stay in your vault.';
  }

  @override
  String get tagsMergeTitle => 'Merge tags?';

  @override
  String tagsMergeBody(String source, String target, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures',
      one: '1 capture',
    );
    return 'Merge “$source” into “$target”? $_temp0 will use the remaining tag. The source tag is removed. Photos, videos and other tags stay unchanged.';
  }

  @override
  String get tagsMergeConfirm => 'Merge tags';

  @override
  String get mergeChoose => 'Choose the tag to keep';

  @override
  String get mergeCancel => 'Cancel merge';

  @override
  String get mergeFindDestination => 'Find destination tag';

  @override
  String get libraryNameLabel => 'Name';

  @override
  String get librarySaveFailed => 'Could not save. Retry.';

  @override
  String get libraryUpdateFailed => 'Could not update private library. Retry.';

  @override
  String get momentsLoadFailed => 'Could not read captures. Retry';

  @override
  String get momentsEmpty => 'No dated captures yet';

  @override
  String get viewTitle => 'View';

  @override
  String get viewAll => 'All';

  @override
  String get viewPhotos => 'Photos';

  @override
  String get viewVideos => 'Videos';

  @override
  String get viewFavoritesOnly => 'Favorites only';

  @override
  String get viewSort => 'Sort';

  @override
  String get viewNewest => 'Newest first';

  @override
  String get viewOldest => 'Oldest first';

  @override
  String get viewName => 'Name';

  @override
  String get viewApply => 'Apply view';

  @override
  String viewShowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count captures',
      one: 'Show 1 capture',
    );
    return '$_temp0';
  }

  @override
  String get viewReset => 'Reset';
}
