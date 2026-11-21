# Public project plans

| Path | Purpose |
| --- | --- |
| next-up.md | Finite public work queue and completed items |
| review-fixes.md | Ordered queue of fixes from the 2026-11-17 whole-project review, with status and evidence |
| review-log.md | Historical code review and coverage notes moved out of next-up.md |
| open-questions.md | Unresolved and resolved design questions |
| decisions/ | Accepted public architecture decisions |

Decision numbers: public records run 001 to 035 and continue from 041 (owner, 2026-11-18).
Comments in code and tests that cite decisions 036 to 040, and "decision 027" in
`lib/vault/master_key_store.dart`, refer to records from the private history that are not in this
repository: 036 search covers titles and tags only, 037 the application ID, 038 the recovery key
is shown without the clipboard and nothing is saved before it is confirmed, 039 staged MOVE
uploads and no empty-password authentication, 040 a lock stops casting and clears decoded media.
The old 027 says that a live session accepting a recovery key is proof of it.

Use planned, active, blocked, complete or deferred for status. Record evidence
and limits when closing work. Keep credentials and private operational records out.
