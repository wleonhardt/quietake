package shtr

import (
	"bytes"
	"io"
	"testing"
)

// FuzzDecrypt checks that damaged containers fail with an error and never
// panic. Run longer with: go test -fuzz=FuzzDecrypt -fuzztime=60s
func FuzzDecrypt(f *testing.F) {
	vectors, key := load(f)
	for _, c := range vectors.Cases {
		f.Add(mustHex(f, c.ContainerHex))
	}
	f.Fuzz(func(t *testing.T, data []byte) {
		_ = Decrypt(bytes.NewReader(data), key, io.Discard)
	})
}
