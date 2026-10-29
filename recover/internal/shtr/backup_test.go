package shtr

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"golang.org/x/crypto/argon2"
	"golang.org/x/crypto/nacl/secretbox"
	"os"
	"testing"
)

func TestBackupEnvelope(t *testing.T) {
	data, err := os.ReadFile("../../../docs/recovery-vectors/v1.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		PublicKey  string          `json:"public_key"`
		Passphrase string          `json:"passphrase"`
		Box        json.RawMessage `json:"box"`
	}
	if err = json.Unmarshal(data, &fixture); err != nil {
		t.Fatal(err)
	}
	key, err := MasterKeyFromBackup(fixture.Box, fixture.Passphrase)
	if err != nil {
		t.Fatal(err)
	}
	expected, _ := base64.StdEncoding.DecodeString(fixture.PublicKey)
	if !bytes.Equal(key[:], expected) {
		t.Fatal("identity mismatch")
	}
	clear(key[:])
	for _, phrase := range []string{"1234", "another river violet paper lantern canyon"} {
		if _, err = MasterKeyFromBackup(fixture.Box, phrase); err == nil {
			t.Fatal("accepted wrong phrase")
		}
	}
	for name, value := range map[string]any{"v": 2, "kdf": "argon2i", "ops": 1, "mem": 1073741824, "nonce": "", "wrapped": "AA==", "extra": true} {
		var box map[string]any
		json.Unmarshal(fixture.Box, &box)
		box[name] = value
		changed, _ := json.Marshal(box)
		if _, err = MasterKeyFromBackup(changed, fixture.Passphrase); err == nil {
			t.Fatalf("accepted %s", name)
		}
	}
	if _, err = MasterKeyFromBackup(bytes.Repeat([]byte{' '}, 4097), fixture.Passphrase); err == nil {
		t.Fatal("accepted oversize")
	}
	for _, name := range []string{"v", "purpose", "kdf", "ops", "mem", "salt", "nonce", "wrapped"} {
		var box map[string]json.RawMessage
		json.Unmarshal(fixture.Box, &box)
		escaped := ""
		for _, r := range name {
			escaped += fmt.Sprintf(`\u%04x`, r)
		}
		duplicate := append([]byte(`{"`+escaped+`":`+string(box[name])+`,`), bytes.TrimSpace(fixture.Box)[1:]...)
		if _, err = MasterKeyFromBackup(duplicate, fixture.Passphrase); err == nil {
			t.Fatalf("accepted escaped duplicate %s", name)
		}
	}
	duplicate := append([]byte(`{"v":1,`), bytes.TrimSpace(fixture.Box)[1:]...)
	if _, err = MasterKeyFromBackup(duplicate, fixture.Passphrase); err == nil {
		t.Fatal("accepted duplicate")
	}
}

func TestQuietakeEnvelopeV2(t *testing.T) {
	const phrase = "synthetic river violet paper lantern canyon"
	salt := make([]byte, 16)
	var nonce [24]byte
	var kek [32]byte
	derived := argon2.IDKey([]byte(phrase), salt, 3, 262144, 1, 32)
	copy(kek[:], derived)
	clear(derived)
	defer clear(kek[:])
	key := bytes.Repeat([]byte{42}, 32)
	message := append([]byte("quietake.nas-recovery.v2\x00"), key...)
	wrapped := secretbox.Seal(nil, message, &nonce, &kek)
	clear(message)
	box := map[string]any{"v": 2, "purpose": "quietake.nas-recovery", "kdf": "argon2id13", "ops": 3, "mem": 268435456, "salt": base64.StdEncoding.EncodeToString(salt), "nonce": base64.StdEncoding.EncodeToString(nonce[:]), "wrapped": base64.StdEncoding.EncodeToString(wrapped)}
	data, _ := json.Marshal(box)
	opened, err := MasterKeyFromBackup(data, phrase)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(opened[:], key) {
		t.Fatal("identity changed")
	}
	clear(opened[:])
	box["v"] = 1
	data, _ = json.Marshal(box)
	if _, err = MasterKeyFromBackup(data, phrase); err == nil {
		t.Fatal("accepted mismatched version and purpose")
	}
}
