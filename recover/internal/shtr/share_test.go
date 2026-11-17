package shtr

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

type shareVectors struct {
	Passphrase string `json:"passphrase"`
	Cases      []struct {
		Name    string `json:"name"`
		Entries []struct {
			Name    string `json:"name"`
			Content string `json:"content_hex"`
		} `json:"entries"`
		Bundle string `json:"bundle_hex"`
	} `json:"cases"`
}

func loadShare(t *testing.T) shareVectors {
	t.Helper()
	data, err := os.ReadFile("../../../docs/vectors/share.json")
	if err != nil {
		t.Fatal(err)
	}
	var v shareVectors
	if err := json.Unmarshal(data, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func TestShareVectorsOpen(t *testing.T) {
	v := loadShare(t)
	for _, c := range v.Cases {
		bundle, _ := hex.DecodeString(c.Bundle)
		dir := t.TempDir()
		names, err := ExtractShare(bytes.NewReader(bundle), v.Passphrase, dir, 1<<20)
		if err != nil {
			t.Fatalf("%s: %v", c.Name, err)
		}
		if len(names) != len(c.Entries) {
			t.Fatalf("%s: got %v", c.Name, names)
		}
		for i, e := range c.Entries {
			want, _ := hex.DecodeString(e.Content)
			got, err := os.ReadFile(filepath.Join(dir, e.Name))
			if err != nil || names[i] != e.Name || !bytes.Equal(got, want) {
				t.Fatalf("%s: entry %s differs (%v)", c.Name, e.Name, err)
			}
		}
	}
}

func TestShareRejectsDamage(t *testing.T) {
	v := loadShare(t)
	good, _ := hex.DecodeString(v.Cases[2].Bundle)
	try := func(label string, b []byte, pass string, max int64) {
		dir := t.TempDir()
		if _, err := ExtractShare(bytes.NewReader(b), pass, dir, max); err == nil {
			t.Errorf("%s: accepted", label)
		}
		if left, _ := os.ReadDir(dir); len(left) != 0 {
			t.Errorf("%s: left %d files", label, len(left))
		}
	}
	try("wrong passphrase", good, "nope", 1<<20)
	try("over cap", good, v.Passphrase, 100)
	for _, at := range []int{0, 4, 20, 40, 100, 130, 148, 200, len(good) - 1} {
		b := append([]byte(nil), good...)
		b[at] ^= 1
		try("flip", b, v.Passphrase, 1<<20)
	}
	for _, n := range []int{0, 10, 147, 148, 148 + 81, len(good) - 1} {
		try("cut", good[:n], v.Passphrase, 1<<20)
	}
	try("trailing", append(append([]byte(nil), good...), make([]byte, 81)...), v.Passphrase, 1<<20)
	for _, p := range []struct{ at, val int }{{6, 0}, {6, 1<<20 + 1}, {10, 0}, {10, 4}, {14, 8191}, {14, 256<<20 + 1}} {
		b := append([]byte(nil), good...)
		b[p.at], b[p.at+1], b[p.at+2], b[p.at+3] = byte(p.val>>24), byte(p.val>>16), byte(p.val>>8), byte(p.val)
		try("limits", b, v.Passphrase, 1<<20)
	}
}
