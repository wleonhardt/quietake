import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  static var privacyChannel: FlutterMethodChannel?
  static var current: SceneDelegate? {
    UIApplication.shared.connectedScenes.compactMap { $0.delegate as? SceneDelegate }.first
  }
  private var cover: UIView?
  private var coverLabel: UILabel?
  private var frameReady = false
  private var generation = 0
  private(set) var backgrounded = false
  var isCovered: Bool { cover?.superview != nil }
  var captured: Bool { window?.windowScene?.screen.isCaptured ?? false }
  var privacyState: [String: Any] {
    ["screenshotProtected": false, "captured": captured, "covered": isCovered,
     "backgrounded": backgrounded, "generation": generation]
  }

  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    NotificationCenter.default.addObserver(self, selector: #selector(captureChanged(_:)),
      name: UIScreen.capturedDidChangeNotification, object: nil)
    setCovered(true)
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    generation += 1
    frameReady = false
    setCovered(true)
    super.sceneWillResignActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    backgrounded = true
    generation += 1
    frameReady = false
    setCovered(true)
    super.sceneDidEnterBackground(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    captureChanged()
  }

  @objc private func captureChanged(_ notification: Notification? = nil) {
    generation += 1
    frameReady = false
    setCovered(true)
    Self.privacyChannel?.invokeMethod("state", arguments: privacyState)
  }

  func flutterFrameReady(_ expectedGeneration: Int) {
    guard expectedGeneration == generation else { return }
    frameReady = true
    if window?.windowScene?.activationState == .foregroundActive && !captured { backgrounded = false }
    updateCover()
  }

  private func updateCover() {
    setCovered(!frameReady || captured || window?.windowScene?.activationState != .foregroundActive)
  }

  private func setCovered(_ visible: Bool) {
    guard let window = window else { return }
    if visible {
      if cover == nil {
        let view = UIView(frame: window.bounds)
        view.backgroundColor = UIColor(red: 18/255, green: 25/255, blue: 35/255, alpha: 1)
        view.isOpaque = true
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.accessibilityViewIsModal = true
        let label = UILabel(frame: view.bounds.insetBy(dx: 24, dy: 24))
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = UIColor(red: 237/255, green: 243/255, blue: 1, alpha: 1)
        label.textAlignment = .center
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(label)
        cover = view
        coverLabel = label
      }
      cover!.frame = window.bounds
      coverLabel?.text = captured ? "Screen recording or mirroring detected.\nStop it to return to Quietake." : "Quietake"
      window.addSubview(cover!)
      window.bringSubviewToFront(cover!)
    } else {
      cover?.removeFromSuperview()
    }
  }

  #if DEBUG
  // Checks the real UIKit cover without taking or exporting a snapshot.
  func checkCover() -> [String: Bool] {
    setCovered(true)
    let opaque = cover?.isOpaque == true && cover?.superview === window
    let fullSize = cover?.frame == window?.bounds
    updateCover()
    return ["opaque": opaque, "fullSize": fullSize]
  }
  #endif

  deinit { NotificationCenter.default.removeObserver(self) }
}
