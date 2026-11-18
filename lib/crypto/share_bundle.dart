import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

/// A bundle could not be written, or could not be opened because the
/// passphrase is wrong, the file is damaged or it breaks a limit.
class ShareBundleException implements Exception {
  const ShareBundleException(this.message);
  final String message;
  @override
  String toString() => 'ShareBundleException: $message';
}

/// One file to place in a bundle under a neutral [name].
class ShareEntry {
  const ShareEntry(this.name, this.file);
  final String name;
  final File file;
}

/// The `.quietake-share` format of decision 025 option B, specified in
/// docs/share-bundle.md. It uses a share-only passphrase and key, so it never
/// involves the vault master key or the `.shtr` container.
class ShareBundle {
  ShareBundle(this.sodium);

  final SodiumSumo sodium;

  static const magic = [0x53, 0x48, 0x53, 0x42]; // SHSB
  static const version = 1;
  static const defaultChunkSize = 65536;
  static const defaultOps = 3;
  static const defaultMem = 67108864;
  static const maxChunkSize = 1 << 20;
  static const minOps = 1;
  static const maxOps = 3;
  static const minMem = 8192;
  static const maxMem = 256 << 20;
  static const maxPassphraseBytes = 1024;

  /// Most entries a reader extracts. The app writes at most 10; this only stops
  /// a crafted bundle from filling private storage with empty files.
  static const maxEntries = 100;
  static const defaultMaxTotal = 512 << 20;
  static const _marker = 'quietake.share.v1';
  static const _saltBytes = 16;
  static const _headerBytes = 148;

  /// Writes [entries] to [out]. [ops] and [mem] default to the app's cost;
  /// tests lower them. A failed write leaves nothing at [out].
  Future<void> write(
    File out,
    String passphrase,
    List<ShareEntry> entries, {
    int ops = defaultOps,
    int mem = defaultMem,
    int chunkSize = defaultChunkSize,
  }) async {
    _checkPassphrase(passphrase);
    if (chunkSize < 1 || chunkSize > maxChunkSize) {
      throw ArgumentError.value(chunkSize, 'chunkSize');
    }
    _checkKdf(ops, mem);
    final seen = <String>{};
    for (final e in entries) {
      _checkName(e.name);
      if (!seen.add(e.name.toLowerCase())) {
        throw ShareBundleException('duplicate entry name ${e.name}');
      }
    }
    final salt = sodium.randombytes.buf(_saltBytes);
    final nonce = sodium.randombytes.buf(sodium.crypto.secretBox.nonceBytes);
    final shareKey = sodium.crypto.secretStream.keygen();
    SecureKey? wrapKey;
    final part = File('${out.path}.part');
    try {
      wrapKey = await _derive(passphrase, salt, ops, mem);
      final message = Uint8List(utf8.encode(_marker).length + 1 + 32)
        ..setRange(0, _marker.length, utf8.encode(_marker));
      shareKey.runUnlockedSync((bytes) {
        message.setRange(message.length - 32, message.length, bytes);
        return null;
      });
      final wrapped = sodium.crypto.secretBox.easy(
        message: message,
        nonce: nonce,
        key: wrapKey,
      );
      message.fillRange(0, message.length, 0);
      final header = BytesBuilder(copy: false)
        ..add(magic)
        ..addByte(version)
        ..addByte(0)
        ..add(_u32(chunkSize))
        ..add(_u32(ops))
        ..add(_u32(mem))
        ..add(salt)
        ..add(nonce)
        ..add(wrapped);
      final sink = part.openWrite();
      try {
        sink.add(header.takeBytes());
        final cipher = sodium.crypto.secretStream.pushEx(
          messageStream: _chunk(_body(entries), chunkSize),
          key: shareKey,
        );
        // pushEx emits the 24-byte stream header first, then the chunks.
        await for (final c in cipher) {
          sink.add(c.message);
        }
      } finally {
        await sink.close();
      }
      await part.rename(out.path);
    } catch (_) {
      if (part.existsSync()) part.deleteSync();
      rethrow;
    } finally {
      shareKey.dispose();
      wrapKey?.dispose();
    }
  }

  /// Authenticates [bundle] with [passphrase] and writes each entry into
  /// [dest]. Returns the entry names in order. On any failure the files
  /// written so far are deleted.
  Future<List<String>> extract(
    File bundle,
    String passphrase,
    Directory dest, {
    int maxTotal = defaultMaxTotal,
  }) async {
    _checkPassphrase(passphrase);
    final reader = _ByteReader(bundle.openRead());
    SecureKey? wrapKey;
    SecureKey? shareKey;
    final parser = _EntryParser(dest, maxTotal);
    try {
      final header = await reader.take(_headerBytes);
      if (header.length != _headerBytes ||
          !_equals(header.sublist(0, 4), magic) ||
          header[4] != version) {
        throw const ShareBundleException('not a Quietake share bundle');
      }
      final view = ByteData.sublistView(header);
      final chunkSize = view.getUint32(6);
      final ops = view.getUint32(10);
      final mem = view.getUint32(14);
      if (chunkSize < 1 || chunkSize > maxChunkSize) {
        throw const ShareBundleException('unsupported chunk size');
      }
      _checkKdf(ops, mem);
      wrapKey = await _derive(passphrase, header.sublist(18, 34), ops, mem);
      final Uint8List raw;
      try {
        raw = sodium.crypto.secretBox.openEasy(
          cipherText: header.sublist(58, 124),
          nonce: header.sublist(34, 58),
          key: wrapKey,
        );
      } on SodiumException {
        throw const ShareBundleException('wrong passphrase or damaged bundle');
      }
      final marker = utf8.encode(_marker);
      final ok =
          raw.length == marker.length + 1 + 32 &&
          _equals(raw.sublist(0, marker.length), marker) &&
          raw[marker.length] == 0;
      if (!ok) {
        raw.fillRange(0, raw.length, 0);
        throw const ShareBundleException('wrong passphrase or damaged bundle');
      }
      shareKey = SecureKey.fromList(sodium, raw.sublist(marker.length + 1));
      raw.fillRange(0, raw.length, 0);

      final aBytes = sodium.crypto.secretStream.aBytes;
      final streamHeader = header.sublist(124, 148);
      Stream<SecretStreamCipherMessage> cipherChunks() async* {
        yield SecretStreamCipherMessage(streamHeader);
        while (true) {
          final c = await reader.take(chunkSize + aBytes);
          if (c.isEmpty) return;
          yield SecretStreamCipherMessage(c);
          if (c.length < chunkSize + aBytes) return;
        }
      }

      var sawFinal = false;
      try {
        await for (final m in sodium.crypto.secretStream.pullEx(
          cipherStream: cipherChunks(),
          key: shareKey,
        )) {
          if (sawFinal) {
            throw const ShareBundleException('data after final chunk');
          }
          parser.add(m.message);
          sawFinal = m.tag == SecretStreamMessageTag.finalPush;
        }
      } on ShareBundleException {
        rethrow;
      } on Exception {
        // Authentication failure or a stream that ended before FINAL.
        throw const ShareBundleException('bundle is damaged or truncated');
      }
      if (!sawFinal || !parser.atBoundary) {
        throw const ShareBundleException('bundle is truncated');
      }
      return parser.names;
    } catch (_) {
      parser.discard();
      rethrow;
    } finally {
      shareKey?.dispose();
      wrapKey?.dispose();
      await reader.cancel();
    }
  }

  Stream<List<int>> _body(List<ShareEntry> entries) async* {
    for (final e in entries) {
      final nameBytes = utf8.encode(e.name);
      final length = e.file.lengthSync();
      yield [
        ..._u32(nameBytes.length),
        ...nameBytes,
        ...(Uint8List(8)..buffer.asByteData().setUint64(0, length)),
      ];
      var written = 0;
      await for (final bytes in e.file.openRead()) {
        written += bytes.length;
        yield bytes;
      }
      if (written != length) {
        throw ShareBundleException('${e.name} changed while it was read');
      }
    }
  }

  Stream<SecretStreamPlainMessage> _chunk(
    Stream<List<int>> source,
    int chunkSize,
  ) async* {
    var buf = BytesBuilder(copy: false);
    await for (final bytes in source) {
      buf.add(bytes);
      while (buf.length >= chunkSize) {
        final all = buf.takeBytes();
        yield SecretStreamPlainMessage(
          Uint8List.sublistView(all, 0, chunkSize),
        );
        buf = BytesBuilder(copy: false)
          ..add(Uint8List.sublistView(all, chunkSize));
      }
    }
    yield SecretStreamPlainMessage(
      buf.takeBytes(),
      tag: SecretStreamMessageTag.finalPush,
    );
  }

  Future<SecureKey> _derive(
    String passphrase,
    Uint8List salt,
    int ops,
    int mem,
  ) => sodium.runIsolated(
    (keys, pairs) => sodium.crypto.pwhash.callStr(
      outLen: sodium.crypto.secretBox.keyBytes,
      password: passphrase,
      salt: salt,
      opsLimit: ops,
      memLimit: mem,
      alg: CryptoPwhashAlgorithm.argon2id13,
    ),
  );

  static void _checkPassphrase(String passphrase) {
    final n = utf8.encode(passphrase).length;
    if (n < 1 || n > maxPassphraseBytes) {
      throw const ShareBundleException('passphrase length is not supported');
    }
  }

  static void _checkKdf(int ops, int mem) {
    if (ops < minOps || ops > maxOps || mem < minMem || mem > maxMem) {
      throw const ShareBundleException('unsupported key derivation cost');
    }
  }

  /// Names Windows treats as devices whatever their extension.
  static final _windowsDevice = RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\.|$)',
    caseSensitive: false,
  );

  /// Throws unless [name] is a safe neutral entry name.
  static void _checkName(String name) {
    final bytes = utf8.encode(name);
    final bad =
        bytes.isEmpty ||
        bytes.length > 255 ||
        name == '.' ||
        name == '..' ||
        name.endsWith('.') ||
        _windowsDevice.hasMatch(name) ||
        name.runes.any(
          (r) => r < 0x20 || r == 0x7f || r == 0x2f || r == 0x5c || r == 0x3a,
        );
    if (bad) throw ShareBundleException('unsafe entry name');
  }

  static Uint8List _u32(int v) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, v);

  static bool _equals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Splits the authenticated plaintext into entries and writes them to [dest].
class _EntryParser {
  _EntryParser(this.dest, this.maxTotal);

  final Directory dest;
  final int maxTotal;
  final names = <String>[];
  final _seen = <String>{};
  final _written = <File>[];
  final _buf = BytesBuilder(copy: false);
  var _total = 0;
  // 0 name length, 1 name, 2 content length, 3 content
  var _state = 0;
  var _need = 4;
  String _name = '';
  RandomAccessFile? _out;

  bool get atBoundary => _state == 0 && _buf.isEmpty && _out == null;

  void add(Uint8List data) {
    var bytes = data;
    while (bytes.isNotEmpty) {
      if (_state == 3) {
        final n = bytes.length < _need ? bytes.length : _need;
        _out!.writeFromSync(bytes, 0, n);
        _need -= n;
        bytes = Uint8List.sublistView(bytes, n);
        if (_need == 0) _finishEntry();
        continue;
      }
      final take = bytes.length < _need - _buf.length
          ? bytes.length
          : _need - _buf.length;
      _buf.add(Uint8List.sublistView(bytes, 0, take));
      bytes = Uint8List.sublistView(bytes, take);
      if (_buf.length < _need) continue;
      final field = _buf.takeBytes();
      _advance(field);
    }
  }

  void _advance(Uint8List field) {
    switch (_state) {
      case 0:
        final len = ByteData.sublistView(field).getUint32(0);
        if (len < 1 || len > 255) {
          throw const ShareBundleException('bad entry name length');
        }
        _state = 1;
        _need = len;
      case 1:
        try {
          _name = utf8.decode(field);
        } on FormatException {
          throw const ShareBundleException('bad entry name');
        }
        ShareBundle._checkName(_name);
        if (!_seen.add(_name.toLowerCase())) {
          throw const ShareBundleException('duplicate entry name');
        }
        if (_seen.length > ShareBundle.maxEntries) {
          throw const ShareBundleException('too many entries');
        }
        _state = 2;
        _need = 8;
      case 2:
        final length = ByteData.sublistView(field).getUint64(0);
        if (length < 0 || length > maxTotal - _total) {
          throw const ShareBundleException('bundle is larger than allowed');
        }
        _total += length;
        final file = File('${dest.path}/$_name');
        _written.add(file);
        _out = file.openSync(mode: FileMode.writeOnly);
        _state = 3;
        _need = length;
        if (length == 0) _finishEntry();
    }
  }

  void _finishEntry() {
    _out?.closeSync();
    _out = null;
    names.add(_name);
    _state = 0;
    _need = 4;
  }

  void discard() {
    _out?.closeSync();
    _out = null;
    for (final f in _written) {
      if (f.existsSync()) f.deleteSync();
    }
  }
}

/// Pulls a fixed prefix off a byte stream, then reads further fixed blocks.
class _ByteReader {
  _ByteReader(Stream<List<int>> source) : _it = StreamIterator(source);

  final StreamIterator<List<int>> _it;
  Uint8List _carry = Uint8List(0);

  Future<Uint8List> take(int n) async {
    final buf = BytesBuilder(copy: false)..add(_carry);
    while (buf.length < n && await _it.moveNext()) {
      buf.add(_it.current);
    }
    final all = buf.takeBytes();
    if (all.length <= n) {
      _carry = Uint8List(0);
      return all;
    }
    _carry = Uint8List.sublistView(all, n);
    return Uint8List.sublistView(all, 0, n);
  }

  Future<void> cancel() => _it.cancel();
}
