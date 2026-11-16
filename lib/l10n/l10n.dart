import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  /// The current translations. Widgets built without the app's delegates, such as
  /// in a bare test harness, fall back to English instead of failing.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}
