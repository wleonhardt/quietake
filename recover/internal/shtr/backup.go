package shtr

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"regexp"
	"unicode/utf8"

	"golang.org/x/crypto/argon2"
	"golang.org/x/crypto/nacl/secretbox"
)

const BackupName = "quietake.recovery.json"
const LegacyBackupName = "tucklight.recovery.json"
const BackupLimit = 4096
const backupMarker = "quietake.nas-recovery.v2\x00"
const legacyBackupMarker = "tucklight.nas-recovery.v1\x00"

// MasterKeyFromBackup opens only the separately versioned server recovery box.
// All memory/CPU/size parameters are checked before the offline KDF is invoked.
func MasterKeyFromBackup(data []byte, passphrase string) (*[32]byte, error) {
	bad := errors.New("backup recovery failed: check passphrase and recovery file")
	if len(data) == 0 || len(data) > BackupLimit || !utf8.Valid(data) || !utf8.ValidString(passphrase) ||
		len(passphrase) > 1024 || utf8.RuneCountInString(passphrase) < 24 {
		return nil, bad
	}
	chars := map[rune]bool{}
	numeric := true
	for _, r := range passphrase {
		if r < 32 || r == 127 {
			return nil, bad
		}
		chars[r] = true
		if r < '0' || r > '9' {
			numeric = false
		}
	}
	if len(chars) < 8 || numeric {
		return nil, bad
	}
	// Tokenize once to reject duplicates and unknown keys, including escaped keys.
	decoder := json.NewDecoder(bytes.NewReader(data))
	token, err := decoder.Token()
	if err != nil || token != json.Delim('{') {
		return nil, bad
	}
	fields := map[string]json.RawMessage{}
	for decoder.More() {
		field, err := decoder.Token()
		if err != nil {
			return nil, bad
		}
		name, ok := field.(string)
		if !ok {
			return nil, bad
		}
		if _, exists := fields[name]; exists {
			return nil, bad
		}
		var value json.RawMessage
		if decoder.Decode(&value) != nil {
			return nil, bad
		}
		fields[name] = value
	}
	if _, err = decoder.Token(); err != nil {
		return nil, bad
	}
	if _, err = decoder.Token(); err != io.EOF || len(fields) != 8 {
		return nil, bad
	}
	var box struct {
		V       int    `json:"v"`
		Purpose string `json:"purpose"`
		KDF     string `json:"kdf"`
		Ops     int    `json:"ops"`
		Mem     int    `json:"mem"`
		Salt    string `json:"salt"`
		Nonce   string `json:"nonce"`
		Wrapped string `json:"wrapped"`
	}
	strict := json.NewDecoder(bytes.NewReader(data))
	strict.DisallowUnknownFields()
	if len(regexp.MustCompile(`"[a-z]+"\s*:`).FindAll(data, -1)) != 8 || strict.Decode(&box) != nil || box.KDF != "argon2id13" || box.Ops != 3 || box.Mem != 268435456 {
		return nil, bad
	}
	marker := backupMarker
	switch {
	case box.V == 2 && box.Purpose == "quietake.nas-recovery":
	case box.V == 1 && box.Purpose == "tucklight.nas-recovery":
		marker = legacyBackupMarker
	default:
		return nil, bad
	}
	salt, e1 := base64.StdEncoding.DecodeString(box.Salt)
	nonceB, e2 := base64.StdEncoding.DecodeString(box.Nonce)
	wrapped, e3 := base64.StdEncoding.DecodeString(box.Wrapped)
	if e1 != nil || e2 != nil || e3 != nil || len(salt) != 16 || len(nonceB) != 24 || len(wrapped) != len(marker)+32+16 || base64.StdEncoding.EncodeToString(salt) != box.Salt || base64.StdEncoding.EncodeToString(nonceB) != box.Nonce || base64.StdEncoding.EncodeToString(wrapped) != box.Wrapped {
		return nil, bad
	}
	password := []byte(passphrase)
	defer clear(password)
	derived := argon2.IDKey(password, salt, 3, 262144, 1, 32)
	defer clear(derived)
	var kek [32]byte
	copy(kek[:], derived)
	defer clear(kek[:])
	var nonce [24]byte
	copy(nonce[:], nonceB)
	message, ok := secretbox.Open(nil, wrapped, &nonce, &kek)
	defer clear(message)
	if !ok || len(message) != len(marker)+32 || !bytes.Equal(message[:len(marker)], []byte(marker)) {
		return nil, bad
	}
	var key [32]byte
	copy(key[:], message[len(marker):])
	return &key, nil
}
