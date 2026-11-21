import AppIntents
import SwiftUI
import WidgetKit

/// Lock Screen and Control Center button that opens Quietake's locked camera
/// (decision 028). The label is "Camera" without the app name, so the control
/// does not reveal the app when the plain icon is on. It holds no secret.
@available(iOS 18.0, *)
struct LockedCameraControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "cam.quietake.app.lockedCamera") {
      ControlWidgetButton(action: OpenLockedCameraIntent()) {
        Label("Camera", systemImage: "camera")
      }
    }
    .displayName("Camera")
    .description("Opens the camera while the vault stays locked.")
  }
}

@main
struct QuietakeControlBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOS 18.0, *) {
      LockedCameraControl()
    }
  }
}
