package shtr

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/rand"
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

// TestShareRandomDamage changes up to three random bytes of a bundle. Offset 5
// is reserved and the low byte of the memory cost (offset 17) is rounded down
// by Argon2, so neither changes the key or the content and both are skipped.
func TestShareRandomDamage(t *testing.T) {
	v := loadShare(t)
	good, _ := hex.DecodeString(v.Cases[2].Bundle)
	rng := rand.New(rand.NewSource(20261117))
	for run := 0; run < 150; run++ {
		b := append([]byte(nil), good...)
		for i := rng.Intn(3); i >= 0; i-- {
			at := rng.Intn(len(b))
			if at == 5 || at == 17 {
				at = 6
			}
			b[at] ^= byte(1 + rng.Intn(255))
		}
		dir := t.TempDir()
		if _, err := ExtractShare(bytes.NewReader(b), v.Passphrase, dir, 1<<20); err == nil {
			t.Fatalf("run %d: damaged bundle accepted", run)
		}
		if left, _ := os.ReadDir(dir); len(left) != 0 {
			t.Fatalf("run %d: left %d files", run, len(left))
		}
	}
}

// emptyEntries is the plaintext body of n uniquely named empty entries.
func emptyEntries(n int) []byte {
	var b []byte
	for i := 0; i < n; i++ {
		name := fmt.Sprintf("f-%d.jpg", i)
		b = append(b, 0, 0, 0, byte(len(name)))
		b = append(b, name...)
		b = append(b, make([]byte, 8)...)
	}
	return b
}

func TestShareParserEntryLimit(t *testing.T) {
	run := func(n int) error {
		var written []string
		p := &shareParser{dir: t.TempDir(), max: 1 << 20, seen: map[string]bool{}, written: &written}
		return p.add(emptyEntries(n))
	}
	if err := run(ShareMaxEntries); err != nil {
		t.Fatalf("at the limit: %v", err)
	}
	if err := run(ShareMaxEntries + 1); err == nil {
		t.Fatal("one over the limit was accepted")
	}
}

func TestShareNamesWindowsCannotHold(t *testing.T) {
	for _, name := range []string{"a:b.jpg", "CON", "nul.jpg", "Com1.txt", "LPT9", "photo."} {
		if shareNameOK(name) {
			t.Errorf("accepted %q", name)
		}
	}
	for _, name := range []string{"photo-01.jpg", "video-02.mp4", "console.jpg", "com.jpg", "lpt10.txt", ".hidden"} {
		if !shareNameOK(name) {
			t.Errorf("refused %q", name)
		}
	}
}
