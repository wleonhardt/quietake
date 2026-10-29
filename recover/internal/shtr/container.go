package shtr

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"io"

	"golang.org/x/crypto/nacl/secretbox"
)

var Magic = []byte("SHTR")

const (
	Version         = 1
	fixedHeader     = 10
	secretboxNonce  = 24
	wrappedKeyBytes = 32 + 16
	HeaderLength    = fixedHeader + secretboxNonce + wrappedKeyBytes + StreamHeaderBytes // 106
	MaxChunkSize    = 1 << 20                                                            // Processing budget, not the app's default chunk size.
)

var (
	ErrNotContainer = errors.New("not a valid v1 .shtr container")
	ErrWrongKey     = errors.New("master key does not open this container")
	ErrTruncated    = errors.New("container is truncated (no FINAL chunk)")
)

// Decrypt streams the plaintext of a v1 container to w. Fails on a wrong
// key, any tampering, and a missing FINAL chunk.
func Decrypt(r io.Reader, master *[32]byte, w io.Writer) error {
	head := make([]byte, HeaderLength)
	if _, err := io.ReadFull(r, head); err != nil {
		return ErrNotContainer
	}
	if !bytes.Equal(head[:4], Magic) || head[4] != Version {
		return ErrNotContainer
	}
	chunkSize := int(binary.BigEndian.Uint32(head[6:10]))
	if chunkSize <= 0 || chunkSize > MaxChunkSize {
		return errors.New("unsupported chunk size")
	}
	var nonce [24]byte
	copy(nonce[:], head[10:34])
	fileKey, ok := secretbox.Open(nil, head[34:82], &nonce, master)
	if !ok {
		return ErrWrongKey
	}
	st, err := newPull(fileKey, head[82:106])
	if err != nil {
		return err
	}

	cipherChunk := chunkSize + StreamABytes
	buf := make([]byte, cipherChunk)
	for {
		// Read a full ciphertext chunk; a short read means the FINAL chunk.
		n, err := io.ReadFull(r, buf)
		if err == io.EOF {
			return ErrTruncated // stream ended without a FINAL chunk
		}
		last := err == io.ErrUnexpectedEOF
		if err != nil && !last {
			return err
		}
		if last && n < StreamABytes {
			return ErrTruncated
		}
		msg, tag, err := st.pull(buf[:n])
		if err != nil {
			return fmt.Errorf("chunk: %w", err)
		}
		if _, err := w.Write(msg); err != nil {
			return err
		}
		if tag == TagFinal {
			// The format says FINAL carries fewer than chunkSize bytes
			// (docs/container-format.md), and nothing may follow it.
			if len(msg) == chunkSize {
				return errors.New("FINAL chunk is a full chunk")
			}
			var extra [1]byte
			if _, err := io.ReadFull(r, extra[:]); err != io.EOF {
				return errors.New("data after the FINAL chunk")
			}
			return nil
		}
		if last {
			return ErrTruncated
		}
	}
}
