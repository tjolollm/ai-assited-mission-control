package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
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
	var got Greeting
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("decoding body: %v", err)
	}
	if got.Message != "hello, world" {
		t.Errorf("message = %q, want %q", got.Message, "hello, world")
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
