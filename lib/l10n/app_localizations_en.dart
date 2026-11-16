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

  @override
  String get pickerCameraTitle => 'Tags for new captures';

  @override
  String get pickerRemoveTitle => 'Remove tags';

  @override
  String get pickerAddTitle => 'Add tags';

  @override
  String get pickerCameraNote => 'Clears on lock or background.';

  @override
  String pickerSelectionNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures',
      one: '1 capture',
    );
    return '$_temp0 · other tags stay unchanged';
  }

  @override
  String get pickerCancel => 'Cancel tag selection';

  @override
  String get pickerNoTags => 'No tags';

  @override
  String pickerAlreadyTagged(int tagged, int total) {
    return '$tagged of $total already tagged';
  }

  @override
  String get pickerManage => 'Manage tags';

  @override
  String get pickerStale => 'A selected tag changed. Review your selection.';

  @override
  String get pickerReview => 'Review';

  @override
  String pickerUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Use $count tags',
      one: 'Use 1 tag',
    );
    return '$_temp0';
  }

  @override
  String pickerAddCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count tags',
      one: 'Add 1 tag',
    );
    return '$_temp0';
  }

  @override
  String pickerRemoveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count tags',
      one: 'Remove 1 tag',
    );
    return '$_temp0';
  }

  @override
  String get galleryActions => 'Library actions';

  @override
  String get galleryActionsClose => 'Close Library actions';

  @override
  String get gallerySelectCaptures => 'Select captures';

  @override
  String get gallerySearchEdit => 'Edit search';

  @override
  String get gallerySearchHint => 'Search names and tags';

  @override
  String get galleryRemovedTag => 'Removed tag';

  @override
  String get galleryScopeAny => 'All Library · Match any tag';

  @override
  String get galleryScopeAll => 'All Library · Match all tags';

  @override
  String get gallerySortNewest => 'Newest captures';

  @override
  String get gallerySortOldest => 'Oldest captures';

  @override
  String get gallerySortName => 'Name order';

  @override
  String get galleryTagMatching => 'Tag matching';

  @override
  String get galleryMatchAll => 'Match all tags';

  @override
  String get galleryMatchAny => 'Match any tag';

  @override
  String get galleryFavorites => 'Favorites';

  @override
  String get galleryResetView => 'Reset view';

  @override
  String get galleryAddTag => 'Add a tag';

  @override
  String get galleryAddTagHint =>
      'Choose existing tags, or search names with the text above.';

  @override
  String get galleryCancelSelection => 'Cancel selection';

  @override
  String gallerySelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get gallerySelectAll => 'Select all results';

  @override
  String get galleryShareCopies => 'Share copies';

  @override
  String get galleryUnfavorite => 'Unfavorite';

  @override
  String get galleryFavorite => 'Favorite';

  @override
  String get galleryNameCapture => 'Name capture';

  @override
  String get galleryNasReadFailed =>
      'Could not read saved NAS details. Try again.';

  @override
  String get galleryImportTooltip => 'Import copies from Files';

  @override
  String get gallerySyncCancel => 'Cancel sync';

  @override
  String get gallerySyncSetup => 'Set up backup';

  @override
  String get gallerySyncNow => 'Sync with NAS';

  @override
  String get galleryCloseSearch => 'Close search';

  @override
  String get gallerySearchTitle => 'Search';

  @override
  String get gallerySettings => 'Settings';

  @override
  String get galleryOrgUnavailable =>
      'Organization unavailable. Originals are safe. Retry';

  @override
  String get galleryOpenFailed => 'Could not open vault. Retry';

  @override
  String get galleryEmptyTitle => 'Your library starts here';

  @override
  String get galleryEmptyMessage => 'Take a photo or import copies from Files.';

  @override
  String get galleryOpenCamera => 'Open camera';

  @override
  String get galleryImportCopies => 'Import copies';

  @override
  String get galleryNoMatchTitle => 'No captures match';

  @override
  String get galleryNoMatchMessage =>
      'Clear your search and filters to see all captures.';

  @override
  String get galleryClearFilters => 'Clear search and filters';

  @override
  String galleryTileSelect(String label) {
    return 'Select $label';
  }

  @override
  String galleryTileOpen(String label) {
    return 'Open $label';
  }

  @override
  String get galleryTileFavorite => 'favorite';

  @override
  String galleryTilePosition(int position, int total) {
    return '$position of $total';
  }

  @override
  String galleryTileDuration(String time) {
    return 'duration $time';
  }

  @override
  String get galleryPreviewUnavailable => 'Preview unavailable';

  @override
  String get importIntro =>
      'Copy photos and videos from Files into your Library. Originals stay unchanged, including location and other metadata. Nothing is deleted or shared.';

  @override
  String get importChooseFiles => 'Choose files';

  @override
  String get importChooseFolder => 'Choose folder';

  @override
  String get importSupportedTitle => 'Supported files and limits';

  @override
  String get importSupportedBody =>
      'JPEG, PNG or playable MP4. Up to 20 files and 512 MiB total; photos up to 32 MiB and 64 MP. A folder imports its files (not subfolders), up to 10,000, 20 at a time; choose the same folder again to resume. TV playback depends on codecs. Imports use the date added. Selected copies may finish encrypting while Quietake is locked.';

  @override
  String get importCancelling => 'Cancelling after current file…';

  @override
  String get importCancelRemaining => 'Cancel remaining';

  @override
  String importFolderCount(int handled, int total) {
    return '$handled of $total files';
  }

  @override
  String get importBusyPrevious =>
      'Previous import is finishing. Try again shortly.';

  @override
  String get importOpenFailed =>
      'Could not open import. Check storage and try again.';

  @override
  String get importStoppedEarly =>
      'Import stopped early. Copies listed as imported are saved.';

  @override
  String get importCleanupFailed =>
      'Temporary cleanup failed. Restart Quietake before trying again.';

  @override
  String get importFolderStopped =>
      'Folder import stopped. Choose the folder again to continue; finished files are saved.';

  @override
  String importImported(int count) {
    return '$count imported';
  }

  @override
  String importDuplicates(int count) {
    return '$count duplicates skipped';
  }

  @override
  String importAlreadyDone(int count) {
    return '$count already imported earlier';
  }

  @override
  String importFailedCount(int count) {
    return '$count failed';
  }

  @override
  String importNotStarted(int count) {
    return '$count not started';
  }

  @override
  String importSummaryEnd(String summary) {
    return '$summary.';
  }

  @override
  String importSummaryContinue(String summary) {
    return '$summary. Choose the same folder again to continue.';
  }

  @override
  String get shareTitleOne => 'Share a copy?';

  @override
  String shareTitleMany(int count) {
    return 'Share $count copies?';
  }

  @override
  String get shareWarning =>
      'The app you choose receives unencrypted copies and may keep them.';

  @override
  String get shareStripTitle => 'Remove metadata from JPEG photo copies';

  @override
  String get shareStripOn =>
      'JPEG copies keep only their orientation: location, camera, time, comments and thumbnails are removed. PNG and video copies stay unchanged.';

  @override
  String get shareStripOff =>
      'Copies keep all original metadata, including location if present.';

  @override
  String shareLimits(int items, int mib) {
    return 'Up to $items captures and $mib MiB per batch.';
  }

  @override
  String shareProgress(int prepared, int total) {
    return 'Preparing $prepared of $total';
  }

  @override
  String get shareFailed =>
      'Could not share. Another share may still be finishing. Try again.';

  @override
  String get shareChooseApp => 'Choose app';

  @override
  String get viewerShareFailed => 'Could not share. Please try again.';

  @override
  String get viewerDetails => 'Details';

  @override
  String viewerType(String kind) {
    return 'Type: $kind';
  }

  @override
  String viewerCaptured(String when) {
    return 'Captured: $when';
  }

  @override
  String get viewerUnknown => 'Unknown';

  @override
  String viewerTags(String tags) {
    return 'Tags: $tags';
  }

  @override
  String get viewerNone => 'None';

  @override
  String viewerSize(int bytes) {
    return 'Encrypted size: $bytes bytes';
  }

  @override
  String get viewerSizeUnavailable => 'Encrypted size: unavailable';

  @override
  String get viewerClose => 'Close';

  @override
  String get viewerDeletePhotoTitle => 'Delete this photo?';

  @override
  String get viewerDeleteVideoTitle => 'Delete this video?';

  @override
  String viewerDeleteKeepNas(int days) {
    return 'Recently deleted keeps it on this phone, encrypted, for $days days so you can restore it. Your NAS copy stays until then. Delete now removes it from this phone and your configured NAS permanently.';
  }

  @override
  String viewerDeleteKeep(int days) {
    return 'Recently deleted keeps it on this phone, encrypted, for $days days so you can restore it. Delete now removes it from this phone permanently.';
  }

  @override
  String get viewerDeleteNasNow =>
      'It will be permanently removed from this phone and your configured NAS.';

  @override
  String get viewerDeleteNow =>
      'It will be permanently removed from this phone.';

  @override
  String get viewerDeleteNasTail =>
      'If the NAS is unavailable, deletion finishes when sync succeeds.';

  @override
  String get viewerDeletePendingTail =>
      'Pending deletions apply if you reconnect a NAS backup.';

  @override
  String get viewerDeleteEnd =>
      'Other backups and shared copies are unaffected. Active casting will stop.';

  @override
  String get viewerDelete => 'Delete';

  @override
  String get viewerRemoveFavorite => 'Remove favorite';

  @override
  String get viewerAddFavorite => 'Add favorite';

  @override
  String get viewerSlideshowStart => 'Start slideshow';

  @override
  String get viewerSlideshowStop => 'Stop slideshow';

  @override
  String get viewerShare => 'Share a copy';

  @override
  String get viewerDeletePhoto => 'Delete photo';

  @override
  String get viewerDeleteVideo => 'Delete video';

  @override
  String get viewerHideControls => 'Hide controls';

  @override
  String get viewerShowControls => 'Show controls';

  @override
  String viewerCasting(String device) {
    return 'casting to $device';
  }

  @override
  String get viewerPhotoUnavailable => 'Photo unavailable. Retry';

  @override
  String get viewerPrivatePhoto => 'Private photo';

  @override
  String get viewerResetFit => 'Reset to fit';

  @override
  String get viewerVideoUnavailable => 'Video unavailable. Retry';

  @override
  String get viewerReplay => 'Replay video';

  @override
  String get viewerPlay => 'Play video';

  @override
  String get viewerPause => 'Pause video';

  @override
  String get viewerVideoPosition => 'Video position';

  @override
  String get viewerBack10 => 'Back 10 seconds';

  @override
  String get viewerForward10 => 'Forward 10 seconds';

  @override
  String get viewerMute => 'Mute video';

  @override
  String get viewerUnmute => 'Unmute video';

  @override
  String get lockNow => 'Lock now';

  @override
  String get brandTagline => 'Private camera';

  @override
  String get backupTitle => 'Check backup';

  @override
  String get backupIntro =>
      'Checks every encrypted file in your saved NAS backup using this vault’s key. Large libraries need time, data and temporary space. This check does not change originals.';

  @override
  String get backupNeverChecked =>
      'This backup has never been fully checked. Check it to confirm your copies can be read.';

  @override
  String backupStale(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'The last full check was $_temp0 ago. Check again to confirm your copies can still be read.';
  }

  @override
  String get backupCancelCheck => 'Cancel check';

  @override
  String get backupCancelQueued => 'Cancel queued check';

  @override
  String get backupCheckSaved => 'Check saved backup';

  @override
  String backupCheckedAt(String date, String time, String state) {
    return 'Checked $date at $time · $state';
  }

  @override
  String get backupUnchanged => 'Nothing changed since';

  @override
  String get backupChanged => 'Changed since; check again';

  @override
  String get backupKeepKey =>
      'Keep your recovery key separately. A successful check does not test the copy of the key you saved elsewhere.';

  @override
  String get backupLeaveNote =>
      'You can leave this screen while checking. Capture uploads wait for the check to finish. Checks stop if the app process closes.';

  @override
  String get castSearchFailed =>
      'Could not search for TVs. Check Wi-Fi and try again.';

  @override
  String castConnected(String device) {
    return 'Connected to $device. Open a capture to cast it.';
  }

  @override
  String get castTitle => 'Cast to a TV';

  @override
  String get castClose => 'Close Cast picker';

  @override
  String get castUnencrypted =>
      'Selected media streams unencrypted over your local network while casting.';

  @override
  String get castLooking => 'Looking for TVs on this network';

  @override
  String get castNoneFound => 'No TVs found';

  @override
  String get castSameWifi => 'Is the TV on the same Wi-Fi as this phone?';

  @override
  String get castRetry => 'Retry';

  @override
  String castStop(String device) {
    return 'Stop casting to $device';
  }

  @override
  String get castCancelConnection => 'Cancel connection';

  @override
  String get castToTv => 'Cast to TV';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPrivacySection => 'Privacy & access';

  @override
  String get settingsIdleLabel => 'Lock after inactivity';

  @override
  String get settingsIdleOff => 'Off';

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
      'Recording and video playback delay idle locking. Lock now saves an active recording, pauses playback and stops casting.';

  @override
  String get settingsScreenshotsIos =>
      'App-switcher previews are hidden. iOS screenshots cannot be blocked.';

  @override
  String get settingsScreenshotsAndroid =>
      'Screenshots, screen recording and app-switcher previews are protected on Android.';

  @override
  String get settingsPrivacySaveFailed =>
      'Could not save privacy settings. Try again.';

  @override
  String get settingsPasscodeChanged => 'Passcode changed';

  @override
  String get settingsBackupSection => 'Backup';

  @override
  String get settingsBackupIntro =>
      'Optional backup of encrypted media to your own WebDAV share.';

  @override
  String get settingsUrlLabel => 'WebDAV folder URL';

  @override
  String get settingsUsername => 'Username';

  @override
  String get settingsPassword => 'Password';

  @override
  String get settingsBackgroundTitle => 'Back up while app is closed';

  @override
  String get settingsBackgroundBody =>
      'Android schedules encrypted uploads when network and battery allow. Save and complete one foreground sync first. Force-stop pauses work until you reopen Quietake.';

  @override
  String get settingsMobileTitle => 'Allow mobile data';

  @override
  String get settingsMobileBody =>
      'Off uses unmetered networks only. Large videos can consume substantial data.';

  @override
  String get settingsBgChecking => 'Checking Android scheduler…';

  @override
  String get settingsBgScheduled => 'Scheduled when network and battery allow.';

  @override
  String get settingsBgUploading => 'Android is uploading encrypted copies.';

  @override
  String get settingsBgTransferred =>
      'Last background pass finished. Full backup verification is separate.';

  @override
  String get settingsBgReconcile =>
      'Open the vault and sync to check this backup before background uploads resume.';

  @override
  String get settingsBgPending =>
      'Background backup pending. Android will retry.';

  @override
  String get settingsBgOff =>
      'Background backup is off or waiting for its first successful sync.';

  @override
  String get settingsBgUnavailable =>
      'Scheduler unavailable. Foreground sync remains available.';

  @override
  String get settingsSave => 'Save backup settings';

  @override
  String get settingsTest => 'Test connection';

  @override
  String get settingsTesting => 'Testing connection…';

  @override
  String settingsConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Connected · $_temp0';
  }

  @override
  String settingsErrHttp(int status) {
    return 'Connection failed (HTTP $status). Check folder URL, username and password.';
  }

  @override
  String get settingsErrReach =>
      'Could not reach NAS. Check the URL and Wi-Fi.';

  @override
  String get settingsErrGeneric =>
      'Connection failed. Check the saved details and try again.';

  @override
  String get settingsSaveFirst =>
      'Save connection changes before checking backup.';

  @override
  String get settingsEnterDetails =>
      'Enter a folder URL, username and password';

  @override
  String get settingsSaveFailed =>
      'Could not save connection details. Try again.';

  @override
  String get settingsDisconnectFailed =>
      'Could not disconnect NAS backup. Try again.';

  @override
  String get settingsWrongPasscode => 'Wrong passcode. Try again.';

  @override
  String get settingsRecoveryReadFailed =>
      'Could not read the recovery key. Try again.';

  @override
  String get settingsDisconnectTitle => 'Disconnect NAS backup?';

  @override
  String get settingsClearTitle => 'Clear saved NAS details?';

  @override
  String get settingsDisconnectBody =>
      'Stops automatic backup and removes saved connection details. Captures stay on your phone and NAS. Pending NAS deletions will not finish until you reconnect that backup.';

  @override
  String get settingsDisconnectAction => 'Disconnect';

  @override
  String get settingsClearAction => 'Clear details';

  @override
  String get settingsDisconnectButton => 'Disconnect NAS backup';

  @override
  String get settingsClearButton => 'Clear saved NAS details';

  @override
  String get settingsRecoverySection => 'Recovery & export';

  @override
  String get settingsShowRecovery => 'Show recovery key';

  @override
  String get settingsNasPassTitle => 'NAS backup passphrase';

  @override
  String get settingsNasPassBody =>
      'Enable, change or disable recovery without your recovery key';

  @override
  String get settingsPortableTitle => 'Portable encrypted backup';

  @override
  String get settingsPortableBody =>
      'Save a ZIP to Files using your recovery key';

  @override
  String get settingsCameraSection => 'Camera';

  @override
  String get settingsBurstLabel => 'Photos in a burst';

  @override
  String get settingsBurstHelp => 'Press and hold the shutter.';

  @override
  String settingsBurstChoice(int count) {
    return '$count photos';
  }

  @override
  String get settingsStorageSection => 'Storage';

  @override
  String get settingsStorageUnreadable => 'Storage could not be read.';

  @override
  String get settingsStorageCounting => 'Counting captures…';

  @override
  String get settingsStorageNone => 'No captures on this phone yet.';

  @override
  String settingsStorageSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures',
      one: '1 capture',
    );
    return '$_temp0, $size encrypted on this phone.';
  }

  @override
  String settingsStorageTrashed(int count, int days) {
    return '$count in Recently deleted, removed for good after $days days.';
  }

  @override
  String settingsSizeBytes(int value) {
    return '$value bytes';
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
  String get settingsKeepDeleted => 'Keep deleted captures for 30 days';

  @override
  String get settingsKeepDeletedBody =>
      'Delete moves a capture to Recently deleted first. It stays encrypted.';

  @override
  String get settingsLicenses => 'Licenses';

  @override
  String get settingsShow => 'Show';

  @override
  String get portableTitleRestore => 'Restore encrypted backup';

  @override
  String get portableTitleExport => 'Portable backup';

  @override
  String get portableIntroRestore =>
      'Restore only into a fresh empty vault. Your recovery key opens the ZIP and encrypted captures. Existing libraries cannot be merged.';

  @override
  String get portableIntroExport =>
      'Save an encrypted ZIP of captures and organization. Your existing recovery key opens it; keep that key separately. No credentials or keyfiles are included.';

  @override
  String get portableChoose => 'Choose backup ZIP';

  @override
  String get portableCheckOnly => 'Check backup only';

  @override
  String get portableRestoreButton => 'Restore empty vault';

  @override
  String get portableCreateButton => 'Create encrypted ZIP';

  @override
  String get portableLimitsTitle => 'Backup limits and storage';

  @override
  String get portableLimitsBody =>
      'Up to 10,000 captures and 2 GiB per ZIP. Preparation needs private temporary storage. Vault originals stay unchanged. No credentials or keyfiles are included.';

  @override
  String get portableCancelPrep => 'Cancel preparation';

  @override
  String get portablePicking => 'Choose an encrypted ZIP in Files.';

  @override
  String get portablePickCancelled => 'Selection cancelled.';

  @override
  String get portablePicked =>
      'Backup selected. Enter its recovery key and a new passcode.';

  @override
  String get portableCopyFailed =>
      'Could not copy backup. Check storage and try again.';

  @override
  String get portableStillFinishing =>
      'Previous backup is finishing. Try again shortly.';

  @override
  String get portableNeedKey => 'Choose a backup and enter its recovery key.';

  @override
  String get portableNeedPasscode =>
      'Choose a backup and confirm a passcode of at least six characters.';

  @override
  String get portablePreparing => 'Preparing encrypted backup…';

  @override
  String portableChecking(int done, int total) {
    return 'Checking encrypted files: $done of $total…';
  }

  @override
  String get portableChecked =>
      'Backup checked: every encrypted file and the catalog authenticate with this key. Nothing was restored. Choose the file again to restore it.';

  @override
  String get portableRestored =>
      'Vault restored. Use your new passcode once to enable biometric unlock.';

  @override
  String portableExporting(int done, int total) {
    return 'Preparing encrypted files: $done of $total…';
  }

  @override
  String get portableSaved =>
      'Encrypted backup saved. Keep its recovery key separately.';

  @override
  String get portableSaveCancelled => 'Save cancelled. Vault originals kept.';

  @override
  String get portableBadKey => 'Enter the recovery key saved for this backup.';

  @override
  String get portableCancelled => 'Cancelled. Vault originals kept.';

  @override
  String get portableFailed =>
      'Could not restore or save backup. Check its key, file, available storage and empty-vault requirement.';

  @override
  String get nasTitleRestore => 'Restore from NAS';

  @override
  String get nasTitleManage => 'Backup passphrase';

  @override
  String get nasIntroRestore =>
      'Use the separate backup passphrase previously enabled on your NAS. The short phone passcode cannot recover this backup. Restore authenticates all files into an empty vault; no merge. Your NAS stays read-only.';

  @override
  String get nasIntroManage =>
      'Protect NAS recovery with a separate strong passphrase. Anyone with the encrypted file can try guesses offline. Prefer six random words; length alone does not prove strength. Complete a saved NAS sync first. The NAS must support safe file locking; otherwise nothing is written.';

  @override
  String get nasUrlLabel => 'HTTPS WebDAV folder URL';

  @override
  String get nasUserLabel => 'NAS username';

  @override
  String get nasPasswordLabel => 'NAS password';

  @override
  String get nasPinNew => 'New local passcode';

  @override
  String get nasPinCurrent => 'Current local passcode';

  @override
  String get nasPinConfirm => 'Confirm new local passcode';

  @override
  String get nasPhraseLabel => 'Backup passphrase';

  @override
  String get nasPhraseConfirm => 'Confirm backup passphrase';

  @override
  String get nasGenerate => 'Generate six words';

  @override
  String get nasHide => 'Hide passphrase';

  @override
  String get nasShow => 'Show passphrase';

  @override
  String get nasWordsCredit =>
      'Words: Electronic Frontier Foundation · CC BY 4.0';

  @override
  String get nasWordLicenses => 'Word-list licenses';

  @override
  String get nasEnableButton => 'Enable or change passphrase';

  @override
  String get nasDisableButton => 'Disable passphrase recovery';

  @override
  String get nasFootRestore =>
      'Up to 10,000 captures. Private temporary space is needed. Unlock with your new passcode afterward. Background upload stays off.';

  @override
  String get nasFootManage =>
      'This changes recovery protection only. It never changes your phone passcode or re-encrypts captures. Removing current recovery does not revoke old server snapshots.';

  @override
  String get nasGenerateFailed => 'Could not generate a passphrase. Try again.';

  @override
  String get nasConfirmDisableTitle => 'Disable passphrase recovery?';

  @override
  String get nasConfirmSaveTitle => 'Save backup passphrase?';

  @override
  String get nasConfirmDisableBody =>
      'Removes the current recovery file from the saved NAS folder. Captures stay. Old server snapshots may still accept an earlier passphrase. Keep your independent recovery key.';

  @override
  String get nasConfirmSaveBody =>
      'Creates or replaces recovery in the saved NAS folder. Save the new passphrase separately. Old server snapshots may still accept an earlier passphrase; this does not rotate your vault key.';

  @override
  String get nasDisableAction => 'Disable recovery';

  @override
  String get nasSaveAction => 'Save passphrase';

  @override
  String get nasSeparatePhrase =>
      'Use a separate backup passphrase, not your local passcode.';

  @override
  String get nasNeedPasscode =>
      'Choose and confirm a new passcode of at least six characters.';

  @override
  String get nasNeedDetails =>
      'Enter your saved NAS folder, username and password.';

  @override
  String get nasMismatch => 'Backup passphrases do not match.';

  @override
  String get nasCheckingRestore => 'Checking encrypted NAS backup…';

  @override
  String get nasCheckingSaved => 'Checking saved NAS recovery…';

  @override
  String get nasRestoredTitle => 'Vault restored';

  @override
  String get nasRestoredUnsaved =>
      'The NAS connection could not be saved. Your captures are restored; add the connection again in Settings to resume backups.';

  @override
  String get nasContinue => 'Continue';

  @override
  String get nasDisabledDone => 'Passphrase recovery disabled. Captures kept.';

  @override
  String get nasSavedDone =>
      'Backup passphrase saved. Keep it and your recovery key separately.';

  @override
  String get nasWrongCurrent => 'Wrong current passcode. Try again.';

  @override
  String get nasCancelled => 'Cancelled. Originals kept.';

  @override
  String get nasRestoreFailed =>
      'Could not restore. Check the NAS connection, backup passphrase and empty-vault requirement. Originals kept.';

  @override
  String get nasChangeFailed =>
      'Could not change recovery. Check saved NAS backup, supported recovery file and server compatibility. Sync first, then retry. Originals kept.';

  @override
  String get coverChooseTitle => 'Choose cover';

  @override
  String get coverEmpty =>
      'Tag some captures first, then choose one as the cover.';

  @override
  String get coverUse => 'Use this capture as the cover';

  @override
  String get restoreGateFailed =>
      'Could not finish interrupted backup restore. Prepared encrypted files are preserved. Check available storage, then try again.';

  @override
  String get restoreGateRetry => 'Retry restore';

  @override
  String get settingsCheckRecovery => 'Check my recovery key';

  @override
  String get recoveryCheckTitle => 'Check recovery key';

  @override
  String get recoveryCheckIntro =>
      'Type the recovery key you saved elsewhere. It is compared on this phone and never stored.';

  @override
  String get recoveryCheckAction => 'Check';

  @override
  String get recoveryCheckClose => 'Close';

  @override
  String get recoveryCheckMatch => 'This matches your vault\'s recovery key.';

  @override
  String get recoveryCheckMismatch =>
      'This key does not match this vault. Check where you saved it, then try again.';

  @override
  String get recoveryCheckInvalid =>
      'This is not a valid recovery key. Check for missing or extra characters.';

  @override
  String get redactTitle => 'Hide parts of the photo';

  @override
  String get redactUndo => 'Undo last area';

  @override
  String get redactDone => 'Done';

  @override
  String redactStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count areas will be hidden.',
      one: '1 area will be hidden.',
      zero: 'Drag over the photo to hide an area.',
    );
    return '$_temp0';
  }

  @override
  String get redactFailed => 'This photo could not be opened for editing.';

  @override
  String get shareRedactButton => 'Hide parts of this photo…';

  @override
  String shareRedactEdit(int count) {
    return 'Hidden areas: $count. Change…';
  }

  @override
  String get shareRedactNote =>
      'The shared copy becomes a PNG with those areas pixelated and no metadata. The original stays unchanged in your vault.';

  @override
  String redactCell(int row, int column) {
    return 'Row $row, column $column';
  }

  @override
  String get redactSections => 'Or hide a section of the photo';
}
