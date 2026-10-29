import Flutter
import UIKit
import UniformTypeIdentifiers

/// Copies only encrypted ZIPs. External input documents remain read-only.
final class PortableFiles: NSObject, UIDocumentPickerDelegate {
  private let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("quietake-backup", isDirectory: true)
  private var pending: FlutterResult?
  private var saving = false
  private let cancellation = NSLock()
  private var cancelled = false
  private var isCancelled: Bool {
    cancellation.lock(); defer { cancellation.unlock() }
    return cancelled
  }
  private func cancel(_ value: Bool) {
    cancellation.lock(); defer { cancellation.unlock() }
    cancelled = value
  }

  override init() { super.init(); try? FileManager.default.removeItem(at: root) }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "cancel" { cancel(true); result(nil); return }
    guard pending == nil else { result(FlutterError(code: "busy", message: "Backup operation still open", details: nil)); return }
    if call.method == "clear" {
      if FileManager.default.fileExists(atPath: root.path) {
        do { try FileManager.default.removeItem(at: root) }
        catch { result(FlutterError(code: "storage", message: "Could not clear backup copies", details: nil)); return }
      }
      result(nil); return
    }
    guard let presenter = SceneDelegate.current?.window?.rootViewController else {
      result(FlutterError(code: "backup", message: "Could not open Files", details: nil)); return
    }
    do {
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      let picker: UIDocumentPickerViewController
      if call.method == "pick" {
        saving = false
        picker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip], asCopy: false)
      } else if call.method == "save" {
        guard let args = call.arguments as? [String: Any], let path = args["path"] as? String,
              URL(fileURLWithPath: path).resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else {
          throw NSError(domain: "backup", code: 1)
        }
        saving = true
        picker = UIDocumentPickerViewController(forExporting: [URL(fileURLWithPath: path)], asCopy: true)
      } else { result(FlutterMethodNotImplemented); return }
      picker.allowsMultipleSelection = false
      picker.delegate = self
      cancel(false)
      pending = result
      presenter.present(picker, animated: true)
    } catch { result(FlutterError(code: "backup", message: "Could not open Files", details: nil)) }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(saving ? false : nil)
    pending = nil
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let callback = pending else { return }
    if saving { pending = nil; callback(true); return }
    guard let source = urls.first, urls.count == 1 else { pending = nil; callback(nil); return }
    let target = root.appendingPathComponent(UUID().uuidString).appendingPathExtension("zip")
    DispatchQueue.global(qos: .userInitiated).async {
      let access = source.startAccessingSecurityScopedResource()
      defer { if access { source.stopAccessingSecurityScopedResource() } }
      do {
        _ = try copyBounded(from: source, to: target, limit: 2 * 1024 * 1024 * 1024, isCancelled: { self.isCancelled })
        DispatchQueue.main.async { self.pending = nil; callback(target.path) }
      } catch {
        try? FileManager.default.removeItem(at: target)
        DispatchQueue.main.async {
          self.pending = nil
          callback(FlutterError(code: "backup", message: "Could not copy encrypted backup. Check storage and retry.", details: nil))
        }
      }
    }
  }
}
