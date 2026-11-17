import AppIntents
import Foundation

/// Raised by the Lock Screen control (decision 028). The intent holds no secret and
/// never unlocks the vault: it only asks the app to lock itself and show the locked
/// camera, which seals each photo to the vault's public key.
enum LockedCameraRequest {
  static let notification = Notification.Name("cam.quietake.lockedCameraRequested")
  /// Set in the app process by the intent; read once by the Dart lock screen.
  static var pending = false

  static func raise() {
    pending = true
    NotificationCenter.default.post(name: notification, object: nil)
  }
}

@available(iOS 18.0, *)
struct OpenLockedCameraIntent: AppIntent {
  static let title: LocalizedStringResource = "Camera"
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    LockedCameraRequest.raise()
    return .result()
  }
}
