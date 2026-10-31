# Development process

Status: adopted 2026-10-30. Applicable checks must pass before completion.

## Choose the work and checks

Before an increment, state its deliverable, relevant inputs/checks and expected
expensive runs. Prefer one baseline and one final full local pass per meaningful
input revision, with focused tests during development. Explain any extra full run.

| Changed inputs | Required local evidence |
| --- | --- |
| Prose or buildless website only | Relevant local links/content/schema checks; visual review for changed presentation. No Flutter build, analyzer or device rerun. |
| Tooling/workflow only | Focused behavioral tooling regressions, complete affected tooling suite and workflow lint. Hosted workflow changes retain full CI until selection is proven. |
| App code, assets, dependency/build inputs | Clean Flutter analysis and passing host suite. UI/vault changes require Android/iOS behavior checks; native changes require applicable JVM/device evidence. |
| Crypto/recovery or format inputs | Applicable app checks plus Go formatting/vet/tests and interoperability. Frozen vectors remain unchanged. |
| Signed candidate | Independent committed-source preparation, actual artifact inspection, private backup and required runtime checks. Unsigned CI cannot substitute. |

Reuse a check only when its relevant input tree, test/harness, dependencies,
toolchain and environment are unchanged. Cite its original commit and scope;
do not relabel old evidence as newly run. Unknown impact requires full relevant
checks. Resume, export of identical bytes and status-document edits do not
invalidate runtime evidence. Required GitHub statuses still belong to the actual
tested revision. Existing physical evidence is not Play-delivery proof.

Keep both named required CI jobs present. A tested classifier may select content
checks for an explicit non-app allowlist; missing base history, unknown paths,
app assets and classifier/workflow edits select full checks. A selected step
failure or missing completion must fail the job. Never disable branch protection
or synthesize success to bypass a failure.

Freeze version, dependencies and approved content before signed preparation.
Build once per candidate, retain its hashes/symbols and promote the same artifact.
Changed executable inputs need a new candidate. Never replace earlier archives.

## Diagnose and wait responsibly

- Inspect a failed step once and make one discriminating experiment. Assertion
  failures require diagnosis; do not blindly retry or inflate timeouts. Permit
  one unchanged retry only for documented infrastructure failure. If repeated,
  stop full reruns and bound the next diagnostic experiment to 30 minutes.
- At 45 minutes or 20,000 metered tokens per bounded investigation, whichever
  comes first, report findings, uncertainty and the next experiment before
  expanding scope. Ask before exceeding that investigation budget. If reliable
  attribution is unavailable, say so and use the elapsed-time checkpoint.
- Prefer completion notifications or one existing watch. If fallback polling is
  needed, use at least five minutes after initial setup. Yield when nothing
  independent remains; notify on terminal state, meaningful evidence or required
  input. Do not create status-only work while waiting. Higher-priority tool wait,
  communication and Goal lifecycle requirements take precedence. No unsolicited
  scheduled monitoring or automatic Goal pause is authorized.
- Do not delegate passive monitoring. Additional agents require authorization
  and independent outputs worth their context cost. Read the short current state
  and relevant receipts, not complete histories by default.
- Carry approvals forward. Every gate needs an authority, affected scope and
  evidence; distinguish provider requirements from repository choices. Existing
  approval cannot be expanded to a new protected or distribution operation.

## Bound device tests and narrow retries

Use `tool/e2e.sh android integration_test/lock_test.dart` (or an authorized device
ID) to select explicit files. Selection is validated before device changes; no
arguments still runs all automatic files. Keep lifecycle-dependent cases together
when later cases rely on setup performed by an earlier case.

- Every automatic integration entrypoint uses the shared binding with a two-minute
  per-case deadline. The measured library workflow explicitly allows three minutes;
  the long-video case allows four minutes. Library phase timestamps distinguish
  continuing work from a stalled operation.
- A separate host process limits each file to five minutes, including its native
  build, connection, setup and teardown. Bootstrap builds have fifteen minutes;
  emulator boot and installation waits have two. These are initial budgets, not
  performance promises. Change one only with measured successful-run evidence.
- The host watchdog terminates only its owned process group, escalates after five
  seconds, and exits 124. Heartbeats cannot extend the deadline. The runner stops
  before the next file and restores the original Android wake setting on exit.
- Retain expanded case names and `QUIETAKE_START`, `QUIETAKE_END` and
  `QUIETAKE_TIMEOUT` markers. A live emulator heartbeat is not test progress.
- Do not await a widget frame while paused. Observe background work through bounded
  asynchronous state/storage checks; resume before asserting rendered UI. Check
  that sensitive routes are hidden on the first resumed frame.
- After a hang, first prove watchdog failure/cleanup and run only the affected
  file. Full-suite acceptance follows focused success. Never report a suspected
  cause as confirmed merely because a local retry passes.

Recurring churn and next improvements:

| Observed issue | Current prevention / next measure |
| --- | --- |
| Unlimited integration case/file waits | Two independent deadlines and named progress markers; measure detection latency, not heartbeat count. |
| Native dispatcher continues after a load failure | One file per Flutter invocation and fail-fast shell dispatch. |
| Frame/gesture timing differs between CI and local devices | Resume before frame waits; use deterministic drag geometry and observable page/controller state. |
| AC-reported USB phone sleeps, repeated unlock requests | Hold all-charging stay-awake for the authorized batch, then restore its exact prior value. |
| Permissions disappear during automatic uninstall | Preserve `--no-uninstall`, development identity inspection and protected-package boundaries. |
| Concurrent Flutter commands corrupt generated plugin registration | Serialize builds/tests in each checkout. |
| Full suite repeated for unrelated content or identical exports | Scoped checks and input-bound evidence reuse; require a reason for each repeat. |
| Per-file native builds consume time | Keep the new timing markers. A measured baseline found 25 assemblies totaling 456.6 seconds. Evaluate a small combined-harness/cache experiment only after bounded execution is stable; preserve isolation and compare failure localization. |

## Record once and measure

Keep plans/next-up.md under roughly 100 lines, linking historical evidence instead
of repeating it. Commit verified chunks and material transitions, not unchanged
polls. Preserve failures and unverified limits. Do not turn estimates into passes.

At increment completion record: combined CI runner minutes, full-suite reruns
and reasons, idle polling turns, and attributable metered tokens if available.
Separate parallel runner time from elapsed time and tokens from monetary cost.
After three increments compare with baseline and retain only changes that reduce
work without missing required evidence. Measure build/test duration before
introducing shared caches or a combined integration harness; both remain deferred.

Privacy, secret handling, protected installations, serialized Flutter operations,
source-export boundaries and explicit device/live-service/distribution authority
remain unchanged. No optimization permits deleting user vaults or weakening locks.
