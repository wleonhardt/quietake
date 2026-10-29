/// A Cast receiver on the LAN.
class CastDevice {
  const CastDevice(this.id, this.name);

  final String id;
  final String name;
}

/// What the app needs from a casting SDK. `GoogleCastBackend` wraps
/// flutter_chrome_cast; `FakeCastBackend` (test_support) drives the tests.
abstract interface class CastBackend {
  /// Current list of discovered receivers; emits again on every change.
  Stream<List<CastDevice>> get devices;

  /// A connected/connecting receiver has ended its session.
  Stream<void> get disconnected;

  Future<void> startDiscovery();
  Future<void> stopDiscovery();

  /// Opens a session; throws on failure.
  Future<void> connect(CastDevice device);

  /// Tells the receiver to show [url]; [contentType] is `image/jpeg`,
  /// `video/mp4`, etc.
  Future<void> load(Uri url, String contentType, {required String title});

  /// Ends the session and stops playback on the receiver.
  Future<void> disconnect();
}
