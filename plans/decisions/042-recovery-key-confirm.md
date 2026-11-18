# 042 Setup asks for one word of the saved recovery key

Status: accepted as the default 2026-11-18 (review item R49; the owner has not seen the wording).
Being built.

## Problem

The recovery key screen at Setup ends with one button, "I saved it". One tap passes it. A person
who taps through has no recovery key, and the app is built so that nothing else can reset the
passcode.

## Decision

- At Setup, "I saved it" leads to a second step on the same screen. The key is no longer shown.
  The step asks for one word of the saved copy, picked at random: "Type word 14".
- The step also accepts the whole key, as words or as text, so a person who saved it in a
  password manager can paste it instead of counting words.
- A wrong answer shows a message and stays on the step. "Show the key again" goes back to the
  key; the next try asks for a newly picked word.
- There is no way to skip the step. Nothing is stored until it passes (decision 038 already
  writes the keyfile only after the recovery screen is done).
- The recovery screen shows the words numbered, so "word 14" can be found on paper and on the
  screen. Entry fields and the recovery tool ignore list numbers (`7`, `7.`, `7)`), so a copied
  numbered list still works.
- "Show recovery key" in Settings shows the same numbered words but asks nothing back.

## Why one word

Wallet apps ask for two to four words. One word is enough to stop a tap-through and to make
the person look at the saved copy once; more words add typing on a phone keyboard without
proving more. The check is a nudge, not proof: someone can go back, read the word and return.

## Limits and open points

- The step proves that a copy exists at that moment, not that it is complete or kept safe.
  "Check my recovery key" in Settings remains the full check.
- The wording is a draft for the owner; translations (de, es, fr) are drafts.
- The typed word is shown in clear, like the key on the screen before it.
