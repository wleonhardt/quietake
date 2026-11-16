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
