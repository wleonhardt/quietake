import 'dart:typed_data';

import 'package:crypto/crypto.dart';

enum RecoveryWordsProblem { count, unknownWord, wrong }

/// Why typed words were refused. [position] is the 1-based word for
/// [RecoveryWordsProblem.unknownWord]; no message repeats a word.
class RecoveryWordsException extends FormatException {
  const RecoveryWordsException(this.problem, super.message, {this.position});
  final RecoveryWordsProblem problem;
  final int? position;
}

/// The recovery key written as words (decision 041): the 32 key bytes and one
/// check byte, as a 21-digit number in base 7776, most significant digit
/// first, each digit a word of the bundled EFF long list. The check byte is
/// the first byte of SHA-256 of the key, so a wrong or misplaced word is
/// noticed before the key is tried. The base64 form stays valid everywhere.
class RecoveryWords {
  const RecoveryWords._();

  static const wordCount = 21;
  static const _keyBytes = 32;

  static final _listNumber = RegExp(r'^\d+[.)]?$');

  /// The typed words in lower case, without list numbers such as `7`, `7.`
  /// or `7)`: the recovery screen shows the words numbered (decision 042).
  static List<String> wordsOf(String text) => text
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((token) => !_listNumber.hasMatch(token))
      .toList();

  /// True when [text] is meant as the word form. The base64 form has at most
  /// eleven groups, so more tokens than that are words, and a miscounted list
  /// of words gets the word form's own message.
  static bool looksLikeWords(String text) => wordsOf(text).length > 11;

  static String encode(Uint8List key, List<String> list) {
    if (key.length != _keyBytes) throw ArgumentError.value(key.length, 'key');
    var number = BigInt.zero;
    for (final byte in [...key, sha256.convert(key).bytes.first]) {
      number = (number << 8) | BigInt.from(byte);
    }
    final base = BigInt.from(list.length);
    final words = List.filled(wordCount, '');
    for (var i = wordCount - 1; i >= 0; i--) {
      words[i] = list[(number % base).toInt()];
      number ~/= base;
    }
    return words.join(' ');
  }

  /// The key bytes, or a [RecoveryWordsException].
  static Uint8List decode(String text, List<String> list) {
    final tokens = wordsOf(text);
    if (tokens.length != wordCount) {
      throw const RecoveryWordsException(
        RecoveryWordsProblem.count,
        'The recovery key has 21 words',
      );
    }
    final index = {for (var i = 0; i < list.length; i++) list[i]: i};
    final base = BigInt.from(list.length);
    var number = BigInt.zero;
    for (var i = 0; i < tokens.length; i++) {
      final digit = index[tokens[i]];
      if (digit == null) {
        throw RecoveryWordsException(
          RecoveryWordsProblem.unknownWord,
          'Word ${i + 1} is not in the word list',
          position: i + 1,
        );
      }
      number = number * base + BigInt.from(digit);
    }
    if (number.bitLength > (_keyBytes + 1) * 8) {
      throw const RecoveryWordsException(
        RecoveryWordsProblem.wrong,
        'These words are not a recovery key',
      );
    }
    final bytes = Uint8List(_keyBytes + 1);
    for (var i = _keyBytes; i >= 0; i--) {
      bytes[i] = (number & BigInt.from(255)).toInt();
      number >>= 8;
    }
    final key = Uint8List.sublistView(bytes, 0, _keyBytes);
    if (sha256.convert(key).bytes.first != bytes[_keyBytes]) {
      bytes.fillRange(0, bytes.length, 0);
      throw const RecoveryWordsException(
        RecoveryWordsProblem.wrong,
        'A word is wrong or in the wrong place; check the 21 words',
      );
    }
    final out = Uint8List.fromList(key);
    bytes.fillRange(0, bytes.length, 0);
    return out;
  }
}
