import Flutter
import UIKit
import UniformTypeIdentifiers

/// Security-scoped sources are read-only; only bounded private copies reach Dart.
final class PrivateImport: NSObject, UIDocumentPickerDelegate {
  private let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("quietake-import", isDirectory: true)
  private var pending: FlutterResult?
  private let cancellation = NSLock()
  private var cancelled = false
  private var isCancelled: Bool {
    cancellation.lock(); defer { cancellation.unlock() }
    return cancelled
  }
  private func setCancelled(_ value: Bool) {
    cancellation.lock(); defer { cancellation.unlock() }
    cancelled = value
  }

  override init() {
    super.init()
    try? FileManager.default.removeItem(at: directory)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "cancel" { setCancelled(true); result(nil); return }
    if call.method == "clear" {
      guard pending == nil else { result(FlutterError(code: "busy", message: "Import still open", details: nil)); return }
      do {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
        result(nil)
      } catch { result(FlutterError(code: "storage", message: "Could not clear temporary import copies", details: nil)) }
      return
    }
    guard call.method == "pick" else { result(FlutterMethodNotImplemented); return }
    guard pending == nil else { result(FlutterError(code: "busy", message: "Import already open", details: nil)); return }
    guard let presenter = SceneDelegate.current?.window?.rootViewController else {
      result(FlutterError(code: "picker", message: "Could not open Files", details: nil)); return
    }
    do {
      if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.jpeg, .png, .mpeg4Movie], asCopy: false)
      picker.allowsMultipleSelection = true
      picker.delegate = self
      setCancelled(false)
      pending = result
      presenter.present(picker, animated: true)
    } catch { result(FlutterError(code: "storage", message: "Could not prepare import storage", details: nil)) }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?([])
    pending = nil
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending else { return }
    let target = directory
    DispatchQueue.global(qos: .userInitiated).async {
      var remaining = 512 * 1024 * 1024
      let entries: [[String: String]]
      if urls.count > 20 {
        entries = [["name": "Selection", "error": "Choose up to 20 files."]]
      } else {
        entries = urls.map { source in
          let name = source.lastPathComponent
          if self.isCancelled { return ["name": name, "error": "Cancelled"] }
          let suffix = source.pathExtension.lowercased()
          guard ["jpg", "jpeg", "png", "mp4"].contains(suffix) else {
            return ["name": name, "error": "Use JPEG, PNG or MP4."]
          }
          let access = source.startAccessingSecurityScopedResource()
          defer { if access { source.stopAccessingSecurityScopedResource() } }
          let output = target.appendingPathComponent(UUID().uuidString).appendingPathExtension(suffix)
          let limit = min(remaining, suffix == "mp4" ? 512 * 1024 * 1024 : 32 * 1024 * 1024)
          do {
            let count = try copyBounded(from: source, to: output, limit: limit, isCancelled: { self.isCancelled })
            remaining -= count
            return ["name": name, "path": output.path]
          } catch {
            try? FileManager.default.removeItem(at: output)
            let message: String
            switch error {
            case BoundedCopyError.cancelled: message = "Cancelled"
            case BoundedCopyError.limit: message = "Import size limit exceeded."
            default: message = self.isCancelled ? "Cancelled" : "Could not copy. Check storage and try again."
            }
            return ["name": name, "error": message]
          }
        }
      }
      DispatchQueue.main.async { self.pending = nil; result(entries) }
    }
  }
}
