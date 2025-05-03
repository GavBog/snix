package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"

	"github.com/coreos/go-systemd/v22/activation"
	sloghttp "github.com/samber/slog-http"
	"golang.org/x/sync/errgroup"
)

const BUILDKITE_BUILDS_ENDPOINT = "https://api.buildkite.com/v2/organizations/snix/pipelines/snix/builds"

var BUILDKITE_ACCESS_TOKEN = ""

func handler(w http.ResponseWriter, r *http.Request) {
	// We only support /$commitSha1 requests, with $commitSha1 being 40 characters.
	p := strings.TrimPrefix(r.URL.Path, "/")
	if len(p) != 40 {
		http.Error(w, "invalid commit hash", http.StatusNotFound)
		return
	}

	// Only allow lowerhex
	for _, c := range p {
		if !(c >= '0' && c <= '9') && !(c >= 'a' && c <= 'f') {
			http.Error(w, "invalid commit hash", http.StatusNotFound)
			return
		}
	}

	commit_sha1 := p
	url := fmt.Sprintf("%v?commit=%v", BUILDKITE_BUILDS_ENDPOINT, commit_sha1)

	rq, err := http.NewRequestWithContext(r.Context(), "GET", url, nil)
	if err != nil {
		panic(fmt.Errorf("unable to construct request: %w", err))
	}
	val := fmt.Sprintf("Bearer %s", BUILDKITE_ACCESS_TOKEN)
	rq.Header.Add("Authorization", val)

	resp, err := http.DefaultClient.Do(rq)
	if err != nil {
		panic(fmt.Errorf("unable to send request: %w", err))
	}

	w.Header().Add("content-type", resp.Header.Get("content-type"))
	w.Header().Add("cache-control", resp.Header.Get("cache-control"))

	io.Copy(w, resp.Body)
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))

	credentialsDirectory, found := os.LookupEnv("CREDENTIALS_DIRECTORY")
	if !found {
		log.Fatal("CREDENTIALS_DIRECTORY needs to be set")
	}

	p := filepath.Join(credentialsDirectory, "buildkite-api-token")
	buildkiteToken, err := os.ReadFile(p)
	if err != nil {
		log.Fatalf("unable to read buildkite token: %s", err)
	}
	BUILDKITE_ACCESS_TOKEN = strings.TrimSuffix(string(buildkiteToken), "\n")

	listeners, err := activation.Listeners()
	if err != nil {
		log.Fatalf("unable to get listeners: %s", err)
	}

	if len(listeners) == 0 {
		log.Fatal("no listeners specified, did you configure socket activation correctly?")
	}

	g, ctx := errgroup.WithContext(ctx)
	server := &http.Server{
		Handler: sloghttp.New(logger)(http.HandlerFunc(handler)),
		BaseContext: func(l net.Listener) context.Context {
			return ctx
		},
	}

	for _, listener := range listeners {
		g.Go(func() error {
			return server.Serve(listener)
		})
	}

	if err := g.Wait(); err != nil {
		panic(err)
	}

	<-ctx.Done()
}
