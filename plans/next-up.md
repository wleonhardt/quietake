# Next up

## Queue

- Complete hosted acceptance of scoped CI under [development process](development-process.md).
  Keep both required checks; docs/site-only changes use content checks, while
  app/tooling/workflow and unknown changes retain full validation. Hosted
  content-path success and deliberate-failure proof passed in temporary PR 18;
  full-path acceptance remains in PR 17.
- Validate the 1.0.0+4 successor with offline policy access, Cast 23.0.0 and native
  notices. Source CI passed; Android's final viewer navigation scenario timed
  out after 24 completed files / 81 cases. Test gestures now cross the midpoint
  without relying on release velocity and respect nested photo drag thresholds.
  Six behavioral regressions and all five viewer cases on Android/iOS pass locally;
  final hosted acceptance on the changed candidate remains required.
- Publish the approved hello@quietake.cam policy revision after required checks.
- Finish exact signed-artifact checks, declarations and Play-delivered validation.
  Source and development-device tests do not establish distribution readiness.

## Done

- Source uses MPL 2.0; license/source and native notice access are implemented.
- Current development checks cover lock/privacy, encrypted recovery and synthetic
  receiver disconnection. Preserve their evidence and limitations.
- Release preparation retains immutable artifacts and separate app/upload signing
  identities. Public CI contains no signing or publishing credentials.
