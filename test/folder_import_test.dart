import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/library/folder_import.dart';
import 'package:quietake/library/import_media.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

class _Source implements FolderSource {
  _Source(this.dir, this.entries, {this.identity = 'content://tree/holiday'});
  final Directory dir;
  final List<FolderEntry> entries;
  @override
  final String identity;
  final copied = <String>[];
  var maxStaged = 0;
  final failing = <String>{};
  void Function(String id)? onCopy;

  @override
  Future<List<FolderEntry>> list() async => entries;

  @override
  Future<File> copyTo(FolderEntry entry, Directory directory) async {
    if (failing.contains(entry.id)) throw const FileSystemException('gone');
    await directory.create(recursive: true);
    final staged = directory.listSync().length + 1;
    if (staged > maxStaged) maxStaged = staged;
    copied.add(entry.id);
    onCopy?.call(entry.id);
    return File('${dir.path}/${entry.id}')
        .copy('${directory.path}/${entry.name}');
  }
}

void main() {
  late Directory root;
  late Directory external;
  late Directory staging;
  late Vault vault;
  late FolderImport importer;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('quietake-folder-import');
    external = await Directory('${root.path}/external').create();
    staging = Directory('${root.path}/quietake-import');
    final sodium = await SodiumSumoInit.init();
    vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      await Directory('${root.path}/vault').create(),
    );
    importer = FolderImport(
      vault,
      staging,
      importer: MediaImporter(vault, staging, validate: (_, _) async {}),
    );
  });
  tearDown(() async {
    vault.dispose();
    await root.delete(recursive: true);
  });

  Future<List<FolderEntry>> files(int count, {String ext = 'jpg'}) async => [
    for (var i = 0; i < count; i++)
      await (() async {
        final name = 'img$i.$ext';
        // Distinct bytes per file so none is an exact duplicate.
        await File('${external.path}/$name').writeAsBytes([i, i >> 8, 7, 7]);
        return FolderEntry(id: name, name: name);
      })(),
  ];

  test(
    'imports supported files in chunks and leaves the folder unchanged',
    () async {
      final entries = [...await files(45), ...await files(1, ext: 'txt')];
      final before = {
        for (final e in external.listSync())
          e.path: (e as File).readAsBytesSync(),
      };
      final source = _Source(external, entries);
      final progress = <int>[];
      final summary = await importer.run(
        source,
        onProgress: (handled, total) => progress.add(handled),
      );
      expect(summary.total, 45, reason: 'the .txt file is not supported');
      expect(summary.imported, 45);
      expect(summary.failed, 0);
      expect(await vault.list(), hasLength(45));
      expect(progress, [0, 20, 40, 45]);
      // Never more than one chunk of private copies at a time.
      expect(source.maxStaged, lessThanOrEqualTo(FolderImport.chunkSize));
      expect(await staging.exists(), isFalse);
      expect({
        for (final e in external.listSync())
          e.path: (e as File).readAsBytesSync(),
      }, before);
    },
  );

  test('an interrupted import resumes with only the remaining files', () async {
    final entries = await files(45);
    final first = _Source(external, entries);
    var cancel = false;
    first.onCopy = (id) {
      if (id == 'img20.jpg') cancel = true; // Inside the second chunk.
    };
    final partial = await importer.run(first, isCancelled: () => cancel);
    expect(partial.cancelled, greaterThan(0));
    final done = (await vault.list()).length;
    expect(done, inInclusiveRange(20, 40));

    final second = _Source(external, entries);
    final summary = await importer.run(second);
    expect(await vault.list(), hasLength(45));
    expect(summary.imported + summary.alreadyDone, 45);
    expect(summary.alreadyDone, greaterThanOrEqualTo(20));
    // Files recorded by the first run are not copied again.
    expect(second.copied, isNot(contains('img0.jpg')));
    expect(second.copied.length, 45 - summary.alreadyDone);
  });

  test('a file that could not be read is retried on the next run', () async {
    final entries = await files(3);
    final source = _Source(external, entries)..failing.add('img1.jpg');
    final first = await importer.run(source);
    expect((first.imported, first.failed), (2, 1));

    final second = await importer.run(_Source(external, entries));
    expect((second.imported, second.alreadyDone, second.failed), (1, 2, 0));
    expect(await vault.list(), hasLength(3));
  });

  test('exact duplicates are recorded so a rerun skips them quickly', () async {
    final entries = await files(2);
    await File('${external.path}/copy.jpg')
        .writeAsBytes(await File('${external.path}/img0.jpg').readAsBytes());
    entries.add(const FolderEntry(id: 'copy.jpg', name: 'copy.jpg'));
    final first = await importer.run(_Source(external, entries));
    expect((first.imported, first.duplicates), (2, 1));

    final again = _Source(external, entries);
    final second = await importer.run(again);
    expect(second.alreadyDone, 3);
    expect(again.copied, isEmpty);
  });

  test('more than 10,000 files is refused before anything is copied', () async {
    final entries = [
      for (var i = 0; i < 10001; i++)
        FolderEntry(id: 'f$i.jpg', name: 'f$i.jpg'),
    ];
    final source = _Source(external, entries);
    await expectLater(importer.run(source), throwsFormatException);
    expect(source.copied, isEmpty);
    expect(await vault.list(), isEmpty);
  });

  test('the ledger is encrypted and its name hides the folder', () async {
    final entries = await files(2);
    await importer.run(_Source(external, entries));
    final ledgers = Directory('${vault.dir.path}/.import').listSync();
    expect(ledgers, hasLength(1));
    final ledger = ledgers.single as File;
    expect(ledger.path, isNot(contains('holiday')));
    final raw = utf8.decode(await ledger.readAsBytes(), allowMalformed: true);
    expect(raw, isNot(contains('img0.jpg')));
    expect(await vault.list(), hasLength(2), reason: 'ledger is not media');
  });

  test('a damaged ledger is ignored so the folder can still import', () async {
    final entries = await files(2);
    await importer.run(_Source(external, entries));
    final ledger =
        Directory('${vault.dir.path}/.import').listSync().single as File;
    await ledger.writeAsBytes([1, 2, 3, 4]);
    final again = await importer.run(_Source(external, entries));
    expect(again.duplicates, 2, reason: 'exact copies are found by content');
    expect(again.failed, 0);
    expect(await vault.list(), hasLength(2));
  });

  test('different folders keep separate ledgers', () async {
    final entries = await files(2);
    await importer.run(_Source(external, entries, identity: 'a'));
    final other = _Source(external, entries, identity: 'b');
    final summary = await importer.run(other);
    // Same content: the second folder finds exact duplicates, not ledger hits.
    expect(summary.alreadyDone, 0);
    expect(summary.duplicates, 2);
  });

  group('PickedFolder', () {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final calls = <MethodCall>[];
    Object? pickReply;

    setUp(() {
      calls.clear();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(folderChannel, (
        call,
      ) async {
        calls.add(call);
        return switch (call.method) {
          'pick' => pickReply,
          'copy' => '${call.arguments['directory']}/copy.jpg',
          _ => null,
        };
      });
    });
    tearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        folderChannel,
        null,
      ),
    );

    test('a cancelled picker returns null', () async {
      pickReply = null;
      expect(await PickedFolder.pick(), isNull);
    });

    test('lists the entries and copies one by id into the directory', () async {
      pickReply = {
        'identity': 'content://tree/x',
        'entries': [
          {'id': 'doc:1', 'name': 'a.jpg'},
          {'id': 'doc:2', 'name': 'b.png'},
        ],
      };
      final folder = (await PickedFolder.pick())!;
      expect(folder.identity, 'content://tree/x');
      final entries = await folder.list();
      expect(entries.map((e) => e.name), ['a.jpg', 'b.png']);
      final file = await folder.copyTo(entries.first, staging);
      expect(file.path, '${staging.path}/copy.jpg');
      expect(calls.last.arguments, {'id': 'doc:1', 'directory': staging.path});
      await folder.cancel();
      await folder.release();
      expect(calls.map((c) => c.method), ['pick', 'copy', 'cancel', 'release']);
    });

    test(
      'a native copy failure becomes a failed file, not a crashed run',
      () async {
        pickReply = {
          'identity': 'f',
          'entries': [
            {'id': 'doc:1', 'name': 'a.jpg'},
          ],
        };
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          folderChannel,
          (call) async => call.method == 'pick'
              ? pickReply
              : throw PlatformException(code: 'copy'),
        );
        final summary = await importer.run((await PickedFolder.pick())!);
        expect((summary.imported, summary.failed), (0, 1));
      },
    );
  });
}
