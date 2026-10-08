#!/bin/sh
# The gate that accepts a downloaded AWS CLI zip only if it is the zip with the signature
# of AWS. The status lines of gpgv must contain a GOODSIG, and a VALIDSIG with the
# primary-key fingerprint that the lock pins. The image build on each CI run is the test
# of the path that accepts. This script is the test of the paths that reject, because no
# other check can find an error in them. It also shows that the program and the
# fingerprint here are the same as the program and the fingerprint in the Dockerfile and
# the lock.
set -eu
cd "$(dirname "$0")"

GATE='/^\[GNUPG:\] GOODSIG /{g=1} /^\[GNUPG:\] VALIDSIG / && $NF == k {v=1} END{exit !(g&&v)}'
KEY=FB5DB77FD5C118B80511ADA8A6310ACC4672475C
IMPOSTOR=DEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF
fail=0

grep -qF "$GATE" rsync.Dockerfile \
  || { echo "FAIL: rsync.Dockerfile does not contain the gate this checks"; fail=1; }
grep -qF "$KEY" ../toolchain.lock.toml \
  || { echo "FAIL: toolchain.lock.toml does not pin $KEY"; fail=1; }

# The gpgv --status-fd 1 output for a signature that AWS made for the AWS CLI installer.
good() {
  cat <<EOF
[GNUPG:] NEWSIG
[GNUPG:] KEY_CONSIDERED $1 0
[GNUPG:] SIG_ID qNpIIK9WjvA/o2exCaDRMYHEk2I 2026-08-14 1786731634
[GNUPG:] GOODSIG A6310ACC4672475C AWS CLI Team <aws-cli@amazon.com>
[GNUPG:] VALIDSIG $1 2026-08-14 1786731634 0 4 0 1 10 00 $1
EOF
}

# case_ gets the description, the correct exit and the pinned fingerprint. It reads the
# status lines from stdin.
case_() {
  got=0
  awk -v k="$3" "$GATE" >/dev/null || got=$?
  if [ "$got" -eq "$2" ]; then
    echo "ok: $1"
  else
    echo "FAIL: $1 (wanted exit $2, got $got)"
    fail=1
  fi
}

good "$KEY"     | case_ "AWS's own signature is accepted"                     0 "$KEY"
good "$KEY"     | case_ "a different pinned fingerprint rejects it"           1 "$IMPOSTOR"
good "$IMPOSTOR"| case_ "a signature by another key is rejected"              1 "$KEY"
printf '%s\n' "[GNUPG:] VALIDSIG $KEY 2026-08-14 1786731634 0 4 0 1 10 00 $KEY" \
                | case_ "VALIDSIG without GOODSIG is rejected (expired key)"  1 "$KEY"
printf '%s\n' "[GNUPG:] GOODSIG A6310ACC4672475C AWS CLI Team" \
                | case_ "GOODSIG without VALIDSIG is rejected"                1 "$KEY"
: | case_ "no output at all is rejected (gpgv absent or crashed)"             1 "$KEY"

[ "$fail" -eq 0 ] || { echo; echo "the AWS CLI signature gate is not sound"; exit 1; }
echo
echo "the AWS CLI signature gate rejects everything but AWS's own signature"
