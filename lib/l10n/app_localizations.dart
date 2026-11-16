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
