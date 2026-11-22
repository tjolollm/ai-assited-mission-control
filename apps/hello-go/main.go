// Command hello-go serves a JSON "hello, world" greeting over HTTP.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// Greeting is the body of the response to GET /.
type Greeting struct {
	Message string `json:"message"`
}

// helloBody is the encoded greeting, without the trailing newline json.Encoder would add, so the body is byte for
// byte the one hello-rust sends.
var helloBody = mustMarshal(Greeting{Message: "hello, world"})

func mustMarshal(v any) []byte {
	b, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return b
}

// newHandler returns the routes of the service: GET / answers with the greeting, and any other path is not found.
func newHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", hello)
	return mux
}

func hello(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if _, err := w.Write(helloBody); err != nil {
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

	// On SIGTERM, which kubelet sends to stop a pod, or SIGINT, finish the requests in flight and exit.
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()
	go func() {
		<-ctx.Done()
		log.Print("hello-go shutting down")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Printf("shutdown: %v", err)
		}
	}()

	log.Printf("hello-go listening on %s", addr)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
