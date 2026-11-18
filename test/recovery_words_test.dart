import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/vault/recovery_words.dart';

List<String> _list() =>
    File('assets/passphrases/eff_large_wordlist.txt')
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim().split(RegExp(r'\s+')).last)
        .toList();

void main() {
  final list = _list();

  test('the word list is the one the passphrase generator checks', () {
    expect(list, hasLength(7776));
    expect(list.toSet(), hasLength(7776));
  });

  test('every key becomes 21 words and comes back unchanged', () {
    final random = Random(20261118);
    for (final key in [
      Uint8List(32),
      Uint8List.fromList(List.filled(32, 255)),
      for (var i = 0; i < 200; i++)
        Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
    ]) {
      final words = RecoveryWords.encode(key, list);
      expect(words.split(' '), hasLength(21));
      expect(RecoveryWords.looksLikeWords(words), isTrue);
      expect(RecoveryWords.decode(words, list), key);
      expect(RecoveryWords.decode('  ${words.toUpperCase()}\n', list), key);
    }
  });

  test('a changed, swapped, missing or unknown word is refused', () {
    final key = Uint8List.fromList(List.generate(32, (i) => i * 7 % 256));
    final words = RecoveryWords.encode(key, list).split(' ');
    var refusedChanges = 0;
    for (var i = 0; i < words.length; i++) {
      final changed = [...words]
        ..[i] = list[(list.indexOf(words[i]) + 1) % 7776];
      try {
        RecoveryWords.decode(changed.join(' '), list);
      } on FormatException {
        refusedChanges++;
      }
    }
    // One check byte: a single changed word slips through 1 time in 256.
    expect(refusedChanges, greaterThanOrEqualTo(20));
    final swapped = [...words]
      ..[3] = words[4]
      ..[4] = words[3];
    expect(
      () => RecoveryWords.decode(swapped.join(' '), list),
      throwsFormatException,
    );
    expect(
      () => RecoveryWords.decode(words.take(20).join(' '), list),
      throwsFormatException,
    );
    expect(
      () =>
          RecoveryWords.decode(([...words]..[0] = 'quietake').join(' '), list),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Word 1 is not in the word list',
        ),
      ),
    );
    // The largest word 21 times is above 2^264.
    expect(
      () => RecoveryWords.decode(List.filled(21, list.last).join(' '), list),
      throwsFormatException,
    );
    expect(RecoveryWords.looksLikeWords('8BnF 1gDk ekIo 7e27'), isFalse);
    expect(
      RecoveryWords.looksLikeWords(List.filled(11, 'AAAA').join(' ')),
      isFalse,
    );
    expect(RecoveryWords.looksLikeWords(words.take(20).join(' ')), isTrue);
  });

  test('list numbers between the words are ignored', () {
    final key = Uint8List.fromList(List.generate(32, (i) => 255 - i));
    final words = RecoveryWords.encode(key, list).split(' ');
    for (final numbered in [
      [for (final (i, w) in words.indexed) '${i + 1}\u00a0$w'].join('   '),
      [for (final (i, w) in words.indexed) '${i + 1}. $w'].join('\n'),
      [for (final (i, w) in words.indexed) '${i + 1}) $w'].join(' '),
    ]) {
      expect(RecoveryWords.looksLikeWords(numbered), isTrue);
      expect(RecoveryWords.decode(numbered, list), key);
    }
    // A text form with groups of digits stays the text form.
    expect(
      RecoveryWords.looksLikeWords(List.filled(11, '1234').join(' ')),
      isFalse,
    );
  });

  test('frozen vectors: the app and the recovery tool agree on the words', () {
    final vectors =
        (jsonDecode(File('docs/recovery-vectors/words.json').readAsStringSync())
                as Map<String, dynamic>)['cases']
            as List;
    expect(vectors, isNotEmpty);
    for (final vector in vectors.cast<Map<String, dynamic>>()) {
      final key = base64Decode(vector['recovery_key'] as String);
      expect(RecoveryWords.encode(key, list), vector['words']);
      expect(RecoveryWords.decode(vector['words'] as String, list), key);
    }
  });
}
