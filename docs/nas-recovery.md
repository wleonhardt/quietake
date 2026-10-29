# NAS recovery with a backup passphrase

This is optional protection for the existing vault key, separate from the local
unlock passcode. It requires your own HTTPS WebDAV folder and credentials. It
does not add a server or publisher-operated recovery service.

## Enable, change or disable

Complete one successful foreground sync first, then open Settings → Backup
passphrase. Enter the current local passcode, generate six random words or enter
a strong phrase, confirm it and approve saving. Save the phrase separately from
the phone. Generated words come from the attributed EFF long list; app licenses
include its CC BY 4.0 notice. User-written phrases have a minimum policy, not a
verified entropy estimate.

The operation authenticates the remote catalog under the current vault key.
Management requires an exclusive depth-infinity collection write lock, strong
ETags and WebDAV conditional atomic MOVE support. The lock protects the
authenticated catalog and recovery file together. A competing write, lost lock
or changed recovery ETag causes the operation to fail safely. Unknown envelope
versions are preserved. Current local passcode authorizes replacing a supported envelope
even if its previous backup passphrase was forgotten. Capture files, local
passcodes and the independent recovery key do not change.

Disable requires the current passcode and confirmation. It removes only the
current recovery envelope and any owned interrupted staging for that folder;
encrypted captures stay. Ordinary and background sync never recreate it.
Changing or disabling does not rotate the master key or revoke old server
snapshots, downloaded copies or unavailable interrupted staging. Anyone holding
an envelope can try passphrase guesses offline. Keep the independent recovery
key too. Disconnecting backup leaves the remote envelope intact.

## Restore

On a fresh installation, choose Restore from NAS. Enter the saved folder URL,
NAS credentials and separate backup passphrase, then choose and confirm a new
local passcode. The old phone passcode alone cannot recover this backup.

Recovery reads the NAS without uploading or deleting. It authenticates the
envelope, encrypted catalog and every media container before adopting the staged
vault. A metadata-only backup is supported. Restore requires an empty vault;
there is no merge or live identity replacement. Wrong credentials/passphrases,
damaged captures and unsupported schema fail without replacing originals.
The list is bounded to 16 MiB and 10,000 captures. Incoming media is
authenticated incrementally while copying ciphertext into private staging;
malformed media streams and GET error responses are terminated without downloading
their remaining bodies. Unused WebDAV control response bodies are capped at
64 KiB. Valid large backups still need sufficient private disk space. A validated
interrupted adoption finishes on next startup through the existing restore
transaction. Unlock with the new local passcode
afterward. Successful restore may save the connection in protected storage;
Android background upload remains off until enabled explicitly.

The independent Go CLI supports the same envelope from a folder or WebDAV:

```bash
quietake-recover -backup-passphrase-prompt -dir ./vault -out ./restored
```

Only the masked terminal prompt accepts the passphrase. No passphrase argument
or environment option is provided. See [the CLI guide](../recover/README.md).

## Envelope schema 2

Filename: `quietake.recovery.json`. The complete UTF-8 document is at most
4096 bytes. It contains exactly these eight fields, once each; unknown,
duplicate or escaped property names are rejected. JSON integers must be integers,
not floating-point values. Field order and ordinary JSON whitespace are immaterial.

| Field | Required value |
| --- | --- |
| `v` | `2` |
| `purpose` | `"quietake.nas-recovery"` |
| `kdf` | `"argon2id13"` |
| `ops` | `3` |
| `mem` | `268435456` bytes |
| `salt` | Canonical padded standard Base64 of 16 random bytes |
| `nonce` | Canonical padded standard Base64 of 24 random bytes |
| `wrapped` | Canonical padded standard Base64 of the authenticated ciphertext |

Validate the schema, all field sizes and fixed KDF parameters before derivation.
Argon2id version 1.3 uses three iterations, 256 MiB, parallelism one and a
32-byte result. Passphrases are exact UTF-8, without trimming or normalization.
Require at least 24 Unicode scalar values, eight distinct scalars, at most 1024
UTF-8 bytes, no C0/DEL controls, and reject ASCII-only numeric phrases. Creation
also rejects a phrase equal to the current local passcode. The same phrase
policy applies to decoding both supported schemas.

The secretbox plaintext is ASCII `quietake.nas-recovery.v2`, one NUL byte, then
the 32-byte master key. Use XSalsa20-Poly1305 secretbox easy layout, with its
16-byte authentication tag first. The decoded ciphertext length is therefore
73 bytes. Validate the authenticated marker before returning a `SecureKey`.
Dispose derived keys and clear temporary plaintext byte buffers after use.
Managed strings and runtime copies do not guarantee complete memory erasure.

This schema does not change `.shtr` v1 or the local PIN keyfile. Never upload
`vault.keyfile.json` or a raw master key. The independent Dart/Go known-answer
fixture is [recovery-vectors/v1.json](recovery-vectors/v1.json), containing only
public synthetic data. Existing `docs/vectors/` remain frozen.

## Legacy recovery and migration

Readers also accept schema 1 only with its exact `tucklight.nas-recovery` purpose
and authenticated `tucklight.nas-recovery.v1` plus NUL marker (74-byte ciphertext).
Changing the version without its matching purpose is rejected before derivation.
The frozen v1 fixture is retained; new writers emit schema 2. Media container v1
and the encrypted catalog schema remain unchanged.

Explicit restore can read a legacy `tucklight.catalog` and
`tucklight.recovery.json` pair without modifying the source. After authentication,
the restored local catalog is named `quietake.catalog`. Mixed old/new recovery
identities are rejected. Ordinary backup and recovery management reject legacy
collections; configure a fresh backup folder for Quietake. See
[identity migration](identity-migration.md).

## Atomic management and release limits

Acquire an exclusive depth-infinity collection write lock before reading and
authenticating the remote catalog or recovery envelope. Request 300 seconds and
accept only a finite server lease of at most 300 seconds. Reject unsupported,
shared, shallow or malformed lock responses before writing recovery material.
The server must enforce the token on all writes, including staging and cleanup.
Release it best-effort. An accepted interrupted lease expires within its granted
duration; servers returning an unsupported lease are rejected and unlock is
attempted. Loss or expiry must cause finalization to fail rather than bypass
protection. Another client's ordinary backup may wait or retry during management.
A direct successful LOCK response may omit `lockroot` on legacy servers; an
explicit root must match the exact requested collection (decision 033).
Read-only recovery does not need a lock.

Write a random opaque staging name after durably journaling its ownership in
private storage. Finalize initial creation with the collection lock token and
Overwrite:F. For replacement or disable, submit the lock token and existing
recovery-file ETag together in one tagged condition list. Separate tagged lists
are OR, not AND, under [RFC 4918 section 10.4.3](https://www.rfc-editor.org/rfc/rfc4918.html#section-10.4.3).
The exclusive collection lock preserves the catalog identity while that single
condition protects the destination. Disable uses conditional DELETE. Retry
cleanup only for locally recorded staging ownership on its recorded server/user
target; never infer authority from an arbitrary remote filename.

Recovery management shares the foreground/native backup gate and drains before
session key disposal. Captures during the operation queue normal backup afterward.
Locking or backgrounding invalidates an open confirmation and clears the entered
local passcode, including a lock/unlock transition before the next rendered frame.
Returning to the screen requires a new confirmation and passcode entry.

Authentication proves that each supplied container belongs to the recovered key;
it does not prove that the server supplied every capture or its newest version.
A malicious or stale server can omit files or replay valid older snapshots.
The catalog is encrypted organization metadata, not an authenticated complete
inventory. Old copies remain decryptable by anyone with the corresponding key.

The initial fixed cost follows the [libsodium moderate profile](https://doc.libsodium.org/password_hashing/default_phf).
The generator follows [EFF's six-word guidance](https://www.eff.org/dice).
Emulator tests are not a security audit or physical performance calibration.
Independent external review and physical KDF calibration remain release gates.
Servers must enforce exclusive collection locks and conditional MOVE/DELETE.
A server may briefly return weak ETags after writes; management fails safely
until a strong validator is available. Source publication does not establish
store release readiness or compatibility with every WebDAV implementation.
