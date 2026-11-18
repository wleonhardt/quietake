import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/app_version.dart';

void main() {
  test('the version shown in Settings is the one in pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((line) => line.startsWith('version: '));
    expect(line, 'version: $appVersion+$appBuild');
  });
}
