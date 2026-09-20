// Package greet is the smallest possible library that still has a branch to
// cover. It is deliberately a library (no main function) so `go build ./...`
// succeeds and statement coverage can reach 100%.
package greet

import "fmt"

// Greet returns a greeting for name. An empty name greets the world.
func Greet(name string) string {
	if name == "" {
		return "Hello, world!"
	}
	return fmt.Sprintf("Hello, %s!", name)
}
