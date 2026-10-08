#!/bin/sh
# chain-file.sh "$GITHUB_WORKFLOW_REF": print the workflow file of the caller. This is the
# argument to `gh workflow run` when a run chains the next run.
#
# The ref is owner/repo/.github/workflows/<file>@<ref>, and <ref> can also contain slashes
# (refs/heads/main). Thus, the script first removes the @ and all the text after it. Then
# it removes the path.
#
# With `--check`, this file does its test cases and prints no file name. Thus, the rule
# and its test cases stay together.
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
