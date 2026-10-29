package main

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestWebDAVRejectsUnsafeURLs(t *testing.T) {
	for _, raw := range []string{"https:///vault/", "http://nas.example/vault/", "ftp://localhost/vault/", "https://u:p@nas.example/vault/"} {
		t.Run(raw, func(t *testing.T) {
			if _, err := newWebDAV(raw, "test", "test"); err == nil {
				t.Fatal("accepted unsafe URL")
			}
		})
	}
}

func TestWebDAVDoesNotForwardCredentialsThroughRedirect(t *testing.T) {
	requests := 0
	recipient := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		w.WriteHeader(http.StatusOK)
	}))
	defer recipient.Close()
	origin := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, recipient.URL+"/capture.shtr", http.StatusFound)
	}))
	defer origin.Close()
	dav, err := newWebDAV(origin.URL+"/vault/", "test-user", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	// Trust this synthetic TLS server while preserving the client's redirect policy.
	dav.c.Transport = origin.Client().Transport
	r, err := dav.open("capture.shtr")
	if err == nil {
		r.Close()
		t.Error("followed redirect instead of reporting the HTTP status")
	}
	if requests != 0 {
		t.Fatal("redirect recipient was contacted")
	}
}

func TestWebDAVRoundTripNames(t *testing.T) {
	name := "photo%20 literal.jpg.shtr"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		u, p, ok := r.BasicAuth()
		if !ok || u != "test-user" || p != "test-password" {
			t.Error("missing test authentication")
		}
		switch r.Method {
		case "PROPFIND":
			if r.Header.Get("Depth") != "1" {
				t.Error("wrong listing depth")
			}
			w.WriteHeader(http.StatusMultiStatus)
			io.WriteString(w, `<D:multistatus xmlns:D="DAV:"><D:response><D:href>/vault/</D:href><D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat></D:response><D:response><D:href>/vault/photo%2520%20literal.jpg.shtr</D:href><D:propstat><D:prop><D:resourcetype/></D:prop></D:propstat></D:response></D:multistatus>`)
		case "GET":
			if r.URL.Path != "/vault/"+name {
				t.Errorf("unexpected decoded path %q", r.URL.Path)
			}
			io.WriteString(w, "synthetic container")
		default:
			t.Errorf("unexpected method %s", r.Method)
		}
	}))
	defer server.Close()
	dav, err := newWebDAV(server.URL+"/vault", "test-user", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	names, err := dav.list()
	if err != nil {
		t.Fatal(err)
	}
	if len(names) != 1 || names[0] != name {
		t.Fatalf("unexpected names %q", names)
	}
	r, err := dav.open(names[0])
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	data, err := io.ReadAll(r)
	if err != nil || string(data) != "synthetic container" {
		t.Fatal("download did not preserve the response")
	}
}

func TestWebDAVProgressingDownloadExceedsBudgetOverall(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		for _, chunk := range []string{"one", "two", "three", "four", "five", "six"} {
			if _, err := io.WriteString(w, chunk); err != nil {
				return
			}
			w.(http.Flusher).Flush()
			select {
			case <-r.Context().Done():
				return
			case <-time.After(70 * time.Millisecond):
			}
		}
	}))
	defer server.Close()
	dav, err := newWebDAV(server.URL, "test", "test")
	if err != nil {
		t.Fatal(err)
	}
	dav.timeout = 200 * time.Millisecond
	body, err := dav.open("clip.shtr")
	if err != nil {
		t.Fatal(err)
	}
	defer body.Close()
	got, err := io.ReadAll(body)
	if err != nil || string(got) != "onetwothreefourfivesix" {
		t.Fatalf("progressing download failed: %q, %v", got, err)
	}
}

func TestWebDAVStalledHeadersAndBodyStop(t *testing.T) {
	for _, headers := range []bool{false, true} {
		t.Run(map[bool]string{false: "headers", true: "body"}[headers], func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if headers {
					io.WriteString(w, "partial")
					w.(http.Flusher).Flush()
				}
				<-r.Context().Done()
			}))
			defer server.Close()
			dav, err := newWebDAV(server.URL, "test", "test")
			if err != nil {
				t.Fatal(err)
			}
			dav.timeout = 100 * time.Millisecond
			body, err := dav.open("clip.shtr")
			if headers {
				if err != nil {
					t.Fatal(err)
				}
				defer body.Close()
				_, err = io.ReadAll(body)
			}
			if err == nil {
				t.Fatal("stalled network operation did not fail")
			}
		})
	}
}

func TestWebDAVConsumerProcessingDoesNotUseNetworkBudget(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, "complete")
	}))
	defer server.Close()
	dav, err := newWebDAV(server.URL, "test", "test")
	if err != nil {
		t.Fatal(err)
	}
	dav.timeout = 100 * time.Millisecond
	body, err := dav.open("clip.shtr")
	if err != nil {
		t.Fatal(err)
	}
	defer body.Close()
	time.Sleep(250 * time.Millisecond)
	got, err := io.ReadAll(body)
	if err != nil || string(got) != "complete" {
		t.Fatalf("consumer delay interrupted recovery: %q, %v", got, err)
	}
}

func TestWebDAVRejectsUnboundedRecoveryListing(t *testing.T) {
	for _, mode := range []string{"bytes", "captures"} {
		t.Run(mode, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusMultiStatus)
				io.WriteString(w, `<D:multistatus xmlns:D="DAV:">`)
				if mode == "bytes" {
					io.WriteString(w, "<!--"+strings.Repeat("x", 16*1024*1024)+"-->")
				} else {
					for i := 0; i < 10001; i++ {
						fmt.Fprintf(w, `<D:response><D:href>/vault/capture-%d.shtr</D:href></D:response>`, i)
					}
				}
				io.WriteString(w, `</D:multistatus>`)
			}))
			defer server.Close()
			dav, err := newWebDAV(server.URL, "test", "test")
			if err != nil {
				t.Fatal(err)
			}
			if _, err := dav.list(); err == nil {
				t.Fatal("accepted an unbounded recovery listing")
			}
		})
	}
}
