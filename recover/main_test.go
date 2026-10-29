package main

import (
	"bytes"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"quietake/recover/internal/shtr"
)

func TestRecoveryWritesOnlyVerifiedMedia(t *testing.T) {
	// Frozen, public synthetic vectors; no user vault or recovery key is read.
	data, err := os.ReadFile("../docs/vectors/containers.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors struct {
		RecoveryKey string `json:"recovery_key"`
		Cases       []struct {
			Plaintext string `json:"plaintext_hex"`
			Container string `json:"container_hex"`
		} `json:"cases"`
	}
	if err := json.Unmarshal(data, &vectors); err != nil {
		t.Fatal(err)
	}
	key, err := shtr.MasterKeyFromRecovery(vectors.RecoveryKey)
	if err != nil {
		t.Fatal(err)
	}
	cipher, err := hex.DecodeString(vectors.Cases[5].Container)
	if err != nil {
		t.Fatal(err)
	}
	plain, err := hex.DecodeString(vectors.Cases[5].Plaintext)
	if err != nil {
		t.Fatal(err)
	}
	for _, mode := range []string{"success", "tamper", "truncated", "trailing", "wrong-key", "check", "catalog"} {
		t.Run(mode, func(t *testing.T) {
			src := t.TempDir()
			out := t.TempDir()
			input := append([]byte(nil), cipher...)
			master := *key
			switch mode {
			case "tamper":
				input[len(input)-1] ^= 1
			case "truncated":
				input = input[:len(input)-17]
			case "trailing":
				input = append(input, 0)
			case "wrong-key":
				master[0] ^= 1
			}
			name := "photo.jpg.shtr"
			targetName := "photo.jpg"
			if mode == "catalog" {
				name = "tucklight.catalog"
				targetName = "tucklight.catalog.json"
			}
			if err := os.WriteFile(filepath.Join(src, name), input, 0600); err != nil {
				t.Fatal(err)
			}
			target := filepath.Join(out, targetName)
			original := []byte("preserve existing recovery output")
			if mode != "check" {
				if err := os.WriteFile(target, original, 0600); err != nil {
					t.Fatal(err)
				}
			}
			err := one(dirSource(src), name, &master, out, mode == "check")
			if mode == "check" {
				if err != nil {
					t.Fatal(err)
				}
				entries, err := os.ReadDir(out)
				if err != nil || len(entries) != 0 {
					t.Fatal("check wrote output")
				}
				return
			}
			want := original
			if mode == "success" || mode == "catalog" {
				if err != nil {
					t.Fatal(err)
				}
				want = plain
			} else if err == nil {
				t.Fatal("accepted damaged container")
			}
			got, err := os.ReadFile(target)
			if err != nil || !bytes.Equal(got, want) {
				t.Fatal("recovery output changed unexpectedly")
			}
			if _, err := os.Stat(target + ".part"); !os.IsNotExist(err) {
				t.Fatal("partial plaintext was retained")
			}
		})
	}
}

func TestRecoveryOutputNames(t *testing.T) {
	for name, want := range map[string]string{
		"photo.jpg.shtr":             "photo.jpg",
		"tucklight.catalog":          "tucklight.catalog.json",
		"quietake.catalog":           "quietake.catalog.json",
		"tucklight.catalog.part":     "",
		"tucklight.catalog.incoming": "",
		"photo.jpg.shtr.part":        "",
		"../outside.shtr":            "",
		`..\outside.shtr`:            "",
		"nested/photo.shtr":          "",
		`nested\photo.shtr`:          "",
		"/outside.shtr":              "",
		"..shtr":                     "",
		"...shtr":                    "",
	} {
		if got := recoveryOutputName(name); got != want {
			t.Errorf("%q: got %q, want %q", name, got, want)
		}
	}
}

func TestMaskedRecoveryKey(t *testing.T) {
	// Public synthetic bytes only; never read a user key or credential store.
	want := bytes.Repeat([]byte{42}, 32)
	encoded := base64.StdEncoding.EncodeToString(want)
	called := 0
	read := func(label string) ([]byte, error) {
		called++
		if label != "recovery key: " {
			t.Fatal("wrong prompt label")
		}
		return []byte(encoded), nil
	}
	got, err := masterKey("", "", "", false, true, read)
	if err != nil || !bytes.Equal(got[:], want) || called != 1 {
		t.Fatal("prompted key did not decode")
	}
	for _, input := range []string{"", "invalid"} {
		_, err := masterKey("", "", "", false, true, func(string) ([]byte, error) { return []byte(input), nil })
		if err == nil {
			t.Fatal("invalid prompt input accepted")
		}
	}
	interrupted := errors.New("read interrupted")
	if _, err := masterKey("", "", "", false, true, func(string) ([]byte, error) { return nil, interrupted }); !errors.Is(err, interrupted) {
		t.Fatal("read error lost")
	}
	input := []byte(encoded)
	if _, err := masterKey("", "", "", false, true, func(string) ([]byte, error) { return input, nil }); err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(input, make([]byte, len(input))) {
		t.Fatal("temporary prompt bytes retained")
	}
}

func TestRecoveryPromptConflictsNeverRead(t *testing.T) {
	for _, option := range []struct {
		key, file, passcode string
		passcodePrompt      bool
	}{
		{key: "synthetic"}, {file: "must-not-open"}, {passcode: "synthetic"}, {passcodePrompt: true},
	} {
		_, err := masterKey(option.key, option.file, option.passcode, option.passcodePrompt, true, func(string) ([]byte, error) { t.Fatal("conflicting prompt was read"); return nil, nil })
		if err == nil {
			t.Fatal("conflicting input modes accepted")
		}
	}
}

func TestExistingRecoveryInputsRemainCompatible(t *testing.T) {
	data, err := os.ReadFile("../docs/vectors/keyfile.json")
	if err != nil {
		t.Fatal(err)
	}
	var vector struct {
		Passcode string          `json:"passcode"`
		Master   string          `json:"expected_master_key_hex"`
		Keyfile  json.RawMessage `json:"keyfile"`
	}
	if err := json.Unmarshal(data, &vector); err != nil {
		t.Fatal(err)
	}
	want, err := hex.DecodeString(vector.Master)
	if err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(t.TempDir(), "synthetic-keyfile.json")
	if err := os.WriteFile(file, vector.Keyfile, 0600); err != nil {
		t.Fatal(err)
	}
	noRead := func(string) ([]byte, error) { t.Fatal("scripted input prompted"); return nil, nil }
	got, err := masterKey(base64.StdEncoding.EncodeToString(want), "", "", false, false, noRead)
	if err != nil || !bytes.Equal(got[:], want) {
		t.Fatal("scripted recovery key changed")
	}
	got, err = masterKey("", file, vector.Passcode, false, false, noRead)
	if err != nil || !bytes.Equal(got[:], want) {
		t.Fatal("scripted keyfile input changed")
	}
	var input []byte
	got, err = masterKey("", file, "", true, false, func(label string) ([]byte, error) {
		if label != "passcode: " {
			t.Fatal("wrong passcode label")
		}
		input = []byte(vector.Passcode)
		return input, nil
	})
	if err != nil || !bytes.Equal(got[:], want) || !bytes.Equal(input, make([]byte, len(input))) {
		t.Fatal("passcode prompt or cleanup changed")
	}
}

func TestRecoveryMainProcess(t *testing.T) {
	if os.Getenv("QUIETAKE_TEST_MAIN") != "1" {
		return
	}
	os.Args = append(os.Args[:1], os.Args[3:]...)
	flag.CommandLine = flag.NewFlagSet("recovery-test", flag.ExitOnError)
	main()
}

func TestRecoveryQuotesRemoteTerminalControls(t *testing.T) {
	data, err := os.ReadFile("../docs/vectors/containers.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		Key   string `json:"recovery_key"`
		Cases []struct {
			Container string `json:"container_hex"`
		} `json:"cases"`
	}
	if err := json.Unmarshal(data, &fixture); err != nil {
		t.Fatal(err)
	}
	cipher, err := hex.DecodeString(fixture.Cases[0].Container)
	if err != nil {
		t.Fatal(err)
	}
	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	for _, bad := range []bool{false, true} {
		t.Run(fmt.Sprint(bad), func(t *testing.T) {
			name := "capture\x1b]52;c;c3ludGhldGlj\x07\r.jpg.shtr"
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.Method == "PROPFIND" {
					w.WriteHeader(http.StatusMultiStatus)
					fmt.Fprintf(w, `<D:multistatus xmlns:D="DAV:"><D:response><D:href>/vault/%s</D:href></D:response></D:multistatus>`, url.PathEscape(name))
				} else if !bad {
					w.Write(cipher)
				}
			}))
			defer server.Close()
			// The argument key is a frozen public synthetic vector, never a user key.
			command := exec.Command(executable, "-test.run=^TestRecoveryMainProcess$", "--", "-key", fixture.Key, "-webdav", server.URL+"/vault/", "-check")
			command.Env = append(os.Environ(), "QUIETAKE_TEST_MAIN=1")
			output, err := command.CombinedOutput()
			if (err != nil) != bad {
				t.Fatal("unexpected recovery status")
			}
			if bytes.ContainsAny(output, "\x1b\x07\r") {
				t.Fatal("recovery output contains live terminal controls")
			}
		})
	}
}

type unopenedRecoverySource struct{ opened bool }

func (s *unopenedRecoverySource) list() ([]string, error) { return nil, nil }
func (s *unopenedRecoverySource) open(string) (io.ReadCloser, error) {
	s.opened = true
	return nil, errors.New("source must remain unopened")
}

func TestRecoveryRejectsPathsBeforeOpening(t *testing.T) {
	for _, name := range []string{"../outside.shtr", `..\outside.shtr`, "nested/photo.shtr", `nested\photo.shtr`, "/outside.shtr", "..shtr", "...shtr"} {
		src := &unopenedRecoverySource{}
		if err := one(src, name, new([32]byte), t.TempDir(), false); err == nil || src.opened {
			t.Errorf("unsafe portable filename %q reached source or output", name)
		}
	}
}

func TestRecoveryDotNamesNeverLeaveOutput(t *testing.T) {
	data, err := os.ReadFile("../docs/vectors/containers.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		Key   string `json:"recovery_key"`
		Cases []struct {
			Container string `json:"container_hex"`
		} `json:"cases"`
	}
	if err := json.Unmarshal(data, &fixture); err != nil {
		t.Fatal(err)
	}
	key, err := shtr.MasterKeyFromRecovery(fixture.Key)
	if err != nil {
		t.Fatal(err)
	}
	cipher, err := hex.DecodeString(fixture.Cases[5].Container)
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"..shtr", "...shtr"} {
		t.Run(name, func(t *testing.T) {
			root := t.TempDir()
			src := filepath.Join(root, "source")
			out := filepath.Join(root, "nested", "output")
			if err := os.MkdirAll(src, 0700); err != nil {
				t.Fatal(err)
			}
			if err := os.MkdirAll(out, 0700); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(src, name), cipher, 0600); err != nil {
				t.Fatal(err)
			}
			if err := one(dirSource(src), name, key, out, false); err == nil {
				t.Fatal("accepted a dot output target")
			}
			for _, escaped := range []string{filepath.Join(root, "nested.part"), out + ".part"} {
				if _, err := os.Stat(escaped); !os.IsNotExist(err) {
					t.Fatal("recovery wrote plaintext outside selected output")
				}
			}
		})
	}
}
