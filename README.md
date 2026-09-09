# lib

[![ci](https://github.com/katoptra/lib/actions/workflows/ci.yml/badge.svg)](https://github.com/katoptra/lib/actions/workflows/ci.yml)
[![license](https://img.shields.io/github/license/katoptra/lib)](LICENSE)

The toolbox every katoptra mirror includes by URL. The rule it enforces: the code that
starts a run, contains it, resolves its secrets, checks it and reports it lives here,
once. The code that moves bytes for a transport lives here too, once per engine, and
`engines/rsync.yml` is the first. A mirror holds only its identity, the order of its
pipeline, and the few verbs no other mirror shares.

## The layers

```mermaid
flowchart TB
  subgraph mirror["A mirror repository (katoptra/ctan, say)"]
    tf["Taskfile.yml<br/>root vars: SOURCE, BUCKET, HOST<br/>pipeline, plan-pipeline<br/>overrides, if any"]
    opv["op.env<br/>op:// references"]
    rt["render.txt<br/>the committed dry run"]
    cw["sync.yml, check.yml<br/>callers of lib's"]
  end
  subgraph lib["katoptra/lib, pinned to v2"]
    tb["toolbox.yml<br/>menu, image, run, op, sync, plan<br/>render, check, clock, ping"]
    en["engines/rsync.yml<br/>list, diff, split, batches, reconcile ...<br/>hooks: prepare, verify, index, smoke"]
    im["ghcr.io/katoptra/toolbox:&lt;variant&gt;-v2<br/>docker/ + toolchain.lock.toml"]
    wf[".github/workflows/sync.yml, check.yml<br/>.github/actions/toolbox"]
  end
  tf -- "includes, flattened" --> tb
  tf -- "includes, flattened" --> en
  tb -- "runs pipeline inside" --> im
  cw -- "uses @release SHA" --> wf
  wf -- "task sync / task check" --> tb
```

| Layer | Lives in | Owns | A mirror touches it when |
|---|---|---|---|
| Toolbox | `toolbox.yml` | How a run starts, is contained, resolves secrets, is rendered, checked and reported | Never; it is included as is |
| Engine | `engines/<transport>.yml` | How bytes move for one transport: rsync to R2, Proton Drive, HTTPS | It lists a verb under `excludes:` and defines its own |
| Image | `docker/`, `toolchain.lock.toml` | Every tool a run needs, pinned by checksum | Never; it names one in `IMAGE` |
| Workflows | `.github/workflows`, `.github/actions/toolbox` | How Actions installs the tools and runs `task sync` and `task check` | Never; its callers are a few lines each |
| Mirror | The mirror's own repository | Identity, pipeline order, the exceptions | Always; this is all it holds |

## What a run looks like

The same path on a laptop and in Actions. On a laptop it starts at `task sync`.

```mermaid
sequenceDiagram
  participant D as jshvn/dispatch
  participant W as sync.yml (reusable)
  participant H as Host: task
  participant O as op run
  participant C as Container: task
  D->>W: workflow_dispatch, vars
  W->>W: toolbox action installs task and op from the lock
  W->>H: task sync -- RECONCILE=... MAX_BATCHES=...
  H->>H: image: pull IMAGE if missing
  H->>O: op: op run --env-file=op.env
  O->>C: run: engine run --rm -v repo:/work -e NAME ... IMAGE task pipeline
  C->>C: clock
  C->>C: engine verbs: list, diff, split, batches, reconcile ...
  C->>C: report, then ping
  alt pipeline failed
    C->>C: failed: report STATUS=failed, then ping-fail
  else the runner cut the run off
    W->>C: task op -- task failed
  else .run/chain exists
    W->>D: gh workflow run, the caller's own file
  end
```

Three things the diagram hides:

- **Secrets cross by name, never by value.** `op run` resolves `op.env` on the host and
  exports the values; `run` passes `-e NAME` for each name in `op.env` and in `PASS`,
  plus `HEALTHCHECK_URL`, `GITHUB_STEP_SUMMARY` and `GITHUB_RUN_ID` always, so no value
  ever appears on a command line or in a log.
- **1Password is read once per run.** One `op run` wraps the whole pipeline, and the
  failure path, `failed`, runs inside the same container, so a failed run costs no
  second read. The one exception is a run the runner cut off, by the timeout or a
  cancellation, which never reached its own failure path: the workflow runs `failed`
  again from outside, one more read on a rare day. A mirror without an `op.env` runs
  on its repository secrets: the reusable workflow exports every inherited secret into
  the sync step's environment by name, the ones the mirror lists in `PASS` cross into
  the container, and the 1Password CLI is not installed at all.
- **Nothing inside the container reaches the network for task itself.** The image sets
  `TASK_REMOTE_OFFLINE=1` and the mirror's `.task/remote` cache rides in with the repo.
- **`plan` is `sync` with the read-only half.** It runs `plan-pipeline` instead of
  `pipeline`, inside the same image with the same secrets.

## The verbs

### What a mirror must define

| Name | Kind | Meaning |
|---|---|---|
| `SOURCE`, `BUCKET`, `HOST` | root vars | The mirror's identity. Engines read them; the library never defaults them. |
| `NAME`, `DESC`, `IMAGE` | include vars | The menu's title and line, and the image the run happens inside. |
| `pipeline`, `plan-pipeline` | tasks | The full run and its read-only half, in order, inside the image; `sync` and `plan` call them. An engine supplies both; a mirror with no engine defines them. |

### What a mirror may define

| Name | Kind | Meaning |
|---|---|---|
| `PASS` | include var | Host environment names that cross into the container beside the ones in `op.env`, for a pipeline that reads its environment. Task vars are not environment: they go after `--`, as `task sync -- MAX_BATCHES=8`. |
| `report-mirror` | task | The mirror's rows of the run summary, after the toolbox's and the engine's. Excluded on the toolbox include. |
| `smoke-mirror` | task | The mirror's own read-back checks, after the engine's sample. Excluded on the engine include. |
| `MENU` | include var | Extra lines for the menu, one per mirror-specific verb. |
| `LIB_DIR` | include var | Where `image-build` finds `docker/`; defaults to `../lib`. |
| `op.env` | file | `op://` references, one per secret. Absent means the environment is already resolved: on a laptop, whatever is exported; in Actions, the repository's secrets, crossing by the names in `PASS`. |
| `excludes:` | include key | Library verbs the mirror replaces. See below. |

### What the toolbox provides

Host side, and the mirror does not override these. They are the contract the workflows
call and the menu documents.

| Verb | Does |
|---|---|
| `default` | The grouped menu, from `NAME`, `DESC` and `MENU` |
| `sync` | `op -- task pipeline`: one run |
| `plan` | `op -- task plan-pipeline`: the read-only half |
| `check` | `render`, then diff against `render.txt` |
| `render-update` | `render`, then accept it as `render.txt` |
| `render` | `task --dry --force pipeline` inside the image, over an empty `.run`, saved to `.run/render.txt` |
| `run -- <cmd>` | Anything inside the image, with the repo at `/work` |
| `op -- <cmd>` | `run`, wrapped in `op run --env-file=op.env` when the file exists |
| `image` | Pull `IMAGE`; a no-op while it exists locally |
| `image-build` | Build `IMAGE` from `LIB_DIR/docker/<variant>.Dockerfile` |
| `image-clean` | Remove `IMAGE` |
| `clean` | Delete `.run`, `staging` and the Taskfile cache; nothing else |

Inside the image. A mirror or engine may override these when it keeps its own.

| Verb | Does |
|---|---|
| `clock` | Write "epoch UTC-hour weekday" to `.run/start.txt` and forget the last run's chain file |
| `report` | Append the run summary to the Actions job page (stdout elsewhere): its own rows, then `report-engine`'s, then `report-mirror`'s |
| `report-engine`, `report-mirror` | Hooks: no-ops here, the engine's and the mirror's rows |
| `ping` | GET `HEALTHCHECK_URL`; skipped when unset |
| `ping-fail` | GET `HEALTHCHECK_URL/fail`; skipped when unset |
| `failed` | The failure path: `report STATUS=failed`, then `ping-fail` |

`sync` runs `pipeline`, and on a failure `failed`, all in the one container; the
workflow runs `failed` from outside only for a run the runner cut off. One table, three
layers: the toolbox's rows (when the run started
and how long it took, the image, whether the next run is queued), the engine's, the
mirror's, each a `| Label | value |` line appended to the same file. Every row tolerates
a missing file, because the report also runs after a failed pipeline.

### What an engine provides

An engine is a second include with the verbs for one transport. Its verbs are the
pipeline vocabulary, reserved across every engine so a mirror's `pipeline` reads the
same whichever transport it uses. The rsync engine, `engines/rsync.yml`, is the first:
an rsync upstream into an S3 bucket, as a list diff and never a local tree.

| Verb | Does |
|---|---|
| `pipeline`, `plan-pipeline` | The verbs below in order, and the read-only half of them: `clock`, `list`, `state`, `diff`, `split` |
| `list` | `rsync --list-only` of `SOURCE`, through `FILTER`, normalised to `.run/upstream.txt` as `path TAB size TAB mtime`, byte-sorted; a listing under `LIST_FLOOR` lines stops the run |
| `state` | Fetch `.state/applied.txt.xz` from the bucket; a missing one asks `rebuild` |
| `rebuild` | List the bucket and make the state exactly what it holds at upstream's sizes |
| `diff` | `changed.txt`, `deleted.txt` and `paths.txt`: upstream against the state |
| `split` | Refuse a tree over `CEILING_GB` or a file the disk cannot hold; split the delta into `batch-NNNN.txt` of `BATCH_GB`, the decision batch last |
| `prepare` | Hook. With `TL_KEY` set and the delta touching `TL`: fetch the tlpdb and check its signature against the pinned key |
| `batches` | Work the first `MAX_BATCHES`, each `fetch`, `verify`, `publish`, `checkpoint`; touch `.run/chain` when batches remain |
| `verify` | Hook. With `TL_KEY` set: every signed file and every container in the batch against the tlpdb |
| `delete` | Remove the keys upstream dropped, 1,000 per call, once every batch has landed, and drop them from the state |
| `reconcile` | In the run that starts in hour 03 UTC, or with `RECONCILE=true`: rebuild the state, then delete what neither upstream, `OWN` nor the state's own directories own |
| `index` | Hook. Nothing here; a mirror that draws directory pages or a landing page replaces it |
| `smoke` | A sample of the run's keys read back through `HOST`, sizes against the listing, the tlpdb sha512 when `TL` is set, then `smoke-mirror` |
| `smoke-mirror` | Hook. Nothing here; a mirror with more to read back defines it |
| `report-engine` | Hook. The engine's rows of the run summary |
| `retry` | Run a command, retrying rsync's transport exit codes with backoff; 24 is a success |

`normalise`, `pull`, `push`, `batch`, `fetch`, `publish`, `merge`, `checkpoint` and
`remove` are the verbs those call; `pull` and `push` move an xz-compressed key between
the bucket and `.run`, and a mirror's own verb may call them. A mirror replaces a hook by
listing it under `excludes:` on the engine include and defining its own; `report-engine`
is defined in the toolbox too, as a no-op, so an engine consumer's toolbox include
excludes it.

A mirror sets `SOURCE`, `BUCKET` and `HOST` in its root vars, always. Everything else
has an inline default in the engine, and a mirror sets only what differs:

| Var | Default | Meaning |
|---|---|---|
| `CEILING_GB` | 0, no ceiling | `split` refuses a tree larger than this many decimal GB |
| `BATCH_GB` | 4 | Decimal GB per batch; a larger file is a batch by itself |
| `MAX_BATCHES` | 4 | Batches per run; the rest chain the next run |
| `LIST_FLOOR` | 0, no guard | A listing under this many lines is a truncated one, never a deletion list |
| `RECONCILE` | `auto` | `true`, `false`, or `auto`: the run that started in hour 03 UTC |
| `RETRY_BASE` | 15 | Seconds; the retry sleeps are `RETRY_BASE * 2^i` plus jitter |
| `TL`, `TL_KEY` | empty | A signed TeX Live subtree and the fingerprint that signs it; empty, no signature checks |
| `FILTER` | empty | rsync filter arguments that narrow the listing, for a mirror of a subtree |
| `OWN` | empty | Bucket-root keys the mirror owns, space separated; `reconcile` never deletes them |
| `INDEX` | empty | The key suffix of the directory pages a mirror's `index` draws; set, `reconcile` spares those pages and every bare directory of the state, their second key |

A var the mirror puts in its root `vars:` is fixed for every run: inside an included
verb a root value shadows a `KEY=value` from the command line. One the mirror leaves to
its default is the run's to set, `task sync -- MAX_BATCHES=8 RECONCILE=true`. So a root
var that restates a default is worse than none: it silences the command line.

A mirror of one signed subtree, shaped like tlnet:

```yaml
version: '3'
vars:
  SOURCE: rsync://rsync.dante.ctan.org/CTAN/
  BUCKET: tlnet
  HOST: tlnet.ijosh.com
  TL: systems/texlive/tlnet
  TL_KEY: C78B82D8C79512F79CC0D7C80D5E5D9106BAB6BC
  CEILING_GB: 10
  OWN: index.html
  FILTER: >-
    --exclude=*.r[0-9]*.tar.xz --exclude=/systems/texlive/tlnet/update-tlmgr-r*
    --include=/systems/ --include=/systems/texlive/ --include=/systems/texlive/tlnet/***
    --exclude=*
env:
  AWS_CONFIG_FILE: '{{.ROOT_DIR}}/aws.config'
includes:
  toolbox:
    taskfile: https://raw.githubusercontent.com/katoptra/lib/v2/toolbox.yml
    flatten: true
    excludes: [report-engine, report-mirror]
    vars:
      NAME: tlnet
      DESC: a daily mirror of TeX Live's tlnet at https://tlnet.ijosh.com/
      IMAGE: ghcr.io/katoptra/toolbox:rsync-v2
      PASS: AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_ENDPOINT_URL
  rsync:
    taskfile: https://raw.githubusercontent.com/katoptra/lib/v2/engines/rsync.yml
    flatten: true
    excludes: [index]
tasks:
  index:
    desc: The landing page, dated today, at the bucket root
    cmds:
      - sed "s/DATE/$(date -u +%Y-%m-%d)/" site/index.html | aws s3 cp --content-type text/html --cache-control no-cache - s3://{{.BUCKET}}/index.html
  report-mirror:
    internal: true
    cmds:
      - 'echo "| Landing page | index.html, dated $(date -u +%Y-%m-%d) |" >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"'
```

`SOURCE` is the archive root and `FILTER` narrows the listing to the subtree, so every
key keeps its `systems/texlive/tlnet/` prefix. `OWN` keeps `reconcile` off the landing
page, `index` is the one hook the mirror fills, and the pipeline is the engine's.

### The bucket is the mirror; the state is a cache

An rsync engine keeps a state file in the bucket, under `.state/`, listing every key the
bucket holds at upstream's size and mtime. Each run diffs upstream's listing against it,
so an hourly run costs one listing of upstream and none of the bucket. Two things follow.

- **There is no seed.** A missing state file is rebuilt from a listing of the bucket. An
  empty bucket gives an empty state, so the first run's delta is the whole tree, worked
  `MAX_BATCHES` at a time; when batches remain the run chains the next one, and the fill
  converges in a few chained runs with no flag. A lost state file costs the same listing
  and nothing else.
- **`RECONCILE` is the check on a live mirror.** It rebuilds the state from the bucket
  on purpose, daily by default, and deletes keys neither upstream nor the state owns.

What a mirror cannot afford to lose is the bucket. Everything else, the state file and the
staging tree included, is derived from it and from upstream.

## Overriding a verb

List it under `excludes:` on the include that defines it and define it in the mirror.
A duplicate without `excludes` is a parse error, on purpose.

```yaml
includes:
  rsync:
    taskfile: https://raw.githubusercontent.com/katoptra/lib/v2/engines/rsync.yml
    flatten: true
    excludes: [index]          # the mirror draws its own landing page
tasks:
  index:
    cmds: [...]
```

The rules that keep this honest:

- Keep the name and the meaning. A `verify` that does something other than verify is a
  new verb with its own name, listed in `MENU`.
- Extend through a hook, never a copy. A mirror that needs the engine's `smoke` and
  more defines `smoke-mirror`, which `smoke` runs last, rather than excluding `smoke`
  and pasting it: the copy stops following releases the day it is made. A mirror with a
  step to add beside `clock` adds a step to its pipeline, not a `clock` of its own.
- The replacement reads the mirror's root vars, the same as the original did.
- Override engine verbs and the in-container toolbox verbs. Do not override the host
  side: `sync`, `plan`, `check` and `run` are what the workflows and the menu promise.
- Everything the mirror does not exclude comes from here, and a release changes it.

## Plugging in an engine

One engine per transport, one image variant per engine. Adding one is five files and
two matrix entries:

1. **Tools**: add each tool's version and per-arch checksum to `toolchain.lock.toml`.
2. **Image**: `docker/<variant>.Dockerfile`, base pinned by digest, every tool installed
   from the lock, `TASK_REMOTE_OFFLINE=1`, and a final stage that asserts each tool
   reports the locked version. `docker/rsync.Dockerfile` is the model.
3. **Verbs**: `engines/<variant>.yml` with the pipeline vocabulary above. No `vars:`
   default for anything a mirror owns; defaults go inline as `{{.X | default N}}`.
4. **Example**: `examples/<variant>/` with a Taskfile whose `pipeline` is every verb, a
   committed `render.txt`, and an `offline` verb that runs the ones that need no bucket
   over `fixtures/`. `examples/rsync/` is the model. This is the engine's own check.
5. **CI**: add the variant to the `matrix` in `ci.yml` and `release.yml`.

| Variant | Base | Tools | For |
|---|---|---|---|
| `rsync` | ubuntu 24.04 | rsync, gnupg, xz, curl, perl, go-task, AWS CLI v2 (s3, sts) | rsync upstreams to R2: ctan, tlnet, cran, cpan |
| `proton` | python 3.13 slim | proton-drive, age, go-task, boto3, requests, pytest, ruff | Python pipelines: dropbox, photos |

An HTTPS engine would be a third row: the same base as `rsync`, curl and the AWS CLI,
and a `list` that reads an index instead of `rsync --list-only`.

## Using it in a mirror

A mirror repository holds seven things:

```
Taskfile.yml                  root vars, the two includes, overrides
.taskrc.yml                   trusts raw.githubusercontent.com, refetches at most hourly
op.env                        op:// references only (optional)
render.txt                    the committed dry run
.github/workflows/sync.yml    calls katoptra/lib/.github/workflows/sync.yml at a release commit
.github/workflows/check.yml   calls katoptra/lib/.github/workflows/check.yml at a release commit
.github/dependabot.yml        bumps the two calls on a lib release
```

```yaml
# Taskfile.yml
version: '3'
vars:
  SOURCE: rsync://rsync.dante.ctan.org/CTAN/
  BUCKET: ctan
  HOST: ctan.ijosh.com
includes:
  toolbox:
    taskfile: https://raw.githubusercontent.com/katoptra/lib/v2/toolbox.yml
    flatten: true
    excludes: [report-engine]
    vars:
      NAME: ctan
      DESC: an hourly mirror of CTAN at https://ctan.ijosh.com/
      IMAGE: ghcr.io/katoptra/toolbox:rsync-v2
      PASS: AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_ENDPOINT_URL
  rsync:
    taskfile: https://raw.githubusercontent.com/katoptra/lib/v2/engines/rsync.yml
    flatten: true
```

That is a whole mirror: the engine supplies `pipeline` and `plan-pipeline`. The three
`AWS_*` names are the secrets, on a laptop exported and in Actions the repository's;
`AWS_REGION` is `auto` in the image. A mirror on another transport includes that
transport's engine instead, and a mirror with a Python pipeline of its own includes the
toolbox alone and defines the two pipeline verbs from the toolbox's `clock`, `report`
and `ping` and its own steps.

```yaml
# .taskrc.yml
remote:
  trusted-hosts: [raw.githubusercontent.com]
  cache-expiry: 1h
```

```yaml
# .github/workflows/sync.yml
name: sync
on:
  workflow_dispatch:
    inputs: {vars: {type: string, default: ''}}
permissions: {contents: read, actions: write}   # the chain step; a called workflow cannot raise this
concurrency: {group: sync, cancel-in-progress: false}
jobs:
  sync:
    uses: katoptra/lib/.github/workflows/sync.yml@04f7901cf1aa7551bc43db5ff801a225a189c42a # v1.0.2
    with: {vars: '${{ inputs.vars }}'}
    secrets: inherit
```

```yaml
# .github/workflows/check.yml
name: check
on: {pull_request: {}}
jobs:
  check:
    uses: katoptra/lib/.github/workflows/check.yml@04f7901cf1aa7551bc43db5ff801a225a189c42a # v1.0.2
```

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule: {interval: weekly}
    groups: {actions: {patterns: ['*']}}
```

Two pins, one policy. The workflow calls are pinned to a release commit with the
version in a trailing comment, as an Actions policy that requires a full SHA on every
`uses:` demands, and Dependabot bumps them; each reusable workflow checks this
repository out at that same commit for the toolbox action and the lock, so the workflow
pin is the only Actions-side pin. The include and the image float at `v2`, on purpose:
moving that tag is how a verb or a tool reaches every mirror on its next run. `timeout-
minutes` goes in `with:` only when it differs from the workflow's default of 355.

Then `task render-update` once, commit `render.txt`, and `task check` from then on.
Every pull request that changes what the mirror executes shows up as a diff in
`render.txt`, and that diff is the review.

## Working on it

```sh
$ git clone https://github.com/katoptra/lib
$ cd lib/examples/rsync && task image-build && task check && task run -- task offline
$ cd ../proton && task image-build && task check
```

`task image-build` builds the image the example names from `docker/`. `task check`
renders the example's pipeline inside it and diffs against `render.txt`; `task run --
task offline` runs the engine's verbs that need no bucket over `fixtures/`: the list
diff, `retry`, and `prepare` and `verify` over a signed subtree whose key is the
example's own. Change a verb, run `task render-update` in each example, and the diff in
the pull request is the review. `CONTRIBUTING.md` has the three rules this repository
adds to the org's.

## Releasing

Tag a commit `vX.Y.Z` and push the tag. The release workflow builds both images for
amd64 and arm64, pushes `<variant>-vX.Y.Z` and `<variant>-vX`, and moves the `vX` git
tag. Every mirror pinned to `vX` picks the change up on its next run. A breaking change
to a verb's name or contract is a new major.

Pull requests are welcome.

MIT licensed. Built by [Josh Vaughen](https://ijosh.com).
