package main

import (
	"reflect"
	"testing"
)

func TestMappedOutputNames(t *testing.T) {
	random := "3f9c0a7e5b1d44c2a86e0d1f7b92c4aa.shtr"
	other := "00112233445566778899aabbccddeeff.shtr"
	cases := []struct {
		name    string
		catalog string
		listing []string
		want    map[string]string
	}{
		{"maps a random name back", `{"remoteNames":{"2026-10-26.jpg.shtr":"` + random + `"}}`,
			[]string{random, "quietake.catalog"}, map[string]string{random: "2026-10-26.jpg"}},
		{"no field keeps generic names", `{"version":1,"albums":{},"items":{}}`,
			[]string{random}, map[string]string{}},
		{"ignores a mapping whose file is not listed", `{"remoteNames":{"a.shtr":"` + random + `"}}`,
			[]string{other}, map[string]string{}},
		{"rejects a path in the local name", `{"remoteNames":{"../a.shtr":"` + random + `"}}`,
			[]string{random}, map[string]string{}},
		{"rejects a local name that is not a container", `{"remoteNames":{"a.jpg":"` + random + `"}}`,
			[]string{random}, map[string]string{}},
		{"drops a remote name claimed by two captures", `{"remoteNames":{"a.shtr":"` + random + `","b.shtr":"` + random + `"}}`,
			[]string{random, other}, map[string]string{}},
		{"drops a name that collides with an unmapped file", `{"remoteNames":{"a.shtr":"` + random + `"}}`,
			[]string{random, "a.shtr"}, map[string]string{}},
		{"bad JSON keeps generic names", `{not json`, []string{random}, map[string]string{}},
		{"wrong types keep generic names", `{"remoteNames":[1,2]}`, []string{random}, map[string]string{}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := mappedOutputNames([]byte(c.catalog), c.listing)
			if !reflect.DeepEqual(got, c.want) {
				t.Fatalf("got %v, want %v", got, c.want)
			}
		})
	}
}
