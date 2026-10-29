# Contributing

Open an issue or discussion before substantial changes. Keep patches small and
include a failing reproduction for bugs or behavior tests for new features.

Run `flutter analyze` and `flutter test`. For recovery changes, run Go formatting,
vet, tests and `dart run tool/check_interop.dart`. App UI and vault changes also
need the guarded Android and iOS synthetic device suites. Read AGENTS.md for data
protection rules. Never include real media, credentials, recovery keys or logs
containing personal information in reports.

Contributions are made under GPL-3.0-only. Identify third-party code and its license.

Website changes need no package installation: run
`python3 -m http.server 8000 --directory website`, inspect desktop and mobile
layouts, and check navigation. GitHub Actions publishes only `website/`.
