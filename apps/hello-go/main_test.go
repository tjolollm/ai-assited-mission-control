package main

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

func TestHelloReturnsJSONGreeting(t *testing.T) {
	srv := httptest.NewServer(newHandler())
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/")
	if err != nil {
		t.Fatalf("GET /: %v", err)
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}
	if ct := resp.Header.Get("Content-Type"); ct != "application/json" {
		t.Errorf("Content-Type = %q, want %q", ct, "application/json")
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("reading body: %v", err)
	}
	// Byte for byte the same body as hello-rust sends.
	if want := `{"message":"hello, world"}`; string(body) != want {
		t.Errorf("body = %q, want %q", body, want)
	}
}

func TestRoutes(t *testing.T) {
	tests := []struct {
		name, method, path string
		want               int
	}{
		{"unknown path is not found", http.MethodGet, "/nope", http.StatusNotFound},
		{"other methods are not allowed", http.MethodPost, "/", http.StatusMethodNotAllowed},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec := httptest.NewRecorder()
			newHandler().ServeHTTP(rec, httptest.NewRequest(tt.method, tt.path, nil))
			if rec.Code != tt.want {
				t.Errorf("%s %s: status = %d, want %d", tt.method, tt.path, rec.Code, tt.want)
			}
		})
	}
}

func TestPortFromEnv(t *testing.T) {
	for value, want := range map[string]uint16{"": defaultPort, "9000": 9000, "0": 0} {
		if got, err := portFromEnv(value); err != nil || got != want {
			t.Errorf("portFromEnv(%q) = %d, %v; want %d, nil", value, got, err, want)
		}
	}
	// A service name, a host:port, trailing junk or an out-of-range number is an error, as in hello-rust.
	for _, value := range []string{"http", "1.2.3.4:80", "8080x", "65536", "-1"} {
		if got, err := portFromEnv(value); err == nil {
			t.Errorf("portFromEnv(%q) = %d, nil; want an error", value, got)
		}
	}
}

func TestNewServerSetsTimeouts(t *testing.T) {
	srv := newServer(newHandler())
	for name, d := range map[string]time.Duration{
		"ReadHeaderTimeout": srv.ReadHeaderTimeout,
		"ReadTimeout":       srv.ReadTimeout,
		"WriteTimeout":      srv.WriteTimeout,
		"IdleTimeout":       srv.IdleTimeout,
	} {
		if d <= 0 {
			t.Errorf("%s = %s, want a positive timeout", name, d)
		}
	}
}

// startServe runs serve with handler on a local port and returns the URL, the cancel that triggers the shutdown, and a
// channel that yields serve's result.
func startServe(t *testing.T, handler http.Handler, grace time.Duration) (string, context.CancelFunc, <-chan error) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	done := make(chan error, 1)
	go func() { done <- serve(ctx, &http.Server{Handler: handler}, ln, grace) }()
	return "http://" + ln.Addr().String(), cancel, done
}

func TestServeLetsRequestsInFlightFinish(t *testing.T) {
	started := make(chan struct{})
	var finished atomic.Bool
	handler := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		close(started)
		time.Sleep(300 * time.Millisecond)
		finished.Store(true)
		_, _ = io.WriteString(w, "done")
	})
	url, shutdown, done := startServe(t, handler, 5*time.Second)

	type result struct {
		body string
		err  error
	}
	resc := make(chan result, 1)
	go func() {
		resp, err := http.Get(url)
		if err != nil {
			resc <- result{err: err}
			return
		}
		defer func() { _ = resp.Body.Close() }()
		b, err := io.ReadAll(resp.Body)
		resc <- result{string(b), err}
	}()

	<-started
	shutdown()

	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("serve = %v, want nil", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("serve did not return after shutdown")
	}
	if !finished.Load() {
		t.Error("serve returned before the request in flight finished")
	}
	if res := <-resc; res.err != nil || res.body != "done" {
		t.Errorf("request in flight: body %q, err %v; want %q, nil", res.body, res.err, "done")
	}
}

func TestServeCutsOffRequestsAfterGrace(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	t.Cleanup(func() { close(release) })
	handler := http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		close(started)
		<-release
	})
	url, shutdown, done := startServe(t, handler, 200*time.Millisecond)

	go func() {
		if resp, err := http.Get(url); err == nil {
			_ = resp.Body.Close()
		}
	}()
	<-started
	begin := time.Now()
	shutdown()

	select {
	case err := <-done:
		if !errors.Is(err, context.DeadlineExceeded) {
			t.Fatalf("serve = %v, want %v", err, context.DeadlineExceeded)
		}
		if took := time.Since(begin); took > 2*time.Second {
			t.Errorf("serve took %s to give up, want about the 200ms grace", took)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("serve kept waiting for a stuck request past the grace period")
	}
}
