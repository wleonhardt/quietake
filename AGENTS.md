# Quietake agent operations

Read README.md and plans/next-up.md first. User instructions take priority, then
this file, then accepted records in plans/decisions/.

## Non-negotiable rules

- Run `flutter analyze` and `flutter test` before and after changes. Both must pass.
- Serialize Flutter commands within a checkout.
- Run `cd recover && gofmt -l . && go vet ./... && go test ./...` for recovery changes.
- Run `dart run tool/check_interop.dart` for crypto or recovery changes.
- Run `tool/e2e.sh android` and `tool/e2e.sh ios` for app UI or vault changes.
- Test only synthetic development data. Never install over, clear, or uninstall
  release or legacy application IDs. Use guarded device runners; phone, NAS and
  Cast receiver operations require explicit authorization.
- Keep plaintext within private app storage except explicit sharing and active
  Cast streams. Preserve pending captures until encrypted publication succeeds.
- Keep keys in SecureKey and dispose them. Never log keys or credentials.
- Preserve frozen vectors and the v1 container contract.
- Backup must authenticate ownership and never infer deletion from absence.
- Maintain stable widget keys and behavior-based tests.
- Check plans/decisions/ before structural changes. Project knowledge belongs
  in plans/, not agent memory.
- Never read or publish secrets, signing files, private media, or local build output.

## Before done

Run relevant checks, record limitations, update plans/next-up.md, review the diff,
and commit a small verified change with its purpose. A source test is not proof of
physical device behavior or store readiness.

## Context recovery and layout

Read README.md, plans/next-up.md and relevant docs before resuming work.
`lib/` contains Flutter code; `android/` and `ios/` contain native bridges.
`test/` and `integration_test/` contain host and synthetic device tests.
`recover/` contains the independent Go CLI. `tool/` contains guarded runners.
`docs/` defines formats. `website/` is a buildless GitHub Pages site.
`plans/` holds public project plans only.
