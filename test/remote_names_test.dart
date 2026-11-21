import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/sync/remote_names.dart';

void main() {
  const local = '2026-10-26T12-30-00.000Z.jpg.shtr';

  test('an unmapped capture keeps its own name in both directions', () {
    const names = RemoteNames.empty();
    expect(names.remoteFor(local), local);
    expect(names.localFor(local), local);
  });

  test(
    'an assigned name is random hex, hides the capture name and round trips',
    () {
      final names = const RemoteNames.empty().assign(local, Random(1));
      final remote = names.remoteFor(local);
      expect(remote, matches(RegExp(r'^[0-9a-f]{32}\.shtr$')));
      expect(remote, isNot(contains('2026')));
      expect(names.localFor(remote), local);
    },
  );

  test('assign never changes an existing mapping or the original object', () {
    final first = const RemoteNames.empty().assign(local, Random(1));
    expect(() => first.assign(local, Random(2)), throwsStateError);
    expect(const RemoteNames.empty().isEmpty, isTrue);
    expect(first.isEmpty, isFalse);
  });

  test('two captures get different names', () {
    final random = Random(3);
    final names = const RemoteNames.empty()
        .assign('a.jpg.shtr', random)
        .assign('b.jpg.shtr', random);
    expect(names.remoteFor('a.jpg.shtr'), isNot(names.remoteFor('b.jpg.shtr')));
  });

  test('JSON round trips and an empty mapping writes nothing', () {
    final names = const RemoteNames.empty().assign(local, Random(1));
    expect(
      RemoteNames.fromJson(names.toJson()).remoteFor(local),
      names.remoteFor(local),
    );
    expect(const RemoteNames.empty().toJson(), isEmpty);
    expect(RemoteNames.fromJson(null).isEmpty, isTrue);
  });

  test('forget drops a mapping so a deleted capture frees its name', () {
    final names = const RemoteNames.empty().assign(local, Random(1));
    final remote = names.remoteFor(local);
    final after = names.forget(local);
    expect(after.localFor(remote), remote);
    expect(after.isEmpty, isTrue);
  });

  for (final bad in <Object?>[
    'text',
    {'a.shtr': 5},
    {'../x.shtr': 'b.shtr'},
    {'a.shtr': 'dir/b.shtr'},
    {'a.shtr': 'b.txt'},
    {'a.shtr': 'same.shtr', 'b.shtr': 'same.shtr'},
    {'a.shtr': 'b.shtr', 'b.shtr': 'c.shtr'},
  ]) {
    test('rejects malformed mapping $bad', () {
      expect(() => RemoteNames.fromJson(bad), throwsFormatException);
    });
  }

  test('adopt maps a known NAS name and refuses clashes', () {
    const remote = '3f9c0a7e5b1d44c2a86e0d1f7b92c4aa.shtr';
    final names = const RemoteNames.empty().adopt(local, remote);
    expect(names.remoteFor(local), remote);
    expect(names.localFor(remote), local);
    expect(() => names.adopt(local, 'x.shtr'), throwsStateError);
    expect(() => names.adopt('b.shtr', remote), throwsStateError);
    expect(() => names.adopt('b.shtr', local), throwsStateError);
    expect(
      () => const RemoteNames.empty().adopt(local, local),
      throwsStateError,
    );
  });
}
