# lib

The toolbox every katoptra mirror includes by URL. Read `README.md` for the contract and
`docs/superpowers/specs/2026-09-08-toolbox-library-design.md` for the decisions. `MIGRATION.md` is how a
mirror moves onto it.

## Constraints

- `toolbox.yml` declares no `vars:` default for anything a mirror owns. Defaults go
  inline. This is a go-task fact, verified: a library `vars:` default shadows the
  mirror's root value.
- Verb names are reserved across host and container. `plan` is the host-side read-only
  run; an engine's batch planner is `split`. The hooks, `prepare`, `verify`, `index`,
  `smoke`, `report-engine` in the engine and `report-mirror` in the toolbox, are the
  only verbs a mirror redefines, each excluded on the include that defines it.
  `report-engine` exists in both files, so an engine consumer excludes it on the
  toolbox include.
- A mirror's root var shadows a command-line `KEY=value` inside an included verb, so an
  engine tunable is an inline default and never a root var of the example.
- Every tool in an image comes from `toolchain.lock.toml` with a checksum. The AWS CLI
  zip is the marked exception.
- Images set `TASK_REMOTE_OFFLINE=1`. Inside a run the include resolves from the
  mirror's `.task/remote` cache, bind-mounted with the repo, never from the network.
- `run` and `render` mount the repository's git top level at `/work` and set the working
  directory to the Taskfile's subdirectory. For a mirror the two coincide; for the
  examples here it is what makes `../../toolbox.yml` reachable.
- `render` captures task's dry run from inside the container (`sh -c 'task ... 2>&1'`)
  so the container engine's own progress lines never reach `render.txt`.
- Inside a `sh:` var, `printf -- '-e %s'` prints dashes: task's built-in shell takes
  the `--` as the format. Use `printf '%s %s ' -e "$v"`.
- Actions pinned to a full SHA with the version in a trailing comment.

## Verifying a change

```sh
cd examples/rsync  && task image-build && task run -- task tools && task check && task run -- task offline
cd examples/proton && task image-build && task run -- task tools && task check
```

A verb change updates the `render.txt` files via `task render-update`; `offline` is
the engine's own check over `examples/rsync/fixtures/`.
