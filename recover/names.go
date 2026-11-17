package main

import (
	"encoding/json"
	"errors"
	"strings"

	"quietake/recover/internal/shtr"
)

// maxCatalogBytes bounds the catalog read for name recovery. The app limit is 2 MiB.
const maxCatalogBytes = 4 << 20

// mappedOutputNames returns output names for randomly named containers, read from
// the decrypted private catalog's optional remoteNames object (local name to NAS
// name). A mapping is used only when its file is listed, the local name is a
// plain .shtr name, the remote name is claimed once, and the output collides with
// no other output. Anything else keeps the generic name, never an error.
func mappedOutputNames(catalog []byte, listing []string) map[string]string {
	result := map[string]string{}
	var doc struct {
		RemoteNames map[string]string `json:"remoteNames"`
	}
	if json.Unmarshal(catalog, &doc) != nil {
		return result
	}
	listed := map[string]bool{}
	for _, name := range listing {
		listed[name] = true
	}
	claims := map[string]int{}
	for _, remote := range doc.RemoteNames {
		claims[remote]++
	}
	outputs := map[string]int{}
	for _, name := range listing {
		if out := recoveryOutputName(name); out != "" {
			outputs[out]++
		}
	}
	for local, remote := range doc.RemoteNames {
		if !listed[remote] || claims[remote] != 1 || !strings.HasSuffix(local, ".shtr") {
			continue
		}
		out := recoveryOutputName(local)
		if out == "" || outputs[out] > 0 {
			continue
		}
		outputs[out]++
		result[remote] = out
	}
	return result
}

type limitedBuffer struct{ data []byte }

func (b *limitedBuffer) Write(p []byte) (int, error) {
	if len(b.data)+len(p) > maxCatalogBytes {
		return 0, errors.New("catalog too large")
	}
	b.data = append(b.data, p...)
	return len(p), nil
}

// catalogOutputNames decrypts quietake.catalog in memory, if listed, and returns
// mappedOutputNames. Any failure returns no mapping and readable false, so the
// caller can say that server names are kept; the catalog's own recovery result
// is still reported by the normal pass.
func catalogOutputNames(src source, listing []string, master *[32]byte) (mapped map[string]string, readable bool) {
	for _, name := range listing {
		if name != "quietake.catalog" {
			continue
		}
		r, err := src.open(name)
		if err != nil {
			return map[string]string{}, false
		}
		defer r.Close()
		var buf limitedBuffer
		if shtr.Decrypt(r, master, &buf) != nil {
			return map[string]string{}, false
		}
		return mappedOutputNames(buf.data, listing), true
	}
	return map[string]string{}, true
}
