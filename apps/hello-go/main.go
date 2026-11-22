// Command hello-go serves a JSON "hello, world" greeting over HTTP.
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"
)

// helloBody is the response to GET /, byte for byte the one hello-rust sends.
const helloBody = `{"message":"hello, world"}`

// defaultPort is the port the service listens on when PORT is unset or empty.
const defaultPort = 8080

// shutdownGrace is how long requests in flight get to finish after SIGTERM, well inside kubelet's default grace
// period of 30s.
const shutdownGrace = 10 * time.Second

// newHandler returns the routes of the service: GET / answers with the greeting, and any other path is not found.
func newHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", hello)
	return mux
}

// portFromEnv returns the port to listen on, from the value of PORT: unset or empty means defaultPort. Like hello-rust,
// it takes only a decimal port number, not a service name or a host:port.
func portFromEnv(value string) (uint16, error) {
	if value == "" {
		return defaultPort, nil
	}
	port, err := strconv.ParseUint(value, 10, 16)
	if err != nil {
		return 0, fmt.Errorf("PORT=%q: %w", value, err)
	}
	return uint16(port), nil
}

// newServer returns the HTTP server for handler, with timeouts that keep slow or abandoned connections from holding
// goroutines and file descriptors for the life of the process.
func newServer(handler http.Handler) *http.Server {
	return &http.Server{
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
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

	log.Print("hello-go shutting down")
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
	port, err := portFromEnv(os.Getenv("PORT"))
	if err != nil {
		log.Fatal(err)
	}
	// SIGTERM is how kubelet stops a pod. Registered before listening, so no signal goes unhandled.
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()

	ln, err := net.Listen("tcp", ":"+strconv.Itoa(int(port)))
	if err != nil {
		log.Fatal(err)
	}
	srv := newServer(newHandler())

	log.Printf("hello-go listening on %s", ln.Addr())
	switch err := serve(ctx, srv, ln, shutdownGrace); {
	case errors.Is(err, context.DeadlineExceeded):
		log.Printf("shutdown: requests still running after %s were cut off", shutdownGrace)
	case err != nil:
		log.Fatal(err)
	}
}
