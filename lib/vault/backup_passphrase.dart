import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sodium/sodium_sumo.dart';

/// A minimum policy is not an entropy estimate. Prefer the random generator.
class BackupPassphrase {
  static void validate(String phrase) {
    final chars = phrase.runes.toList();
    if (chars.length < 24 ||
        chars.toSet().length < 8 ||
        utf8.encode(phrase).length > 1024 ||
        chars.any((c) => c < 32 || c == 127) ||
        RegExp(r'^\d+$').hasMatch(phrase)) {
      throw const FormatException(
        'Use at least 24 characters and 8 distinct characters. Prefer six random words; do not use your phone passcode.',
      );
    }
  }

  static Future<List<String>>? _words;
  static Future<List<String>> words() {
    final pending = _words ??= _load();
    // A failed asset read must not disable passphrase generation until restart.
    return pending.catchError((Object error) {
      _words = null;
      throw error;
    });
  }

  static Future<List<String>> _load() async {
    final source = await rootBundle.loadString(
      'assets/passphrases/eff_large_wordlist.txt',
    );
    final words = source
        .trim()
        .split('\n')
        .map((line) => line.trim().split(RegExp(r'\s+')).last)
        .toList();
    if (words.length != 7776 || words.toSet().length != 7776) {
      throw const FormatException('Invalid passphrase word list');
    }
    return words;
  }

  static Future<String> generate(SodiumSumo sodium) async {
    final list = await words();
    while (true) {
      final phrase = List.generate(
        6,
        (_) => list[sodium.randombytes.uniform(list.length)],
      ).join(' ');
      try {
        validate(phrase);
        return phrase;
      } on FormatException {
        // Rare short/repetitive draws must satisfy the same creation policy.
      }
    }
  }
}
