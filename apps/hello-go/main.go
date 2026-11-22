// Command hello-go serves a JSON "hello, world" greeting over HTTP.
package main

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"time"
)

// Greeting is the body of the response to GET /.
type Greeting struct {
	Message string `json:"message"`
}

// newHandler returns the routes of the service: GET / answers with the greeting, and any other path is not found.
func newHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", hello)
	return mux
}

func hello(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(Greeting{Message: "hello, world"}); err != nil {
		log.Printf("writing response: %v", err)
	}
}

func main() {
	addr := ":8080"
	if port := os.Getenv("PORT"); port != "" {
		addr = ":" + port
	}
	srv := &http.Server{
		Addr:              addr,
		Handler:           newHandler(),
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("hello-go listening on %s", addr)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
