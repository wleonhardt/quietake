/// Size limits that must move together. A vault that syncs must also be
/// restorable, so the catalog size (which bounds how many captures a vault
/// can track), the capture count a restore accepts and the server listing a
/// restore reads are one set. The recovery tool in `recover/` carries the
/// same numbers; `test/limits_test.dart` compares them.
library;

/// Plaintext size of the encrypted library index. About 190 bytes a capture.
const maxCatalogBytes = 8 * 1024 * 1024;

/// Captures a NAS restore, and the recovery tool, accept from one folder.
const maxBackupCaptures = 40000;

/// Size of a server folder listing that sync and restore will read.
const maxListingBytes = 64 * 1024 * 1024;
