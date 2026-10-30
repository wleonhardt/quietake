# Next up

## Queue

- In progress: verify version 1.0.0+4 with offline privacy access, Cast 23.0.0 and complete Google native notices. Local analysis and 439 host cases pass; full iOS passed 81 cases with five expected skips. Authorized synthetic physical-receiver playback, disconnection and manual/Home-return locking pass. Signed-candidate and Play-installed checks remain separate.

- In progress: complete required hosted checks. The latest run passed all 25 Android files / 86 cases and the Source job, but the Android job failed before tests because an emulator-version probe lacked libpulse.so.0. The runner now installs that dependency and requires a successful tracing-setup marker before running tests. Actual traced Linux startup remains to be verified; earlier intermittent emulator losses remain unexplained.
- In progress: publish the requested hello@quietake.cam privacy contact consistently in the public page and bundled policy.
- Planned: complete documented security checks, resolve findings and validate the release on physical devices. Professional independent security review is optional; no independent-audit claim is made.
- Planned: finalize store privacy disclosures, signing and distribution.

## Done

- NAS recovery benchmarking measures three synthetic wrap/open samples at the fixed 256 MiB Argon2id cost and verifies key preservation. Device profile checks pass; timing does not establish suitability on every supported phone.
- The device test runner keeps wired phones awake even when charging is reported as AC, then restores the prior setting on success or failure.
- Version 1.0.0+3 source passed its required hosted checks and isolated native regression validation. Further device and distribution gates remain.

- The container reader rejects wrapped-key-only truncation before backup adoption; regressions cover every truncated empty-file prefix and preserve local/remote originals.
- Android user-leave hints enter the existing privacy gate before a rapid Home return; host regression and normal development emulator checks pass. First-use permission activities also lock, requiring unlock after a response.
- Corrected release candidate source declares version 1.0.0+2; signing and distribution remain separate gates.
- Original source uses MPL 2.0; Settings includes its license and source location.

- Existing license notices are accessible from Settings without configuring NAS recovery.
- Required source/unsigned-bundle and Android integration CI gates are configured; each new source revision requires fresh checks.
- JPEG sharing erases indexed EXIF GPS values while preserving originals and orientation.
- Bundle inspection rejects partially signed archives; store icon export preserves RGBA format.
- Public source snapshot and static project website prepared.
