# GoldenCI

Golden-path CI for Go, Node, and Python — lint, tests with a coverage gate, build, and vulnerability scanning in a few lines of YAML.

[![GitHub Marketplace](https://img.shields.io/badge/marketplace-GoldenCI-yellow)](https://github.com/marketplace/actions/goldenci)
[![selfcheck](https://github.com/goldenci/goldenci/actions/workflows/selfcheck.yml/badge.svg?branch=main)](https://github.com/goldenci/goldenci/actions/workflows/selfcheck.yml)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)

## Quickstart

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  ci:
    uses: goldenci/goldenci/.github/workflows/golden-ci.yml@v1
    with:
      language: go            # go | node | python | auto
      lint: true
      test: true
      coverage-threshold: 70
      build: true
      security-scan: true
```

That is the entire integration. No secrets are required for this path.

## What you get

Four independently re-runnable checks appear on the PR, named after the job ids in `golden-ci.yml`:

- `ci / lint`
- `ci / test`
- `ci / build`
- `ci / scan`

(The workflow also declares `detect`, `review-env`, `integration-test`, and `summary` jobs. `review-env` and `integration-test` only run when `review-env: true`; `summary` never fails the run.)

The `summary` job writes this table to `$GITHUB_STEP_SUMMARY`:

```markdown
## GoldenCI

| Stage | Result | Detail |
|---|---|---|
| detect | ok | language=go |
| lint | pass | 0 issues |
| test | pass | coverage 74.2% (threshold 70) |
| build | pass | |
| scan | pass | sast 0, vulns 0 |
| review-env | skipped |  |
| integration-test | skipped |  |
```

Result values are `pass` / `fail` / `skipped` (mapped from each job's `result`; `detect` renders `ok` instead of `pass`).

## Supported languages

| Language | Detection marker file(s) | Lint tool | Test command | Coverage file path |
|---|---|---|---|---|
| `go` | `go.mod` | `golangci-lint` via `golangci/golangci-lint-action` (`--timeout=5m`) | `go test ./... -covermode=atomic -coverprofile=coverage.out` | `coverage.out` |
| `node` | `package.json` | `npx eslint .` | `npm test -- --coverage --coverageReporters=json-summary --coverageReporters=text` | `coverage/coverage-summary.json` |
| `python` | `pyproject.toml`, `requirements.txt`, `setup.py`, `setup.cfg` | `ruff check` via `astral-sh/ruff-action` | `pytest --cov=. --cov-report=xml --cov-report=term --ignore=.goldenci-tools` | `coverage.xml` |

Auto-detection order (first match wins, regular files directly in `working-directory`): `go.mod` → go, `package.json` → node, `pyproject.toml` → python, `requirements.txt` → python, `setup.py` → python, `setup.cfg` → python.

Toolchain versions are never hardcoded where a project declares one: Go reads `go-version-file: <workdir>/go.mod`; Node prefers `.nvmrc`, then `engines.node` in `package.json`, else `22`; Python reads `python-version-file: <workdir>/pyproject.toml` when present, else `3.12`. All three enable dependency caching.

A container image build is opt-in by the mere presence of `<workdir>/Dockerfile` in the `build` job.

## The workflow

### `golden-ci.yml` — CI Loop

Runs `detect`, then `lint` / `test` / `build` / `scan` as parallel jobs, optionally `review-env` → `integration-test`, then a `summary` job. This is the pre-merge hard gate.

Trigger: wire it to `push` / `pull_request` in your own workflow file.

```yaml
jobs:
  ci:
    uses: goldenci/goldenci/.github/workflows/golden-ci.yml@v1
```

| Input | Type | Required | Default | Description |
|---|---|---|---|---|
| `language` | string | no | `auto` | `go \| node \| python \| auto` |
| `lint` | boolean | no | `true` | Run lint / code-quality job |
| `test` | boolean | no | `true` | Run unit test job |
| `coverage-threshold` | number | no | `70` | Static coverage floor, percent (independent of the ratchet) |
| `build` | boolean | no | `true` | Run build job |
| `review-env` | boolean | no | `false` | Deploy an ephemeral PR review environment |
| `security-scan` | boolean | no | `true` | Run SAST + dependency vulnerability scan |
| `working-directory` | string | no | `.` | Directory to operate in |
| `review-env-cmd` | string | no | `''` | Shell command that provisions the review env; must print `url=<URL>` to `$GITHUB_OUTPUT` |
| `integration-test-cmd` | string | no | `''` | Shell command for integration tests; receives `REVIEW_ENV_URL` in env |

## Outputs reference

### `golden-ci.yml`

| Output | Description |
|---|---|
| `language` | The resolved project language |
| `coverage-unit` | Unit test coverage percent (`''` when the test job was skipped) |
| `coverage-integration` | Integration test coverage percent (`''` when not produced) |
| `lint-issues` | Number of lint / code-quality issues |
| `sast-findings` | Number of SAST findings reported by CodeQL |
| `review-env-url` | URL of the ephemeral review environment |

### `action.yml` (composite action)

| Output | Description |
|---|---|
| `language` | Detected (or explicitly requested) language: `go \| node \| python` |
| `coverage` | Unit-test coverage percent, one decimal place; empty when tests were skipped |
| `coverage-passed` | `true` when coverage met `coverage-threshold` |
| `lint-issues` | Number of lint / code-quality issues found; empty when lint was skipped |
| `sast-findings` | Number of SAST findings; empty when the security scan was skipped |

## Composite action usage

Use `uses: goldenci/goldenci@v1` as a single step when you want the whole golden path folded into an existing job you already control — it takes the same `language` / `lint` / `test` / `coverage-threshold` / `build` / `security-scan` inputs plus `working-directory` and `setup-toolchain` (all strings, booleans quoted as `'true'`/`'false'`).

Use the reusable workflow for everything else: it is the primary surface, gives you one status check per stage (`ci / lint`, `ci / test`, …), and is the only form that can express `review-env` — which `action.yml` deliberately omits, because an ephemeral environment needs multiple jobs.

## Permissions and secrets

**`golden-ci.yml` needs only `contents: read`, and zero secrets.** That is its whole `permissions:` block. CodeQL runs with `upload: never`, so no SARIF is sent to GitHub and **no `security-events: write` permission is needed** — which keeps the zero-required-secrets promise intact on private repos too.

## Hard gates

What actually fails a run:

- **Lint failure** — a non-zero exit from `golangci-lint` / `eslint` / `ruff check` fails `ci / lint`. The issue *count* is reported separately and never gates on its own.
- **Unit test failure** — a non-zero exit from the test command fails `ci / test`.
- **Coverage below `coverage-threshold`** — `coverage-gate.sh` exits 1 and fails `ci / test`. Integration coverage is recorded, not statically gated (`THRESHOLD: '0'`, `ALLOW_MISSING: 'true'`).
- **SAST findings at error severity** — any CodeQL result whose `level` (or its rule's `defaultConfiguration.level`) resolves to `error` fails `ci / scan`.
- **Dependency vulnerabilities at or above high severity** — `govulncheck` (Go), `npm audit --audit-level=high` (Node), or `pip-audit` (Python) reporting findings fails `ci / scan`.

## Versioning policy

- `@v1` — moving major tag. Tracks the latest `v1.x.y`; you get patches and new additive features on your next run with no changes on your side.
- `@v1.2.0` — frozen. Pin this when you want byte-identical behavior across runs.
- Within a major, changes are **additive only**: new optional inputs, never a removed or renamed input, never a changed default.
- Anything breaking ships as `@v2`, with `v1` left working untouched.

Cutting a release: push a tag matching `v<major>.<minor>.<patch>` (e.g. `git tag v1.4.0 && git push origin v1.4.0`). [`release.yml`](.github/workflows/release.yml) creates the GitHub Release with generated notes and force-moves the major tag (`v1`) to it. On the first `v1.0.0`, open that release on GitHub and check "Publish this Action to the GitHub Marketplace" once by hand — the API has no equivalent for that step.

## Examples

- [`examples/go-example/`](examples/go-example) — minimal Go library module (`package greet`): `go.mod` detection, `.golangci.yml`, table test at 100% coverage.
- [`examples/node-example/`](examples/node-example) — minimal CommonJS module: `package.json` detection, flat-config ESLint, Jest with a `json-summary` coverage report, committed `package-lock.json`.
- [`examples/python-example/`](examples/python-example) — minimal Python module: `pyproject.toml` detection, `ruff check`, `pytest` with a Cobertura XML report.

The nested `.github/workflows/ci.yml` in each example is illustrative only — GitHub only reads workflows from a repository's root `.github/workflows/`, so those files never run. The real exercise of all three happens in this repo's [`selfcheck.yml`](.github/workflows/selfcheck.yml).

## Troubleshooting

**`ci / test` fails on coverage.** `coverage-gate.sh` prints exactly this to stderr and exits 1:

```
coverage gate FAILED: unit coverage 68.0% is below the required 70%
```

(The literal format is `coverage gate FAILED: %s coverage %s%% is below the required %s%%` — label, actual, threshold.) The actual percentage is also on stdout and in the step summary. Either raise coverage or lower `coverage-threshold`.

**`detect-language.sh` exits 1.** No marker file was found — set `language:` explicitly to `go`, `node`, or `python`. The stderr lists exactly what it looked for:

```
error: could not auto-detect a language in '.'
error: looked for these marker files, in order: go.mod,package.json,pyproject.toml,requirements.txt,setup.py,setup.cfg
error: set the `language` input explicitly to go, node, or python
```

An invalid `language:` value (anything outside `go|node|python|auto`) exits 2 instead. A `working-directory` that is not a directory also exits 2.

## Non-goals

- **No plugin/extensibility system.** If the workflow does not fit, fork it.
- **No monorepo orchestration in v1.** `working-directory` handles a single subdirectory, not a matrix of packages.
- **No self-hosted runner support in v1.** Every job is `runs-on: ubuntu-latest`.
- **No release, deploy, or post-merge validation.** This repo is CI only — lint, test, build, scan. Nothing else.

## Contributing / License

Issues and PRs welcome. Everything in this repo is dogfooded by [`selfcheck.yml`](.github/workflows/selfcheck.yml), which lints the workflow with `actionlint`, shellchecks `internal/scripts/`, asserts the script contracts, and runs the real reusable workflow and root composite action against all three examples. Run it green before opening a PR, and pin any new third-party action to a commit SHA.

Licensed under the [Apache License, Version 2.0](LICENSE).
