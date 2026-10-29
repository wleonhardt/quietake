import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keys.dart';

bool _registered = false;

void showAppLicenses(BuildContext context) {
  if (!_registered) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        'EFF Long Wordlist',
      ], await rootBundle.loadString('assets/passphrases/LICENSE.txt'));
    });
    _registered = true;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const LicensePage(
        key: Keys.licensesPage,
        applicationName: 'Quietake',
      ),
    ),
  );
}
