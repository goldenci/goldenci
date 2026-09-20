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
# Installs project dependencies for the detected language. Operates in
# $PWD — the caller sets working-directory: on the step.

set -euo pipefail

[ "${GOLDENCI_DEBUG:-}" = "1" ] && set -x

usage() {
  cat >&2 <<'USAGE'
Usage: bash install-deps.sh                 (env-driven)
       bash install-deps.sh <language>

Installs dependencies for the current project in $PWD.

Positional argument overrides the matching env var (intended for local use):
  <language>   go | node | python

Options:
  -h, --help   print this help to stderr and exit 0

Environment:
  LANGUAGE        required  go | node | python
  GOLDENCI_DEBUG  set to 1 to enable `set -x`

Behavior per language:
  go      go mod download
  node    npm ci
  python  pip install --upgrade pip; then, if present, install
          requirements-dev.txt; then requirements.txt if present, else an
          editable install (`pip install -e .`) when pyproject.toml,
          setup.py, or setup.cfg is present (failure there is non-fatal —
          the project may rely on requirements-dev.txt alone)

Exit codes:
  0  dependencies installed (or nothing to install)
  2  LANGUAGE missing/invalid
  *  whatever the underlying package manager exited with, on failure
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

language="${1:-${LANGUAGE:-}}"
language="$(printf '%s' "$language" | tr '[:upper:]' '[:lower:]')"

if [ -z "$language" ]; then
  printf 'error: LANGUAGE is required (go|node|python)\n' >&2
  usage
  exit 2
fi

case "$language" in
  go)
    go mod download
    ;;
  node)
    npm ci
    ;;
  python)
    python -m pip install --upgrade pip
    if [ -f requirements-dev.txt ]; then
      pip install -r requirements-dev.txt
    fi
    if [ -f requirements.txt ]; then
      pip install -r requirements.txt
    elif [ -f pyproject.toml ] || [ -f setup.py ] || [ -f setup.cfg ]; then
      pip install -e . \
        || echo "editable install failed; continuing with already-installed deps" >&2
    fi
    ;;
  *)
    printf 'error: LANGUAGE %s is not one of go|node|python\n' "'$language'" >&2
    exit 2
    ;;
esac
