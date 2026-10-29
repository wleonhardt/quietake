// quietake-recover: read .shtr containers with a recovery key, local keyfile
// and passcode, or enabled NAS backup passphrase, from a folder or WebDAV share.
//
//	quietake-recover -key-prompt -dir /Volumes/vault -out ./restored
//	quietake-recover -key-prompt -webdav https://nas.example.com/vault/ -user backup-user -out ./restored
//	quietake-recover -keyfile vault.keyfile.json -passcode-prompt -dir ./vault -out ./restored
//	quietake-recover -key ... -check -dir ./vault        # verify every container, write nothing
package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	"golang.org/x/term"
	"quietake/recover/internal/shtr"
)

func main() {
	key := flag.String("key", "", "recovery key (visible in process arguments; prefer -key-prompt)")
	backupPrompt := flag.Bool("backup-passphrase-prompt", false, "recover using the NAS recovery file and a masked backup passphrase")
	keyPrompt := flag.Bool("key-prompt", false, "ask for the recovery key without echo")
	keyfile := flag.String("keyfile", "", "path to vault.keyfile.json (needs -passcode or -passcode-prompt)")
	passcode := flag.String("passcode", "", "vault passcode for -keyfile")
	prompt := flag.Bool("passcode-prompt", false, "ask for the passcode without echo")
	dir := flag.String("dir", "", "folder holding .shtr files (a mounted share works)")
	dav := flag.String("webdav", "", "WebDAV folder URL, e.g. https://nas.example.com/vault/")
	user := flag.String("user", "", "WebDAV user")
	pass := flag.String("pass", "", "WebDAV password (or set QUIETAKE_WEBDAV_PASS)")
	out := flag.String("out", "", "output folder; plaintext names are the container names minus .shtr")
	check := flag.Bool("check", false, "decrypt and verify only, write nothing")
	flag.Parse()

	if (*dir == "") == (*dav == "") {
		fail(errors.New("give exactly one of -dir or -webdav"))
	}
	if !*check && *out == "" {
		fail(errors.New("-out is required unless -check"))
	}

	if *backupPrompt && (*key != "" || *keyPrompt || *keyfile != "" || *passcode != "" || *prompt) {
		fail(errors.New("-backup-passphrase-prompt cannot be combined with other key/passcode options"))
	}
	var err error
	var src source
	if *dir != "" {
		src = dirSource(*dir)
	} else {
		if *pass != "" {
			fmt.Fprintln(os.Stderr, "warning: -pass is visible in the process list and shell history; prefer QUIETAKE_WEBDAV_PASS")
		} else {
			*pass = os.Getenv("QUIETAKE_WEBDAV_PASS")
		}
		src, err = newWebDAV(*dav, *user, *pass)
		if err != nil {
			fail(err)
		}
	}
	var master *[32]byte
	if *backupPrompt {
		master, err = backupMasterKey(src, readSecret)
	} else {
		master, err = masterKey(*key, *keyfile, *passcode, *prompt, *keyPrompt, readSecret)
	}
	if err != nil {
		fail(err)
	}
	defer clear(master[:])

	names, err := src.list()
	if err != nil {
		fail(err)
	}
	if !*check {
		if err := os.MkdirAll(*out, 0o700); err != nil {
			fail(err)
		}
	}
	okN, badN := 0, 0
	for _, name := range names {
		if recoveryOutputName(name) == "" {
			continue
		}
		if err := one(src, name, master, *out, *check); err != nil {
			badN++
			fmt.Fprintf(os.Stderr, "FAIL %q: %q\n", name, err.Error())
			continue
		}
		okN++
		fmt.Printf("ok   %q\n", name)
	}
	fmt.Printf("%d ok, %d failed\n", okN, badN)
	if badN > 0 {
		os.Exit(1)
	}
}

func recoveryOutputName(name string) string {
	output := ""
	if name == "quietake.catalog" || name == "tucklight.catalog" {
		output = name + ".json"
	} else if strings.HasSuffix(name, ".shtr") {
		output = strings.TrimSuffix(name, ".shtr")
	}
	if output == "." || !filepath.IsLocal(output) || strings.ContainsAny(output, `/\`) {
		return ""
	}
	return output
}

func one(src source, name string, master *[32]byte, out string, check bool) error {
	output := recoveryOutputName(name)
	if output == "" {
		return errors.New("unsupported recovery filename")
	}
	r, err := src.open(name)
	if err != nil {
		return err
	}
	defer r.Close()
	if check {
		return shtr.Decrypt(r, master, io.Discard)
	}
	target := filepath.Join(out, output)
	tmp := target + ".part"
	f, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	w := bufio.NewWriter(f)
	if err := shtr.Decrypt(r, master, w); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := w.Flush(); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, target)
}

func masterKey(key, keyfile, passcode string, prompt, keyPrompt bool, read func(string) ([]byte, error)) (*[32]byte, error) {
	if keyPrompt {
		if key != "" || keyfile != "" || passcode != "" || prompt {
			return nil, errors.New("-key-prompt cannot be combined with other key/passcode options")
		}
		b, err := read("recovery key: ")
		defer clear(b)
		if err != nil {
			return nil, err
		}
		return shtr.MasterKeyFromRecovery(string(b))
	}
	switch {
	case key != "" && keyfile != "":
		return nil, errors.New("give -key or -keyfile, not both")
	case key != "" && (passcode != "" || prompt):
		return nil, errors.New("-key does not take a passcode")
	case key != "":
		return shtr.MasterKeyFromRecovery(key)
	case keyfile != "":
		data, err := os.ReadFile(keyfile)
		if err != nil {
			return nil, err
		}
		if prompt {
			b, err := read("passcode: ")
			defer clear(b)
			if err != nil {
				return nil, err
			}
			passcode = string(b)
		}
		if passcode == "" {
			return nil, errors.New("-keyfile needs -passcode or -passcode-prompt")
		}
		return shtr.MasterKeyFromKeyfile(data, passcode)
	default:
		return nil, errors.New("give -backup-passphrase-prompt, -key-prompt, -key, or -keyfile + passcode")
	}
}

func readSecret(label string) ([]byte, error) {
	if !term.IsTerminal(int(syscall.Stdin)) {
		return nil, errors.New("interactive prompt requires a terminal")
	}
	fmt.Fprint(os.Stderr, label)
	b, err := term.ReadPassword(int(syscall.Stdin))
	fmt.Fprintln(os.Stderr)
	return b, err
}

func fail(err error) {
	fmt.Fprintf(os.Stderr, "error: %q\n", err.Error())
	os.Exit(2)
}
