//go:build !(android && cgo)

package main

import (
	"fmt"
	"io"
	"os"

	"github.com/sirupsen/logrus"
)

func main() {
	args := os.Args
	if len(args) <= 1 {
		fmt.Fprintln(os.Stderr, "Arguments error")
		os.Exit(1)
	}
	// mihomo mirrors every log line to stdout synchronously; the host never reads it,
	// and a full pipe would block each logging goroutine, connection handlers included.
	logrus.SetOutput(io.Discard)
	go exitOnTermination()
	startServer(args[1])
}
