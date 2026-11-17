import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/backup/restore_transaction.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late Directory root;
  late RestoreTransaction transaction;
  late String fingerprintOfPrepared;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('restore-resume-');
    final sodium = await SodiumSumoInit.init();
    transaction = RestoreTransaction(MasterKeyStore(sodium, root));
    fingerprintOfPrepared = base64Encode(
      sodium.crypto.genericHash.call(message: utf8.encode('prepared keyfile')),
    );
  });
  tearDown(() => root.delete(recursive: true));

  Future<void> journal({
    String? fingerprint,
    bool preparedKeyfile = false,
    bool preparedVault = false,
    bool existingTarget = false,
  }) async {
    await transaction.pending.create();
    await File('${transaction.pending.path}/ready').writeAsString(
      jsonEncode({
        'version': 1,
        'keyfile': fingerprint ?? fingerprintOfPrepared,
      }),
    );
    if (preparedKeyfile) {
      await File('${transaction.pending.path}/vault.keyfile.json')
          .writeAsString('prepared keyfile');
    }
    if (preparedVault) {
      await Directory('${transaction.pending.path}/vault').create();
      await File('${transaction.pending.path}/vault/a.shtr').writeAsBytes([1]);
    }
    if (existingTarget) {
      await transaction.target.create();
      await File('${transaction.target.path}/other.shtr').writeAsBytes([2]);
    }
  }

  test(
    'startup removes abandoned staging folders and reports no restore',
    () async {
      final stale = await Directory('${root.path}/.portable-stage-1.validated')
          .create();
      await File('${stale.path}/x').writeAsBytes([1]);
      expect(await transaction.resume(), isFalse);
      expect(await stale.exists(), isFalse);
    },
  );

  test('a journal without its prepared credentials is preserved', () async {
    await journal(preparedVault: true);
    await expectLater(
      transaction.resume(),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Prepared credentials missing'),
        ),
      ),
    );
    expect(await transaction.pending.exists(), isTrue);
  });

  test(
    'prepared credentials that do not match the journal are preserved',
    () async {
      await journal(
        fingerprint: 'AAAA',
        preparedKeyfile: true,
        preparedVault: true,
      );
      await expectLater(
        transaction.resume(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Prepared credentials differ'),
          ),
        ),
      );
      expect(await transaction.pending.exists(), isTrue);
    },
  );

  test('a prepared vault never replaces a vault that gained files', () async {
    await journal(
      preparedKeyfile: true,
      preparedVault: true,
      existingTarget: true,
    );
    await expectLater(
      transaction.resume(),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('no longer empty'),
        ),
      ),
    );
    expect(File('${transaction.target.path}/other.shtr').existsSync(), isTrue);
    expect(
      File('${transaction.pending.path}/vault/a.shtr').existsSync(),
      isTrue,
    );
  });

  test('an empty target folder is replaced by the prepared vault', () async {
    await journal(preparedKeyfile: true, preparedVault: true);
    await transaction.target.create();
    expect(await transaction.resume(), isTrue);
    expect(File('${transaction.target.path}/a.shtr').existsSync(), isTrue);
    expect(await transaction.pending.exists(), isFalse);
  });
}
