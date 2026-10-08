#!/bin/sh
# validate-vars.sh "RECONCILE=true MAX_BATCHES=8": reject each input that is not KEY=value
# pairs with spaces between them. Each key must be upper case (A-Z and _). Each value must
# contain only letters, digits, ".", "_", "/" and "-".
#
# The sync workflow divides this input into words and gives them to `task sync --`. There,
# each word becomes a go-task variable, and the engine can put it into a command. Quotes
# around each such variable are the other solution. But one variable is in $(( )), where a
# quoted operand is a syntax error. Thus, this check, before the input goes into a
# command, is the location that can reject the full class of bad input.
#
# With `--check`, this file does its test cases and does not examine an input. Thus, the
# rule and its test cases stay together.
set -eu

# Byte collation, not the collation of the caller. In a UTF-8 locale, a range (for example
# [A-Z]) also agrees with lower-case letters. Thus, without byte collation, the check can
# accept a lower-case key.
LC_ALL=C
export LC_ALL

validate() {
  for kv in $1; do
    case "$kv" in *=*) ;; *) echo "vars: not KEY=value: $kv" >&2; return 1 ;; esac
    case "${kv%%=*}" in ''|*[!A-Z_]*) echo "vars: bad key: $kv" >&2; return 1 ;; esac
    case "${kv#*=}" in *[!A-Za-z0-9._/-]*) echo "vars: bad value: $kv" >&2; return 1 ;; esac
  done
}

if [ "${1:-}" != --check ]; then
  validate "${1:-}"
  exit 0
fi

fail=0
ok() { if validate "$1" 2>/dev/null; then echo "ok: accepts $2"; else echo "FAIL: refused $2"; fail=1; fi; }
no() { if validate "$1" 2>/dev/null; then echo "FAIL: accepted $2"; fail=1; else echo "ok: refuses $2"; fi; }

ok ''                                   'an empty input'
ok 'RECONCILE=true'                     'one pair'
ok 'RECONCILE=true MAX_BATCHES=8'       'several pairs'
ok 'TL=systems/texlive/tlnet'           'a path value'
ok 'CEILING_GB='                        'an empty value'
ok 'TL_KEY=C78B82D8C79512F79CC0D7C80D5E5D9106BAB6BC' 'a fingerprint'

no 'RECONCILE=x; echo pwned'            'a command separator'
no 'BATCH_GB=$(id)'                     'a command substitution'
no 'MAX_BATCHES=`id`'                   'a backquote'
no 'RECONCILE=x" = "x" ; echo pwned'    'a quote break-out'
no 'A=b|c'                              'a pipe'
no 'A=b&c'                              'an ampersand'
no 'A=b>c'                              'a redirect'
no 'A=b*'                               'a glob'
no 'reconcile=true'                     'a lower-case key'
no '=value'                             'an empty key'
no 'noequals'                           'a word that is not a pair'
no 'OK=fine BAD=$(id)'                  'a bad pair after a good one'

[ "$fail" -eq 0 ] || { echo; echo "the vars guard is not sound"; exit 1; }
echo
echo "the vars guard accepts plain KEY=value and refuses every metacharacter above"
