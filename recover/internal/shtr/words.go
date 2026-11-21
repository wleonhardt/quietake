package shtr

import (
	"crypto/sha256"
	_ "embed"
	"errors"
	"fmt"
	"math/big"
	"strings"
)

// The EFF long word list, a copy of the app's asset (CC BY 4.0, see NOTICE.md).
//
//go:embed eff_large_wordlist.txt
var wordlistSource string

const recoveryWordCount = 21

func wordIndex() map[string]int64 {
	index := make(map[string]int64, 7776)
	for _, line := range strings.Split(strings.TrimSpace(wordlistSource), "\n") {
		fields := strings.Fields(line)
		index[fields[len(fields)-1]] = int64(len(index))
	}
	return index
}

// masterKeyFromWords parses the word form of the recovery key: the 32 key
// bytes and the first byte of their SHA-256, as 21 base-7776 digits, most
// significant first. Messages never repeat a word.
func masterKeyFromWords(tokens []string) (*[32]byte, error) {
	if len(tokens) != recoveryWordCount {
		return nil, errors.New("the recovery key has 21 words")
	}
	index := wordIndex()
	base := big.NewInt(int64(len(index)))
	number := new(big.Int)
	for i, token := range tokens {
		digit, ok := index[strings.ToLower(token)]
		if !ok {
			return nil, fmt.Errorf("word %d is not in the word list", i+1)
		}
		number.Mul(number, base).Add(number, big.NewInt(digit))
	}
	if number.BitLen() > 33*8 {
		return nil, errors.New("these words are not a recovery key")
	}
	var raw [33]byte
	number.FillBytes(raw[:])
	defer clear(raw[:])
	var out [32]byte
	copy(out[:], raw[:32])
	if sha256.Sum256(out[:])[0] != raw[32] {
		clear(out[:])
		return nil, errors.New("a word is wrong or in the wrong place; check the 21 words")
	}
	return &out, nil
}
