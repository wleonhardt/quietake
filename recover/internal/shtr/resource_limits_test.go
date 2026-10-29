package shtr

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"io"
	"os"
	"testing"
)

func TestContainerRejectsOversizedChunkBudget(t *testing.T) {
	vectors, key := load(t)
	cipher := mustHex(t, vectors.Cases[1].ContainerHex)
	binary.BigEndian.PutUint32(cipher[6:10], (1<<20)+1)
	if err := Decrypt(bytes.NewReader(cipher), key, io.Discard); err == nil {
		t.Fatal("accepted a chunk above the supported processing budget")
	}
	binary.BigEndian.PutUint32(cipher[6:10], 1<<20)
	var plain bytes.Buffer
	if err := Decrypt(bytes.NewReader(cipher), key, &plain); err != nil ||
		!bytes.Equal(plain.Bytes(), mustHex(t, vectors.Cases[1].PlaintextHex)) {
		t.Fatal("supported boundary chunk failed")
	}
}

func TestKeyfileRejectsInvalidCostAndShape(t *testing.T) {
	data, err := os.ReadFile("../../../docs/vectors/keyfile.json")
	if err != nil {
		t.Fatal(err)
	}
	var vector struct {
		Passcode string         `json:"passcode"`
		Keyfile  map[string]any `json:"keyfile"`
	}
	if err := json.Unmarshal(data, &vector); err != nil {
		t.Fatal(err)
	}
	for _, change := range []map[string]any{
		{"ops": 0}, {"mem": 0}, {"ops": 4}, {"mem": (1 << 28) + 1024},
		{"salt": "AA=="}, {"nonce": "AA=="}, {"wrapped": "AA=="},
	} {
		t.Run(firstKey(change), func(t *testing.T) {
			fields := make(map[string]any)
			for key, value := range vector.Keyfile {
				fields[key] = value
			}
			for key, value := range change {
				fields[key] = value
			}
			malformed, err := json.Marshal(fields)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := MasterKeyFromKeyfile(malformed, vector.Passcode); err == nil || err == ErrWrongPasscode {
				t.Fatal("malformed metadata did not produce a validation error")
			}
		})
	}
}

func firstKey(fields map[string]any) string {
	for key := range fields {
		return key
	}
	return ""
}
