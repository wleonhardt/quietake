import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @recentlyDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recently deleted'**
  String get recentlyDeletedTitle;

  /// No description provided for @recentlyDeletedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recently deleted'**
  String get recentlyDeletedEmpty;

  /// Explains how long deleted captures are kept.
  ///
  /// In en, this message translates to:
  /// **'Deleted captures stay encrypted on this phone for {days} days, then are removed for good.'**
  String recentlyDeletedNote(int days);

  /// No description provided for @recentlyDeletedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read deleted captures. Retry'**
  String get recentlyDeletedLoadFailed;

  /// Days before a deleted capture is removed for good.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left} other{{count} days left}}'**
  String recentlyDeletedDaysLeft(int count);

  /// No description provided for @recentlyDeletedRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get recentlyDeletedRestore;

  /// No description provided for @recentlyDeletedDeleteNow.
  ///
  /// In en, this message translates to:
  /// **'Delete now'**
  String get recentlyDeletedDeleteNow;

  /// No description provided for @recentlyDeletedDeleteNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete now?'**
  String get recentlyDeletedDeleteNowTitle;

  /// No description provided for @recentlyDeletedDeleteNowBody.
  ///
  /// In en, this message translates to:
  /// **'This capture is permanently removed from this phone and your configured NAS. It cannot be restored.'**
  String get recentlyDeletedDeleteNowBody;

  /// No description provided for @recentlyDeletedAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all now?'**
  String get recentlyDeletedAllTitle;

  /// Confirmation for permanently deleting every capture in Recently deleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 capture is permanently removed from this phone and your configured NAS. It cannot be restored.} other{{count} captures are permanently removed from this phone and your configured NAS. They cannot be restored.}}'**
  String recentlyDeletedAllBody(int count);

  /// No description provided for @recentlyDeletedAllNow.
  ///
  /// In en, this message translates to:
  /// **'Delete all now'**
  String get recentlyDeletedAllNow;

  /// No description provided for @recentlyDeletedRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore. Please retry.'**
  String get recentlyDeletedRestoreFailed;

  /// No description provided for @recentlyDeletedDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish deleting. Please retry.'**
  String get recentlyDeletedDeleteFailed;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @lockUnlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Quietake'**
  String get lockUnlockReason;

  /// No description provided for @lockBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock is unavailable. Use your passcode.'**
  String get lockBiometricUnavailable;

  /// No description provided for @lockFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock. Try again or use your recovery key.'**
  String get lockFailed;

  /// No description provided for @lockMessage.
  ///
  /// In en, this message translates to:
  /// **'Unlock your private vault.'**
  String get lockMessage;

  /// No description provided for @passcodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Passcode'**
  String get passcodeLabel;

  /// No description provided for @lockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockUnlock;

  /// No description provided for @lockUseBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get lockUseBiometrics;

  /// No description provided for @lockForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot passcode?'**
  String get lockForgot;

  /// No description provided for @lockCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get lockCamera;

  /// No description provided for @lockedCameraSaved.
  ///
  /// In en, this message translates to:
  /// **'Photo sealed. It appears in your library after you unlock.'**
  String get lockedCameraSaved;

  /// No description provided for @lockedCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the photo.'**
  String get lockedCameraFailed;

  /// No description provided for @lockedCameraClose.
  ///
  /// In en, this message translates to:
  /// **'Close camera'**
  String get lockedCameraClose;

  /// No description provided for @lockedCapturesPublished.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo from the lock screen camera is now in your library.} other{{count} photos from the lock screen camera are now in your library.}}'**
  String lockedCapturesPublished(int count);

  /// No description provided for @recoveryKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get recoveryKeyLabel;

  /// No description provided for @recoveryKeyIntro.
  ///
  /// In en, this message translates to:
  /// **'Keep this key in your password manager, separately from your encrypted files. You need both to recover your captures if you forget the passcode or lose this device. A NAS backup passphrase is another recovery option only if you have enabled it.'**
  String get recoveryKeyIntro;

  /// No description provided for @recoveryFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint {fingerprint}'**
  String recoveryFingerprint(String fingerprint);

  /// No description provided for @recoveryFingerprintNote.
  ///
  /// In en, this message translates to:
  /// **'Save the fingerprint with the key. A new phone shows it so you can check the key you typed.'**
  String get recoveryFingerprintNote;

  /// No description provided for @recoverySaved.
  ///
  /// In en, this message translates to:
  /// **'I saved it'**
  String get recoverySaved;

  /// No description provided for @changePasscodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change passcode'**
  String get changePasscodeTitle;

  /// No description provided for @changePasscodeNote.
  ///
  /// In en, this message translates to:
  /// **'Your captures and recovery key stay the same.'**
  String get changePasscodeNote;

  /// No description provided for @currentPasscodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Current passcode'**
  String get currentPasscodeLabel;

  /// No description provided for @newPasscodeLabel.
  ///
  /// In en, this message translates to:
  /// **'New passcode'**
  String get newPasscodeLabel;

  /// No description provided for @confirmNewPasscodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new passcode'**
  String get confirmNewPasscodeLabel;

  /// No description provided for @passcodesDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passcodes do not match'**
  String get passcodesDoNotMatch;

  /// No description provided for @currentPasscodeIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Current passcode is incorrect'**
  String get currentPasscodeIncorrect;

  /// No description provided for @changePasscodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change passcode. Try again.'**
  String get changePasscodeFailed;

  /// No description provided for @changePasscodeBusy.
  ///
  /// In en, this message translates to:
  /// **'Changing…'**
  String get changePasscodeBusy;

  /// No description provided for @setupConfirmKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm recovery key'**
  String get setupConfirmKeyTitle;

  /// No description provided for @setupConfirmKeyBody.
  ///
  /// In en, this message translates to:
  /// **'This phone has no captures yet, so the key cannot be checked against them. Compare this fingerprint with the one saved next to your recovery key.'**
  String get setupConfirmKeyBody;

  /// No description provided for @setupNotMine.
  ///
  /// In en, this message translates to:
  /// **'Not mine'**
  String get setupNotMine;

  /// No description provided for @setupMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get setupMatches;

  /// No description provided for @setupCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the vault. Check storage and try again.'**
  String get setupCreateFailed;

  /// No description provided for @setupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the vault. Check storage and try again.'**
  String get setupRestoreFailed;

  /// No description provided for @setupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore vault'**
  String get setupRestoreTitle;

  /// No description provided for @setupCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a passcode'**
  String get setupCreateTitle;

  /// No description provided for @setupRestoreMessage.
  ///
  /// In en, this message translates to:
  /// **'Unlock your encrypted files with your saved recovery key.'**
  String get setupRestoreMessage;

  /// No description provided for @setupTagline.
  ///
  /// In en, this message translates to:
  /// **'Your camera. Your captures. Your control.'**
  String get setupTagline;

  /// No description provided for @setupPasscodeHelper.
  ///
  /// In en, this message translates to:
  /// **'At least {count} characters'**
  String setupPasscodeHelper(int count);

  /// No description provided for @confirmPasscodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm passcode'**
  String get confirmPasscodeLabel;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @setupCreateVault.
  ///
  /// In en, this message translates to:
  /// **'Create vault'**
  String get setupCreateVault;

  /// No description provided for @setupStartNew.
  ///
  /// In en, this message translates to:
  /// **'Start a new vault instead'**
  String get setupStartNew;

  /// No description provided for @setupHaveKey.
  ///
  /// In en, this message translates to:
  /// **'I have a recovery key'**
  String get setupHaveKey;

  /// No description provided for @setupRestoreZip.
  ///
  /// In en, this message translates to:
  /// **'Restore an encrypted ZIP'**
  String get setupRestoreZip;

  /// No description provided for @setupRestoreNas.
  ///
  /// In en, this message translates to:
  /// **'Restore from NAS with backup passphrase'**
  String get setupRestoreNas;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @camUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Check camera permission in Settings.'**
  String get camUnavailable;

  /// No description provided for @camTagsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open private tags. Retry from Library.'**
  String get camTagsOpenFailed;

  /// No description provided for @camOrientationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update camera orientation.'**
  String get camOrientationFailed;

  /// No description provided for @camPendingSave.
  ///
  /// In en, this message translates to:
  /// **'Capture waiting for secure save. Free storage, then lock and unlock to retry.'**
  String get camPendingSave;

  /// No description provided for @camRecovered.
  ///
  /// In en, this message translates to:
  /// **'Recovered {count, plural, =1{1 capture} other{{count} captures}}.'**
  String camRecovered(int count);

  /// No description provided for @camRecoveredVideoNote.
  ///
  /// In en, this message translates to:
  /// **'Interrupted videos may be incomplete or may not play on a TV.'**
  String get camRecoveredVideoNote;

  /// No description provided for @camPendingCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check pending captures. Free storage and reopen the camera.'**
  String get camPendingCheckFailed;

  /// No description provided for @camNone.
  ///
  /// In en, this message translates to:
  /// **'No camera'**
  String get camNone;

  /// No description provided for @camFocusLockFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not lock focus and exposure on this camera.'**
  String get camFocusLockFailed;

  /// No description provided for @camRecordStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start recording. Try again.'**
  String get camRecordStartFailed;

  /// No description provided for @camRecordStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not stop recording. Try again.'**
  String get camRecordStopFailed;

  /// No description provided for @camNoFrames.
  ///
  /// In en, this message translates to:
  /// **'No video frames were recorded. Try again.'**
  String get camNoFrames;

  /// No description provided for @camPendingNoTags.
  ///
  /// In en, this message translates to:
  /// **'Capture waiting for secure save. Tags were not applied; check Library after recovery.'**
  String get camPendingNoTags;

  /// No description provided for @camSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save capture. Try again.'**
  String get camSaveFailed;

  /// No description provided for @camSavedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} photos securely'**
  String camSavedPhotos(int count);

  /// No description provided for @camSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch camera. Try again.'**
  String get camSwitchFailed;

  /// No description provided for @camMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access in Settings to record video. Photos are still available.'**
  String get camMicDenied;

  /// No description provided for @camVideoStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start video. Check camera and microphone permissions in Settings.'**
  String get camVideoStartFailed;

  /// No description provided for @camSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving securely…'**
  String get camSaving;

  /// No description provided for @camSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved securely'**
  String get camSaved;

  /// No description provided for @camTagsNotApplied.
  ///
  /// In en, this message translates to:
  /// **'Tags were not applied; organize in Library.'**
  String get camTagsNotApplied;

  /// No description provided for @camNotCastReady.
  ///
  /// In en, this message translates to:
  /// **'This video may not play on your TV.'**
  String get camNotCastReady;

  /// No description provided for @camPreview.
  ///
  /// In en, this message translates to:
  /// **'Camera preview'**
  String get camPreview;

  /// No description provided for @camPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to focus. Press and hold to lock focus and exposure.'**
  String get camPreviewHint;

  /// No description provided for @camFocusLocked.
  ///
  /// In en, this message translates to:
  /// **'Focus and exposure locked'**
  String get camFocusLocked;

  /// No description provided for @camRecTimer.
  ///
  /// In en, this message translates to:
  /// **'REC {time}'**
  String camRecTimer(String time);

  /// No description provided for @camStartingVideo.
  ///
  /// In en, this message translates to:
  /// **'Starting video…'**
  String get camStartingVideo;

  /// No description provided for @camCastFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cast. Try again.'**
  String get camCastFailed;

  /// No description provided for @camCasting.
  ///
  /// In en, this message translates to:
  /// **'Casting to {device}'**
  String camCasting(String device);

  /// No description provided for @camChooseTags.
  ///
  /// In en, this message translates to:
  /// **'Choose tags for new captures'**
  String get camChooseTags;

  /// No description provided for @camTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get camTags;

  /// No description provided for @camTagCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String camTagCount(int count);

  /// No description provided for @camFlashOff.
  ///
  /// In en, this message translates to:
  /// **'Flash off'**
  String get camFlashOff;

  /// No description provided for @camFlashAuto.
  ///
  /// In en, this message translates to:
  /// **'Flash automatic'**
  String get camFlashAuto;

  /// No description provided for @camFlashOn.
  ///
  /// In en, this message translates to:
  /// **'Flash on'**
  String get camFlashOn;

  /// No description provided for @camFlashUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This camera has no flash.'**
  String get camFlashUnavailable;

  /// No description provided for @camTimerOff.
  ///
  /// In en, this message translates to:
  /// **'Timer off'**
  String get camTimerOff;

  /// No description provided for @camTimerSeconds.
  ///
  /// In en, this message translates to:
  /// **'Timer {seconds} seconds'**
  String camTimerSeconds(int seconds);

  /// No description provided for @camGridHide.
  ///
  /// In en, this message translates to:
  /// **'Hide grid'**
  String get camGridHide;

  /// No description provided for @camGridShow.
  ///
  /// In en, this message translates to:
  /// **'Show grid'**
  String get camGridShow;

  /// No description provided for @camSwitchRear.
  ///
  /// In en, this message translates to:
  /// **'Switch to rear camera'**
  String get camSwitchRear;

  /// No description provided for @camSwitchFront.
  ///
  /// In en, this message translates to:
  /// **'Switch to front camera'**
  String get camSwitchFront;

  /// No description provided for @camStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get camStopRecording;

  /// No description provided for @camRecordVideo.
  ///
  /// In en, this message translates to:
  /// **'Record video'**
  String get camRecordVideo;

  /// No description provided for @camStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get camStop;

  /// No description provided for @camVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get camVideo;

  /// No description provided for @camTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get camTakePhoto;

  /// No description provided for @camCancelTimer.
  ///
  /// In en, this message translates to:
  /// **'Cancel timer'**
  String get camCancelTimer;

  /// No description provided for @camPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get camPhoto;

  /// No description provided for @camOpenLibrary.
  ///
  /// In en, this message translates to:
  /// **'Open Library'**
  String get camOpenLibrary;

  /// No description provided for @camLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get camLibrary;

  /// No description provided for @camTakeBurst.
  ///
  /// In en, this message translates to:
  /// **'Take {count} photos'**
  String camTakeBurst(int count);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @tagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTitle;

  /// No description provided for @tagsMoments.
  ///
  /// In en, this message translates to:
  /// **'Moments'**
  String get tagsMoments;

  /// No description provided for @tagsSortName.
  ///
  /// In en, this message translates to:
  /// **'Sort by name'**
  String get tagsSortName;

  /// No description provided for @tagsSortCount.
  ///
  /// In en, this message translates to:
  /// **'Sort by most captures'**
  String get tagsSortCount;

  /// No description provided for @tagsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create tag'**
  String get tagsCreate;

  /// No description provided for @tagsFind.
  ///
  /// In en, this message translates to:
  /// **'Find tags'**
  String get tagsFind;

  /// No description provided for @tagsCountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not count captures. Retry'**
  String get tagsCountFailed;

  /// No description provided for @tagsUntagged.
  ///
  /// In en, this message translates to:
  /// **'Untagged'**
  String get tagsUntagged;

  /// No description provided for @tagsCaptureCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 capture} other{{count} captures}}'**
  String tagsCaptureCount(int count);

  /// No description provided for @tagsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching tags'**
  String get tagsNoMatch;

  /// No description provided for @tagsNone.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get tagsNone;

  /// No description provided for @tagsNoMatchHint.
  ///
  /// In en, this message translates to:
  /// **'Try another name or create this one.'**
  String get tagsNoMatchHint;

  /// No description provided for @tagsNoneHint.
  ///
  /// In en, this message translates to:
  /// **'Tags group captures across the Library.'**
  String get tagsNoneHint;

  /// No description provided for @tagsCreateNamed.
  ///
  /// In en, this message translates to:
  /// **'Create \'{name}\''**
  String tagsCreateNamed(String name);

  /// No description provided for @tagsCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'Create first tag'**
  String get tagsCreateFirst;

  /// No description provided for @tagsOptions.
  ///
  /// In en, this message translates to:
  /// **'Tag options'**
  String get tagsOptions;

  /// No description provided for @tagsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get tagsRename;

  /// No description provided for @tagsRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename tag'**
  String get tagsRenameTitle;

  /// No description provided for @tagsSetCover.
  ///
  /// In en, this message translates to:
  /// **'Set cover'**
  String get tagsSetCover;

  /// No description provided for @tagsClearCover.
  ///
  /// In en, this message translates to:
  /// **'Clear cover'**
  String get tagsClearCover;

  /// No description provided for @tagsMergeInto.
  ///
  /// In en, this message translates to:
  /// **'Merge into…'**
  String get tagsMergeInto;

  /// No description provided for @tagsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get tagsDelete;

  /// No description provided for @tagsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete tag?'**
  String get tagsDeleteTitle;

  /// No description provided for @tagsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Remove “{name}” from all captures? Photos and videos stay in your vault.'**
  String tagsDeleteBody(String name);

  /// No description provided for @tagsMergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge tags?'**
  String get tagsMergeTitle;

  /// No description provided for @tagsMergeBody.
  ///
  /// In en, this message translates to:
  /// **'Merge “{source}” into “{target}”? {count, plural, =1{1 capture} other{{count} captures}} will use the remaining tag. The source tag is removed. Photos, videos and other tags stay unchanged.'**
  String tagsMergeBody(String source, String target, int count);

  /// No description provided for @tagsMergeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Merge tags'**
  String get tagsMergeConfirm;

  /// No description provided for @mergeChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose the tag to keep'**
  String get mergeChoose;

  /// No description provided for @mergeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel merge'**
  String get mergeCancel;

  /// No description provided for @mergeFindDestination.
  ///
  /// In en, this message translates to:
  /// **'Find destination tag'**
  String get mergeFindDestination;

  /// No description provided for @libraryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get libraryNameLabel;

  /// No description provided for @librarySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Retry.'**
  String get librarySaveFailed;

  /// No description provided for @libraryUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update private library. Retry.'**
  String get libraryUpdateFailed;

  /// No description provided for @momentsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read captures. Retry'**
  String get momentsLoadFailed;

  /// No description provided for @momentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No dated captures yet'**
  String get momentsEmpty;

  /// No description provided for @viewTitle.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewTitle;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get viewAll;

  /// No description provided for @viewPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get viewPhotos;

  /// No description provided for @viewVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get viewVideos;

  /// No description provided for @viewFavoritesOnly.
  ///
  /// In en, this message translates to:
  /// **'Favorites only'**
  String get viewFavoritesOnly;

  /// No description provided for @viewSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get viewSort;

  /// No description provided for @viewNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get viewNewest;

  /// No description provided for @viewOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get viewOldest;

  /// No description provided for @viewName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get viewName;

  /// No description provided for @viewApply.
  ///
  /// In en, this message translates to:
  /// **'Apply view'**
  String get viewApply;

  /// No description provided for @viewShowCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 capture} other{Show {count} captures}}'**
  String viewShowCount(int count);

  /// No description provided for @viewReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get viewReset;

  /// No description provided for @pickerCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags for new captures'**
  String get pickerCameraTitle;

  /// No description provided for @pickerRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove tags'**
  String get pickerRemoveTitle;

  /// No description provided for @pickerAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add tags'**
  String get pickerAddTitle;

  /// No description provided for @pickerCameraNote.
  ///
  /// In en, this message translates to:
  /// **'Clears on lock or background.'**
  String get pickerCameraNote;

  /// No description provided for @pickerSelectionNote.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 capture} other{{count} captures}} · other tags stay unchanged'**
  String pickerSelectionNote(int count);

  /// No description provided for @pickerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel tag selection'**
  String get pickerCancel;

  /// No description provided for @pickerNoTags.
  ///
  /// In en, this message translates to:
  /// **'No tags'**
  String get pickerNoTags;

  /// No description provided for @pickerAlreadyTagged.
  ///
  /// In en, this message translates to:
  /// **'{tagged} of {total} already tagged'**
  String pickerAlreadyTagged(int tagged, int total);

  /// No description provided for @pickerManage.
  ///
  /// In en, this message translates to:
  /// **'Manage tags'**
  String get pickerManage;

  /// No description provided for @pickerStale.
  ///
  /// In en, this message translates to:
  /// **'A selected tag changed. Review your selection.'**
  String get pickerStale;

  /// No description provided for @pickerReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get pickerReview;

  /// No description provided for @pickerUse.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Use 1 tag} other{Use {count} tags}}'**
  String pickerUse(int count);

  /// No description provided for @pickerAddCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 tag} other{Add {count} tags}}'**
  String pickerAddCount(int count);

  /// No description provided for @pickerRemoveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Remove 1 tag} other{Remove {count} tags}}'**
  String pickerRemoveCount(int count);

  /// No description provided for @galleryActions.
  ///
  /// In en, this message translates to:
  /// **'Library actions'**
  String get galleryActions;

  /// No description provided for @galleryActionsClose.
  ///
  /// In en, this message translates to:
  /// **'Close Library actions'**
  String get galleryActionsClose;

  /// No description provided for @gallerySelectCaptures.
  ///
  /// In en, this message translates to:
  /// **'Select captures'**
  String get gallerySelectCaptures;

  /// No description provided for @gallerySearchEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit search'**
  String get gallerySearchEdit;

  /// No description provided for @gallerySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search names and tags'**
  String get gallerySearchHint;

  /// No description provided for @galleryRemovedTag.
  ///
  /// In en, this message translates to:
  /// **'Removed tag'**
  String get galleryRemovedTag;

  /// No description provided for @galleryScopeAny.
  ///
  /// In en, this message translates to:
  /// **'All Library · Match any tag'**
  String get galleryScopeAny;

  /// No description provided for @galleryScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All Library · Match all tags'**
  String get galleryScopeAll;

  /// No description provided for @gallerySortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest captures'**
  String get gallerySortNewest;

  /// No description provided for @gallerySortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest captures'**
  String get gallerySortOldest;

  /// No description provided for @gallerySortName.
  ///
  /// In en, this message translates to:
  /// **'Name order'**
  String get gallerySortName;

  /// No description provided for @galleryTagMatching.
  ///
  /// In en, this message translates to:
  /// **'Tag matching'**
  String get galleryTagMatching;

  /// No description provided for @galleryMatchAll.
  ///
  /// In en, this message translates to:
  /// **'Match all tags'**
  String get galleryMatchAll;

  /// No description provided for @galleryMatchAny.
  ///
  /// In en, this message translates to:
  /// **'Match any tag'**
  String get galleryMatchAny;

  /// No description provided for @galleryFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get galleryFavorites;

  /// No description provided for @galleryResetView.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get galleryResetView;

  /// No description provided for @galleryAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get galleryAddTag;

  /// No description provided for @galleryAddTagHint.
  ///
  /// In en, this message translates to:
  /// **'Choose existing tags, or search names with the text above.'**
  String get galleryAddTagHint;

  /// No description provided for @galleryCancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get galleryCancelSelection;

  /// No description provided for @gallerySelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String gallerySelectedCount(int count);

  /// No description provided for @gallerySelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all results'**
  String get gallerySelectAll;

  /// No description provided for @galleryShareCopies.
  ///
  /// In en, this message translates to:
  /// **'Share copies'**
  String get galleryShareCopies;

  /// No description provided for @galleryUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get galleryUnfavorite;

  /// No description provided for @galleryFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get galleryFavorite;

  /// No description provided for @galleryNameCapture.
  ///
  /// In en, this message translates to:
  /// **'Name capture'**
  String get galleryNameCapture;

  /// No description provided for @galleryNasReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read saved NAS details. Try again.'**
  String get galleryNasReadFailed;

  /// No description provided for @galleryImportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import copies from Files'**
  String get galleryImportTooltip;

  /// No description provided for @gallerySyncCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel sync'**
  String get gallerySyncCancel;

  /// No description provided for @gallerySyncSetup.
  ///
  /// In en, this message translates to:
  /// **'Set up backup'**
  String get gallerySyncSetup;

  /// No description provided for @gallerySyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync with NAS'**
  String get gallerySyncNow;

  /// No description provided for @galleryCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get galleryCloseSearch;

  /// No description provided for @gallerySearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get gallerySearchTitle;

  /// No description provided for @gallerySettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get gallerySettings;

  /// No description provided for @galleryOrgUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Organization unavailable. Originals are safe. Retry'**
  String get galleryOrgUnavailable;

  /// No description provided for @galleryOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open vault. Retry'**
  String get galleryOpenFailed;

  /// No description provided for @galleryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library starts here'**
  String get galleryEmptyTitle;

  /// No description provided for @galleryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Take a photo or import copies from Files.'**
  String get galleryEmptyMessage;

  /// No description provided for @galleryOpenCamera.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get galleryOpenCamera;

  /// No description provided for @galleryImportCopies.
  ///
  /// In en, this message translates to:
  /// **'Import copies'**
  String get galleryImportCopies;

  /// No description provided for @galleryNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No captures match'**
  String get galleryNoMatchTitle;

  /// No description provided for @galleryNoMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Clear your search and filters to see all captures.'**
  String get galleryNoMatchMessage;

  /// No description provided for @galleryClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear search and filters'**
  String get galleryClearFilters;

  /// No description provided for @galleryTileSelect.
  ///
  /// In en, this message translates to:
  /// **'Select {label}'**
  String galleryTileSelect(String label);

  /// No description provided for @galleryTileOpen.
  ///
  /// In en, this message translates to:
  /// **'Open {label}'**
  String galleryTileOpen(String label);

  /// No description provided for @galleryTileFavorite.
  ///
  /// In en, this message translates to:
  /// **'favorite'**
  String get galleryTileFavorite;

  /// No description provided for @galleryTilePosition.
  ///
  /// In en, this message translates to:
  /// **'{position} of {total}'**
  String galleryTilePosition(int position, int total);

  /// No description provided for @galleryTileDuration.
  ///
  /// In en, this message translates to:
  /// **'duration {time}'**
  String galleryTileDuration(String time);

  /// No description provided for @galleryPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get galleryPreviewUnavailable;

  /// No description provided for @importIntro.
  ///
  /// In en, this message translates to:
  /// **'Copy photos and videos from Files into your Library. Originals stay unchanged, including location and other metadata. Nothing is deleted or shared.'**
  String get importIntro;

  /// No description provided for @importChooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get importChooseFiles;

  /// No description provided for @importChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get importChooseFolder;

  /// No description provided for @importSubfolders.
  ///
  /// In en, this message translates to:
  /// **'Include subfolders'**
  String get importSubfolders;

  /// No description provided for @importSubfoldersBody.
  ///
  /// In en, this message translates to:
  /// **'Also reads photos and videos in folders inside the chosen one.'**
  String get importSubfoldersBody;

  /// No description provided for @importOpenShare.
  ///
  /// In en, this message translates to:
  /// **'Open encrypted share'**
  String get importOpenShare;

  /// No description provided for @importSharePassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Passphrase for this share'**
  String get importSharePassphraseTitle;

  /// No description provided for @importSharePassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get importSharePassphraseLabel;

  /// No description provided for @importShareOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get importShareOpenButton;

  /// No description provided for @importShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the share. Check the passphrase and the file.'**
  String get importShareFailed;

  /// No description provided for @importSupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Supported files and limits'**
  String get importSupportedTitle;

  /// No description provided for @importSupportedBody.
  ///
  /// In en, this message translates to:
  /// **'JPEG, PNG or playable MP4. Up to 20 files and 512 MiB total; photos up to 32 MiB and 64 MP. A folder imports its files (not subfolders), up to 10,000, 20 at a time; choose the same folder again to resume. TV playback depends on codecs. Imports use the date added. Selected copies may finish encrypting while Quietake is locked. An encrypted share (.quietake-share) opens with its passphrase; its photos and videos then import like other files.'**
  String get importSupportedBody;

  /// No description provided for @importCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling after current file…'**
  String get importCancelling;

  /// No description provided for @importCancelRemaining.
  ///
  /// In en, this message translates to:
  /// **'Cancel remaining'**
  String get importCancelRemaining;

  /// No description provided for @importFolderCount.
  ///
  /// In en, this message translates to:
  /// **'{handled} of {total} files'**
  String importFolderCount(int handled, int total);

  /// No description provided for @importBusyPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous import is finishing. Try again shortly.'**
  String get importBusyPrevious;

  /// No description provided for @importOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open import. Check storage and try again.'**
  String get importOpenFailed;

  /// No description provided for @importStoppedEarly.
  ///
  /// In en, this message translates to:
  /// **'Import stopped early. Copies listed as imported are saved.'**
  String get importStoppedEarly;

  /// No description provided for @importCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Temporary cleanup failed. Restart Quietake before trying again.'**
  String get importCleanupFailed;

  /// No description provided for @importFolderStopped.
  ///
  /// In en, this message translates to:
  /// **'Folder import stopped. Choose the folder again to continue; finished files are saved.'**
  String get importFolderStopped;

  /// No description provided for @importImported.
  ///
  /// In en, this message translates to:
  /// **'{count} imported'**
  String importImported(int count);

  /// No description provided for @importDuplicates.
  ///
  /// In en, this message translates to:
  /// **'{count} duplicates skipped'**
  String importDuplicates(int count);

  /// No description provided for @importAlreadyDone.
  ///
  /// In en, this message translates to:
  /// **'{count} already imported earlier'**
  String importAlreadyDone(int count);

  /// No description provided for @importFailedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String importFailedCount(int count);

  /// No description provided for @importNotStarted.
  ///
  /// In en, this message translates to:
  /// **'{count} not started'**
  String importNotStarted(int count);

  /// No description provided for @importSummaryEnd.
  ///
  /// In en, this message translates to:
  /// **'{summary}.'**
  String importSummaryEnd(String summary);

  /// No description provided for @importSummaryContinue.
  ///
  /// In en, this message translates to:
  /// **'{summary}. Choose the same folder again to continue.'**
  String importSummaryContinue(String summary);

  /// No description provided for @shareTitleOne.
  ///
  /// In en, this message translates to:
  /// **'Share a copy?'**
  String get shareTitleOne;

  /// No description provided for @shareTitleMany.
  ///
  /// In en, this message translates to:
  /// **'Share {count} copies?'**
  String shareTitleMany(int count);

  /// No description provided for @shareWarning.
  ///
  /// In en, this message translates to:
  /// **'The app you choose receives unencrypted copies and may keep them.'**
  String get shareWarning;

  /// No description provided for @shareStripTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove metadata from JPEG photo copies'**
  String get shareStripTitle;

  /// No description provided for @shareStripOn.
  ///
  /// In en, this message translates to:
  /// **'JPEG copies keep only their orientation: location, camera, time, comments and thumbnails are removed. PNG and video copies stay unchanged.'**
  String get shareStripOn;

  /// No description provided for @shareStripOff.
  ///
  /// In en, this message translates to:
  /// **'Copies keep all original metadata, including location if present.'**
  String get shareStripOff;

  /// No description provided for @shareLimits.
  ///
  /// In en, this message translates to:
  /// **'Up to {items} captures and {mib} MiB per batch.'**
  String shareLimits(int items, int mib);

  /// No description provided for @shareProgress.
  ///
  /// In en, this message translates to:
  /// **'Preparing {prepared} of {total}'**
  String shareProgress(int prepared, int total);

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share. Another share may still be finishing. Try again.'**
  String get shareFailed;

  /// No description provided for @shareChooseApp.
  ///
  /// In en, this message translates to:
  /// **'Choose app'**
  String get shareChooseApp;

  /// No description provided for @viewerShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share. Please try again.'**
  String get viewerShareFailed;

  /// No description provided for @viewerDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get viewerDetails;

  /// No description provided for @viewerType.
  ///
  /// In en, this message translates to:
  /// **'Type: {kind}'**
  String viewerType(String kind);

  /// No description provided for @viewerCaptured.
  ///
  /// In en, this message translates to:
  /// **'Captured: {when}'**
  String viewerCaptured(String when);

  /// No description provided for @viewerUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get viewerUnknown;

  /// No description provided for @viewerTags.
  ///
  /// In en, this message translates to:
  /// **'Tags: {tags}'**
  String viewerTags(String tags);

  /// No description provided for @viewerNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get viewerNone;

  /// No description provided for @viewerSize.
  ///
  /// In en, this message translates to:
  /// **'Encrypted size: {bytes} bytes'**
  String viewerSize(int bytes);

  /// No description provided for @viewerSizeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Encrypted size: unavailable'**
  String get viewerSizeUnavailable;

  /// No description provided for @viewerClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get viewerClose;

  /// No description provided for @viewerSetCover.
  ///
  /// In en, this message translates to:
  /// **'Use as cover of {tag}'**
  String viewerSetCover(String tag);

  /// No description provided for @viewerCoverSet.
  ///
  /// In en, this message translates to:
  /// **'Cover of {tag} updated.'**
  String viewerCoverSet(String tag);

  /// No description provided for @viewerDeletePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get viewerDeletePhotoTitle;

  /// No description provided for @viewerDeleteVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this video?'**
  String get viewerDeleteVideoTitle;

  /// No description provided for @viewerDeleteKeepNas.
  ///
  /// In en, this message translates to:
  /// **'Recently deleted keeps it on this phone, encrypted, for {days} days so you can restore it. Your NAS copy stays until then. Delete now removes it from this phone and your configured NAS permanently.'**
  String viewerDeleteKeepNas(int days);

  /// No description provided for @viewerDeleteKeep.
  ///
  /// In en, this message translates to:
  /// **'Recently deleted keeps it on this phone, encrypted, for {days} days so you can restore it. Delete now removes it from this phone permanently.'**
  String viewerDeleteKeep(int days);

  /// No description provided for @viewerDeleteNasNow.
  ///
  /// In en, this message translates to:
  /// **'It will be permanently removed from this phone and your configured NAS.'**
  String get viewerDeleteNasNow;

  /// No description provided for @viewerDeleteNow.
  ///
  /// In en, this message translates to:
  /// **'It will be permanently removed from this phone.'**
  String get viewerDeleteNow;

  /// No description provided for @viewerDeleteNasTail.
  ///
  /// In en, this message translates to:
  /// **'If the NAS is unavailable, deletion finishes when sync succeeds.'**
  String get viewerDeleteNasTail;

  /// No description provided for @viewerDeletePendingTail.
  ///
  /// In en, this message translates to:
  /// **'Pending deletions apply if you reconnect a NAS backup.'**
  String get viewerDeletePendingTail;

  /// No description provided for @viewerDeleteEnd.
  ///
  /// In en, this message translates to:
  /// **'Other backups and shared copies are unaffected. Active casting will stop.'**
  String get viewerDeleteEnd;

  /// No description provided for @viewerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get viewerDelete;

  /// No description provided for @viewerRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove favorite'**
  String get viewerRemoveFavorite;

  /// No description provided for @viewerAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add favorite'**
  String get viewerAddFavorite;

  /// No description provided for @viewerSlideshowStart.
  ///
  /// In en, this message translates to:
  /// **'Start slideshow'**
  String get viewerSlideshowStart;

  /// No description provided for @viewerSlideshowStop.
  ///
  /// In en, this message translates to:
  /// **'Stop slideshow'**
  String get viewerSlideshowStop;

  /// No description provided for @viewerShare.
  ///
  /// In en, this message translates to:
  /// **'Share a copy'**
  String get viewerShare;

  /// No description provided for @viewerDeletePhoto.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get viewerDeletePhoto;

  /// No description provided for @viewerDeleteVideo.
  ///
  /// In en, this message translates to:
  /// **'Delete video'**
  String get viewerDeleteVideo;

  /// No description provided for @viewerHideControls.
  ///
  /// In en, this message translates to:
  /// **'Hide controls'**
  String get viewerHideControls;

  /// No description provided for @viewerShowControls.
  ///
  /// In en, this message translates to:
  /// **'Show controls'**
  String get viewerShowControls;

  /// No description provided for @viewerCasting.
  ///
  /// In en, this message translates to:
  /// **'casting to {device}'**
  String viewerCasting(String device);

  /// No description provided for @viewerPhotoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable. Retry'**
  String get viewerPhotoUnavailable;

  /// No description provided for @viewerPrivatePhoto.
  ///
  /// In en, this message translates to:
  /// **'Private photo'**
  String get viewerPrivatePhoto;

  /// No description provided for @viewerResetFit.
  ///
  /// In en, this message translates to:
  /// **'Reset to fit'**
  String get viewerResetFit;

  /// No description provided for @viewerVideoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video unavailable. Retry'**
  String get viewerVideoUnavailable;

  /// No description provided for @viewerReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay video'**
  String get viewerReplay;

  /// No description provided for @viewerPlay.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get viewerPlay;

  /// No description provided for @viewerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause video'**
  String get viewerPause;

  /// No description provided for @viewerVideoPosition.
  ///
  /// In en, this message translates to:
  /// **'Video position'**
  String get viewerVideoPosition;

  /// No description provided for @viewerBack10.
  ///
  /// In en, this message translates to:
  /// **'Back 10 seconds'**
  String get viewerBack10;

  /// No description provided for @viewerForward10.
  ///
  /// In en, this message translates to:
  /// **'Forward 10 seconds'**
  String get viewerForward10;

  /// No description provided for @viewerMute.
  ///
  /// In en, this message translates to:
  /// **'Mute video'**
  String get viewerMute;

  /// No description provided for @viewerUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute video'**
  String get viewerUnmute;

  /// No description provided for @lockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get lockNow;

  /// No description provided for @brandTagline.
  ///
  /// In en, this message translates to:
  /// **'Private camera'**
  String get brandTagline;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Check backup'**
  String get backupTitle;

  /// No description provided for @backupIntro.
  ///
  /// In en, this message translates to:
  /// **'Checks every encrypted file in your saved NAS backup using this vault’s key. Large libraries need time, data and temporary space. This check does not change originals.'**
  String get backupIntro;

  /// No description provided for @backupNeverChecked.
  ///
  /// In en, this message translates to:
  /// **'This backup has never been fully checked. Check it to confirm your copies can be read.'**
  String get backupNeverChecked;

  /// No description provided for @backupStale.
  ///
  /// In en, this message translates to:
  /// **'The last full check was {days, plural, =1{1 day} other{{days} days}} ago. Check again to confirm your copies can still be read.'**
  String backupStale(int days);

  /// No description provided for @backupCancelCheck.
  ///
  /// In en, this message translates to:
  /// **'Cancel check'**
  String get backupCancelCheck;

  /// No description provided for @backupCancelQueued.
  ///
  /// In en, this message translates to:
  /// **'Cancel queued check'**
  String get backupCancelQueued;

  /// No description provided for @backupCheckSaved.
  ///
  /// In en, this message translates to:
  /// **'Check saved backup'**
  String get backupCheckSaved;

  /// No description provided for @backupCheckedAt.
  ///
  /// In en, this message translates to:
  /// **'Checked {date} at {time} · {state}'**
  String backupCheckedAt(String date, String time, String state);

  /// No description provided for @backupUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed since'**
  String get backupUnchanged;

  /// No description provided for @backupChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed since; check again'**
  String get backupChanged;

  /// No description provided for @backupKeepKey.
  ///
  /// In en, this message translates to:
  /// **'Keep your recovery key separately. A successful check does not test the copy of the key you saved elsewhere.'**
  String get backupKeepKey;

  /// No description provided for @backupLeaveNote.
  ///
  /// In en, this message translates to:
  /// **'You can leave this screen while checking. Capture uploads wait for the check to finish. Checks stop if the app process closes.'**
  String get backupLeaveNote;

  /// No description provided for @castSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not search for TVs. Check Wi-Fi and try again.'**
  String get castSearchFailed;

  /// No description provided for @castConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to {device}. Open a capture to cast it.'**
  String castConnected(String device);

  /// No description provided for @castTitle.
  ///
  /// In en, this message translates to:
  /// **'Cast to a TV'**
  String get castTitle;

  /// No description provided for @castClose.
  ///
  /// In en, this message translates to:
  /// **'Close Cast picker'**
  String get castClose;

  /// No description provided for @castUnencrypted.
  ///
  /// In en, this message translates to:
  /// **'Selected media streams unencrypted over your local network while casting.'**
  String get castUnencrypted;

  /// No description provided for @castLooking.
  ///
  /// In en, this message translates to:
  /// **'Looking for TVs on this network'**
  String get castLooking;

  /// No description provided for @castNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No TVs found'**
  String get castNoneFound;

  /// No description provided for @castSameWifi.
  ///
  /// In en, this message translates to:
  /// **'Is the TV on the same Wi-Fi as this phone?'**
  String get castSameWifi;

  /// No description provided for @castRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get castRetry;

  /// No description provided for @castStop.
  ///
  /// In en, this message translates to:
  /// **'Stop casting to {device}'**
  String castStop(String device);

  /// No description provided for @castCancelConnection.
  ///
  /// In en, this message translates to:
  /// **'Cancel connection'**
  String get castCancelConnection;

  /// No description provided for @castToTv.
  ///
  /// In en, this message translates to:
  /// **'Cast to TV'**
  String get castToTv;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsPrivacySection.
  ///
  /// In en, this message translates to:
  /// **'Privacy & access'**
  String get settingsPrivacySection;

  /// No description provided for @settingsIdleLabel.
  ///
  /// In en, this message translates to:
  /// **'Lock after inactivity'**
  String get settingsIdleLabel;

  /// No description provided for @settingsIdleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsIdleOff;

  /// No description provided for @settingsIdleMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute} other{{minutes} minutes}}'**
  String settingsIdleMinutes(int minutes);

  /// No description provided for @settingsIdleNote.
  ///
  /// In en, this message translates to:
  /// **'Recording and video playback delay idle locking. Lock now saves an active recording, pauses playback and stops casting.'**
  String get settingsIdleNote;

  /// No description provided for @settingsScreenshotsIos.
  ///
  /// In en, this message translates to:
  /// **'App-switcher previews are hidden. iOS screenshots cannot be blocked.'**
  String get settingsScreenshotsIos;

  /// No description provided for @settingsScreenshotsAndroid.
  ///
  /// In en, this message translates to:
  /// **'Screenshots, screen recording and app-switcher previews are protected on Android.'**
  String get settingsScreenshotsAndroid;

  /// No description provided for @settingsPrivacySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save privacy settings. Try again.'**
  String get settingsPrivacySaveFailed;

  /// No description provided for @settingsPasscodeChanged.
  ///
  /// In en, this message translates to:
  /// **'Passcode changed'**
  String get settingsPasscodeChanged;

  /// No description provided for @settingsBackupSection.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackupSection;

  /// No description provided for @settingsBackupIntro.
  ///
  /// In en, this message translates to:
  /// **'Optional backup of encrypted media to your own WebDAV share.'**
  String get settingsBackupIntro;

  /// No description provided for @settingsUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'WebDAV folder URL'**
  String get settingsUrlLabel;

  /// No description provided for @settingsUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get settingsUsername;

  /// No description provided for @settingsPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsPassword;

  /// No description provided for @settingsBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up while app is closed'**
  String get settingsBackgroundTitle;

  /// No description provided for @settingsBackgroundBody.
  ///
  /// In en, this message translates to:
  /// **'Android schedules encrypted uploads when network and battery allow. Save and complete one foreground sync first. Force-stop pauses work until you reopen Quietake.'**
  String get settingsBackgroundBody;

  /// No description provided for @settingsMobileTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow mobile data'**
  String get settingsMobileTitle;

  /// No description provided for @settingsMobileBody.
  ///
  /// In en, this message translates to:
  /// **'Off uses unmetered networks only. Large videos can consume substantial data.'**
  String get settingsMobileBody;

  /// No description provided for @settingsBgChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking Android scheduler…'**
  String get settingsBgChecking;

  /// No description provided for @settingsBgScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled when network and battery allow.'**
  String get settingsBgScheduled;

  /// No description provided for @settingsBgUploading.
  ///
  /// In en, this message translates to:
  /// **'Android is uploading encrypted copies.'**
  String get settingsBgUploading;

  /// No description provided for @settingsBgTransferred.
  ///
  /// In en, this message translates to:
  /// **'Last background pass finished. Full backup verification is separate.'**
  String get settingsBgTransferred;

  /// No description provided for @settingsBgReconcile.
  ///
  /// In en, this message translates to:
  /// **'Open the vault and sync to check this backup before background uploads resume.'**
  String get settingsBgReconcile;

  /// No description provided for @settingsBgPending.
  ///
  /// In en, this message translates to:
  /// **'Background backup pending. Android will retry.'**
  String get settingsBgPending;

  /// No description provided for @settingsBgOff.
  ///
  /// In en, this message translates to:
  /// **'Background backup is off or waiting for its first successful sync.'**
  String get settingsBgOff;

  /// No description provided for @settingsBgUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Scheduler unavailable. Foreground sync remains available.'**
  String get settingsBgUnavailable;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save backup settings'**
  String get settingsSave;

  /// No description provided for @settingsTest.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get settingsTest;

  /// No description provided for @settingsTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing connection…'**
  String get settingsTesting;

  /// No description provided for @settingsConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected · {count, plural, =1{1 file} other{{count} files}}'**
  String settingsConnected(int count);

  /// No description provided for @settingsErrHttp.
  ///
  /// In en, this message translates to:
  /// **'Connection failed (HTTP {status}). Check folder URL, username and password.'**
  String settingsErrHttp(int status);

  /// No description provided for @settingsErrReach.
  ///
  /// In en, this message translates to:
  /// **'Could not reach NAS. Check the URL and Wi-Fi.'**
  String get settingsErrReach;

  /// No description provided for @settingsErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check the saved details and try again.'**
  String get settingsErrGeneric;

  /// No description provided for @settingsSaveFirst.
  ///
  /// In en, this message translates to:
  /// **'Save connection changes before checking backup.'**
  String get settingsSaveFirst;

  /// No description provided for @settingsEnterDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter a folder URL, username and password'**
  String get settingsEnterDetails;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save connection details. Try again.'**
  String get settingsSaveFailed;

  /// No description provided for @settingsDisconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not disconnect NAS backup. Try again.'**
  String get settingsDisconnectFailed;

  /// No description provided for @settingsWrongPasscode.
  ///
  /// In en, this message translates to:
  /// **'Wrong passcode. Try again.'**
  String get settingsWrongPasscode;

  /// No description provided for @settingsRecoveryReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the recovery key. Try again.'**
  String get settingsRecoveryReadFailed;

  /// No description provided for @settingsDisconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect NAS backup?'**
  String get settingsDisconnectTitle;

  /// No description provided for @settingsClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear saved NAS details?'**
  String get settingsClearTitle;

  /// No description provided for @settingsDisconnectBody.
  ///
  /// In en, this message translates to:
  /// **'Stops automatic backup and removes saved connection details. Captures stay on your phone and NAS. Pending NAS deletions will not finish until you reconnect that backup.'**
  String get settingsDisconnectBody;

  /// No description provided for @settingsDisconnectAction.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get settingsDisconnectAction;

  /// No description provided for @settingsClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear details'**
  String get settingsClearAction;

  /// No description provided for @settingsDisconnectButton.
  ///
  /// In en, this message translates to:
  /// **'Disconnect NAS backup'**
  String get settingsDisconnectButton;

  /// No description provided for @settingsClearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear saved NAS details'**
  String get settingsClearButton;

  /// No description provided for @settingsRecoverySection.
  ///
  /// In en, this message translates to:
  /// **'Recovery & export'**
  String get settingsRecoverySection;

  /// No description provided for @settingsShowRecovery.
  ///
  /// In en, this message translates to:
  /// **'Show recovery key'**
  String get settingsShowRecovery;

  /// No description provided for @settingsNasPassTitle.
  ///
  /// In en, this message translates to:
  /// **'NAS backup passphrase'**
  String get settingsNasPassTitle;

  /// No description provided for @settingsNasPassBody.
  ///
  /// In en, this message translates to:
  /// **'Enable, change or disable recovery without your recovery key'**
  String get settingsNasPassBody;

  /// No description provided for @settingsPortableTitle.
  ///
  /// In en, this message translates to:
  /// **'Portable encrypted backup'**
  String get settingsPortableTitle;

  /// No description provided for @settingsPortableBody.
  ///
  /// In en, this message translates to:
  /// **'Save a ZIP to Files using your recovery key'**
  String get settingsPortableBody;

  /// No description provided for @settingsCameraSection.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get settingsCameraSection;

  /// No description provided for @settingsBurstLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos in a burst'**
  String get settingsBurstLabel;

  /// No description provided for @settingsBurstHelp.
  ///
  /// In en, this message translates to:
  /// **'Press and hold the shutter.'**
  String get settingsBurstHelp;

  /// No description provided for @settingsBurstChoice.
  ///
  /// In en, this message translates to:
  /// **'{count} photos'**
  String settingsBurstChoice(int count);

  /// No description provided for @settingsStorageSection.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorageSection;

  /// No description provided for @settingsStorageUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Storage could not be read.'**
  String get settingsStorageUnreadable;

  /// No description provided for @settingsStorageCounting.
  ///
  /// In en, this message translates to:
  /// **'Counting captures…'**
  String get settingsStorageCounting;

  /// No description provided for @settingsStorageNone.
  ///
  /// In en, this message translates to:
  /// **'No captures on this phone yet.'**
  String get settingsStorageNone;

  /// No description provided for @settingsStorageSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 capture} other{{count} captures}}, {size} encrypted on this phone.'**
  String settingsStorageSummary(int count, String size);

  /// No description provided for @settingsStorageTrashed.
  ///
  /// In en, this message translates to:
  /// **'{count} in Recently deleted, removed for good after {days} days.'**
  String settingsStorageTrashed(int count, int days);

  /// No description provided for @settingsSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{value} bytes'**
  String settingsSizeBytes(int value);

  /// No description provided for @settingsSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String settingsSizeKb(String value);

  /// No description provided for @settingsSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String settingsSizeMb(String value);

  /// No description provided for @settingsPlainIcon.
  ///
  /// In en, this message translates to:
  /// **'Use a plain icon and name'**
  String get settingsPlainIcon;

  /// No description provided for @settingsPlainIconBody.
  ///
  /// In en, this message translates to:
  /// **'Shows a gray icon named Tools instead of Quietake. The app may close for a moment when you switch. This does not hide Quietake from the app list or system settings.'**
  String get settingsPlainIconBody;

  /// No description provided for @settingsPlainIconBodyIos.
  ///
  /// In en, this message translates to:
  /// **'Shows a different gray icon. The name stays Quietake, and iOS shows a notice when the icon changes. This does not hide Quietake from the app list or system settings.'**
  String get settingsPlainIconBodyIos;

  /// No description provided for @settingsPlainIconFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the app icon.'**
  String get settingsPlainIconFailed;

  /// No description provided for @settingsKeepDeleted.
  ///
  /// In en, this message translates to:
  /// **'Keep deleted captures for 30 days'**
  String get settingsKeepDeleted;

  /// No description provided for @settingsKeepDeletedBody.
  ///
  /// In en, this message translates to:
  /// **'Delete moves a capture to Recently deleted first. It stays encrypted.'**
  String get settingsKeepDeletedBody;

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get settingsLicenses;

  /// No description provided for @settingsShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get settingsShow;

  /// No description provided for @portableTitleRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore encrypted backup'**
  String get portableTitleRestore;

  /// No description provided for @portableTitleExport.
  ///
  /// In en, this message translates to:
  /// **'Portable backup'**
  String get portableTitleExport;

  /// No description provided for @portableIntroRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore only into a fresh empty vault. Your recovery key opens the ZIP and encrypted captures. Existing libraries cannot be merged.'**
  String get portableIntroRestore;

  /// No description provided for @portableIntroExport.
  ///
  /// In en, this message translates to:
  /// **'Save an encrypted ZIP of captures and organization. Your existing recovery key opens it; keep that key separately. No credentials or keyfiles are included.'**
  String get portableIntroExport;

  /// No description provided for @portableChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose backup ZIP'**
  String get portableChoose;

  /// No description provided for @portableCheckOnly.
  ///
  /// In en, this message translates to:
  /// **'Check backup only'**
  String get portableCheckOnly;

  /// No description provided for @portableRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore empty vault'**
  String get portableRestoreButton;

  /// No description provided for @portableCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create encrypted ZIP'**
  String get portableCreateButton;

  /// No description provided for @portableLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup limits and storage'**
  String get portableLimitsTitle;

  /// No description provided for @portableLimitsBody.
  ///
  /// In en, this message translates to:
  /// **'Up to 10,000 captures and 2 GiB per ZIP. Preparation needs private temporary storage. Vault originals stay unchanged. No credentials or keyfiles are included.'**
  String get portableLimitsBody;

  /// No description provided for @portableCancelPrep.
  ///
  /// In en, this message translates to:
  /// **'Cancel preparation'**
  String get portableCancelPrep;

  /// No description provided for @portablePicking.
  ///
  /// In en, this message translates to:
  /// **'Choose an encrypted ZIP in Files.'**
  String get portablePicking;

  /// No description provided for @portablePickCancelled.
  ///
  /// In en, this message translates to:
  /// **'Selection cancelled.'**
  String get portablePickCancelled;

  /// No description provided for @portablePicked.
  ///
  /// In en, this message translates to:
  /// **'Backup selected. Enter its recovery key and a new passcode.'**
  String get portablePicked;

  /// No description provided for @portableCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy backup. Check storage and try again.'**
  String get portableCopyFailed;

  /// No description provided for @portableStillFinishing.
  ///
  /// In en, this message translates to:
  /// **'Previous backup is finishing. Try again shortly.'**
  String get portableStillFinishing;

  /// No description provided for @portableNeedKey.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup and enter its recovery key.'**
  String get portableNeedKey;

  /// No description provided for @portableNeedPasscode.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup and confirm a passcode of at least six characters.'**
  String get portableNeedPasscode;

  /// No description provided for @portablePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing encrypted backup…'**
  String get portablePreparing;

  /// No description provided for @portableChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking encrypted files: {done} of {total}…'**
  String portableChecking(int done, int total);

  /// No description provided for @portableChecked.
  ///
  /// In en, this message translates to:
  /// **'Backup checked: every encrypted file and the catalog authenticate with this key. Nothing was restored. Choose the file again to restore it.'**
  String get portableChecked;

  /// No description provided for @portableRestored.
  ///
  /// In en, this message translates to:
  /// **'Vault restored. Use your new passcode once to enable biometric unlock.'**
  String get portableRestored;

  /// No description provided for @portableExporting.
  ///
  /// In en, this message translates to:
  /// **'Preparing encrypted files: {done} of {total}…'**
  String portableExporting(int done, int total);

  /// No description provided for @portableSaved.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup saved. Keep its recovery key separately.'**
  String get portableSaved;

  /// No description provided for @portableSaveCancelled.
  ///
  /// In en, this message translates to:
  /// **'Save cancelled. Vault originals kept.'**
  String get portableSaveCancelled;

  /// No description provided for @portableBadKey.
  ///
  /// In en, this message translates to:
  /// **'Enter the recovery key saved for this backup.'**
  String get portableBadKey;

  /// No description provided for @portableCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled. Vault originals kept.'**
  String get portableCancelled;

  /// No description provided for @portableFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore or save backup. Check its key, file, available storage and empty-vault requirement.'**
  String get portableFailed;

  /// No description provided for @nasTitleRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from NAS'**
  String get nasTitleRestore;

  /// No description provided for @nasTitleManage.
  ///
  /// In en, this message translates to:
  /// **'Backup passphrase'**
  String get nasTitleManage;

  /// No description provided for @nasIntroRestore.
  ///
  /// In en, this message translates to:
  /// **'Use the separate backup passphrase previously enabled on your NAS. The short phone passcode cannot recover this backup. Restore authenticates all files into an empty vault; no merge. Your NAS stays read-only.'**
  String get nasIntroRestore;

  /// No description provided for @nasIntroManage.
  ///
  /// In en, this message translates to:
  /// **'Protect NAS recovery with a separate strong passphrase. Anyone with the encrypted file can try guesses offline. Prefer six random words; length alone does not prove strength. Complete a saved NAS sync first. The NAS must support safe file locking; otherwise nothing is written.'**
  String get nasIntroManage;

  /// No description provided for @nasUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'HTTPS WebDAV folder URL'**
  String get nasUrlLabel;

  /// No description provided for @nasUserLabel.
  ///
  /// In en, this message translates to:
  /// **'NAS username'**
  String get nasUserLabel;

  /// No description provided for @nasPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'NAS password'**
  String get nasPasswordLabel;

  /// No description provided for @nasPinNew.
  ///
  /// In en, this message translates to:
  /// **'New local passcode'**
  String get nasPinNew;

  /// No description provided for @nasPinCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current local passcode'**
  String get nasPinCurrent;

  /// No description provided for @nasPinConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm new local passcode'**
  String get nasPinConfirm;

  /// No description provided for @nasPhraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup passphrase'**
  String get nasPhraseLabel;

  /// No description provided for @nasPhraseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm backup passphrase'**
  String get nasPhraseConfirm;

  /// No description provided for @nasGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate six words'**
  String get nasGenerate;

  /// No description provided for @nasHide.
  ///
  /// In en, this message translates to:
  /// **'Hide passphrase'**
  String get nasHide;

  /// No description provided for @nasShow.
  ///
  /// In en, this message translates to:
  /// **'Show passphrase'**
  String get nasShow;

  /// No description provided for @nasWordsCredit.
  ///
  /// In en, this message translates to:
  /// **'Words: Electronic Frontier Foundation · CC BY 4.0'**
  String get nasWordsCredit;

  /// No description provided for @nasWordLicenses.
  ///
  /// In en, this message translates to:
  /// **'Word-list licenses'**
  String get nasWordLicenses;

  /// No description provided for @nasEnableButton.
  ///
  /// In en, this message translates to:
  /// **'Enable or change passphrase'**
  String get nasEnableButton;

  /// No description provided for @nasDisableButton.
  ///
  /// In en, this message translates to:
  /// **'Disable passphrase recovery'**
  String get nasDisableButton;

  /// No description provided for @nasFootRestore.
  ///
  /// In en, this message translates to:
  /// **'Up to 10,000 captures. Private temporary space is needed. Unlock with your new passcode afterward. Background upload stays off.'**
  String get nasFootRestore;

  /// No description provided for @nasFootManage.
  ///
  /// In en, this message translates to:
  /// **'This changes recovery protection only. It never changes your phone passcode or re-encrypts captures. Removing current recovery does not revoke old server snapshots.'**
  String get nasFootManage;

  /// No description provided for @nasGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not generate a passphrase. Try again.'**
  String get nasGenerateFailed;

  /// No description provided for @nasConfirmDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable passphrase recovery?'**
  String get nasConfirmDisableTitle;

  /// No description provided for @nasConfirmSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save backup passphrase?'**
  String get nasConfirmSaveTitle;

  /// No description provided for @nasConfirmDisableBody.
  ///
  /// In en, this message translates to:
  /// **'Removes the current recovery file from the saved NAS folder. Captures stay. Old server snapshots may still accept an earlier passphrase. Keep your independent recovery key.'**
  String get nasConfirmDisableBody;

  /// No description provided for @nasConfirmSaveBody.
  ///
  /// In en, this message translates to:
  /// **'Creates or replaces recovery in the saved NAS folder. Save the new passphrase separately. Old server snapshots may still accept an earlier passphrase; this does not rotate your vault key.'**
  String get nasConfirmSaveBody;

  /// No description provided for @nasDisableAction.
  ///
  /// In en, this message translates to:
  /// **'Disable recovery'**
  String get nasDisableAction;

  /// No description provided for @nasSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save passphrase'**
  String get nasSaveAction;

  /// No description provided for @nasSeparatePhrase.
  ///
  /// In en, this message translates to:
  /// **'Use a separate backup passphrase, not your local passcode.'**
  String get nasSeparatePhrase;

  /// No description provided for @nasNeedPasscode.
  ///
  /// In en, this message translates to:
  /// **'Choose and confirm a new passcode of at least six characters.'**
  String get nasNeedPasscode;

  /// No description provided for @nasNeedDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter your saved NAS folder, username and password.'**
  String get nasNeedDetails;

  /// No description provided for @nasMismatch.
  ///
  /// In en, this message translates to:
  /// **'Backup passphrases do not match.'**
  String get nasMismatch;

  /// No description provided for @nasCheckingRestore.
  ///
  /// In en, this message translates to:
  /// **'Checking encrypted NAS backup…'**
  String get nasCheckingRestore;

  /// No description provided for @nasCheckingSaved.
  ///
  /// In en, this message translates to:
  /// **'Checking saved NAS recovery…'**
  String get nasCheckingSaved;

  /// No description provided for @nasRestoredTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault restored'**
  String get nasRestoredTitle;

  /// No description provided for @nasRestoredUnsaved.
  ///
  /// In en, this message translates to:
  /// **'The NAS connection could not be saved. Your captures are restored; add the connection again in Settings to resume backups.'**
  String get nasRestoredUnsaved;

  /// No description provided for @nasContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get nasContinue;

  /// No description provided for @nasDisabledDone.
  ///
  /// In en, this message translates to:
  /// **'Passphrase recovery disabled. Captures kept.'**
  String get nasDisabledDone;

  /// No description provided for @nasSavedDone.
  ///
  /// In en, this message translates to:
  /// **'Backup passphrase saved. Keep it and your recovery key separately.'**
  String get nasSavedDone;

  /// No description provided for @nasWrongCurrent.
  ///
  /// In en, this message translates to:
  /// **'Wrong current passcode. Try again.'**
  String get nasWrongCurrent;

  /// No description provided for @nasCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled. Originals kept.'**
  String get nasCancelled;

  /// No description provided for @nasRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore. Check the NAS connection, backup passphrase and empty-vault requirement. Originals kept.'**
  String get nasRestoreFailed;

  /// No description provided for @nasChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change recovery. Check saved NAS backup, supported recovery file and server compatibility. Sync first, then retry. Originals kept.'**
  String get nasChangeFailed;

  /// No description provided for @coverChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose cover'**
  String get coverChooseTitle;

  /// No description provided for @coverEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tag some captures first, then choose one as the cover.'**
  String get coverEmpty;

  /// No description provided for @coverUse.
  ///
  /// In en, this message translates to:
  /// **'Use this capture as the cover'**
  String get coverUse;

  /// No description provided for @restoreGateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish interrupted backup restore. Prepared encrypted files are preserved. Check available storage, then try again.'**
  String get restoreGateFailed;

  /// No description provided for @restoreGateRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry restore'**
  String get restoreGateRetry;

  /// No description provided for @settingsCheckRecovery.
  ///
  /// In en, this message translates to:
  /// **'Check my recovery key'**
  String get settingsCheckRecovery;

  /// No description provided for @recoveryCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Check recovery key'**
  String get recoveryCheckTitle;

  /// No description provided for @recoveryCheckIntro.
  ///
  /// In en, this message translates to:
  /// **'Type the recovery key you saved elsewhere. It is compared on this phone and never stored.'**
  String get recoveryCheckIntro;

  /// No description provided for @recoveryCheckAction.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get recoveryCheckAction;

  /// No description provided for @recoveryCheckClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get recoveryCheckClose;

  /// No description provided for @recoveryCheckNever.
  ///
  /// In en, this message translates to:
  /// **'Never checked.'**
  String get recoveryCheckNever;

  /// No description provided for @recoveryCheckLast.
  ///
  /// In en, this message translates to:
  /// **'Last matched {date}.'**
  String recoveryCheckLast(String date);

  /// No description provided for @recoveryCheckDue.
  ///
  /// In en, this message translates to:
  /// **'Last matched {date}. Check again every few months.'**
  String recoveryCheckDue(String date);

  /// No description provided for @recoveryCheckMatch.
  ///
  /// In en, this message translates to:
  /// **'This matches your vault\'s recovery key.'**
  String get recoveryCheckMatch;

  /// No description provided for @recoveryCheckMismatch.
  ///
  /// In en, this message translates to:
  /// **'This key does not match this vault. Check where you saved it, then try again.'**
  String get recoveryCheckMismatch;

  /// No description provided for @recoveryCheckInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid recovery key. Check for missing or extra characters.'**
  String get recoveryCheckInvalid;

  /// No description provided for @redactTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide parts of the photo'**
  String get redactTitle;

  /// No description provided for @redactUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo last area'**
  String get redactUndo;

  /// No description provided for @redactDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get redactDone;

  /// No description provided for @redactStatus.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Drag over the photo to hide an area.} =1{1 area will be hidden.} other{{count} areas will be hidden.}}'**
  String redactStatus(int count);

  /// No description provided for @redactFailed.
  ///
  /// In en, this message translates to:
  /// **'This photo could not be opened for editing.'**
  String get redactFailed;

  /// No description provided for @shareRedactButton.
  ///
  /// In en, this message translates to:
  /// **'Hide parts of this photo…'**
  String get shareRedactButton;

  /// No description provided for @shareRedactEdit.
  ///
  /// In en, this message translates to:
  /// **'Hidden areas: {count}. Change…'**
  String shareRedactEdit(int count);

  /// No description provided for @shareRedactNote.
  ///
  /// In en, this message translates to:
  /// **'The shared copy becomes a PNG with those areas pixelated and no metadata. The original stays unchanged in your vault.'**
  String get shareRedactNote;

  /// No description provided for @shareRedactButtonMany.
  ///
  /// In en, this message translates to:
  /// **'Hide parts of these photos…'**
  String get shareRedactButtonMany;

  /// No description provided for @shareRedactEditMany.
  ///
  /// In en, this message translates to:
  /// **'Hidden areas: {areas} in {photos, plural, =1{1 photo} other{{photos} photos}}. Change…'**
  String shareRedactEditMany(int areas, int photos);

  /// No description provided for @shareRedactNoteMany.
  ///
  /// In en, this message translates to:
  /// **'Photos with hidden areas are shared as PNG copies with those areas pixelated and no metadata. The originals stay unchanged in your vault.'**
  String get shareRedactNoteMany;

  /// No description provided for @redactCell.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}'**
  String redactCell(int row, int column);

  /// No description provided for @redactSections.
  ///
  /// In en, this message translates to:
  /// **'Or hide a section of the photo'**
  String get redactSections;

  /// No description provided for @settingsRenameRemote.
  ///
  /// In en, this message translates to:
  /// **'Give NAS files random names'**
  String get settingsRenameRemote;

  /// No description provided for @settingsRenameRemoteNone.
  ///
  /// In en, this message translates to:
  /// **'No files on the NAS need new names.'**
  String get settingsRenameRemoteNone;

  /// No description provided for @settingsRenameRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename files on the NAS?'**
  String get settingsRenameRemoteTitle;

  /// Confirmation before renaming NAS files; count is the number of files.
  ///
  /// In en, this message translates to:
  /// **'{count} encrypted files on the NAS get random names, so their names and times no longer show there. Update Quietake on every other phone first: older versions cannot find renamed files. Your originals stay on this phone.'**
  String settingsRenameRemoteBody(int count);

  /// No description provided for @settingsRenameRemoteAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get settingsRenameRemoteAction;

  /// Result after renaming NAS files.
  ///
  /// In en, this message translates to:
  /// **'Renamed {count} files on the NAS.'**
  String settingsRenameRemoteDone(int count);

  /// No description provided for @settingsRenameRemoteFailed.
  ///
  /// In en, this message translates to:
  /// **'Renaming stopped. Run it again to continue. Nothing was lost.'**
  String get settingsRenameRemoteFailed;

  /// No description provided for @shareEncryptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypt with a passphrase'**
  String get shareEncryptedTitle;

  /// No description provided for @shareEncryptedBody.
  ///
  /// In en, this message translates to:
  /// **'The copies go into one file that only a passphrase opens. Quietake shows the passphrase once. Send it by a different route than the file.'**
  String get shareEncryptedBody;

  /// No description provided for @sharePassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Passphrase for this share'**
  String get sharePassphraseTitle;

  /// No description provided for @sharePassphraseBody.
  ///
  /// In en, this message translates to:
  /// **'Write it down or send it separately now. Quietake does not keep it and cannot show it again.'**
  String get sharePassphraseBody;

  /// No description provided for @sharePassphraseContinue.
  ///
  /// In en, this message translates to:
  /// **'Choose app'**
  String get sharePassphraseContinue;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
