import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/library/private_catalog.dart';
import 'package:quietake/limits.dart';
import 'package:quietake/sync/sync_service.dart';

void main() {
  test('a vault that fits the catalog also fits a restore', () {
    // About 190 bytes of catalog per synced capture (name, random server
    // name and a little metadata).
    expect(maxBackupCaptures * 190, lessThanOrEqualTo(maxCatalogBytes));
    expect(PrivateCatalog.maxBytes, maxCatalogBytes);
    expect(SyncService.maxListingBytes, maxListingBytes);
  });

  test('the recovery tool accepts what the app can produce', () {
    final source = File('recover/source.go').readAsStringSync();
    final names = File('recover/names.go').readAsStringSync();
    expect(source, contains('captures > $maxBackupCaptures'));
    expect(
      source,
      contains('const maxListingBytes = ${maxListingBytes ~/ (1024 * 1024)} * 1024 * 1024'),
    );
    // The tool reads a catalog up to twice the app's limit.
    expect(
      names,
      contains('const maxCatalogBytes = ${2 * maxCatalogBytes ~/ (1024 * 1024)} << 20'),
    );
  });
}
