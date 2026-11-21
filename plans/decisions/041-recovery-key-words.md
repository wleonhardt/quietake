# 041 The recovery key has a word form

Status: accepted 2026-11-18 (owner chose "Add a word form, keep base64 valid"). Built.

## Problem

The recovery key was shown only as 44 base64 characters in groups of four. Copying it to paper
or reading it back is error-prone (`I`/`l`, `0`/`O`, upper and lower case), and a mistyped
character is found only when the key fails to open anything.

## Decision

- The recovery screen shows the key as 21 words. "Show as text" shows the base64 form. Both are
  the same key; either one restores a vault.
- Encoding: the 32 key bytes followed by one check byte (the first byte of SHA-256 of the key)
  are read as one big-endian number and written as 21 digits in base 7776, most significant
  first. Each digit is a word of the EFF long word list, in the list's order. 21 words hold
  271 bits, the key and check byte need 264.
- Every place that takes a recovery key accepts both forms: Setup ("I have a recovery key"),
  restore from a ZIP, "Check my recovery key" in Settings, and the recovery tool (`-key`,
  `-key-prompt`). Input with more than eleven whitespace-separated tokens is read as words; the
  base64 form has at most eleven groups. Words are matched without regard to case.
- A typed word list is refused before the key is tried, with one of three messages: not 21
  words, word N is not in the list, or a word is wrong or in the wrong place (check byte). No
  message repeats a word.
- The entry field stays hidden by default and gains a show button; shown, it grows to four
  lines so the words can be read back.
- The base64 form, the keyfile, containers and every frozen vector are unchanged. The ZIP
  backup password stays the normalized base64 form.

## Why 21 words from the EFF list and not 24

The owner's option said "24 words", the count of a BIP39 phrase for 256 bits. The app already
ships the EFF long word list (7776 words) for backup passphrases. Using it needs no second word
list or licence, gives fewer words to copy, and its words were chosen to be distinct and easy to
spell. The price: the form is not BIP39 and no wallet tool reads it. Nothing in Quietake needs
that. If the owner wants exactly 24 BIP39 words, the codec and vectors are the only parts to
replace; see `plans/open-questions.md`.

## Limits

- One check byte: a single wrong word that is still in the list is caught 255 times in 256. A
  key that passes by chance is still wrong and opens nothing; Setup shows its fingerprint when
  the vault is empty.
- The words are English in every app language.
- A hidden entry field is one line and drops line breaks from pasted text, so words pasted from
  a note that puts each word on its own line run together. The recovery screen therefore shows
  the words as one wrapping line. Showing the field before pasting keeps line breaks.
- The recovery tool embeds a copy of the word list; a Go test compares it with the app asset.
- The translations of the new strings (de, es, fr) are drafts.

## Evidence

Vectors `docs/recovery-vectors/words.json` were written by an independent Python script and are
checked by the Dart codec (`test/recovery_words_test.dart`) and the Go tool
(`recover/internal/shtr/words_test.go`); both freeze tests list the file's digest.
`dart run tool/check_interop.dart` recovers a synthetic vault with the words. Device runs are
listed in `plans/review-fixes.md`.
