package shtr

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"testing"
)

type vectors struct {
	MasterKeyHex string `json:"master_key_hex"`
	RecoveryKey  string `json:"recovery_key"`
	Cases        []struct {
		Name         string `json:"name"`
		ChunkSize    int    `json:"chunk_size"`
		PlaintextHex string `json:"plaintext_hex"`
		ContainerHex string `json:"container_hex"`
	} `json:"cases"`
}

func load(t *testing.T) (vectors, *[32]byte) {
	t.Helper()
	data, err := os.ReadFile("../../../docs/vectors/containers.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(data, &v); err != nil {
		t.Fatal(err)
	}
	key, err := MasterKeyFromRecovery(v.RecoveryKey)
	if err != nil {
		t.Fatal(err)
	}
	if hex.EncodeToString(key[:]) != v.MasterKeyHex {
		t.Fatal("recovery key does not parse to the master key")
	}
	return v, key
}

func mustHex(t *testing.T, s string) []byte {
	t.Helper()
	b, err := hex.DecodeString(s)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

// The vector files are frozen (AGENTS.md). A regenerated set that still
// decrypts would pass the tests below; these digests catch that.
func TestVectorFilesFrozen(t *testing.T) {
	for path, want := range map[string]string{
		"../../../docs/vectors/containers.json":  "2cbd9774cbd93a82e9870d2a4c2acd1aff35998fcc3d3b6dacd7c5e4d0944723",
		"../../../docs/vectors/keyfile.json":     "227bcb2662e936c24cb8bc688d84fadfdc559ba0abc8bea43022c4ed645a3ffe",
		"../../../docs/recovery-vectors/v1.json": "a06ee3fcb6a9a73243be5e8097dc213ce060b40f1ba41554731ea46d19431940",
	} {
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		if got := fmt.Sprintf("%x", sha256.Sum256(data)); got != want {
			t.Fatalf("%s changed: %s", path, got)
		}
	}
}

func TestVectorsDecrypt(t *testing.T) {
	v, key := load(t)
	for _, c := range v.Cases {
		t.Run(c.Name, func(t *testing.T) {
			var out bytes.Buffer
			if err := Decrypt(bytes.NewReader(mustHex(t, c.ContainerHex)), key, &out); err != nil {
				t.Fatal(err)
			}
			if !bytes.Equal(out.Bytes(), mustHex(t, c.PlaintextHex)) {
				t.Fatalf("plaintext mismatch (%d vs %d bytes)", out.Len(), len(c.PlaintextHex)/2)
			}
		})
	}
}

func TestRejects(t *testing.T) {
	v, key := load(t)
	ct := mustHex(t, v.Cases[5].ContainerHex) // three_chunks_tail

	t.Run("wrong key", func(t *testing.T) {
		var other [32]byte
		other[0] = 1
		if err := Decrypt(bytes.NewReader(ct), &other, &bytes.Buffer{}); err != ErrWrongKey {
			t.Fatalf("got %v", err)
		}
	})
	t.Run("flipped byte in a middle chunk", func(t *testing.T) {
		bad := append([]byte(nil), ct...)
		bad[HeaderLength+5] ^= 1
		if err := Decrypt(bytes.NewReader(bad), key, &bytes.Buffer{}); err == nil {
			t.Fatal("accepted tampered data")
		}
	})
	t.Run("flipped byte in the final chunk", func(t *testing.T) {
		bad := append([]byte(nil), ct...)
		bad[len(bad)-1] ^= 1
		if err := Decrypt(bytes.NewReader(bad), key, &bytes.Buffer{}); err == nil {
			t.Fatal("accepted tampered final chunk")
		}
	})
	t.Run("dropped final chunk", func(t *testing.T) {
		cut := ct[:len(ct)-17-17]
		if err := Decrypt(bytes.NewReader(cut), key, &bytes.Buffer{}); err == nil {
			t.Fatal("accepted a truncated container")
		}
	})
	t.Run("reordered chunks", func(t *testing.T) {
		bad := append([]byte(nil), ct...)
		a := bad[HeaderLength : HeaderLength+64+17]
		b := bad[HeaderLength+64+17 : HeaderLength+2*(64+17)]
		tmp := append([]byte(nil), a...)
		copy(a, b)
		copy(b, tmp)
		if err := Decrypt(bytes.NewReader(bad), key, &bytes.Buffer{}); err == nil {
			t.Fatal("accepted reordered chunks")
		}
	})
	t.Run("not a container", func(t *testing.T) {
		if err := Decrypt(bytes.NewReader([]byte("hello")), key, &bytes.Buffer{}); err != ErrNotContainer {
			t.Fatalf("got %v", err)
		}
	})
}

func TestKeyfile(t *testing.T) {
	data, err := os.ReadFile("../../../docs/vectors/keyfile.json")
	if err != nil {
		t.Fatal(err)
	}
	var v struct {
		Passcode string          `json:"passcode"`
		Expected string          `json:"expected_master_key_hex"`
		Keyfile  json.RawMessage `json:"keyfile"`
	}
	if err := json.Unmarshal(data, &v); err != nil {
		t.Fatal(err)
	}
	key, err := MasterKeyFromKeyfile(v.Keyfile, v.Passcode)
	if err != nil {
		t.Fatal(err)
	}
	if hex.EncodeToString(key[:]) != v.Expected {
		t.Fatal("keyfile unwrapped to the wrong master key")
	}
	if _, err := MasterKeyFromKeyfile(v.Keyfile, "nope"); err != ErrWrongPasscode {
		t.Fatalf("got %v", err)
	}
}
