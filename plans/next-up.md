# Disposable emulator crash probe

This branch must never merge and does not supply required acceptance checks.
It is based on reviewed public 25961cc. Production code is unchanged.

Run one bounded Linux/API 33 diagnostic experiment with the existing renderer,
memory and emulator build. Attach GDB to the owned emulator with values and core
files disabled, exercise NAS recovery/portable files, then normal development-app
cold launches. Retain stacks and progress, not app data. A clean result means
only that this focused workload did not reproduce the host crash.

Review evidence before changing the production workflow or repeating full CI.
Close this diagnostic PR after evidence collection. The release PR remains
blocked until its own complete required checks pass.
