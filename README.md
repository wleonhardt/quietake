# Quietake

![Quietake camera icon](assets/brand/quietake.png)

**Capture. Keep. Yours.** A private camera built with Flutter for Android and iOS.

[Website](https://quietake.cam) · [Questions and ideas](https://github.com/wleonhardt/quietake/discussions) · [Bug reports](https://github.com/wleonhardt/quietake/issues)

Quietake captures photos and videos into an encrypted local vault. Organize them
with favorites and tags, optionally back up encrypted files to your own HTTPS
WebDAV server, and recover them with the independent Go recovery tool.

This is development source, not a finished store release or an independently
audited security product. There are no official app downloads yet. Android is the
first release target; iOS development is ongoing.

## Privacy boundaries

- Captures bypass the system photo gallery. Owned camera input remains in private
  durable staging until encrypted saving succeeds, then is deleted.
- A passcode protects the vault key. Optional biometrics use platform storage.
  Save the recovery key separately from the phone and encrypted backup.
  Android locks on activity departure, including first-use camera or microphone
  permission screens; unlock again after responding to continue capturing.
- Backup is optional and stores ciphertext on your own server. File sizes and
  filenames remain visible to that server. Sync does not infer deletion from absence.
- Delete can first move a capture to Recently deleted, encrypted on the phone for
  30 days and still on the NAS. Delete now and expiry remove it for good. A
  Settings switch turns this off.
- Explicit sharing gives the selected recipient an unencrypted copy. JPEG share
  copies keep only their orientation by default: all other EXIF fields, XMP,
  Photoshop data, comments and any data after the image end are removed. PNG and video copies remain
  unchanged, so this is not complete metadata anonymization. The share dialog
  can instead make one encrypted `.quietake-share` bundle with a fresh six-word
  passphrase, shown once; send the passphrase by another route. Import has
  "Open encrypted share", another app can open a `.quietake-share` file with
  Quietake (kept privately until you unlock, then offered in Import), and
  `quietake-recover -share` opens a bundle too.
  The passphrase protects the bundle only as well as it is kept secret.
- The lock screen has a Camera button, shown once the vault has been unlocked
  after this feature shipped. A photo taken there is sealed to a public key
  without the vault key and becomes a normal capture at the next unlock; the
  locked camera shows no library, tags or settings. On Android a Quick Settings
  tile, "Quietake camera", opens the same locked camera (also over the phone
  lock screen); it locks the app first and shows nothing else. On iOS 18 a Lock
  Screen or Control Center control named "Camera" does the same once the phone
  is unlocked.
- Settings can switch the launcher to a plain gray icon (and, on Android, the
  name Tools). This does not hide Quietake from the app list or system settings.
- Casting sends decrypted media over local HTTP to the selected receiver. It is
  not end-to-end encrypted. Locking stops casting and clears decrypted caches.
- Android blocks screenshots through platform protection. iOS hides inactive
  previews and responds to recording; it cannot prevent still screenshots.
- Google Cast SDK has its own analytics and diagnostics. Read Google's
  [SDK disclosure](https://developers.google.com/cast/docs/android_sender/data_disclosure).
- The app's privacy policy is available offline before setup and from Settings.
  Public policy URL: [app privacy policy](https://quietake.cam/app-privacy.html).

## Build and test

CI pins Flutter 3.47.7 / Dart 3.13.5, Temurin JDK 21.0.13+9 and Go 1.27.3.
Android uses SDK 37, NDK 28.2.13676358 and the committed Gradle wrapper. iOS builds
also require macOS, Xcode and CocoaPods. Dependencies are locked in `pubspec.lock`.

```sh
flutter pub get
flutter analyze
flutter test
cd recover
go vet ./...
go test ./...
```

Those commands need no phone or emulator: install [Flutter](https://docs.flutter.dev/get-started/install)
and [Go](https://go.dev/dl/) at the pinned versions and they run on the host. The host suite takes
about two minutes. Changes to app screens or vault code also need the device tests below.

Run Flutter commands sequentially in each checkout. Synthetic device tests use
`tool/e2e.sh android` and `tool/e2e.sh ios`. For focused diagnosis, use
`tool/e2e.sh android integration_test/lock_test.dart`; each file has a five-minute
host deadline plus a two-minute default per-case deadline. Read [AGENTS.md](AGENTS.md) before
device operations. Debug/profile builds use `cam.quietake.app.dev`; release uses
`cam.quietake.app`. Never erase a release or legacy installation for testing.
Release signing is intentionally absent. Never substitute a debug certificate.
App checks run on pull requests and main: host/native/recovery checks, unsigned
bundle inspection and Android integration tests. Signing and Play credentials
are not available to those jobs. A green check does not establish store readiness;
iOS and physical/Play-delivered release checks remain separate gates.

## Recovery and documentation

- [Threat model](docs/threat-model.md)
- [Architecture overview](docs/architecture.md)
- [Recovery CLI](recover/README.md)
- [Container contract](docs/container-format.md)
- [Private catalog](docs/private-catalog.md)
- [Portable encrypted backups](docs/portable-backup.md)
- [NAS passphrase recovery](docs/nas-recovery.md)
- [Identity migration](docs/identity-migration.md)

Frozen synthetic vectors under `docs/vectors/` must never be regenerated.
The public repository begins with a reviewed source snapshot; private operational
records and earlier development history are not included.

## Contributing and licensing

Small, behavior-tested changes are welcome. Explain the problem, preserve privacy
contracts, and include verification. See [CONTRIBUTING.md](CONTRIBUTING.md).
Report vulnerabilities privately through [GitHub security advisories](https://github.com/wleonhardt/quietake/security/advisories/new).

Original source is MPL-2.0. Third-party materials retain their own licenses;
see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
