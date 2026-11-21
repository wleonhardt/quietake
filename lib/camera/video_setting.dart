import 'package:camera/camera.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The height a video is recorded at (decision 034). Photos always use the
/// full sensor; only the recording camera follows this.
class VideoSetting {
  const VideoSetting._();
  static const choices = [720, 1080, 2160];
  static const standard = 1080;
  static const _storage = FlutterSecureStorage();
  static const _key = 'camera.videoHeight';

  /// An unreadable or unknown saved value gives [standard].
  static Future<int> load() async {
    try {
      final saved = int.tryParse(await _storage.read(key: _key) ?? '');
      return choices.contains(saved) ? saved! : standard;
    } catch (_) {
      return standard;
    }
  }

  static Future<void> save(int height) {
    if (!choices.contains(height)) throw ArgumentError.value(height, 'height');
    return _storage.write(key: _key, value: '$height');
  }

  /// The camera plugin's preset for [height].
  static ResolutionPreset preset(int height) => switch (height) {
    720 => ResolutionPreset.high,
    2160 => ResolutionPreset.ultraHigh,
    _ => ResolutionPreset.veryHigh,
  };

  /// What people call it.
  static String label(int height) => height == 2160 ? '4K' : '${height}p';
}
