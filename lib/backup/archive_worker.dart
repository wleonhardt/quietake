import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as hashes;

/// ZIP work runs away from the UI isolate. Killing it closes its Dart-owned file
/// handles; the caller owns and clears the incomplete private output directory.
Future<void> runArchiveWorker(
  Map<String, Object> job, {
  bool Function()? isCancelled,
  void Function(int, int)? onProgress,
}) async {
  if (isCancelled?.call() == true) throw StateError('Backup cancelled');
  final events = ReceivePort();
  final ended = Completer<void>();
  var completed = false;
  var cancelled = false;
  Object? error;
  final subscription = events.listen((message) {
    if (message is Map && message['done'] == true) completed = true;
    if (message is Map && message['progress'] is int) {
      onProgress?.call(message['progress'] as int, message['total'] as int);
    }
    if (message is Map && message['failed'] == true || message is List) {
      error = FormatException(
        'Encrypted backup failed at ${message is Map ? message['phase'] : 'worker'}',
      );
    }
    if (message == null && !ended.isCompleted) ended.complete();
  });
  Isolate? worker;
  Timer? cancellation;
  try {
    worker = await Isolate.spawn(
      _run,
      (events.sendPort, job),
      onExit: events.sendPort,
      onError: events.sendPort,
      errorsAreFatal: true,
    );
    cancellation = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (isCancelled?.call() == true) {
        cancelled = true;
        worker?.kill(priority: Isolate.immediate);
      }
    });
    await ended.future;
    if (cancelled || isCancelled?.call() == true) {
      throw StateError('Backup cancelled');
    }
    if (error != null || !completed) {
      throw error ?? const FormatException('Backup interrupted');
    }
  } finally {
    cancellation?.cancel();
    worker?.kill(priority: Isolate.immediate);
    await subscription.cancel();
    events.close();
  }
}

void _run((SendPort, Map<String, Object>) request) {
  final (events, job) = request;
  var phase = 'encode';
  try {
    final password = job['password'] as String;
    if (job['encode'] == true) {
      final output = OutputFileStream(job['target'] as String);
      final encoder = ZipEncoder(password: password)
        ..startEncode(output, level: 0);
      try {
        final files = (job['files'] as List).cast<Map>();
        events.send({'progress': 0, 'total': files.length});
        for (var i = 0; i < files.length; i++) {
          final input = InputFileStream(files[i]['path'] as String);
          try {
            encoder.add(
              ArchiveFile.stream(files[i]['entry'] as String, input)
                ..compression = CompressionType.none,
              level: 0,
            );
          } finally {
            input.closeSync();
          }
          events.send({'progress': i + 1, 'total': files.length});
        }
      } finally {
        encoder.endEncode();
        output.closeSync();
      }
    } else {
      final input = InputFileStream(job['source'] as String);
      try {
        phase = 'directory bounds';
        _checkDirectory(input);
        phase = 'directory parse';
        final zip = ZipDirectory()..read(input, password: password);
        final names = <String>{};
        var total = 0;
        if (zip.fileHeaders.isEmpty || zip.fileHeaders.length > 10002) {
          throw const FormatException('Unsupported backup entry count');
        }
        for (final header in zip.fileHeaders) {
          phase = 'entry bounds';
          final name = header.filename;
          final file = header.file!;
          final mode = header.externalFileAttributes >> 16;
          if (!RegExp(r'^(manifest|catalog|item-[0-9]{5})\.shtr$')
                  .hasMatch(name) ||
              file.filename != name ||
              !names.add(name) ||
              (mode & 0xf000 != 0 && mode & 0xf000 != 0x8000) ||
              header.externalFileAttributes & 0x10 != 0 ||
              header.compressionMethod != 99 ||
              file.compressionMethod != CompressionType.none ||
              header.generalPurposeBitFlag & 1 == 0 ||
              header.uncompressedSize < 106 ||
              header.compressedSize != header.uncompressedSize + 28 ||
              (name == 'manifest.shtr' &&
                  header.uncompressedSize > 4 * 1024 * 1024) ||
              (name == 'catalog.shtr' &&
                  header.uncompressedSize > 2 * 1024 * 1024)) {
            throw const FormatException('Unsupported backup entry');
          }
          total += header.uncompressedSize;
          if (total > 2 * 1024 * 1024 * 1024) {
            throw const FormatException('Backup size limit exceeded');
          }
          phase = 'entry authentication';
          _checkAuthentication(input, header, password);
          phase = 'entry copy';
          final stream = file.getStream(decompress: false);
          final output = File('${job['directory']}/$name')
              .openSync(mode: FileMode.writeOnly);
          try {
            var written = 0;
            while (!stream.isEOS) {
              final bytes = stream.readBytes(64 * 1024).toUint8List();
              written += bytes.length;
              if (written > header.uncompressedSize || bytes.isEmpty) {
                throw const FormatException('Invalid backup length');
              }
              output.writeFromSync(bytes);
            }
            if (written != header.uncompressedSize) {
              throw const FormatException('Incomplete backup entry');
            }
            output.flushSync();
          } finally {
            output.closeSync();
          }
          events.send({
            'progress': names.length,
            'total': zip.fileHeaders.length,
          });
        }
      } finally {
        input.closeSync();
      }
    }
    events.send({'done': true});
  } catch (_) {
    // Never send exception values, passwords or private filenames across the UI.
    events.send({'failed': true, 'phase': phase});
  }
}

/// Bound metadata before the library parses it. V1 intentionally excludes ZIP64,
/// comments and split archives; the complete encrypted ZIP is capped at 2 GiB.
void _checkDirectory(InputFileStream input) {
  final length = input.length;
  if (length < 22 || length > 2 * 1024 * 1024 * 1024) {
    throw const FormatException('Backup size limit exceeded');
  }
  final footer = ByteData.sublistView(
    input.subset(position: length - 22, length: 22).toUint8List(),
  );
  if (footer.getUint32(0, Endian.little) != 0x06054b50 ||
      footer.getUint32(4, Endian.little) != 0 ||
      footer.getUint16(20, Endian.little) != 0 ||
      footer.getUint16(8, Endian.little) !=
          footer.getUint16(10, Endian.little) ||
      footer.getUint16(10, Endian.little) > 10002) {
    throw const FormatException('Unsupported backup ZIP');
  }
  final size = footer.getUint32(12, Endian.little);
  final offset = footer.getUint32(16, Endian.little);
  if (size > 4 * 1024 * 1024 || offset + size != length - 22) {
    throw const FormatException('Invalid backup directory');
  }
  // The bounded central directory limits the library's number/string allocations.
  var position = 0;
  var count = 0;
  final directory = ByteData.sublistView(
    input.subset(position: offset, length: size).toUint8List(),
  );
  while (position < size) {
    if (position + 46 > size ||
        directory.getUint32(position, Endian.little) != 0x02014b50) {
      throw const FormatException('Invalid backup directory');
    }
    final name = directory.getUint16(position + 28, Endian.little);
    final extra = directory.getUint16(position + 30, Endian.little);
    final comment = directory.getUint16(position + 32, Endian.little);
    if (name > 64 || extra > 128 || comment != 0 || ++count > 10002) {
      throw const FormatException('Unsupported backup directory');
    }
    _checkLocalHeader(
      input,
      directory.getUint32(position + 42, Endian.little),
      'Invalid local backup header',
    );
    position += 46 + name + extra;
  }
  if (position != size || count != footer.getUint16(10, Endian.little)) {
    throw const FormatException('Incomplete backup directory');
  }
}

/// A local file header must be the 30-byte signature with bounded name and
/// extra lengths; both the directory walk and extraction check it.
ByteData _checkLocalHeader(InputFileStream input, int offset, String message) {
  final local = ByteData.sublistView(
    input.subset(position: offset, length: 30).toUint8List(),
  );
  if (local.lengthInBytes != 30 ||
      local.getUint32(0, Endian.little) != 0x04034b50 ||
      local.getUint16(26, Endian.little) > 64 ||
      local.getUint16(28, Endian.little) > 128) {
    throw FormatException(message);
  }
  return local;
}

class DigestSink implements Sink<hashes.Digest> {
  hashes.Digest? value;
  @override
  void add(hashes.Digest digest) => value = digest;
  @override
  void close() {}
}

/// Check the complete WinZip authentication code before lazy extraction. A view
/// ending at the last plaintext byte need not drive a decoder past its MAC.
void _checkAuthentication(
  InputFileStream input,
  ZipFileHeader header,
  String password,
) {
  final extra = ByteData.sublistView(header.extraField ?? Uint8List(0));
  if (extra.lengthInBytes != 11 ||
      extra.getUint16(0, Endian.little) != 0x9901 ||
      extra.getUint16(2, Endian.little) != 7 ||
      extra.getUint16(4, Endian.little) != 1 ||
      extra.getUint16(6, Endian.little) != 0x4541 ||
      extra.getUint8(8) != 3 ||
      extra.getUint16(9, Endian.little) != 0 ||
      header.compressedSize < 28) {
    throw const FormatException('Expected AES-256 stored backup entries');
  }
  final local = _checkLocalHeader(
    input,
    header.localHeaderOffset,
    'Invalid backup local header',
  );
  final start =
      header.localHeaderOffset +
      30 +
      local.getUint16(26, Endian.little) +
      local.getUint16(28, Endian.little);
  if (start + header.compressedSize > input.length) {
    throw const FormatException('Truncated backup');
  }
  final salt = input.subset(position: start, length: 16).toUint8List();
  final derived = ZipFile.deriveKey(password, salt, derivedKeyLength: 32);
  final digest = DigestSink();
  final sink = hashes.Hmac(
    hashes.sha1,
    derived.sublist(32, 64),
  ).startChunkedConversion(digest);
  final body = input.subset(
    position: start + 18,
    length: header.compressedSize - 28,
  );
  while (!body.isEOS) {
    sink.add(body.readBytes(64 * 1024).toUint8List());
  }
  sink.close();
  final expected = input
      .subset(position: start + header.compressedSize - 10, length: 10)
      .toUint8List();
  var difference = 0;
  for (var i = 0; i < 10; i++) {
    difference |= expected[i] ^ digest.value!.bytes[i];
  }
  if (difference != 0) {
    throw const FormatException('Backup authentication failed');
  }
}
