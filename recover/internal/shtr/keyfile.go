package shtr

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"regexp"

	"golang.org/x/crypto/argon2"
	"golang.org/x/crypto/nacl/secretbox"
)

// Keyfile is vault.keyfile.json: the master key wrapped under an Argon2id
// key derived from the passcode (libsodium crypto_pwhash, argon2id13).
type Keyfile struct {
	V       int    `json:"v"`
	KDF     string `json:"kdf"`
	Salt    string `json:"salt"`
	Ops     uint32 `json:"ops"`
	Mem     uint32 `json:"mem"` // bytes, as libsodium reports it
	Nonce   string `json:"nonce"`
	Wrapped string `json:"wrapped"`
}

var ErrWrongPasscode = errors.New("wrong passcode")

// MasterKeyFromKeyfile derives the KEK with Argon2id (parallelism 1, as
// libsodium) and unwraps the master key.
func MasterKeyFromKeyfile(data []byte, passcode string) (*[32]byte, error) {
	var kf Keyfile
	if err := json.Unmarshal(data, &kf); err != nil {
		return nil, err
	}
	if kf.V != 1 || kf.KDF != "argon2id13" {
		return nil, errors.New("unsupported keyfile")
	}
	salt, err := base64.StdEncoding.DecodeString(kf.Salt)
	if err != nil {
		return nil, err
	}
	nonceB, err := base64.StdEncoding.DecodeString(kf.Nonce)
	if err != nil {
		return nil, err
	}
	wrapped, err := base64.StdEncoding.DecodeString(kf.Wrapped)
	if err != nil {
		return nil, err
	}
	if len(salt) != 16 || len(nonceB) != 24 || len(wrapped) != 48 ||
		kf.Ops < 1 || kf.Ops > 3 || kf.Mem < 8192 || kf.Mem > 1<<28 {
		return nil, errors.New("unsupported keyfile parameters")
	}
	kek := argon2.IDKey([]byte(passcode), salt, kf.Ops, kf.Mem/1024, 1, 32)
	var kekA [32]byte
	copy(kekA[:], kek)
	clear(kek)
	defer clear(kekA[:])
	var nonce [24]byte
	copy(nonce[:], nonceB)
	raw, ok := secretbox.Open(nil, wrapped, &nonce, &kekA)
	if !ok {
		return nil, ErrWrongPasscode
	}
	var out [32]byte
	copy(out[:], raw)
	clear(raw)
	return &out, nil
}

var recoverySep = regexp.MustCompile(`[\s-]`)

// MasterKeyFromRecovery parses the recovery key as shown by the app:
// base64 of 32 bytes, in groups of four.
func MasterKeyFromRecovery(s string) (*[32]byte, error) {
	raw, err := base64.StdEncoding.DecodeString(recoverySep.ReplaceAllString(s, ""))
	if err != nil || len(raw) != 32 {
		return nil, errors.New("recovery key is not 32 bytes of base64")
	}
	var out [32]byte
	copy(out[:], raw)
	return &out, nil
}
