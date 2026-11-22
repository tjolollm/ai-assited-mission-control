// Command hello-go serves a JSON "hello, world" greeting over HTTP.
package main

import (
	"context"
	"errors"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// helloBody is the response to GET /, byte for byte the one hello-rust sends.
const helloBody = `{"message":"hello, world"}`

// shutdownGrace is how long requests in flight get to finish after SIGTERM, well inside kubelet's default grace
// period of 30s.
const shutdownGrace = 10 * time.Second

// newHandler returns the routes of the service: GET / answers with the greeting, and any other path is not found.
func newHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", hello)
	return mux
}

func hello(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if _, err := io.WriteString(w, helloBody); err != nil {
		log.Printf("writing response: %v", err)
	}
}

// serve runs srv on ln until ctx is done, then stops taking connections and gives the requests in flight up to grace
// to finish, closing any still open after that. It returns once the shutdown is complete: nil when every request
// finished, context.DeadlineExceeded when some were cut off, or the error that stopped the server before ctx was done.
func serve(ctx context.Context, srv *http.Server, ln net.Listener, grace time.Duration) error {
	errc := make(chan error, 1)
	go func() { errc <- srv.Serve(ln) }()

	select {
	case err := <-errc:
		return err
	case <-ctx.Done():
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), grace)
	defer cancel()
	err := srv.Shutdown(shutdownCtx)
	if err != nil {
		// The deadline passed with requests still running; drop their connections.
		_ = srv.Close()
	}
	if serveErr := <-errc; !errors.Is(serveErr, http.ErrServerClosed) {
		return serveErr
	}
	return err
}

func main() {
	addr := ":8080"
	if port := os.Getenv("PORT"); port != "" {
		addr = ":" + port
	}
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatal(err)
	}
	srv := &http.Server{
		Handler:           newHandler(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	// SIGTERM is how kubelet stops a pod.
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()
	go func() {
		<-ctx.Done()
		log.Print("hello-go shutting down")
	}()

	log.Printf("hello-go listening on %s", ln.Addr())
	switch err := serve(ctx, srv, ln, shutdownGrace); {
	case errors.Is(err, context.DeadlineExceeded):
		log.Printf("shutdown: requests still running after %s were cut off", shutdownGrace)
	case err != nil:
		log.Fatal(err)
	}
}
