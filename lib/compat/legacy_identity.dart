/// Exact historical names are required to authenticate existing backups.
/// Writers never use them; legacy installations and remote sources stay intact.
abstract final class LegacyIdentity {
  static const catalog = 'tucklight.catalog';
  static const recoveryBox = 'tucklight.recovery.json';
  static const recoveryPurpose = 'tucklight.nas-recovery';
  static const recoveryMarker = 'tucklight.nas-recovery.v1\u0000';

  static void rejectBackupWrites(Iterable<String> names) {
    if (names.any((name) => name == catalog || name == recoveryBox)) {
      throw const FormatException(
        'Legacy backup is read-only. Restore it, then choose a new backup folder.',
      );
    }
  }
}
