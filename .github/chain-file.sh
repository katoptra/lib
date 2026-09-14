#!/bin/sh
# chain-file.sh "$GITHUB_WORKFLOW_REF": print the caller's own workflow file, the argument
# to `gh workflow run` when a run chains the next one.
#
# The ref is owner/repo/.github/workflows/<file>@<ref>, and <ref> holds slashes of its own
# (refs/heads/main), so the @ and everything after it come off before the path does.
#
# `--check` runs this file's own cases instead, so the rule and its proof stay together.
set -eu

chain_file() {
  path="${1%%@*}"
  printf '%s\n' "${path##*/}"
}

if [ "${1-}" = --check ]; then
  [ "$(chain_file 'katoptra/dropbox/.github/workflows/sync.yml@refs/heads/main')" = sync.yml ]
  [ "$(chain_file 'katoptra/ctan/.github/workflows/hourly.yml@refs/heads/josh/topic')" = hourly.yml ]
  [ "$(chain_file 'o/r/.github/workflows/sync.yml@81fb6ee34abc7703087cfe4a303263febc912c6f')" = sync.yml ]
  echo "chain-file: PASS"
  exit 0
fi

chain_file "$1"
