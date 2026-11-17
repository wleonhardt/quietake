# 025 Encrypted share

Status: accepted 2026-11-16 (owner): option B, the Quietake share container, as a later step; option A is not chosen. No code yet; B needs a container version decision, frozen vectors and Go support before building.

## Problem

The "Encrypted share" idea sends selected captures as a passphrase-protected archive
instead of plaintext copies. The portable backup format cannot be reused as it is:
its media containers and its ZIP password come from the vault master key, so opening
one would hand the recipient the key to the whole vault. A share needs its own secret.

## Options

A. Standard AES-256 ZIP with a generated passphrase (recommended first step).
   The share dialog offers "Encrypted ZIP". The app writes the selected captures,
   after the usual metadata removal or redaction, into a WinZip AES-256 archive whose
   password is a fresh six-word passphrase from the existing `BackupPassphrase`
   generator. The app shows the passphrase once and the owner sends it by another
   channel. Any ZIP tool with AES support opens it (7-Zip, Keka, many Android file
   managers). Apple's built-in Archive Utility and iOS Files do not open AES ZIPs,
   so iPhone recipients need a third-party app.
   Limits: ZIP hides file contents, not names or sizes; use neutral entry names such
   as `photo-01.jpg`. ZIP AES passphrases can be guessed offline, so the strength is
   the passphrase's six random words, not the cipher.

B. Quietake share container. A new container version with a per-share random key
   wrapped by an Argon2id passphrase, readable by Quietake and the Go recovery tool.
   Stronger and name-hiding, but it is a new format: frozen vectors, Go support,
   documentation and a recipient who has the app. Larger than one iteration.

C. Do nothing. Plaintext share copies with metadata removal and redaction already
   exist.

## Recommendation

Build A, because it works with tools the recipient already has and reuses the
passphrase generator, `archive` package and share pipeline. Keep B as a later step if
recipients using Quietake matter. Either way the vault originals never change and
the temporary archive is deleted after sharing like other share copies.

## Needs the owner

- Go or no-go on A, and whether the iPhone limitation is acceptable.
- Wording for the share dialog and the privacy policy, which says copies are
  unencrypted today.
