# lib

The toolbox every katoptra mirror includes by URL. Read `README.md` for the contract and
`docs/superpowers/specs/2026-09-08-toolbox-library-design.md` for the decisions.

## Constraints

- `toolbox.yml` declares no `vars:` default for anything a mirror owns. Defaults go
  inline. This is a go-task fact, verified: a library `vars:` default shadows the
  mirror's root value.
- Verb names are reserved across host and container. `plan` is the host-side read-only
  run; an engine's batch planner is `split`. The hooks, `prepare`, `verify`, `index`,
  `smoke`, `smoke-mirror`, `report-engine` in the rsync engine, `stage` and `prune` in
  the proton engine, and `report-mirror` in the toolbox, are the only verbs a mirror
  redefines, each excluded on the include that defines it; `pipeline` and
  `plan-pipeline` come from the engine and a mirror excludes them only for another
  order. `report-engine` exists in both files, so an engine
  consumer excludes it on the toolbox include. Extension is a hook, never a copy: a
  verb that needs more than the engine does gets a `-mirror` hook the engine calls last.
- A mirror's root var shadows a command-line `KEY=value` inside an included verb, so an
  engine tunable is an inline default and never a root var of the example. A var of
  another name that reads the tunable, `BATCHES_MAX` from `MAX_BATCHES`, still sees the
  command line (verified), so each default is spelled once.
- A called task sees none of its caller's call vars. A hook a verb calls with an
  overridable `RUN` or `STAGING` gets them passed on explicitly, as `smoke` does.
- A global var that reads another var is rendered once, from the root's and the command
  line's values, never from a call var: `GPGCHECK` takes the fingerprint as an awk `-v`
  at each use, where a call var `TL_KEY` is visible.
- No `dir:` on an engine verb. In a flattened include read by path, task joins even an
  absolute `dir:` onto the include's directory (verified, 3.53.1), so `verify` starts
  each command with `cd {{.STAGING}}` instead.
- `render` mounts an empty directory over `.run`, so a `sh:` var read from it at parse
  time renders the same from any working tree. A verb that reads `.run` at parse time
  must tolerate an empty one.
- `.taskrc.yml` keys are `trusted-hosts` and `cache-expiry`; task ignores a key it does
  not know, silently, and refetches on every invocation.
- Every tool in an image comes from `toolchain.lock.toml`, read through `docker/lock.py`,
  the one reader the Dockerfiles and the toolbox action share, and every one is checked
  before it is used. Most carry a recorded sha256. The AWS CLI zip carries none, because
  upstream publishes a detached PGP signature instead, so the fetch stage verifies that
  signature against `docker/aws-cli.pub` and requires the fingerprint the lock pins,
  through the same GOODSIG-and-VALIDSIG awk gate the engine uses for TeX Live.
- Images set `TASK_REMOTE_OFFLINE=1`. Inside a run the include resolves from the
  mirror's `.task/remote` cache, bind-mounted with the repo, never from the network.
- `run` and `render` mount the repository's git top level at `/work` and set the working
  directory to the Taskfile's subdirectory. For a mirror the two coincide; for the
  examples here it is what makes `../../toolbox.yml` reachable.
- `render` captures task's dry run from inside the container (`sh -c 'task ... 2>&1'`)
  so the container engine's own progress lines never reach `render.txt`.
- Inside a `sh:` var, `printf -- '-e %s'` prints dashes: task's built-in shell takes
  the `--` as the format. Use `printf '%s %s ' -e "$v"`.
- Task's built-in shell has no `umask`. A file that must be born 0600 is
  `install -m 600 /dev/null "$f"` and then written, as the proton engine's `age` does.
- The proton engine keeps no state of the mirror's in the bucket, only the CLI session,
  because `filesystem upload` skips a file whose content Proton already holds and
  `-f create-new-revision` handles one that changed. Every CLI call goes through `pd`,
  which pushes the session back whatever the exit: the refresh token rotates, and a run
  that kept a rotated token to itself leaves the next run unable to log in. Two mirrors
  never share one session for the same reason.
- Actions pinned to a full SHA with the version in a trailing comment. A mirror pins the
  two reusable workflows that way; each checks this repository out at its own commit
  (`github.job_workflow_sha`) for the toolbox action and the lock, so a workflow pin is
  the one pin. The include and the image float at `v2` by design: moving that tag is
  the rollout.

## Verifying a change

```sh
cd examples/rsync  && task image-build && task run -- task tools && task check && task run -- task offline
cd examples/proton && task image-build && task run -- task tools && task check && task run -- task offline
```

A verb change updates the `render.txt` files via `task render-update`; `offline` is
each engine's own check. The rsync one runs over `examples/rsync/fixtures/`: the list
diff over `run-root` and `run-empty`, `retry`'s exit codes, and `prepare` and `verify`
over `tree/`, a signed subtree whose tlpdb is signed by a throwaway key pinned in the
example. Regenerate the tree with a new key only to change its shape; the private half
was never kept. The proton one runs `confirm` over `examples/proton/fixtures/`, an
accepting and a refusing upload summary, and the `age` verb round trip with a throwaway
identity.
