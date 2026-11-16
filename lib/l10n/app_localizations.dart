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
