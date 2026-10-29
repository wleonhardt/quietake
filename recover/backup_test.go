package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestBackupMaskedPrompt(t *testing.T) {
	data, err := os.ReadFile("../docs/recovery-vectors/v1.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		Passphrase string          `json:"passphrase"`
		Box        json.RawMessage `json:"box"`
	}
	json.Unmarshal(data, &fixture)
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "tucklight.recovery.json"), fixture.Box, 0600)
	var supplied []byte
	key, err := backupMasterKey(dirSource(dir), func(label string) ([]byte, error) {
		if label != "backup passphrase: " {
			t.Fatal("wrong prompt")
		}
		supplied = []byte(fixture.Passphrase)
		return supplied, nil
	})
	if err != nil {
		t.Fatal(err)
	}
	clear(key[:])
	if !bytes.Equal(supplied, make([]byte, len(supplied))) {
		t.Fatal("prompt bytes retained")
	}
	os.WriteFile(filepath.Join(dir, "tucklight.recovery.json"), bytes.Repeat([]byte{'x'}, 4097), 0600)
	if _, err = backupMasterKey(dirSource(dir), func(string) ([]byte, error) { t.Fatal("prompted before size rejection"); return nil, nil }); err == nil {
		t.Fatal("accepted oversize")
	}
}

func TestBackupRejectsAmbiguousIdentityBeforePrompt(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"quietake.recovery.json", "tucklight.recovery.json"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(`{}`), 0600); err != nil {
			t.Fatal(err)
		}
	}
	_, err := backupMasterKey(dirSource(dir), func(string) ([]byte, error) {
		t.Fatal("must reject ambiguous identity before requesting passphrase")
		return nil, nil
	})
	if err == nil {
		t.Fatal("accepted ambiguous recovery identity")
	}
}
