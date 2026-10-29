// Package shtr reads Quietake .shtr containers with nothing but the master
// key. It is deliberately independent of libsodium: a pure-Go reimplementation
// of crypto_secretstream_xchacha20poly1305 (pull side) and crypto_secretbox,
// checked against vectors produced by the app (docs/vectors).
package shtr

import (
	"crypto/subtle"
	"encoding/binary"
	"errors"

	"golang.org/x/crypto/chacha20"
	"golang.org/x/crypto/poly1305"
)

const (
	StreamKeyBytes    = 32
	StreamHeaderBytes = 24
	StreamABytes      = 17 // 1 tag byte + 16 byte MAC

	TagMessage = 0
	TagPush    = 1
	TagRekey   = 2
	TagFinal   = 3
)

var ErrBadMAC = errors.New("secretstream: authentication failed")

// pullState mirrors libsodium's crypto_secretstream_xchacha20poly1305_state.
type pullState struct {
	k     [32]byte
	nonce [12]byte // counter (4 bytes LE) || inonce (8 bytes)
}

func newPull(key, header []byte) (*pullState, error) {
	if len(key) != StreamKeyBytes || len(header) != StreamHeaderBytes {
		return nil, errors.New("secretstream: bad key or header length")
	}
	sub, err := chacha20.HChaCha20(key, header[:16])
	if err != nil {
		return nil, err
	}
	s := &pullState{}
	copy(s.k[:], sub)
	binary.LittleEndian.PutUint32(s.nonce[:4], 1)
	copy(s.nonce[4:], header[16:24])
	return s, nil
}

func (s *pullState) stream(counter uint32, dst, src []byte) error {
	c, err := chacha20.NewUnauthenticatedCipher(s.k[:], s.nonce[:])
	if err != nil {
		return err
	}
	c.SetCounter(counter)
	c.XORKeyStream(dst, src)
	return nil
}

var pad0 [16]byte

// pull decrypts one chunk (tag byte, ciphertext, MAC) and returns the
// plaintext and tag. No additional data is used by Quietake.
func (s *pullState) pull(in []byte) (msg []byte, tag byte, err error) {
	if len(in) < StreamABytes {
		return nil, 0, errors.New("secretstream: chunk too short")
	}
	mlen := len(in) - StreamABytes
	c := in[1 : 1+mlen]
	mac := in[1+mlen:]

	var block [64]byte
	if err := s.stream(0, block[:], block[:]); err != nil {
		return nil, 0, err
	}
	var polyKey [32]byte
	copy(polyKey[:], block[:32])
	h := poly1305.New(&polyKey)
	defer clear(polyKey[:])
	defer clear(block[:])

	// ad is empty: update(nothing), pad(16 - 0) & 0xf = 0 bytes.
	block = [64]byte{}
	block[0] = in[0]
	if err := s.stream(1, block[:], block[:]); err != nil {
		return nil, 0, err
	}
	tag = block[0]
	block[0] = in[0]
	h.Write(block[:])

	h.Write(c)
	// libsodium pads with (0x10 - sizeof block + mlen) & 0xf, which is mlen & 0xf,
	// not the distance to the next 16-byte boundary. Keep the quirk.
	h.Write(pad0[:mlen&0xf])
	var slen [8]byte
	binary.LittleEndian.PutUint64(slen[:], 0) // adlen
	h.Write(slen[:])
	binary.LittleEndian.PutUint64(slen[:], uint64(64+mlen))
	h.Write(slen[:])
	var want [16]byte
	h.Sum(want[:0])
	if subtle.ConstantTimeCompare(want[:], mac) != 1 {
		return nil, 0, ErrBadMAC
	}

	msg = make([]byte, mlen)
	if err := s.stream(2, msg, c); err != nil {
		return nil, 0, err
	}

	// State update: inonce ^= mac[:8]; counter++; rekey on wrap or REKEY tag.
	for i := 0; i < 8; i++ {
		s.nonce[4+i] ^= mac[i]
	}
	ctr := binary.LittleEndian.Uint32(s.nonce[:4]) + 1
	binary.LittleEndian.PutUint32(s.nonce[:4], ctr)
	if tag&TagRekey != 0 || ctr == 0 {
		s.rekey()
	}
	return msg, tag, nil
}

// rekey follows libsodium: new_key_and_inonce = k || inonce XOR stream(nonce, k).
func (s *pullState) rekey() {
	var buf [32 + 8]byte
	copy(buf[:32], s.k[:])
	copy(buf[32:], s.nonce[4:])
	_ = s.stream(0, buf[:], buf[:])
	copy(s.k[:], buf[:32])
	copy(s.nonce[4:], buf[32:])
	binary.LittleEndian.PutUint32(s.nonce[:4], 1)
}
