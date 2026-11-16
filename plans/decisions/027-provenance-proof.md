# 027 Provenance proof

Status: proposed. Waiting for the owner's go or no-go. No code.

## Problem

An owner may want to show that a photo or video existed unaltered at a given time,
without a server or notary. The idea comes from Guardian Project ProofMode and C2PA.

## Proposal

Opt-in setting, off by default. At capture the app records the SHA-256 of the saved
plaintext and the device time in the private catalog as an optional per-item field, so
catalog schema 1 stays readable by older clients. A per-vault Ed25519 signing key is
derived from the master key with libsodium key derivation, so no new secret is stored.
A share can include a small `.proof.json` file holding the hash, time, signature and
public key. Anyone can check the signature and recompute the hash of the shared file.

## Limits to state in the product

- The time is the phone clock and can be wrong or changed. The proof does not show who
  took the photo or that the scene was real; it shows that this vault key signed this
  hash. It does not survive metadata removal, redaction or re-encoding, which change
  the bytes, so it applies to a copy shared unmodified.
- The public key is stable per vault, so every proof from one vault is linkable to the
  others. That works against anonymity and must be explained before the owner turns it on.
- Nothing leaves the phone unless the owner includes the file in a share.

## Needs the owner

- Go or no-go, given the linkability trade-off with the app's privacy goals.
- Wording for the setting, the share option and the privacy policy.
