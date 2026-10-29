package main

import (
	"errors"
	"io"
	"quietake/recover/internal/shtr"
)

// The passphrase is accepted only through the existing masked terminal reader.
func backupMasterKey(src source, read func(string) ([]byte, error)) (*[32]byte, error) {
	names, err := src.list()
	if err != nil {
		return nil, errors.New("could not list backup recovery files")
	}
	name := ""
	for _, candidate := range names {
		if candidate == shtr.BackupName || candidate == shtr.LegacyBackupName {
			if name != "" {
				return nil, errors.New("ambiguous backup recovery identities")
			}
			name = candidate
		}
	}
	if name == "" {
		return nil, errors.New("could not find backup recovery file")
	}
	r, err := src.open(name)
	if err != nil {
		return nil, errors.New("could not read backup recovery file")
	}
	defer r.Close()
	data, err := io.ReadAll(io.LimitReader(r, shtr.BackupLimit+1))
	if err != nil || len(data) > shtr.BackupLimit {
		return nil, errors.New("invalid backup recovery file")
	}
	phrase, err := read("backup passphrase: ")
	defer clear(phrase)
	if err != nil {
		return nil, err
	}
	return shtr.MasterKeyFromBackup(data, string(phrase))
}
