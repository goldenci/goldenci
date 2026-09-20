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
# Resolves the project language: go, node, or python. stdout is exactly one
# line; every diagnostic goes to stderr.

set -euo pipefail

[ "${GOLDENCI_DEBUG:-}" = "1" ] && set -x

usage() {
  cat >&2 <<'USAGE'
Usage: bash detect-language.sh [<requested>] [<workdir>]

Resolves the project language to one of: go | node | python.

Positional arguments (each falls back to the matching env var):
  <requested>   go | node | python | auto   (env INPUT_LANGUAGE, default: auto)
  <workdir>     directory to inspect        (env WORKDIR, default: .)

Options:
  -h, --help    print this help to stderr and exit 0

Environment:
  INPUT_LANGUAGE    used when <requested> is absent
  WORKDIR           used when <workdir> is absent
  GITHUB_OUTPUT     when set, receives `language` and `detected`
  GOLDENCI_DEBUG    set to 1 to enable `set -x`

If auto-detection finds no marker file and `enry` is on PATH (installed by
fabasoad/setup-enry-action in the composite actions), it's used to name the
actual dominant language in the failure message — diagnostic only, it never
changes what's supported.

Auto-detection order (first match wins; regular files directly in <workdir>):
  go.mod            -> go
  package.json      -> node
  pyproject.toml    -> python
  requirements.txt  -> python
  setup.py          -> python
  setup.cfg         -> python

stdout: exactly one line, the resolved language.

Exit codes:
  0  a language was resolved
  1  requested was `auto` and no marker file matched
  2  usage error: invalid requested language, or <workdir> is not a directory
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

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------

requested="${1:-${INPUT_LANGUAGE:-auto}}"
workdir="${2:-${WORKDIR:-.}}"

# Trim surrounding whitespace, then lowercase.
requested="${requested#"${requested%%[![:space:]]*}"}"
requested="${requested%"${requested##*[![:space:]]}"}"
requested="$(printf '%s' "$requested" | tr '[:upper:]' '[:lower:]')"

[ -z "$requested" ] && requested="auto"

if [ -z "$workdir" ]; then
  workdir="."
fi

case "$requested" in
  go | node | python | auto) ;;
  *)
    printf 'error: requested language %s is not one of go|node|python|auto\n' \
      "'$requested'" >&2
    usage
    exit 2
    ;;
esac

if [ ! -d "$workdir" ]; then
  printf 'error: workdir %s is not a directory\n' "'$workdir'" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Marker files, in detection priority order
# ---------------------------------------------------------------------------

MARKER_FILES=(go.mod package.json pyproject.toml requirements.txt setup.py setup.cfg)
MARKER_LANGS=(go node python python python python)

# expected_markers <language> -> prints the marker files for that language.
expected_markers() {
  local want="$1" i
  for i in "${!MARKER_FILES[@]}"; do
    if [ "${MARKER_LANGS[$i]}" = "$want" ]; then
      printf '%s\n' "${MARKER_FILES[$i]}"
    fi
  done
}

# ---------------------------------------------------------------------------
# Explicit language: emit verbatim, warn when the marker is absent
# ---------------------------------------------------------------------------

if [ "$requested" != "auto" ]; then
  found_marker=""
  while IFS= read -r marker; do
    if [ -f "$workdir/$marker" ]; then
      found_marker="$marker"
      break
    fi
  done < <(expected_markers "$requested")

  if [ -z "$found_marker" ]; then
    printf 'warning: language %s was requested explicitly but no marker file (%s) was found in %s\n' \
      "'$requested'" "$(expected_markers "$requested" | paste -sd, -)" "'$workdir'" >&2
  else
    printf 'language %s requested explicitly (marker %s present in %s)\n' \
      "'$requested'" "'$found_marker'" "'$workdir'" >&2
  fi

  gh_out language "$requested"
  gh_out detected false
  printf '%s\n' "$requested"
  exit 0
fi

# ---------------------------------------------------------------------------
# Auto-detection
# ---------------------------------------------------------------------------

for i in "${!MARKER_FILES[@]}"; do
  marker="${MARKER_FILES[$i]}"
  if [ -f "$workdir/$marker" ]; then
    language="${MARKER_LANGS[$i]}"
    printf 'auto-detected language %s from marker %s in %s\n' \
      "'$language'" "'$marker'" "'$workdir'" >&2
    gh_out language "$language"
    gh_out detected true
    printf '%s\n' "$language"
    exit 0
  fi
done

# No marker file matched. If `enry` (go-enry/enry, the linguist-derived
# detector installed by fabasoad/setup-enry-action in the composite actions)
# is on PATH, use it purely to name what was actually found, so the error is
# "this is Rust, which isn't supported yet" instead of a bare shrug. This
# never changes the exit code or the set of supported languages — GoldenCI
# still only drives go/node/python end to end.
if command -v enry >/dev/null 2>&1; then
  enry_top="$(cd "$workdir" && enry -prog 2>/dev/null | head -n1 | awk '{print $2}')"
  if [ -n "${enry_top:-}" ]; then
    printf 'note: linguist-based detection (enry) reports the dominant language here is %s\n' \
      "$enry_top" >&2
  fi
fi

printf 'error: could not auto-detect a language in %s\n' "'$workdir'" >&2
printf 'error: looked for these marker files, in order: %s\n' \
  "$(printf '%s\n' "${MARKER_FILES[@]}" | paste -sd, -)" >&2
printf 'error: set the language input explicitly to go, node, or python\n' >&2
exit 1
