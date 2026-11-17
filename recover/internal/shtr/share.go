package shtr

import (
	"bytes"
	"encoding/binary"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"unicode/utf8"

	"golang.org/x/crypto/argon2"
	"golang.org/x/crypto/nacl/secretbox"
)

// Share bundle reader, docs/share-bundle.md.
const (
	shareHeader     = 148
	shareMarker     = "quietake.share.v1\x00"
	shareMaxPass    = 1024
	ShareDefaultCap = 512 << 20
)

var ErrShare = errors.New("share bundle: wrong passphrase, damaged or truncated")

func shareNameOK(name string) bool {
	if name == "" || len(name) > 255 || name == "." || name == ".." || !utf8.ValidString(name) {
		return false
	}
	for _, r := range name {
		if r < 0x20 || r == 0x7f || r == '/' || r == '\\' {
			return false
		}
	}
	return true
}

// ExtractShare authenticates a bundle with passphrase and writes its entries
// into dir (which must exist). maxTotal caps the extracted bytes. On any
// failure the files written so far are removed.
func ExtractShare(r io.Reader, passphrase, dir string, maxTotal int64) (names []string, err error) {
	if len(passphrase) < 1 || len(passphrase) > shareMaxPass {
		return nil, errors.New("share bundle: passphrase length is not supported")
	}
	head := make([]byte, shareHeader)
	if _, e := io.ReadFull(r, head); e != nil ||
		!bytes.Equal(head[:4], []byte("SHSB")) || head[4] != 1 {
		return nil, errors.New("not a Quietake share bundle")
	}
	chunkSize := int64(binary.BigEndian.Uint32(head[6:10]))
	ops := binary.BigEndian.Uint32(head[10:14])
	mem := binary.BigEndian.Uint32(head[14:18])
	if chunkSize < 1 || chunkSize > MaxChunkSize || ops < 1 || ops > 3 || mem < 8192 || mem > 256<<20 {
		return nil, errors.New("share bundle: unsupported parameters")
	}
	wrap := argon2.IDKey([]byte(passphrase), head[18:34], ops, mem/1024, 1, 32)
	defer clear(wrap)
	var key [32]byte
	copy(key[:], wrap)
	var nonce [24]byte
	copy(nonce[:], head[34:58])
	msg, ok := secretbox.Open(nil, head[58:124], &nonce, &key)
	if !ok || len(msg) != len(shareMarker)+32 || string(msg[:len(shareMarker)]) != shareMarker {
		return nil, ErrShare
	}
	shareKey := msg[len(shareMarker):]
	defer clear(msg)
	st, e := newPull(shareKey, head[124:148])
	if e != nil {
		return nil, e
	}

	var written []string
	defer func() {
		if err != nil {
			for _, p := range written {
				os.Remove(p)
			}
			names = nil
		}
	}()
	p := &shareParser{dir: dir, max: maxTotal, seen: map[string]bool{}, written: &written}
	defer p.closeOut()

	buf := make([]byte, chunkSize+StreamABytes)
	for {
		n, e := io.ReadFull(r, buf)
		if e == io.EOF {
			return nil, ErrShare
		}
		last := e == io.ErrUnexpectedEOF
		if e != nil && !last {
			return nil, e
		}
		if last && n < StreamABytes {
			return nil, ErrShare
		}
		plain, tag, e := st.pull(buf[:n])
		if e != nil {
			return nil, ErrShare
		}
		if e := p.add(plain); e != nil {
			return nil, e
		}
		if tag == TagFinal {
			if int64(len(plain)) == chunkSize {
				return nil, errors.New("share bundle: FINAL chunk is a full chunk")
			}
			var extra [1]byte
			if _, e := io.ReadFull(r, extra[:]); e != io.EOF {
				return nil, errors.New("share bundle: data after the FINAL chunk")
			}
			if !p.atBoundary() {
				return nil, ErrShare
			}
			return p.names, nil
		}
		if last {
			return nil, ErrShare
		}
	}
}

type shareParser struct {
	dir     string
	max     int64
	total   int64
	seen    map[string]bool
	written *[]string
	names   []string
	buf     []byte
	state   int // 0 name length, 1 name, 2 content length, 3 content
	need    int64
	name    string
	out     *os.File
}

func (p *shareParser) closeOut() {
	if p.out != nil {
		p.out.Close()
		p.out = nil
	}
}

func (p *shareParser) atBoundary() bool {
	return p.state == 0 && len(p.buf) == 0 && p.out == nil
}

func (p *shareParser) add(data []byte) error {
	if p.need == 0 && p.state == 0 && len(p.buf) == 0 {
		p.need = 4
	}
	for len(data) > 0 {
		if p.state == 3 {
			n := int64(len(data))
			if n > p.need {
				n = p.need
			}
			if _, err := p.out.Write(data[:n]); err != nil {
				return err
			}
			p.need -= n
			data = data[n:]
			if p.need == 0 {
				if err := p.finish(); err != nil {
					return err
				}
			}
			continue
		}
		take := p.need - int64(len(p.buf))
		if take > int64(len(data)) {
			take = int64(len(data))
		}
		p.buf = append(p.buf, data[:take]...)
		data = data[take:]
		if int64(len(p.buf)) < p.need {
			continue
		}
		field := p.buf
		p.buf = nil
		if err := p.advance(field); err != nil {
			return err
		}
	}
	return nil
}

func (p *shareParser) advance(field []byte) error {
	switch p.state {
	case 0:
		n := binary.BigEndian.Uint32(field)
		if n < 1 || n > 255 {
			return errors.New("share bundle: bad entry name length")
		}
		p.state, p.need = 1, int64(n)
	case 1:
		name := string(field)
		if !shareNameOK(name) {
			return errors.New("share bundle: unsafe entry name")
		}
		lower := strings.ToLower(name)
		if p.seen[lower] {
			return errors.New("share bundle: duplicate entry name")
		}
		p.seen[lower] = true
		p.name = name
		p.state, p.need = 2, 8
	case 2:
		n := binary.BigEndian.Uint64(field)
		if n > uint64(p.max-p.total) {
			return errors.New("share bundle: larger than allowed")
		}
		p.total += int64(n)
		path := filepath.Join(p.dir, p.name)
		f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
		if err != nil {
			return err
		}
		*p.written = append(*p.written, path)
		p.out = f
		p.state, p.need = 3, int64(n)
		if n == 0 {
			return p.finish()
		}
	}
	return nil
}

func (p *shareParser) finish() error {
	err := p.out.Close()
	p.out = nil
	p.names = append(p.names, p.name)
	p.state, p.need = 0, 4
	return err
}
