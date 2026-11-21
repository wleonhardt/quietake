# 003 Settings storage line

Status: accepted.

## Decision

Settings has a Storage section with one line: the number of capture files on this
phone and their total encrypted size, or "No captures on this phone yet."

## Reasons and limits

- The line counts the files `Vault.list` returns and sums their sizes. It never
  decrypts and reads no catalog data, so it adds no plaintext handling.
- The size is the encrypted container size. Pending-upload counts and a prune
  action are not included: sync state already has its own label, and no cache is
  safe to delete without a separate decision.
- It is read once when Settings opens and is not live.
