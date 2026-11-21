# Threat model

Status: written 2026-11-17 from the source as it is. This describes what the code does today, not
a promise. Quietake is pre-release and has had no independent audit (see `SECURITY.md`).

## What Quietake protects

Photos and videos taken or imported in the app, their titles, favorites and tags, and the key
that encrypts them.

## Who it is built against

| Adversary | What they can do | What stops them | What they still learn |
| --- | --- | --- | --- |
| Someone who picks up the phone while the app is locked | Open the app, try passcodes | Captures are encrypted files; the key is wrapped with the passcode (Argon2id); five wrong tries start a delay that doubles | That the app is installed; with the lock screen camera, they can add photos but see none |
| Another app on the phone | Read shared storage and the system photo library | Captures never go to shared storage or the photo library; pending captures stay in private storage | Nothing, unless you share a copy to it |
| The backup server or its operator | Read every backed-up file | Only encrypted containers and the encrypted catalog are uploaded | File sizes, upload times, the number of files, and file names unless random names are on (new uploads use random names) |
| The network between phone and server | Watch or alter traffic | HTTPS only, no redirects, platform certificate checks; every restored file is authenticated before it is adopted | That the phone talks to that server, and how much |
| Someone you share a copy with | Keep and forward the copy | Nothing: a shared copy is a normal file. JPEG copies lose location and other metadata by default; an encrypted share bundle needs its passphrase | Everything in the copy. Video and PNG copies keep their metadata |
| The Cast receiver and the local network | Fetch the media stream while you cast | The stream URL holds a random 128-bit token and exists only during casting; locking stops it | The media you cast, in the clear over local HTTP. Google's Cast SDK also sends its own analytics |
| Someone watching the screen or a screen recording | See what is displayed | Android blocks screenshots and recents previews; iOS covers the app when it is inactive or being recorded | iOS cannot block a still screenshot |

## What it does not protect against

- A phone that is rooted, jailbroken or running malware with the app's privileges. Such software
  can read the key while the vault is unlocked.
- Someone who can use your unlocked app. Locking is quick, but an unlocked app shows everything.
- Losing both the passcode and the recovery key. Nothing can reset them.
- A weak passcode when someone has a copy of the keyfile. The minimum is six characters, and
  Argon2id only slows guessing.
- Concealment. The plain icon reduces casual notice only; the app stays in the app list.

## Known limits in the current code

- Biometric unlock is off unless you turn it on in Settings. When on, the prompt is a check in
  the app: the copy of the key in the platform keystore is not yet itself bound to biometrics.
  See decisions 033 and 043.
- Locking hides the app and clears decoded previews and the cast stream, but the vault key stays
  in memory until the app process ends.
- The library index is one encrypted file of at most 8 MiB, which bounds the library at roughly
  forty thousand captures; a restore from a server accepts the same number.
- Seeking in a video decrypts from the start of the file (see `container-format.md`).
- The recovery key is the vault key itself. Anyone who has it and a copy of the encrypted files
  can read them.

## Where to look

Formats: `container-format.md`, `private-catalog.md`, `portable-backup.md`, `nas-recovery.md`,
`share-bundle.md`, `recovery-key.md`. Structure: `architecture.md`. Reports: `SECURITY.md`.
