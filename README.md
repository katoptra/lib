# lib

[![ci](https://github.com/katoptra/lib/actions/workflows/ci.yml/badge.svg)](https://github.com/katoptra/lib/actions/workflows/ci.yml)
[![license](https://img.shields.io/github/license/katoptra/lib)](LICENSE)

The toolbox every katoptra mirror includes: the menu, the container, the secrets model,
the dry-run check and the workflows. A mirror keeps its identity and its pipeline;
everything about how a run is started, contained and reported comes from here.

## How it works

1. **`toolbox.yml`** is a go-task include. A mirror includes it by URL, flattened, and
   gets `sync`, `plan`, `check`, `run`, `op`, `image`, `clock`, `ping` and the rest. A
   verb the mirror lists under `excludes:` and defines itself replaces the library's.
2. **`toolchain.lock.toml`** pins every tool by version and checksum. The two images
   under `docker/` and the `toolbox` action install from it and nothing else.
3. **Images** are published to `ghcr.io/katoptra/toolbox` as `rsync-v1` and `proton-v1`
   by the release workflow. A run pulls one and never builds.
4. **Workflows** under `.github/workflows` are reusable: a mirror's `sync.yml` and
   `check.yml` are ten lines each and call these by tag.
5. **`examples/`** hold one consumer per image. Their committed `render.txt` is the
   library's own check: every verb resolves and every command renders.

## Using it in a mirror

```yaml
version: '3'
vars:
  SOURCE: rsync://rsync.dante.ctan.org/CTAN/
  BUCKET: ctan
  HOST: ctan.ijosh.com
includes:
  toolbox:
    taskfile: https://raw.githubusercontent.com/katoptra/lib/v1/toolbox.yml
    flatten: true
    vars:
      NAME: ctan
      DESC: an hourly mirror of CTAN at https://ctan.ijosh.com/
      IMAGE: ghcr.io/katoptra/toolbox:rsync-v1
      PASS: SEED RECONCILE MAX_BATCHES
tasks:
  pipeline:      {cmds: [{task: clock}, {task: list}, {task: ping}]}
  plan-pipeline: {cmds: [{task: clock}, {task: list}]}
```

Two verbs are the contract, `pipeline` and `plan-pipeline`, both run inside the image.
The mirror's identity lives in its root `vars`, where both the library's verbs and the
mirror's own can read it. `PASS` names the host environment variables that cross into
the container beside the ones in `op.env`.

Beside it, a `.taskrc.yml` so nothing prompts and the include is fetched at most hourly:

```yaml
remote:
  trusted-hosts: [raw.githubusercontent.com]
  expiry: 1h
```

An `op.env` of `op://` references, if the secrets live in 1Password. Without one,
`task sync` runs with whatever the environment already holds. And the two caller
workflows:

```yaml
# .github/workflows/sync.yml
name: sync
on:
  workflow_dispatch:
    inputs: {vars: {type: string, default: ''}}
concurrency: {group: sync, cancel-in-progress: false}
jobs:
  sync:
    uses: katoptra/lib/.github/workflows/sync.yml@v1
    with: {vars: '${{ inputs.vars }}'}
    secrets: inherit
```

```yaml
# .github/workflows/check.yml
name: check
on: {pull_request: {}}
jobs:
  check:
    uses: katoptra/lib/.github/workflows/check.yml@v1
```

Then `task render-update` once, commit `render.txt`, and `task check` from then on.

## Working on it

```sh
$ git clone https://github.com/katoptra/lib
$ cd lib/examples/rsync && task image-build && task check
$ cd ../proton && task image-build && task check
```

`task image-build` builds the image the example names from `docker/`. `task check`
renders the example's pipeline inside it and diffs against `render.txt`. Change a verb,
run `task render-update` in each example, and the diff in the pull request is the
review.

## Releasing

Tag a commit `vX.Y.Z` and push the tag. The release workflow builds both images for
amd64 and arm64, pushes `<variant>-vX.Y.Z` and `<variant>-vX`, and moves the `vX` git
tag. Every mirror pinned to `vX` picks the change up on its next run. A breaking change
to a verb's name or contract is a new major.

Pull requests are welcome.

MIT licensed. Built by [Josh Vaughen](https://ijosh.com).
