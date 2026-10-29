# `.shtr` container format, version 1

One encrypted media file. The NAS cannot read its content, but sees the container name and
length. The app's names include capture time and media extension. The plaintext length can be
calculated exactly from the public header and ciphertext length; v1 does not pad media sizes.

All integers big-endian. Primitives are libsodium 1.0.22:
`crypto_secretbox_xsalsa20poly1305` for key wrapping, `crypto_secretstream_xchacha20poly1305` for
the body.

| Offset | Size | Field |
| --- | --- | --- |
| 0 | 4 | magic `SHTR` |
| 4 | 1 | version = `1` |
| 5 | 1 | reserved = `0` |
| 6 | 4 | `chunkSize` (plaintext bytes per chunk; the app writes 262144) |
| 10 | 24 | secretbox nonce |
| 34 | 48 | file key (32 bytes) encrypted with the master key: `crypto_secretbox_easy`, 16-byte MAC first per libsodium `easy` layout |
| 82 | 24 | secretstream header |
| 106 | … | chunks |

Each chunk is `crypto_secretstream_push` output: plaintext length + 17 bytes (1 tag byte inside the
ciphertext + 16-byte MAC). Chunks carry no additional data.

- Every chunk except the last has exactly `chunkSize` plaintext bytes and tag `MESSAGE`.
- The last chunk has tag `FINAL` and fewer than `chunkSize` plaintext bytes, possibly zero. A
  plaintext whose length is a multiple of `chunkSize` therefore ends with a 17-byte empty FINAL
  chunk. A reader that reaches end of file without a FINAL chunk must reject the file as truncated.

Ciphertext length = 106 + ⌊n / chunkSize⌋ × (chunkSize + 17) + (n mod chunkSize) + 17.

## Processing budgets

The encoding remains v1. Current readers and the app writer support positive chunk sizes
through 1 MiB; the app's default remains 256 KiB. This bounds the buffer allocated from
untrusted header metadata, not the total media size. All historical app-generated files and
frozen vectors remain readable. Keyfile readers validate their field sizes and accept
Argon2id costs from 1–3 operations and 8 KiB–256 MiB before deriving a key. Unsupported
custom parameters fail explicitly; they are never clamped. See decision 014.

## Keys

- Master key: 32 random bytes, generated at setup (or adopted from a legacy install).
  The keyfile wraps it with an Argon2id passcode-derived key; platform secure storage caches it
  for app-level biometric unlock. The recovery key is the master key itself. These mechanisms
  do not change the container format.
- File key: 32 random bytes per file, never reused.

## Random access

To decrypt plaintext byte range `[a, b)`, read chunks `⌊a / chunkSize⌋` through `⌊(b-1) / chunkSize⌋`
sequentially from the stream header. secretstream chains chunks, so seeking still means decrypting
from the first chunk of the file up to the target. Replaying 1 GB at 200 MB/s takes about five
seconds before network and player overhead. If that proves too slow for seeking, version 2 can switch to
independent AEAD chunks with a per-chunk nonce derived from the chunk index.

## Recovery

`recover/` (pure Go) reads this format with only the master key, from a folder or the WebDAV
share. `docs/vectors/containers.json` holds eight containers under a fixed master key and
`keyfile.json` one passcode-wrapped key; both sides test against them (`go test ./...` in
`recover/`, `test/vectors_freeze_test.dart` in the app). v1 is frozen by these vectors: any change
to the layout gets a new version byte and new vector files alongside, never a regeneration.

Implementer's note: libsodium's secretstream authenticates `tagblock || ciphertext || pad ||
adlen || 64+mlen` where the pad length is `(0x10 - 64 + mlen) & 0xf`, i.e. `mlen & 0xf`, not the
distance to the next 16-byte boundary. Chunks whose plaintext length is not a multiple of 16 fail
with the "intuitive" padding.

## Optional NAS recovery envelope

`quietake.recovery.json` separately wraps the same master key under an explicit
strong backup passphrase. It does not change `.shtr` v1, the local keyfile or the
frozen vectors. Its strict schema, fixed derivation cost and public synthetic
Dart/Go fixture are documented in [NAS recovery](nas-recovery.md).
