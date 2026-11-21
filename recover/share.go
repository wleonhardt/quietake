package main

import (
	"errors"
	"fmt"
	"os"

	"quietake/recover/internal/shtr"
)

// runShare opens a .quietake-share bundle into out. The passphrase belongs to
// the bundle alone; no vault key, keyfile or NAS is involved.
func runShare(bundle, out string, read func(string) ([]byte, error)) error {
	if out == "" {
		return errors.New("-out is required with -share")
	}
	pass, err := read("share passphrase: ")
	defer clear(pass)
	if err != nil {
		return err
	}
	f, err := os.Open(bundle)
	if err != nil {
		return err
	}
	defer f.Close()
	if err := os.MkdirAll(out, 0o700); err != nil {
		return err
	}
	names, err := shtr.ExtractShare(f, string(pass), out, shtr.ShareDefaultCap)
	if err != nil {
		return err
	}
	for _, n := range names {
		fmt.Printf("ok   %q\n", n)
	}
	fmt.Printf("%d files\n", len(names))
	return nil
}
