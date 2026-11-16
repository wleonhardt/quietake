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

/// Lists one chosen folder and copies single files, read-only, into private storage.
/// Kept in this file so the Xcode project needs no new source entry.
final class FolderImportPicker: NSObject, UIDocumentPickerDelegate {
  private var pending: FlutterResult?
  private var folder: URL?
  private var scoped = false
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

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pick": pick(result)
    case "copy":
      guard let arguments = call.arguments as? [String: Any],
            let id = arguments["id"] as? String,
            let directory = arguments["directory"] as? String else {
        result(FlutterError(code: "copy", message: "Could not copy this file", details: nil)); return
      }
      copy(id: id, directory: directory, result: result)
    case "cancel": setCancelled(true); result(nil)
    case "release": release(); result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func release() {
    if scoped { folder?.stopAccessingSecurityScopedResource() }
    folder = nil
    scoped = false
  }

  private func pick(_ result: @escaping FlutterResult) {
    guard pending == nil else { result(FlutterError(code: "busy", message: "Folder import already open", details: nil)); return }
    guard let presenter = SceneDelegate.current?.window?.rootViewController else {
      result(FlutterError(code: "picker", message: "Could not open Files", details: nil)); return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
    picker.allowsMultipleSelection = false
    picker.delegate = self
    setCancelled(false)
    release()
    pending = result
    presenter.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending, let url = urls.first else { pending?(nil); pending = nil; return }
    folder = url
    scoped = url.startAccessingSecurityScopedResource()
    DispatchQueue.global(qos: .userInitiated).async {
      let names = try? FileManager.default.contentsOfDirectory(
        at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
      DispatchQueue.main.async {
        self.pending = nil
        guard let files = names else {
          self.release()
          result(FlutterError(code: "list", message: "Could not read this folder", details: nil)); return
        }
        // Direct children that are files; one past the Dart limit so it can refuse the folder.
        let entries = files
          .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true }
          .prefix(10001)
          .map { ["id": $0.lastPathComponent, "name": $0.lastPathComponent] }
        result(["identity": url.path, "entries": Array(entries)])
      }
    }
  }

  private func copy(id: String, directory: String, result: @escaping FlutterResult) {
    guard let folder = folder, !id.contains("/"), !id.contains("..") else {
      result(FlutterError(code: "closed", message: "Choose the folder again", details: nil)); return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let source = folder.appendingPathComponent(id)
      let suffix = source.pathExtension.lowercased()
      guard ["jpg", "jpeg", "png", "mp4"].contains(suffix) else {
        DispatchQueue.main.async { result(FlutterError(code: "copy", message: "Could not copy this file", details: nil)) }
        return
      }
      let target = URL(fileURLWithPath: directory, isDirectory: true)
      try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
      let output = target.appendingPathComponent(UUID().uuidString).appendingPathExtension(suffix)
      let limit = suffix == "mp4" ? 512 * 1024 * 1024 : 32 * 1024 * 1024
      do {
        _ = try copyBounded(from: source, to: output, limit: limit, isCancelled: { self.isCancelled })
        DispatchQueue.main.async { result(output.path) }
      } catch {
        try? FileManager.default.removeItem(at: output)
        DispatchQueue.main.async { result(FlutterError(code: "copy", message: "Could not copy this file", details: nil)) }
      }
    }
  }
}
