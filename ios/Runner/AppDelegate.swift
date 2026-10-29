import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let privateImport = PrivateImport()
  private let portableFiles = PortableFiles()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "QuietakePreviews")!
    FlutterMethodChannel(name: "quietake/backup", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { [weak self] call, result in self?.portableFiles.handle(call, result: result) }

    let imports = FlutterMethodChannel(name: "quietake/import", binaryMessenger: registrar.messenger())
    imports.setMethodCallHandler { [self] call, result in privateImport.handle(call, result: result) }
    FlutterMethodChannel(name: "quietake/captures", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        // Dart owns the pending-capture path and passes it; it must stay inside Documents.
        guard call.method == "protect",
              let arguments = call.arguments as? [String: Any],
              let path = arguments["path"] as? String else { result(FlutterMethodNotImplemented); return }
        do {
          let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: false)
            .standardizedFileURL.path
          var directory = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
          guard directory.path.hasPrefix(documents + "/") else {
            result(FlutterError(code: "storage", message: "Pending captures must stay in Documents", details: nil))
            return
          }
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try directory.setResourceValues(values)
          result(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        } catch {
          result(FlutterError(code: "storage", message: "Could not protect pending captures", details: nil))
        }
      }
    let camera = FlutterMethodChannel(name: "quietake/camera", binaryMessenger: registrar.messenger())
    camera.setMethodCallHandler { call, result in
      guard call.method == "requestMicrophone" else {
        result(FlutterMethodNotImplemented)
        return
      }
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        DispatchQueue.main.async { result(granted) }
      }
    }
    let privacy = FlutterMethodChannel(name: "quietake/privacy", binaryMessenger: registrar.messenger())
    SceneDelegate.privacyChannel = privacy
    privacy.setMethodCallHandler { call, result in
      let scene = SceneDelegate.current
      switch call.method {
      case "status": result(scene?.privacyState ?? ["captured": false, "generation": 0])
      case "ready":
        if let generation = call.arguments as? Int { scene?.flutterFrameReady(generation) }
        result(nil)
      #if DEBUG
      case "checkCover": result(scene?.checkCover())
      #endif
      default: result(FlutterMethodNotImplemented)
      }
    }
    let channel = FlutterMethodChannel(name: "quietake/previews", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "video", let args = call.arguments as? [String: Any],
            let raw = args["url"] as? String, let url = URL(string: raw) else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let asset = AVURLAsset(url: url)
          let generator = AVAssetImageGenerator(asset: asset)
          generator.appliesPreferredTrackTransform = true
          generator.maximumSize = CGSize(width: 300, height: 300)
          let frame = try generator.copyCGImage(at: .zero, actualTime: nil)
          guard let bytes = UIImage(cgImage: frame).jpegData(compressionQuality: 0.75) else {
            throw NSError(domain: "preview", code: 1)
          }
          let seconds = CMTimeGetSeconds(asset.duration)
          let duration = seconds.isFinite ? Int(seconds * 1000) : 0
          DispatchQueue.main.async {
            result(["bytes": FlutterStandardTypedData(bytes: bytes), "durationMs": duration])
          }
        } catch {
          DispatchQueue.main.async { result(FlutterError(code: "preview", message: "Video preview unavailable", details: nil)) }
        }
      }
    }
  }
}
