# Offline Android share recipient fixture

This tooling source is outside the app's Android source sets and Flutter assets.
It is never part of a Quietake release. The receiver has no permissions, no
network code and no launcher entry. It reads only granted `content:` URIs after
a one-second delay, then stores byte counts, SHA-256 digests and MIME types in its
own private `receipt.json`. It does not store media or source paths.

Build and validate without installing:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 tool/share_receiver.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tool -p '*_test.py'
```

The builder uses the installed Android SDK and Android Studio JDK. Each standalone
run chooses a fresh `com.example.quietake.sharefixture.run_<random>.dev` identity.
It rejects other package identities and nonempty workspaces before writing.
Signing material is generated only inside the temporary workspace, passed through
a temporary process environment, removed after signing, and never reused from app
credentials. The APK's identity, debugging state, absence of permissions and
signature are checked. The standalone command removes the scratch APK afterward.

The host-driven `tool/share_check.py` runner retains its APK only inside an owned
temporary directory. It requires an Android emulator ID plus `ro.kernel.qemu=1`,
refuses an existing fixture identity, compares sender/recipient UIDs and uses the
fresh validated package. It selects only the exact observed fixture label, with
scrolling derived from the native chooser hierarchy. It verifies byte counts,
SHA-256 and per-file MIME after the delayed read, checks grants remain usable
until returning, then validates sender cleanup. Only its own recipient is removed
in finally; the protected original app path must remain unchanged. Failed probes
close their chooser before terminating. Start from an otherwise idle test emulator.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 tool/share_check.py emulator-5554
PYTHONDONTWRITEBYTECODE=1 python3 tool/share_check.py emulator-5554 --batch
```

Do not run concurrently with other Flutter commands in the checkout. The probe
resets only the development vault and uses public JPEG/MP4/PNG fixtures. It never
selects a contact, network destination or real user media. Never run on a phone.
The SDK builder selects the highest installed stable integer API platform;
preview names such as `android-37.0` would impose a development-OS requirement.

All 24 tooling cases and actual single/mixed-batch separate-UID consumption pass
on 2026-10-27. Build-only success is not evidence of delivery; the driver receipt
and sender assertions are required. See the sharing report in `plans/` for the
native iOS Photos checks and physical-recipient limits.
