# Next up

## Queue

- In progress: diagnose hosted emulator loss after 20 files / 60 passing cases, then complete required hosted checks. Guest-kernel output and crash-file metadata supplement host diagnostics without publishing memory dumps. Capture and the complete physical development suite passed on follow-up; earlier timeouts remain unexplained evidence.
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
