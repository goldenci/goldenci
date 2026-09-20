#!/usr/bin/env bash
#
# Copyright 2026 GoldenCI Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Parses a language-native coverage artifact, normalizes it to one decimal
# place, and gates it against a threshold. stdout is exactly one line — the
# coverage percent; every diagnostic goes to stderr.

set -euo pipefail

[ "${GOLDENCI_DEBUG:-}" = "1" ] && set -x

usage() {
  cat >&2 <<'USAGE'
Usage: bash coverage-gate.sh                                  (env-driven)
       bash coverage-gate.sh <language> <coverage-file> <threshold>

Parses a coverage artifact and gates it against a static floor.

Positional arguments override the matching env var (intended for local use):
  <language>        go | node | python
  <coverage-file>   path to the coverage artifact
  <threshold>       minimum percent (int or decimal)

Options:
  -h, --help        print this help to stderr and exit 0

Environment:
  LANGUAGE        required  go | node | python
  COVERAGE_FILE   optional  default per language:
                              go     -> coverage.out
                              node   -> coverage/coverage-summary.json
                              python -> coverage.xml
  THRESHOLD       optional  minimum percent, default 0 (0 always passes)
  LABEL           optional  `unit` or `integration`, default unit
                            (used only in messages and the step summary)
  ALLOW_MISSING   optional  `true` -> a missing/unparseable coverage file
                            yields empty coverage and exit 0 instead of exit 2
  GITHUB_OUTPUT         when set, receives `coverage`, `threshold`, `passed`
  GITHUB_STEP_SUMMARY   when set, receives one summary line
  GOLDENCI_DEBUG        set to 1 to enable `set -x`

stdout: exactly one line, the normalized coverage percent (e.g. 82.4), or
        nothing at all when ALLOW_MISSING=true and the file is absent.

Exit codes:
  0  coverage >= threshold (or THRESHOLD=0, or ALLOW_MISSING=true with no file)
  1  coverage below threshold
  2  LANGUAGE missing/invalid, unparseable THRESHOLD, or the coverage file is
     missing/unparseable while ALLOW_MISSING is not `true`
USAGE
}

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      usage
      exit 0
      ;;
  esac
done

gh_out() {
  [ -n "${GITHUB_OUTPUT:-}" ] && printf '%s=%s\n' "$1" "$2" >>"$GITHUB_OUTPUT"
  return 0
}

step_summary() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%s\n' "$1" >>"$GITHUB_STEP_SUMMARY"
  return 0
}

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------

language="${1:-${LANGUAGE:-}}"
coverage_file="${2:-${COVERAGE_FILE:-}}"
threshold="${3:-${THRESHOLD:-0}}"
label="${LABEL:-unit}"
allow_missing="${ALLOW_MISSING:-false}"

language="$(printf '%s' "$language" | tr '[:upper:]' '[:lower:]')"
allow_missing="$(printf '%s' "$allow_missing" | tr '[:upper:]' '[:lower:]')"
[ -z "$label" ] && label="unit"
[ -z "$threshold" ] && threshold="0"

if [ -z "$language" ]; then
  printf 'error: LANGUAGE is required (go|node|python)\n' >&2
  usage
  exit 2
fi

case "$language" in
  go) default_coverage_file="coverage.out" ;;
  node) default_coverage_file="coverage/coverage-summary.json" ;;
  python) default_coverage_file="coverage.xml" ;;
  *)
    printf 'error: LANGUAGE %s is not one of go|node|python\n' "'$language'" >&2
    exit 2
    ;;
esac

[ -z "$coverage_file" ] && coverage_file="$default_coverage_file"

if ! printf '%s' "$threshold" | grep -Eq '^[0-9]+([.][0-9]+)?$'; then
  printf 'error: THRESHOLD %s is not a non-negative number\n' "'$threshold'" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Missing file handling
# ---------------------------------------------------------------------------

# report_missing <human-readable reason>
# Honors ALLOW_MISSING: empty coverage + exit 0, else exit 2.
report_missing() {
  local reason="$1"
  if [ "$allow_missing" = "true" ]; then
    printf 'notice: %s; ALLOW_MISSING=true so %s coverage is reported as empty\n' \
      "$reason" "$label" >&2
    gh_out coverage ""
    gh_out threshold "$threshold"
    gh_out passed true
    step_summary "- coverage ($label): **not reported** — no coverage file at \`$coverage_file\`"
    exit 0
  fi
  printf 'error: %s (expected coverage file: %s)\n' "$reason" "'$coverage_file'" >&2
  printf 'error: set ALLOW_MISSING=true to treat this as unreported rather than fatal\n' >&2
  exit 2
}

if [ ! -f "$coverage_file" ]; then
  report_missing "coverage file for $label tests was not found"
fi

if [ ! -s "$coverage_file" ]; then
  report_missing "coverage file for $label tests is empty"
fi

# ---------------------------------------------------------------------------
# Parse, per language (BUILD_SPEC §5.2 — these expressions are frozen)
# ---------------------------------------------------------------------------

raw=""
case "$language" in
  go)
    raw="$(go tool cover -func="$coverage_file" 2>/dev/null |
      awk '/^total:/ {gsub("%","",$3); print $3}' || true)"
    ;;
  node)
    raw="$(jq -r '.total.lines.pct' "$coverage_file" 2>/dev/null || true)"
    ;;
  python)
    raw="$(python3 -c 'import sys,xml.etree.ElementTree as E; print(round(float(E.parse(sys.argv[1]).getroot().get("line-rate"))*100,2))' \
      "$coverage_file" 2>/dev/null || true)"
    ;;
esac

# `null`, empty, or non-numeric is a parse failure.
if [ -z "$raw" ] || [ "$raw" = "null" ] ||
  ! printf '%s' "$raw" | grep -Eq '^[0-9]+([.][0-9]+)?$'; then
  report_missing "could not parse a $language coverage percentage from $coverage_file"
fi

coverage="$(printf '%s\n' "$raw" | awk '{printf "%.1f", $1}')"

# ---------------------------------------------------------------------------
# Compare — float-tolerant, THRESHOLD=0 always passes
# ---------------------------------------------------------------------------

if awk -v c="$coverage" -v t="$threshold" 'BEGIN{exit !(c+0.05>=t)}'; then
  passed="true"
else
  passed="false"
fi

gh_out coverage "$coverage"
gh_out threshold "$threshold"
gh_out passed "$passed"

if [ "$passed" = "true" ]; then
  step_summary "- coverage ($label): **${coverage}%** vs threshold ${threshold}% — PASS"
  printf 'coverage gate passed: %s coverage %s%% meets the required %s%%\n' \
    "$label" "$coverage" "$threshold" >&2
  printf '%s\n' "$coverage"
  exit 0
fi

step_summary "- coverage ($label): **${coverage}%** vs threshold ${threshold}% — FAIL"
printf '%s\n' "$coverage"
printf 'coverage gate FAILED: %s coverage %s%% is below the required %s%%\n' \
  "$label" "$coverage" "$threshold" >&2
exit 1
