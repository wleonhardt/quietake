import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/backup/archive_worker.dart';

void main() {
  const password = 'synthetic-archive-worker-password';
  late Directory root;
  late Directory out;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('quietake-archive-worker');
    out = await Directory('${root.path}/out').create();
  });
  tearDown(() => root.delete(recursive: true));

  Future<File> plain(String name, int length) async => File(
    '${root.path}/$name',
  ).writeAsBytes(Uint8List.fromList(List.generate(length, (i) => i % 251)));

  Future<File> zip(Map<String, File> entries) async {
    final target = '${root.path}/test.zip';
    await runArchiveWorker({
      'encode': true,
      'target': target,
      'password': password,
      'files': [
        for (final e in entries.entries) {'path': e.value.path, 'entry': e.key},
      ],
    });
    return File(target);
  }

  Future<void> extract(File source) => runArchiveWorker({
    'source': source.path,
    'password': password,
    'directory': out.path,
  });

  Matcher failsAt(String phase) => throwsA(
    isA<FormatException>().having((e) => e.message, 'message', contains(phase)),
  );

  Future<List<String>> extracted() async => [
    for (final e in await out.list().toList()) e.uri.pathSegments.last,
  ];

  test('a conforming archive extracts byte for byte', () async {
    final source = await plain('a', 300);
    await extract(await zip({'item-00000.shtr': source}));
    expect(
      await File('${out.path}/item-00000.shtr').readAsBytes(),
      await source.readAsBytes(),
    );
  });

  test('files that are not a bounded ZIP fail before any parsing', () async {
    for (final bytes in [
      Uint8List(0),
      Uint8List(21),
      Uint8List.fromList(List.generate(200, (i) => i)),
    ]) {
      final file = await File('${root.path}/junk').writeAsBytes(bytes);
      await expectLater(extract(file), failsAt('directory bounds'));
    }
    expect(await extracted(), isEmpty);
  });

  test('a ZIP with a trailing comment is rejected as unsupported', () async {
    final good = await (await zip({'item-00000.shtr': await plain('a', 300)}))
        .readAsBytes();
    // Footer comment length field (last two bytes of a 22-byte footer).
    final withComment = Uint8List.fromList([...good, 0x41]);
    withComment[good.length - 2] = 1;
    final file = await File('${root.path}/c.zip').writeAsBytes(withComment);
    await expectLater(extract(file), failsAt('directory bounds'));
  });

  test('entry names outside the vault naming scheme are refused', () async {
    final source = await plain('a', 300);
    for (final name in [
      'notes.txt',
      'item-1.shtr',
      'item-00001.shtr.bak',
      'ITEM-00001.shtr',
      '../item-00001.shtr',
    ]) {
      await expectLater(
        extract(await zip({name: source})),
        failsAt('entry bounds'),
        reason: name,
      );
    }
    expect(await extracted(), isEmpty);
  });

  test('entries too small to hold a container header are refused', () async {
    final tiny = await plain('tiny', 105);
    await expectLater(
      extract(await zip({'item-00000.shtr': tiny})),
      failsAt('entry bounds'),
    );
    expect(await extracted(), isEmpty);
  });

  test('duplicate entry names are refused', () async {
    final source = await plain('a', 300);
    final target = '${root.path}/dup.zip';
    await runArchiveWorker({
      'encode': true,
      'target': target,
      'password': password,
      'files': [
        {'path': source.path, 'entry': 'item-00000.shtr'},
        {'path': source.path, 'entry': 'item-00000.shtr'},
      ],
    });
    await expectLater(extract(File(target)), failsAt('entry bounds'));
  });
}
