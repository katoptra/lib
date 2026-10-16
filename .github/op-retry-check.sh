#!/bin/sh
# The check of the op verb in toolbox.yml. A stub op and a stub sleep go first in PATH. A
# test Taskfile includes toolbox.yml and runs `run` on the host. Thus, the check needs only
# task. It needs no image and no vault.
#
# The three cases:
#   - op fails two times before the command starts: the verb tries again, after 5 and 10 s
#   - op starts the command, and the command fails: the verb does not start it again
#   - op always fails: the verb stops after five tries.
set -eu

lib=$(cd "$(dirname "$0")/.." && pwd)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
mkdir "$dir/bin"
: > "$dir/op.env"
cat > "$dir/Taskfile.yml" <<EOF
version: '3'
includes:
  toolbox: {taskfile: $lib/toolbox.yml, flatten: true, excludes: [run], vars: {NAME: check, DESC: check}}
tasks:
  run:
    cmds: ['{{range .CLI_ARGS_LIST}}{{shellQuote .}} {{end}}']
EOF
# The stub op counts its calls. The first OP_FAILS calls fail before the command starts.
cat > "$dir/bin/op" <<'EOF'
#!/bin/sh
echo call >> "$CHECK_DIR/calls"
test "$(wc -l < "$CHECK_DIR/calls")" -gt "$OP_FAILS" || { echo "[ERROR] (502) Unknown" >&2; exit 1; }
shift 3
exec "$@"
EOF
cat > "$dir/bin/sleep" <<'EOF'
#!/bin/sh
echo "$1" >> "$CHECK_DIR/sleeps"
EOF
chmod +x "$dir/bin/op" "$dir/bin/sleep"

# try OP_FAILS CMD prints "<ok|fail> <op calls> <waits>".
try() {
  rm -f "$dir/calls" "$dir/sleeps"
  rc=0
  (cd "$dir" && CHECK_DIR="$dir" OP_FAILS="$1" PATH="$dir/bin:$PATH" task op -- sh -c "$2" > /dev/null 2>&1) || rc=$?
  printf '%s %s %s\n' "$(test "$rc" = 0 && echo ok || echo fail)" "$(wc -l < "$dir/calls" | tr -d ' ')" "$(cat "$dir/sleeps" 2> /dev/null | xargs)"
}

fails=0
expect() {
  got=$(try "$1" "$2")
  test "$got" = "$3" || { echo "op-retry: OP_FAILS=$1 '$2' gave '$got', not '$3'" >&2; fails=1; }
}
expect 2 true 'ok 3 5 10'
expect 0 'exit 7' 'fail 1 '
expect 9 true 'fail 5 5 10 20 40'
test "$fails" = 0
echo "op-retry: PASS"
