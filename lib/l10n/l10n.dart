import 'package:flutter/widgets.dart';

import '../vault/master_key_store.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  /// The current translations. Widgets built without the app's delegates, such as
  /// in a bare test harness, fall back to English instead of failing.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

/// The wait after too many wrong passcodes, in the reader's language.
String passcodeLockedMessage(AppLocalizations l10n, PasscodeLockedException e) {
  final seconds = (e.retryAfter.inMilliseconds / 1000).ceil();
  return seconds < 60
      ? l10n.passcodeLockedSeconds(seconds)
      : l10n.passcodeLockedMinutes(seconds < 120 ? 1 : (seconds / 60).ceil());
}
