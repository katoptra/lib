#!/bin/sh
# validate-vars.sh "RECONCILE=true MAX_BATCHES=8": refuse anything that is not space
# separated KEY=value with an upper-case key and a plain value.
#
# The sync workflow splits this input into words and hands them to `task sync --`, where
# each becomes a go-task variable the engine may splice into a command. Quoting every
# splice would be the other fix, but one of them lands inside $(( )), where a quoted
# operand is a syntax error, so the boundary is the place that can refuse the whole class.
#
# `--check` runs this file's own cases instead, so the rule and its proof stay together.
set -eu

# Byte collation, not the caller's: under a UTF-8 locale a range like [A-Z] also matches
# lower case, which let a lower-case key through until this file's own cases caught it.
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
no 'RECONCILE=x" = "x" ; echo pwned'    'the quote break-out from the review'
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
