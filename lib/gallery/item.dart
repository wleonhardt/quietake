import 'dart:io';

/// One vault container plus what its name says about it.
class VaultItem {
  VaultItem(this.file);

  final File file;

  late final String name = file.uri.pathSegments.last;

  /// Plaintext extension, e.g. `jpg` from `2026-...Z.jpg.shtr`.
  String get extension {
    final parts = name.split('.');
    return parts.length >= 3 ? parts[parts.length - 2] : '';
  }

  DateTime? get capturedAt {
    final stamp = name
        .replaceFirst(RegExp(r'\.[^.]+\.shtr$'), '')
        .replaceFirstMapped(
          RegExp(r'T(\d{2})-(\d{2})-(\d{2})'),
          (m) => 'T${m[1]}:${m[2]}:${m[3]}',
        );
    return DateTime.tryParse(stamp);
  }

  bool get isVideo => extension == 'mp4' || extension == 'mov';

  String get contentType => switch (extension) {
    'mp4' || 'mov' => 'video/mp4',
    'png' => 'image/png',
    _ => 'image/jpeg',
  };
}
