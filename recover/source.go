package main

import (
	"context"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// source lists and opens containers, from a folder or a WebDAV collection.
type source interface {
	list() ([]string, error)
	open(name string) (io.ReadCloser, error)
}

type dirSource string

func (d dirSource) list() ([]string, error) {
	entries, err := os.ReadDir(string(d))
	if err != nil {
		return nil, err
	}
	var names []string
	for _, e := range entries {
		if !e.IsDir() {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)
	return names, nil
}

func (d dirSource) open(name string) (io.ReadCloser, error) {
	return os.Open(filepath.Join(string(d), name))
}

type webdav struct {
	base    *url.URL
	user    string
	pass    string
	c       *http.Client
	timeout time.Duration
}

func newWebDAV(raw, user, pass string) (*webdav, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, err
	}
	if !strings.HasSuffix(u.Path, "/") {
		u.Path += "/"
	}
	if u.Hostname() == "" || u.User != nil || (u.Scheme != "https" &&
		!(u.Scheme == "http" && (u.Hostname() == "127.0.0.1" || u.Hostname() == "localhost"))) {
		return nil, fmt.Errorf("use an HTTPS WebDAV folder URL without embedded credentials")
	}
	return &webdav{base: u, user: user, pass: pass, timeout: 2 * time.Minute, c: &http.Client{
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}}, nil
}

func (w *webdav) do(method string, u *url.URL, body io.Reader, hdr map[string]string) (*http.Response, error) {
	ctx, cancel := context.WithCancel(context.Background())
	req, err := http.NewRequestWithContext(ctx, method, u.String(), body)
	if err != nil {
		cancel()
		return nil, err
	}
	req.SetBasicAuth(w.user, w.pass)
	for k, v := range hdr {
		req.Header.Set(k, v)
	}
	timer := time.AfterFunc(w.timeout, cancel)
	res, err := w.c.Do(req)
	timer.Stop()
	if err != nil {
		cancel()
		return nil, err
	}
	res.Body = &timedBody{ReadCloser: res.Body, timeout: w.timeout, cancel: cancel}
	return res, nil
}

// Bound each blocking network read, not the total file or consumer processing time.
type timedBody struct {
	io.ReadCloser
	timeout time.Duration
	cancel  context.CancelFunc
}

func (b *timedBody) Read(p []byte) (int, error) {
	timer := time.AfterFunc(b.timeout, b.cancel)
	defer timer.Stop()
	return b.ReadCloser.Read(p)
}

func (b *timedBody) Close() error {
	b.cancel()
	return b.ReadCloser.Close()
}

type multistatus struct {
	Responses []struct {
		Href         string `xml:"DAV: href"`
		ResourceType struct {
			Collection *struct{} `xml:"DAV: collection"`
		} `xml:"DAV: propstat>prop>resourcetype"`
	} `xml:"DAV: response"`
}

func (w *webdav) list() ([]string, error) {
	body := `<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>`
	res, err := w.do("PROPFIND", w.base, strings.NewReader(body), map[string]string{
		"Depth": "1", "Content-Type": "application/xml; charset=utf-8",
	})
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != 207 {
		return nil, fmt.Errorf("PROPFIND %s: HTTP %d", w.base, res.StatusCode)
	}
	const maxListingBytes = 16 * 1024 * 1024
	data, err := io.ReadAll(io.LimitReader(res.Body, maxListingBytes+1))
	if err != nil {
		return nil, err
	}
	if len(data) > maxListingBytes {
		return nil, fmt.Errorf("backup directory exceeds limit")
	}
	var ms multistatus
	if err := xml.Unmarshal(data, &ms); err != nil {
		return nil, err
	}
	var names []string
	captures := 0
	for _, r := range ms.Responses {
		if r.ResourceType.Collection != nil {
			continue
		}
		p, err := url.PathUnescape(strings.TrimSpace(r.Href))
		if err != nil {
			return nil, err
		}
		name := path.Base(p)
		if strings.HasSuffix(name, ".shtr") {
			captures++
			if captures > 10000 {
				return nil, fmt.Errorf("backup capture count exceeds limit")
			}
		}
		names = append(names, name)
	}
	sort.Strings(names)
	return names, nil
}

func (w *webdav) open(name string) (io.ReadCloser, error) {
	u := *w.base
	u.Path = path.Join(u.Path, name)
	res, err := w.do("GET", &u, nil, nil)
	if err != nil {
		return nil, err
	}
	if res.StatusCode != 200 {
		res.Body.Close()
		return nil, fmt.Errorf("GET %s: HTTP %d", name, res.StatusCode)
	}
	return res.Body, nil
}
