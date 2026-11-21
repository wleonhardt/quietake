package shtr

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"testing"
)

type wordVectors struct {
	Cases []struct {
		RecoveryKey string `json:"recovery_key"`
		Words       string `json:"words"`
	} `json:"cases"`
}

func loadWordVectors(t *testing.T) wordVectors {
	t.Helper()
	data, err := os.ReadFile("../../../docs/recovery-vectors/words.json")
	if err != nil {
		t.Fatal(err)
	}
	var v wordVectors
	if err := json.Unmarshal(data, &v); err != nil || len(v.Cases) == 0 {
		t.Fatalf("word vectors: %v", err)
	}
	return v
}

func TestWordListIsTheAppAsset(t *testing.T) {
	asset, err := os.ReadFile("../../../assets/passphrases/eff_large_wordlist.txt")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(asset, []byte(wordlistSource)) {
		t.Fatal("the embedded word list differs from the app asset")
	}
	if len(wordIndex()) != 7776 {
		t.Fatalf("word list has %d distinct words", len(wordIndex()))
	}
}

func TestRecoveryWordsMatchFrozenVectors(t *testing.T) {
	for _, c := range loadWordVectors(t).Cases {
		want, err := base64.StdEncoding.DecodeString(c.RecoveryKey)
		if err != nil {
			t.Fatal(err)
		}
		numbered := ""
		for i, word := range strings.Fields(c.Words) {
			numbered += fmt.Sprintf("%d\u00a0%s   ", i+1, word)
		}
		for _, text := range []string{c.Words, "  " + strings.ToUpper(c.Words) + "\n", strings.ReplaceAll(c.Words, " ", "\n"), numbered, strings.ReplaceAll(numbered, "\u00a0", ". ")} {
			key, err := MasterKeyFromRecovery(text)
			if err != nil {
				t.Fatal(err)
			}
			if !bytes.Equal(key[:], want) {
				t.Fatal("words parse to a different key")
			}
		}
		// The base64 form stays valid.
		key, err := MasterKeyFromRecovery(c.RecoveryKey)
		if err != nil || !bytes.Equal(key[:], want) {
			t.Fatalf("base64 form: %v", err)
		}
	}
}

func TestRecoveryWordsRefuseMistakes(t *testing.T) {
	words := strings.Fields(loadWordVectors(t).Cases[2].Words)
	swapped := append([]string{}, words...)
	swapped[3], swapped[4] = swapped[4], swapped[3]
	unknown := append([]string{"quietake"}, words[1:]...)
	for name, tc := range map[string]struct {
		tokens []string
		want   string
	}{
		"swapped":   {swapped, "a word is wrong or in the wrong place; check the 21 words"},
		"missing":   {words[:20], "the recovery key has 21 words"},
		"unknown":   {unknown, "word 1 is not in the word list"},
		"too large": {strings.Fields(strings.Repeat("zoom ", 21)), "these words are not a recovery key"},
	} {
		_, err := MasterKeyFromRecovery(strings.Join(tc.tokens, " "))
		if err == nil || err.Error() != tc.want {
			t.Fatalf("%s: %v", name, err)
		}
	}
}
