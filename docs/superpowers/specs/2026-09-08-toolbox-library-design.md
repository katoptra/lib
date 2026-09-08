# katoptra/lib: the toolbox library

The shared operating model for every katoptra mirror, as one repository that mirrors
include by URL. A mirror keeps its identity and its pipeline; everything about how a run
is started, contained, secured, rendered and reported comes from here.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Repository | `katoptra/lib`, default branch `main` | The org's CONTRIBUTING already calls it "the library"; `main` matches `katoptra/.github` |
| How mirrors consume it | go-task remote include of `toolbox.yml`, pinned to a floating major tag | Stable since task 3.51; no copying, no submodule; a tag move rolls out to every mirror on its next run |
| Include URL form | `https://raw.githubusercontent.com/katoptra/lib/v1/toolbox.yml` | Needs no git in the image; tested |
| Trust and cache | Each mirror ships `.taskrc.yml` with `remote.trusted-hosts` and `remote.expiry: 1h` | No prompt on laptops or CI, no `--yes`, a fetch at most hourly |
| Inside the container | The image sets `TASK_REMOTE_OFFLINE=1`; the mirror's `.task/remote` cache is bind-mounted with the repo | No network inside a run, and `render` is a true offline dry run |
| Override mechanism | `flatten: true` plus `excludes:` | A verb a mirror lists under `excludes` and defines itself replaces the library's; a duplicate without `excludes` is a parse error |
| Where mirror config lives | The mirror's root `vars:` | Root vars reach flattened library verbs and the mirror's own replacements; include `vars:` reach only the include |
| Library defaults | Inline `{{.X | default N}}` in commands, never in a library `vars:` block | A library `vars:` default shadows the mirror's root value |
| Images | `ghcr.io/katoptra/toolbox:<variant>-v1`, variants `rsync` and `proton`, built and pushed by this repo | Runs never build and never touch Docker Hub; one pull per run from GHCR |
| Versioning | Semver tags `vX.Y.Z`; a release moves the floating `v<major>` tag and pushes `<variant>-vX.Y.Z` and `<variant>-v<major>` image tags | Consumers pin `v1` once, in the include URL and the image name |
| Secrets | `op.env` of `op://` references, resolved by `op run` on the host; names cross into the container, never values | Org rule; GitHub secrets still work through the `PASS` var |
| Workflows | Reusable `sync.yml` and `check.yml` under `.github/workflows`, a composite action that installs task and op at the lock's versions | A mirror's caller workflow is ten lines |
| Clock | jshvn/dispatch triggers `workflow_dispatch` on each mirror; no `schedule:` in any mirror | One calendar, no 60-day cron shutoff |
| The check | `task check` renders the whole pipeline inside the image with `--dry --force` and diffs it against the committed `render.txt` | Any change to what a mirror executes is a visible diff; this is the one check |

## The consumer contract

A mirror repository holds:

```
Taskfile.yml     root vars (its identity), the toolbox include, its pipeline verbs
.taskrc.yml      remote: {trusted-hosts: [raw.githubusercontent.com], expiry: 1h}
op.env           op:// references only (optional; GitHub secrets via PASS otherwise)
render.txt       the committed dry run, updated by `task render-update`
.github/workflows/sync.yml    calls katoptra/lib/.github/workflows/sync.yml@v1
.github/workflows/check.yml   calls katoptra/lib/.github/workflows/check.yml@v1
```

Its Taskfile:

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
      PASS: SEED RECONCILE MAX_BATCHES     # host env names that cross into the container
tasks:
  pipeline:      { cmds: [ ... ] }          # required: the full run, inside the image
  plan-pipeline: { cmds: [ ... ] }          # required: the read-only half
```

Two verbs are the contract: `pipeline` and `plan-pipeline`, both run inside the image.
Everything else is the library's unless excluded and replaced.

## The library's verbs

Host side, in `toolbox.yml`:

| Verb | Does |
|---|---|
| `default` | The grouped menu, from NAME and DESC plus the optional MENU var |
| `image` | Pull IMAGE; a no-op while it exists locally |
| `image-build` | Build IMAGE from LIB_DIR's Dockerfile for the variant named in the tag |
| `image-clean` | Remove IMAGE |
| `run -- <cmd>` | Run a command inside IMAGE with the repo at `/work` |
| `op -- <cmd>` | `run` wrapped in `op run --env-file=op.env` when `op.env` exists |
| `sync` | `op -- task pipeline` |
| `plan` | `op -- task plan-pipeline` |
| `render` | `run -- task --dry --force pipeline`, saved to `.run/render.txt` |
| `check` | `render`, then diff against `render.txt` |
| `render-update` | `render`, then copy over `render.txt` |
| `clean` | Delete every ignored file |

Inside the image, also in `toolbox.yml`:

| Verb | Does |
|---|---|
| `clock` | Write "epoch hour weekday" to `.run/start.txt` |
| `ping` | GET HEALTHCHECK_URL, skipped when unset |
| `ping-fail` | GET HEALTHCHECK_URL/fail, skipped when unset |

## Images

Both images bind-mount the repo at `/work`, set `WORKDIR /work`, `TASK_REMOTE_OFFLINE=1`
and `AWS_REGION=auto`, pin their base by digest, install every tool from
`toolchain.lock.toml` with a checksum, and end with a stage that asserts each tool
reports the locked version.

| Variant | Base | Tools |
|---|---|---|
| `rsync` | ubuntu 24.04 | rsync, gnupg, xz, curl, perl (shasum), go-task, AWS CLI v2 trimmed to s3 and sts |
| `proton` | python 3.13 slim | proton-drive, age, go-task, boto3, requests, pytest, ruff |

## Workflows

`sync.yml` (reusable): input `vars` (a string of `KEY=value` pairs appended to `task sync`),
secret `OP_SERVICE_ACCOUNT_TOKEN` (optional). Checkout, the toolbox action, `task sync`,
then always: `task op -- task ping-fail` on failure; then on success: `gh workflow run
sync.yml` when `.run/chain` exists.

`check.yml` (reusable): checkout, the toolbox action, `task check`.

`ci.yml` (this repo): on pull request and push to main, build each image for amd64, run
its self-test, and run `task check` in each example.

`release.yml` (this repo): on a `v*.*.*` tag, build each image for amd64 and arm64, push
`<variant>-<tag>` and `<variant>-v<major>` to GHCR, move the `v<major>` git tag.

## Out of scope for this repository

- Engine Taskfiles (`rsync.yml` with list, diff, split, batches and friends). They are
  extracted from ctan once ctan and tlnet both consume the toolbox, in their own plan.
- Migrating ctan, tlnet, dropbox and photos. One plan each, after `v1.0.0` exists.
- Terraform for buckets, domains and GitHub environments. That lives in jshvn/terraform.
