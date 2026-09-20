# go-example

A minimal Go library module (`package greet`) used to prove GoldenCI's Go path
end to end: detection via `go.mod`, `golangci-lint`, `go test` with a coverage
profile, and `go build ./...`.

There is no `main` function on purpose — every statement is reachable from the
table test, so coverage is 100% and comfortably clears the 70% gate.

Run it locally:

```
go test ./... -cover
```

`.github/workflows/ci.yml` here is illustrative only (nested workflows never run).
