# Recovery key

The recovery key is the vault's master key: 32 random bytes. It has two written forms. Both are
the same key, and the app and the recovery tool accept either one.

## Text form

Standard base64 of the 32 bytes (44 characters, ending in `=`), shown in groups of four.
Spaces, line breaks and hyphens are ignored on input. Capital and small letters matter.

## Word form

21 words from the EFF long word list (`assets/passphrases/eff_large_wordlist.txt`, 7776 words,
CC BY 4.0).

1. Append one check byte to the key: the first byte of SHA-256 of the 32 key bytes.
2. Read the 33 bytes as one unsigned big-endian number.
3. Write the number as 21 digits in base 7776, most significant digit first.
4. Digit `d` is word number `d` of the list, counting from 0 in file order (`abacus` is 0).

To read the word form, reverse the steps. Refuse input that is not 21 words, holds a word that
is not in the list, encodes a number of more than 264 bits, or has a wrong check byte. Words are
separated by any whitespace and compared in lower case.

Input with more than eleven whitespace-separated tokens is treated as the word form; the text
form has at most eleven groups.

Test vectors: [recovery-vectors/words.json](recovery-vectors/words.json). The all-zero key is
`abacus` twenty times and then `ahoy`.
