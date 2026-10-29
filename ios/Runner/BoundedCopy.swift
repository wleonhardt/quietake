import Foundation

/// Why a private copy stopped; callers choose the user-facing words.
enum BoundedCopyError: Error {
  case cancelled
  case limit
  case io
}

/// Streams `source` into `target` in 64 KiB steps, stopping at `limit` bytes
/// or when `isCancelled` turns true. Returns the bytes copied. The caller owns
/// security-scoped access and removes `target` on failure.
func copyBounded(from source: URL, to target: URL, limit: Int, isCancelled: () -> Bool) throws -> Int {
  guard let input = InputStream(url: source), let output = OutputStream(url: target, append: false) else {
    throw BoundedCopyError.io
  }
  input.open(); output.open()
  defer { input.close(); output.close() }
  var buffer = [UInt8](repeating: 0, count: 64 * 1024)
  var total = 0
  while true {
    if isCancelled() { throw BoundedCopyError.cancelled }
    let read = input.read(&buffer, maxLength: buffer.count)
    if read == 0 { break }
    guard read > 0 else { throw BoundedCopyError.io }
    total += read
    guard total <= limit else { throw BoundedCopyError.limit }
    try buffer.withUnsafeBufferPointer { bytes in
      var written = 0
      while written < read {
        let n = output.write(bytes.baseAddress! + written, maxLength: read - written)
        guard n > 0 else { throw BoundedCopyError.io }
        written += n
      }
    }
  }
  return total
}
