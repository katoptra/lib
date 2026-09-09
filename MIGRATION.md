# One shot: the rsync engine into lib, then ctan, tlnet and dropbox onto it

One agent, one sitting, five phases with a gate after each. At the end: `katoptra/lib`
carries the toolbox and the rsync engine and is released as `v1.0.0`; ctan and tlnet are
consumers of both; dropbox is a consumer of the toolbox; every mirror repository is a
Taskfile, a `.taskrc.yml`, a `render.txt`, two ten-line workflows, docs and its own
files; and every reference in the org points at the new shape. This file is deleted in
the last commit, because the repositories describe the current system and the commit
messages carry the story.

**These mirrors are production.** People install TeX from ctan and tlnet every hour;
dropbox is the only copy of a Dropbox account. The owner accepts a temporary break in
exchange for doing this in one pass, and will fix fast. That does not lower the bar. It
means: prove every step offline before it touches a bucket, merge right after a green
run, start the next run by hand and watch it, and know the rollback before merging.

Read `README.md` first, then this whole file, then start. Phase order matters. Within
a phase, follow the steps in order. A gate that fails means stop, understand, fix, and
re-run the gate; never skip one.

## Status, 2026-09-09: Phases A, B and C done, D built and awaiting its merge, E not started

Written for a session with no memory of the one that did A and C. Read this, then the
corrections section below the phases, then the phase you are about to run.

**Done.**

- lib is released: `v1.0.0` (fc3402d: the engine, the layered report, the example and
  its fixtures), `v1.0.1` (a80d19d: `image` pulls with `<engine> image pull`), `v1.0.2`
  (`04f7901cf1aa7551bc43db5ff801a225a189c42a`: the reusable workflows pin their own
  action). `v1` points at v1.0.2. Both images exist on ghcr.io.
- ctan is migrated: pull request katoptra/ctan#26 squash-merged as d55612b on
  2026-09-08 23:13 UTC, every gate green (the render diff against the old pipeline is
  only the expected `clock`/`list` lines, the fixture checks, the compliance block,
  `check / check`). The first hand-started run, 34289653678, was green in two minutes:
  the image pulled from GHCR, the state found, 512,046 objects at 140.08 GB, one batch,
  every smoke check passed, the ping sent, nothing chained. The 23:42 dispatch, run
  34291864433, was green too, in three minutes; the end-state table wants three of them.
  `p5-ctan` is ticked in the checklist.
- The GHCR package is public and the ctan ruleset requires `check / check`; the owner
  did both by hand on 2026-09-08.
- The checklist artifact has `p4-engine`, `p4-examples`, `p4-fixtures` and `p4-tag`
  ticked. jshvn/dispatch is verified: `schedules/ctan.ts` targets `sync.yml` at
  `42 * * * *`. It has no `dropbox.ts`, by design.
- dropbox is migrated: b8861a7 `feat(toolbox): consume katoptra/lib`, pushed to `master`
  on 2026-09-08 23:52 UTC. The Taskfile includes the toolbox at `v1` with `clock`,
  `ping`, `ping-fail` and `report-mirror` excluded and the migrator's own defined;
  `.taskrc.yml`, `render.txt`, the two callers at `@v1`, the Taskfile test and the README
  are in it; `docker/` and the lock are gone. Gate B.2.1: `task check` green, and the
  normalised render diff against the old pipeline is one added line, `clock` writing
  `.run/start.txt`. Gate B.2.2: 153 tests and ruff green inside `proton-v1`. The
  compliance block passes every line but the three vocabulary flags in the Phase B
  corrections. Gate B.2.3 was cut short (corrections). The first run on the new shape,
  34292572209, was green in 5 minutes 20 seconds: the image pulled from GHCR, one
  `op run` around the pipeline, the state restored as run 28 with 161,649 files and
  655 GB mirrored, 157 inventory pages in four minutes, nothing left to batch, report
  PASS, `report-mirror` appended the migrator's report, ping sent, nothing chained.
  `p5-dropbox` is ticked. The end-state table wants two more green runs; dropbox has no
  schedule, so the owner dispatches them.
- tlnet (Phase D) is built and gated offline on branch `josh/toolbox`: pull request
  katoptra/tlnet#2, commit 26c0427, opened 2026-09-09 00:18 UTC. The Taskfile is the D.2
  shape with `LIST_FLOOR: 8500`, `AWS_REGION: auto` beside the three `R2_*` mappings in
  `env:`, the filter's globs quoted, `index` writing `.run/index.txt` once the landing page
  landed and `report-mirror` reading it; the callers pin `04f7901 # v1.0.2`,
  `timeout-minutes: 60`. Gate D.3.1: `task check` green and `render.txt` read end to end:
  every command names the `tlnet` bucket, the subtree, the filter and `index.html` where
  expected, and nothing names ctan beyond dante's hostname. Gate D.3.2: `task run -- task
  list` inside the image gave 17,000 lines, all under `systems/texlive/tlnet/`, none
  revision-stamped, none under `update-tlmgr-r`, 6.79 GB, the largest file 145 MB
  (`archive/context.doc.tar.xz`), every root installer, updater and tlpdb control file
  present, no symlink lines. Gate D.3.3 (scratch) skipped: no R2 credentials and no
  1Password session in the shell. The compliance block passes, the engine-consumer lines
  included. The ruleset edit (`check` to `check / check`, ruleset 21669759), the merge
  and the dispatch were refused by the permission classifier; the owner did all three by
  hand. `check / check` was green in 15 seconds; the squash is 5c1a220 on `main`.
- tlnet's first run on the new shape, 34295112311, dispatched by the owner at 00:27 UTC,
  was green in 37 seconds: the image pulled from GHCR, no state file so `rebuild` listed
  the bucket and matched all 17,000 upstream objects (6.79 GB) by size, so the delta was
  empty (`0 lines in 0 batches`) and `prepare`, `verify`, the uploads and `smoke`'s
  read-backs had nothing to do; the state landed at `.state/applied.txt.xz`, `index`
  re-uploaded the landing page (its stamp reads 00:28 UTC over the domain), ping sent,
  nothing chained. Hour 00, so no reconcile. The summary's `Signature` row appears only
  when the delta touches the subtree, which this run's did not. The second run,
  34295392727 with `RECONCILE=true`, was green in 36 seconds: the state read back from the
  bucket, the delta still empty, `rebuild` listed the bucket, and the orphan sweep found
  nothing (`delete` skipped on an empty `orphans.txt`), so the bucket holds exactly the
  17,000 upstream keys, `.state/` and `index.html`. `p5-tlnetc` is ticked.

**Next, in order.**

1. Confirm ctan's next scheduled runs stay green (`gh run list -R katoptra/ctan
   --workflow sync.yml`) and read one summary in the browser: the toolbox's rows, the
   engine's rows, a `Directory pages` row. Rollback is C.3.7.
2. dropbox: read run 34292572209's summary in the browser (the toolbox's three rows, then
   the migrator's report), confirm the healthcheck saw the 23:58 UTC ping, and dispatch
   two more runs over the following days (`gh workflow run sync.yml -R katoptra/dropbox`,
   then `gh run watch`); the end-state table wants three green. Rollback is B.2.6.
3. tlnet: let the 03:30 dispatches run (`gh run list -R katoptra/tlnet --workflow
   sync.yml`); the end-state table wants three green. The first run with a real delta,
   once upstream moves, is the first to exercise `prepare`, `verify`, the batches and
   `smoke`'s read-backs: read its summary in the browser for the `Signature` row and the
   `Delta` row's orphan count. Rollback is D.3.6.
4. Phase E.

**What the previous sessions left only on Josh's laptop.** The old `dropbox:toolbox` and
`dropbox-mirror:toolbox` images, no longer used: `container image rm dropbox:toolbox
dropbox-mirror:toolbox`. For the record: the old pipeline's render for the C.3.1 diff came from ctan commit
2cd3b98 (`git worktree add /tmp/ctan-old 2cd3b98`, `task image` there, then
`container run --rm --user $(id -u):$(id -g) -w /work -v "$PWD":/work -e HOME=/tmp
ctan-sync sh -c 'task --dry --force sync 2>&1'`; the `ctan-sync` image is still on the
laptop). The local `ghcr.io/katoptra/toolbox:rsync-v1` was built from the lib checkout
with `task image-build`, not pulled; once the package is public, `task image-clean &&
task image` in ctan fetches the released one. ctan's untracked `fixtures/run-seed` has
its committed twin in lib as `examples/rsync/fixtures/run-empty`.

## The end state, so every decision below has a reference

```
katoptra/lib                            katoptra/ctan                 katoptra/tlnet               katoptra/dropbox
  toolbox.yml                             Taskfile.yml (~150 lines)     Taskfile.yml (~60 lines)     Taskfile.yml (~90 lines)
  engines/rsync.yml                       .taskrc.yml                   .taskrc.yml                  .taskrc.yml
  docker/rsync.Dockerfile                 render.txt                    render.txt                   render.txt
  docker/proton.Dockerfile                aws.config                    aws.config                   op.env
  toolchain.lock.toml                     fixtures/  (ctan's own)       site/index.html              config/mirror.toml
  examples/rsync/   (toolbox + engine)    docs/, README, CLAUDE, ...    README, CLAUDE, ...          src/, tests/, pyproject
  examples/proton/  (toolbox)             .github/workflows/{sync,check}.yml, ten lines each, in all three
  .github/{actions,workflows}
```

Three layers, flattened into one namespace in a mirror:

| Layer | Owns | Hooks it offers (no-op unless a lower layer replaces them) |
|---|---|---|
| toolbox (`toolbox.yml`) | menu, image, run, op, sync, plan, render, check, clean, clock, ping, ping-fail, report | `report-engine`, `report-mirror` |
| engine (`engines/rsync.yml`) | list, normalise, state, rebuild, diff, split, batches, batch, fetch, publish, merge, checkpoint, remove, delete, reconcile, retry, report-engine | `prepare`, `verify`, `index`, `smoke` |
| mirror | root vars, pipeline, plan-pipeline, its overrides of the hooks | none |

A mirror replaces a hook by listing it under `excludes:` on the include that defines it
and defining its own. Every other verb is the library's, and a mirror never redefines
one: a duplicate without `excludes` is a parse error, on purpose.

## Phase A: lib

Branch `main`, push directly; lib has no branch rule. Every step ends with
`cd examples/rsync && task image-build && task check` and the same in `examples/proton`
staying green (the images already exist locally as `*-dev`).

### A.1 Toolbox: the chain file and the layered report

In `toolbox.yml`:

1. `clock` also clears the chain file, so a run that works no batches never re-queues
   itself: `rm -f {{.RUN}}/chain` before writing `start.txt`. The three-field
   `epoch hour weekday` format stays; the engine reads field 2.
2. Three new in-container verbs:
   ```yaml
   report:
     desc: Append the run summary to the Actions job page (stdout elsewhere), base rows then the engine's then the mirror's
     silent: true
     cmds:
       - |
         s=$(cut -d' ' -f1 {{.RUN}}/start.txt 2>/dev/null || date +%s); now=$(date +%s)
         cat >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}" <<EOF
         ## {{.NAME}}: run {{.STATUS | default "succeeded"}}, $(date -u '+%Y-%m-%d %H:%M UTC')

         | | |
         |---|---|
         | Started | $(date -u -d "@$s" '+%H:%M UTC' 2>/dev/null || date -u -r "$s" '+%H:%M UTC'), took $(( (now - s) / 60 )) min |
         | Image | {{.IMAGE}} |
         | Next run | $(test -f {{.RUN}}/chain && echo "queued now, work remains" || echo "at the schedule") |
         EOF
       - {task: report-engine}
       - {task: report-mirror}
   report-engine: {cmds: []}   # the engine's rows; an engine include replaces it
   report-mirror: {cmds: []}   # the mirror's rows; a mirror replaces it
   ```
   Rows are `| Label | value |` lines appended to the same table, so the three layers
   read as one. Every row must tolerate a missing file: the report also runs after a
   failed pipeline.
3. `sync`'s wrapper reports the failure before pinging:
   `task pipeline "$@" || { task report STATUS=failed || true; task ping-fail; exit 1; }`.
4. The menu gains nothing; `report` is a pipeline verb, not an operator one.
5. The reserved-names comment at the top of the file lists the three new verbs and the
   engine's, since they share the namespace.

Gate: both examples' `task check` after `task render-update` (the proton example's
pipeline gains `report` before `ping`; the diff is the new lines and nothing else).

### A.2 The rsync engine, extracted from ctan

Create `engines/rsync.yml`. Source: `katoptra/ctan` at `main` (commit `2cd3b98` or later),
`Taskfile.yml`. Copy verbatim, then apply exactly the changes listed. Verbatim means the
awk stays byte for byte; the commands are the proof of equivalence in Phase C.

**Header comment**: what an engine is, the reserved names, the hook contract, and the
two rules (no `vars:` for anything a mirror owns; inline defaults).

**`vars:`** may hold only values a mirror never sets: the derived `S3: s3://{{.BUCKET}}`
and `URL: https://{{.HOST}}`, the awk helpers `SIZE`, `URLENC`, `ENCODE`, `ANCESTORS`,
and `STATE: .state/applied.txt.xz`, `STAGING: '{{.ROOT_DIR}}/staging'`,
`RSYNC`, `CURL`, `AWS_FLAGS` as in ctan. Everything a mirror tunes is an inline default
where it is used: `{{.BATCH_GB | default 4}}`, `{{.MAX_BATCHES | default 4}}`,
`{{.RECONCILE | default "auto"}}`, `{{.RETRY_BASE | default 15}}`,
`{{.CEILING_GB | default 0}}` (0: no ceiling), `{{.LIST_FLOOR | default 0}}` (the
truncated-listing guard, lines), `{{.TL}}` and `{{.TL_KEY}}` (empty: no TeX Live
checks), `{{.FILTER}}` (rsync filter args for `list`; empty: the whole tree),
`{{.OWN}}` (bucket-root keys the mirror owns and reconcile never deletes, space
separated; empty: none), `{{.INDEX}}` (the directory-page key suffix; empty: none).
`MAX_BATCHES` appears in `batches`, `delete`, `smoke` and `report-engine`; every
occurrence takes the same inline default. ctan's `MAX_BATCHES: '{{.MAX_BATCHES | default "4"}}'`
root-var trick goes away; a CLI var overrides an inline default directly.

**Verbs, verbatim from ctan**: `list`, `normalise`, `state`, `rebuild`, `diff`,
`batches`, `batch`, `fetch`, `publish`, `merge`, `checkpoint`, `remove`, `delete`,
`reconcile`, `retry`. Plus:

- `split`: ctan's `plan`, renamed. The batch planner. `plan` is a toolbox host verb.
- `prepare`: ctan's `tlpdb`, renamed and guarded: the whole body runs only when `TL_KEY`
  is non-empty (`status: ['test -z "{{.TL_KEY}}"']` on top of ctan's own status). With
  `TL_KEY` empty it is the no-op hook.
- `verify`: ctan's `verify`, guarded the same way. It is public (no `internal:`), as in
  ctan, so a mirror can run it by hand against a canned batch.
- `index`: a no-op hook, `{cmds: []}`. ctan's `index` and `render` are ctan's.
- `smoke`: the first two commands of ctan's `smoke` (the sample read-back by encoded
  URL, and the tlpdb sha512 read-back guarded by `TL`), the `TS` var included. The
  directory-page check, the HTML canary and the Perl-client check are ctan's.
- `report-engine`: ctan's `report` table rows except the header, the `Started` line,
  `Directory pages` and `Signature`, rewritten as the rows the toolbox's table expects:
  `Mirror`, `Delta`, `Published to R2`, `State`, `Storage`, and `Signature` guarded on
  `RUN/tl` existing. Every `$(...)` tolerates a missing file (`n()` already does; add
  `2>/dev/null || true` where ctan assumed the file).
- `list` clears the per-run files ctan's `clock` cleared: `rm -f {{.RUN}}/publish.txt
  {{.RUN}}/orphans.txt` as its first command. `clock` is the toolbox's.
- `list` takes `{{.FILTER}}` between `{{.RSYNC}}` and `-rL --list-only`.
- `normalise` compares the line count against `{{.LIST_FLOOR | default 0}}` instead of
  the literal `400000`, and only when the floor is non-zero.
- `split` reads `{{.CEILING_GB | default 0}}` and skips the ceiling test when it is 0.
  `TL` in its awk stays; with `TL` empty, `index($1, "/tlpkg/") == 1` matches nothing,
  which is right.
- `reconcile` excludes, beside `.state/` and the page keys, every key in `OWN`:
  `grep -vxF -f <(printf '%s\n' {{.OWN}})` after the `.state/` grep, only when `OWN` is
  non-empty. With `INDEX` empty the page-key awk excludes nothing, which is right.
- `report-engine`, `smoke`, `prepare`, `verify` are the four verbs a mirror may replace.

**Not in the engine**: `default`, `seed`, `image`, `run`, `clock`, `ping`, `render`,
`index`, `sync`, and the `IMAGE`, `ENGINE`, `RUNNER`, `RUN`, `INDEX`, `INDEXED`, `SLASH`,
`TL`, `TL_KEY`, `CEILING_GB`, `BATCH_GB`, `MAX_BATCHES`, `SEED`, `RECONCILE`,
`RETRY_BASE` vars. `SLASH`, `INDEXED`, `INDEX` are ctan's; the rest are inline defaults.

**Example**: `examples/rsync/Taskfile.yml` becomes a consumer of toolbox plus engine,
with `SOURCE`, `BUCKET`, `HOST`, `LIST_FLOOR: 1`, and
`pipeline: [clock, list, state, rebuild, diff, split, prepare, batches, delete,
reconcile, index, smoke, report, ping]`, `plan-pipeline: [clock, list, state, diff,
split]`, and a `tools` verb as today. Its include of the engine is a path,
`../../engines/rsync.yml`, flattened, like the toolbox. `render.txt` grows to every
engine command: that is the library's own check of the engine.

**Fixtures**: move `katoptra/ctan/fixtures/run-root` and `run-seed` (renamed
`run-empty`) into `examples/rsync/fixtures/`, and give the example an `offline` verb that
runs, inside the image, the checks ctan's menu listed: `normalise` on
`fixtures/listing.txt` if ctan has one, `diff`, `split`, `merge B=...`, `retry CMD='exit 5'
RETRY_BASE=0`, each with `RUN=/work/examples/rsync/fixtures/<dir>` and `STAGING`
overrides. ctan keeps a copy of the fixtures its own `index`, `pages` and `smoke`
overrides need (the `run-root` staging page) under its own `fixtures/`. Wire `task run
-- task offline` into `ci.yml`'s rsync matrix entry after `task check`.

**Docs**: README's engine section describes what now exists: the verb list, the four
hooks, the vars a mirror sets (`SOURCE`, `BUCKET`, `HOST` required; `CEILING_GB`,
`BATCH_GB`, `MAX_BATCHES`, `LIST_FLOOR`, `TL`, `TL_KEY`, `FILTER`, `OWN`, `INDEX`
optional), the report layering, and a full tlnet-shaped consumer as the example. The
sentence saying the engine lives in ctan goes. CONTRIBUTING adds: a change to an engine
verb changes `examples/rsync/render.txt`. CLAUDE.md's constraints add the hook names to
the reserved list. The spec under `docs/superpowers/specs/` is a decision record; leave it.

Gate A.2: `cd examples/rsync && task image-build && task check && task run -- task offline`
green; `examples/proton` `task check` green; `grep -c '^  [a-z-]*:' engines/rsync.yml`
counts the verbs listed above and no other; `grep -n '^vars:' -A30 engines/rsync.yml`
shows nothing a mirror sets.

### A.3 Release

```sh
git push origin main && gh run watch --exit-status $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
git tag v1.0.0 && git push origin v1.0.0
gh run watch --exit-status $(gh run list --workflow release.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

Gate A.3, all of:

- `git ls-remote --tags origin` shows `v1.0.0` and `v1`.
- Anonymously from GHCR: `t=$(curl -s "https://ghcr.io/token?scope=repository:katoptra/toolbox:pull" | jq -r .token)`,
  then `curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $t"
  https://ghcr.io/v2/katoptra/toolbox/manifests/rsync-v1`, and `proton-v1`, answer 200.
  A 401 means the package is private, which it is after the first push and stays until
  the owner makes it public in the browser under the package's settings; there is no
  API for it.
- In a scratch directory, a Taskfile that includes
  `https://raw.githubusercontent.com/katoptra/lib/v1/toolbox.yml` and
  `https://raw.githubusercontent.com/katoptra/lib/v1/engines/rsync.yml`, flattened, with
  a `.taskrc.yml`, lists `split` and `render-update` in `task --list`.
- The org ruleset on ctan: the required status check named `check` becomes
  `check / check`, because a reusable workflow's check reports as `<caller job> /
  <called job>` and a required check that never reports blocks every pull request.
  `gh api repos/katoptra/ctan/rulesets` lists it; `gh api -X PUT
  repos/katoptra/ctan/rulesets/<id>` with the edited body updates it. If the token lacks
  the scope, stop and ask the owner; nothing in Phase C can merge without it. tlnet and
  dropbox have no rule (`gh api repos/katoptra/<r>/rules/branches/<default>` is empty).

## Phase B: dropbox

Already toolbox-shaped; it is where most of `toolbox.yml` came from. Default branch
`master`, no rule: work on `master`, push. Clone at `~/Git/katoptra/dropbox`.

### B.1 Files

- **Add** `.taskrc.yml` (trusted host `raw.githubusercontent.com`, expiry `1h`);
  `.gitignore` gains `.task/` (`.run/` is there).
- **Delete** `docker/`, `config/toolchain.lock.toml`, the `IMAGE`, `ENGINE`, `PASS_ENV`
  vars, the `default`, `image`, `image-clean`, `clean`, `run`, `op`, `render`, `sync`
  verbs. The library's do the same. `RUN_EPOCH` stays if the migrator reads
  `MIRROR_RUN_EPOCH`.
- **Include**: `toolbox` by URL at `v1`, flattened, `NAME: dropbox`, `DESC` as the old
  menu's, `IMAGE: ghcr.io/katoptra/toolbox:proton-v1`, `PASS: MIRROR_VERBOSE`,
  `excludes: [clock, ping, ping-fail, plan, report-mirror]`.
- **Keep**, unchanged in meaning: `pipeline`, `plan-pipeline`, every phase verb, `plan`
  (dropbox's cats the report after the read-only half), `clock`, `ping`, `ping-fail`
  (the migrator owns them), `test`, `lint`, `fmt`, `status`, `empty-trash`,
  `state-rollback`, `session-seal`. Rewrite `test`, `lint`, `fmt` and the operator verbs
  to call the library's `run` and `op` exactly as they call the old ones (`task: run`
  with `CLI_ARGS`). Each operator verb gets a line in `MENU`.
- **Vars to env.** The migrator reads `RECONCILE` and `RUN_BUDGET_MIN` from the
  environment and the old workflow set them from inputs. The reusable workflow cannot
  set job env, so the root maps task vars to env:
  ```yaml
  env:
    RECONCILE: '{{.RECONCILE | default ""}}'
    RUN_BUDGET_MIN: '{{.RUN_BUDGET_MIN | default ""}}'
  ```
  Confirm in `src/migrator/env.py` (or wherever they are read) that an empty string is
  treated as unset; fix it there if not. A manual run is
  `gh workflow run sync.yml -f vars='RECONCILE=true'`.
- **Report.** `pipeline` becomes `[..., reconcile, report-phase, report, ping]`:
  `report-phase` (the migrator, writes `.run/report.md` and closes the run row) then the
  library's `report` (base rows, then `report-mirror`). dropbox's `report-mirror` is
  `cat .run/report.md >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"` guarded on the file
  existing. dropbox's `ping-fail` becomes: run `report-phase` if `.run/report.md` is
  missing (`|| true`), then `python -m migrator ping fail`. The library's `sync` wrapper
  already calls `report STATUS=failed` before `ping-fail`, so the failed-run summary
  keeps the old workflow's behaviour without a workflow step.
- **`test_taskfile.py`** slices the Taskfile between `default:` and `  image:`; neither
  exists now. Rewrite it to assert every non-internal verb with a `desc:` that is
  dropbox's own appears in the `MENU` var, and delete the old assertion. It must pass.
- **Workflows**: `sync.yml` and `check.yml` from the templates in the appendix.
  dropbox's `check.yml` keeps a second job, `tests`, that installs task via the
  library's action (`uses: katoptra/lib/.github/actions/toolbox@v1`) and runs
  `task test` and `task lint`. `with: {timeout-minutes: 355}` on the sync call.
- **Docs**: README (the toolbox section, want your own, the schedule section's dispatch
  file name is already `dropbox.ts`), CLAUDE.md, the runbook parts of README. No mention
  of `docker/`, the lock, the installer, or the old verbs.
- **Untouched**: `config/mirror.toml` (its `id` is the state's primary key), `op.env`,
  `src/`, `tests/` except the one file, the state in R2.

### B.2 Gates

1. `task check` after `task render-update`; diff `render.txt` against
   `task run -- task --dry --force pipeline` captured from the old Taskfile before you
   started (do that first: `git stash`-free, just run it on `master` before editing and
   save to `/tmp/dropbox-before.txt`). Normalise with the appendix's `norm` and diff:
   the only new lines are `report` and its hooks.
2. `task test` (153 tests) and `task lint` inside the library's image.
3. `task plan` from the laptop with `op` signed in: the read-only half runs against the
   real account and prints the report. This is the live proof; dropbox has no scratch.
4. Commit (`feat(toolbox): consume katoptra/lib`), push `master`.
5. `gh workflow run sync.yml` and watch it green. Its summary shows the base rows, then
   the migrator's report. The healthcheck received a ping.
6. If it fails: `git revert HEAD`, push, `gh workflow run sync.yml`, watch, then debug.

## Phase C: ctan

The source of the engine; its migration is the proof that the extraction lost nothing.
Default branch `main`, ruleset: pull request plus `check / check` required. Clone at
`~/Git/katoptra/ctan`. Hourly at :42, 3 to 5 minutes a run.

### C.1 Before editing

```sh
cd ~/Git/katoptra/ctan && git switch main && git pull --ff-only
task run -- task --dry --force sync > /tmp/ctan-before.txt 2>&1     # the old image, the old Taskfile
gh run list --workflow sync.yml --limit 1                            # note the last green run id
git switch -c josh/toolbox
```

### C.2 Files

- **Add** `.taskrc.yml`; `.gitignore` becomes `staging/`, `.run/`, `.task/`.
- **Delete** `docker/`, the `IMAGE`, `ENGINE`, `RUNNER`, `RUN`, `S3`, `URL`, `STATE`,
  `STAGING`, `RSYNC`, `CURL`, `AWS_FLAGS`, `SIZE`, `URLENC`, `ENCODE`, `ANCESTORS`,
  `MAX_BATCHES`, `RECONCILE` vars (the engine's), and every verb the engine or toolbox
  now provides: `default`, `sync`, `clock`, `list`, `normalise`, `state`, `rebuild`,
  `diff`, `plan`, `tlpdb`, `batches`, `batch`, `fetch`, `verify`, `publish`, `merge`,
  `checkpoint`, `remove`, `delete`, `reconcile`, `report`, `ping`, `retry`, `image`,
  `run`. The `fixtures/` that moved to lib go too; ctan keeps what its overrides need.
- **Root vars**: `SOURCE`, `HOST`, `BUCKET`, `TL`, `TL_KEY`, `CEILING_GB: 200`,
  `BATCH_GB: 4`, `LIST_FLOOR: 400000`, `INDEX`, `INDEXED`, `SLASH: '{{.RUN}}/slash'`
  (the library's `RUN` is `.run`, which is what `run/` becomes everywhere), and
  `env: AWS_CONFIG_FILE: '{{.ROOT_DIR}}/aws.config'`.
- **Includes**: `toolbox` by URL at `v1`, `NAME: ctan`, `DESC`, `IMAGE:
  ghcr.io/katoptra/toolbox:rsync-v1`, `PASS: AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
  AWS_ENDPOINT_URL AWS_REGION`, `excludes: [report-engine, report-mirror]`; `rsync`
  engine by URL at `v1`, flattened, `excludes: [index, smoke]`.
- **Verbs kept**: `pipeline` (the old `sync`'s list with `plan` now `split`, `tlpdb` now
  `prepare`, and `report` before `ping`), `plan-pipeline: [clock, list, state, diff,
  split]`, `pages` (the old `render`, renamed; `render` is the toolbox's), `index` (calls
  `pages`), `smoke` (ctan's full version), `report-mirror` (the `Directory pages` row).
  `MENU` lists the offline checks that remain meaningful.
- **`run/` is `.run/`** everywhere: `.gitignore`, CLAUDE.md, `docs/reference.md`, the
  menu lines, and `SLASH`. The fixtures ctan keeps are passed as
  `RUN=/work/fixtures/<dir>` on the command line, which overrides the library's `RUN`.
- **Workflows** from the appendix, `with: {vars: ..., timeout-minutes: 355}`. The old
  `reconcile` and `max_batches` inputs become `vars`; dispatch sends none, so the
  inline defaults (`auto`, `4`) apply, as today. The chain step ctan carries is the
  library's now; delete it.
- **Docs**: README, CLAUDE.md, CONTRIBUTING.md, `docs/reference.md`: the pipeline is
  described by its verbs with the new names, secrets by the `PASS` line, the toolbox by
  a link to lib, runbook commands as `gh workflow run sync.yml -f vars='...'` and
  `task sync -- ...`. No `docker/`, no installer, no `run/`, no old names.

### C.3 Gates

1. `task render-update`; `norm` both files (appendix) and diff. Every remaining line is
   one of: a renamed verb, `.run` for `run`, the report's new rows, the `list` line
   carrying the two `rm -f` that moved from `clock`, the `FILTER`, `LIST_FLOOR`,
   `CEILING_GB` and `OWN` conditionals rendering to the same commands with ctan's
   values. Anything else is a behaviour change: fix it in lib (a `v1.0.1`) or in ctan
   before going on.
2. The offline fixtures ctan kept: `task run -- task pages RUN=/work/fixtures/run-root
   STAGING=/work/fixtures/run-root/staging` and the smoke over `file://` as the old menu
   showed. Green.
3. `task run -- sh -c 'aws s3api help >/dev/null && aws s3 ls --no-sign-request
   --endpoint-url http://127.0.0.1:1 s3://x 2>&1 | grep -qi refused && echo image ok'`.
4. Scratch, if R2 credentials are in the shell (the repository secrets are not readable;
   the owner exports an R2 token or this gate is skipped and noted in the report):
   `unset HEALTHCHECK_URL; task run -- task pipeline BUCKET=ctan-scratch MAX_BATCHES=1
   BATCH_GB=1`. Pass: reaches `report`, the scratch bucket holds `.state/applied.txt.xz`
   and one batch of keys, `.run/chain` exists. Empty the scratch bucket after.
5. Push the branch, open the PR, `check / check` green.
6. Merge between :50 and :30 (`gh pr merge --squash --delete-branch`). Then
   `gh workflow run sync.yml` and watch it green. Its summary shows base rows, engine
   rows, ctan's `Directory pages` row, numbers in the usual range (hundreds uploaded, a
   handful deleted, orphans 0 outside hour 03). `df` in the log shows a pull, not a
   build. The healthcheck received a ping. Then let :42 fire and watch that one too.
7. Rollback is `git revert` of the squash commit through a PR (the ruleset applies to
   reverts too), `gh workflow run sync.yml`, watch. The state file, its key and its
   format are the same before and after, so the old pipeline resumes from it.

## Phase D: tlnet

The largest behavioural change: tlnet stops being a whole-tree `rsync` then `aws s3
sync` pipeline on the bare runner and becomes a consumer of the rsync engine at the
subtree, in the image, with a state file, batches and the daily reconcile. It ends with
the same keys in the same bucket at the same paths. Daily at 03:30 UTC, 30-minute
timeout today. Default branch `main`; check for a rule first.

### D.1 Why it is safe to do this way

The engine's `state` finds no state file, rebuilds it from a listing of the bucket
joined to upstream on size, and takes every matching key as applied. tlnet's bucket
already holds the subtree at CTAN's own paths, uploaded by `aws s3 sync`, so the
rebuilt state covers nearly everything and the first delta is a day's changes. `OWN:
index.html` keeps reconcile off the landing page. A 03:30 start is hour 03, so
`RECONCILE=auto` reconciles every run, which is what the old whole-tree sync did
implicitly with `stale`.

### D.2 Files

- **Add** `.taskrc.yml`; `.gitignore` becomes `staging/`, `.run/`, `.task/`.
- **Delete** every old verb (`default`, `sync`, `fetch`, `verify`, `guard`, `page`,
  `publish`, `stale`, `smoke`, `report`, `ping`) and every old var except `HOST`,
  `TL_KEY` and the landing-page ones.
- **Root vars**:
  ```yaml
  vars:
    SOURCE: rsync://rsync.dante.ctan.org/CTAN/
    HOST: tlnet.ijosh.com
    BUCKET: tlnet
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
    AWS_ACCESS_KEY_ID: {sh: 'printf %s "$R2_ACCESS_KEY_ID"'}
    AWS_SECRET_ACCESS_KEY: {sh: 'printf %s "$R2_SECRET_ACCESS_KEY"'}
    AWS_ENDPOINT_URL: {sh: 'printf https://%s.r2.cloudflarestorage.com "$R2_ACCOUNT_ID"'}
  ```
  `SOURCE` is the CTAN root and `FILTER` narrows the listing to the subtree, so paths
  keep their `systems/texlive/tlnet/` prefix and every key lands where `aws s3 sync`
  put it. The two excludes are what tlnet's old `fetch` excluded: the revision-stamped
  duplicates that would double the 10 GB. The `env:` mapping lets the three `R2_*`
  repository secrets stay as they are: they cross by name via `PASS`, and the Taskfile
  turns them into what the AWS CLI reads, inside the container, in memory. Renaming
  the secrets to `AWS_*` or moving to an `op.env` is a later step, not this one.
  `LIST_FLOOR`: run `task run -- task list` once, count `.run/upstream.txt`, set the
  floor to half of it.
- **Includes**: `toolbox` at `v1` with `NAME: tlnet`, `DESC`, `IMAGE: rsync-v1`,
  `PASS: R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ACCOUNT_ID`,
  `excludes: [report-engine, report-mirror]`; `rsync` engine at `v1`, `excludes: [index]`.
- **Verbs kept**: `pipeline: [clock, list, state, rebuild, diff, split, prepare,
  batches, delete, reconcile, index, smoke, report, ping]`, `plan-pipeline: [clock,
  list, state, diff, split]`, `index` (the old `page`: upload `site/index.html` with the
  date filled in to `s3://{{.BUCKET}}/index.html`, `no-cache`, `text/html`; it runs
  before `smoke` now rather than after `ping`, which is fine: it is one small upload),
  `report-mirror` (a `Landing page` row). The engine's `smoke` reads the tlpdb sha512
  back through the domain, which is exactly the old `smoke`.
- **Workflows** from the appendix, `with: {vars: ..., timeout-minutes: 60}`. The old
  check ran `task --dry sync` on the runner; the library's renders in the image against
  `render.txt`.
- **`aws.config` stays.** The old `verify` (signature chain, xz matches, no duplicates,
  every container checksummed) is the engine's `prepare` and `verify` with `TL` set;
  the old `guard` is `CEILING_GB`; `stale` is `reconcile`.
- **Docs**: README (how it runs, the secrets table, want your own), CLAUDE.md,
  CONTRIBUTING.md. The old pipeline's names go.

### D.3 Gates

1. No before-and-after render diff is possible; the pipeline is a different one. Instead:
   `task render-update`, then read `render.txt` end to end and confirm every command
   names `tlnet`, `systems/texlive/tlnet`, the `FILTER` and `index.html` where expected,
   and nothing names `ctan`.
2. `task run -- task list` inside the image with no credentials: `.run/upstream.txt`
   holds only `systems/texlive/tlnet/` paths, none matching `\.r[0-9]+\.tar\.xz$`, none
   under `update-tlmgr-r`, and the count is a few thousand. Set `LIST_FLOOR`.
3. Scratch, if credentials are in the shell: `unset HEALTHCHECK_URL; task run -- task
   pipeline BUCKET=tlnet-scratch MAX_BATCHES=1 BATCH_GB=1` (the `env:` mapping needs
   `R2_*` exported). Pass: `prepare` verifies the signature, one batch lands, the state
   file exists in the scratch bucket. The `index` upload lands `index.html`. `smoke`
   fails on scratch because the domain serves the real bucket; that is expected, note
   it, and it is the only allowed failure. Empty the scratch bucket after.
4. Push, PR, check green, merge (or push `main` directly if there is no rule).
5. `gh workflow run sync.yml` outside 03:00 to 04:30 UTC and watch. Pass: `state`
   rebuilds from the bucket (the log says so), the delta is small, `verify` passes,
   `reconcile` deletes nothing or only real stale keys (`orphans.txt` in the summary
   is a small number and every key in it is a versioned duplicate or an old file, never
   `index.html`), `smoke` matches, the summary shows the `Signature` row and the
   `Landing page` row, storage under 10 GB, ping received.
6. Rollback: revert, run by hand, watch. The old pipeline never read a state file and
   `aws s3 sync` is idempotent, so it resumes cleanly. The `.state/` prefix the engine
   created is harmless to it.

## Phase E: references, checklist, cleanup

- **lib**: delete this file. README's engine section, CONTRIBUTING and CLAUDE.md are
  already updated in A.2; re-read them against what shipped. `examples/` render files
  current. Tag `v1.0.1` if anything in lib changed during B to D, and note that every
  mirror pinned to `v1` picks it up on its next run.
- **Site** (`katoptra/site`, `data/`): if a mirror entry names an engine, image or
  pipeline shape, update it. The org profile README is rendered from the same data.
- **jshvn/dispatch**: untouched; verify with `gh api repos/jshvn/dispatch/contents/schedules`
  that ctan and tlnet still target `sync.yml` on `main`. dropbox has no schedule; leave
  it that way and say so in the report.
- **Healthchecks**: untouched. Confirm each check received pings from the new runs.
- **The org checklist artifact** (`claude.ai/code/artifact/0ff4e1c2-32a0-4884-91ed-531fa5c6d852`,
  db collection `checklist`, doc `katoptra`): tick `p4-engine`, `p4-examples`,
  `p4-fixtures`, `p4-tag`, `p5-ctan`, `p5-dropbox`, `p5-tlnetc`, `p5-cleanup`.
- **Every mirror** passes the compliance block below.
- **Memory**: the migration-state memory file records the outcome and the date.

## Corrections from Phase A and Phase C, read before B and D

- **A command-line `KEY=value` does not reach an include's verb past a var the include or
  the mirror's root defines.** Verified on go-task 3.53.1: for a verb defined in an
  included file, the include's own vars (`RUN`, `STAGING`, `S3`...) and the mirror's root
  literals (`BUCKET`, `BATCH_GB`...) both beat the command line; only a call-site var
  (`{task: diff, vars: {RUN: ...}}`) beats them. So `task sync -- MAX_BATCHES=8` works
  only because `MAX_BATCHES` has no `vars:` entry anywhere, `task run -- task diff
  RUN=/work/fixtures/x` leaves an engine verb on `.run/`, and the scratch gates written as
  `task pipeline BUCKET=<scratch> BATCH_GB=1` would run against the real bucket. A scratch
  run edits the Taskfile. A mirror's own verbs (`pages`, `smoke` in ctan) do take the
  command line.
- **A root var cannot read an include's var unless the root defines the name first.**
  Vars are an ordered map; the include's `RUN` lands after the root's `SLASH`, so
  `SLASH: '{{.RUN}}/slash'` rendered as `/slash`. ctan spells out `{{.ROOT_DIR}}/.run/slash`.
- **`status:` entries must all succeed to skip a verb.** The `TL_KEY` guard on `prepare`
  is one entry joined with `||` to ctan's own, not a second entry.
- **`silent: true` renders nothing under `--dry`.** `report`, `report-engine` and
  `report-mirror` never appear in `render.txt`; the A.1 gate's "new lines" do not exist.
- **`aws s3api help` needs groff**, which the image does not ship (nor did ctan's). Gate
  C.3.3 is the dead-port call: `aws s3api list-buckets --no-sign-request --endpoint-url
  http://127.0.0.1:1`, expecting a connection error.
- **Apple container has no top-level `pull`.** `image` is `<engine> image pull` (v1.0.1).
- **GHCR has no REST endpoint for package visibility.** The `gh api -X PATCH` line does
  nothing; the package is made public in the browser, once, before any mirror can pull.
- **The reusable `check` reports as `check / check`**, so the ruleset edit is required
  before the first PR can merge, as written; it is one `PUT` of the ruleset body.
- **ctan and tlnet require a full commit SHA on every `uses:`** (repository Actions
  policy, `sha_pinning_required`, with only GitHub-owned and `go-task/*` actions
  allowed; same-org references pass the allow-list). A caller written `@v1` fails at
  startup with no job and no log, and so does one pinned by SHA while lib's reusable
  workflow still names its action `@v1`: the check is transitive. So the callers pin
  `katoptra/lib/.github/workflows/<x>.yml@<release sha> # vX.Y.Z`, lib's reusable
  workflows pin `katoptra/lib/.github/actions/toolbox@<release sha>` (v1.0.2), and
  Dependabot bumps both; only the include and the image float at `v1`. The compliance
  block's two `@v1` greps read `@<sha> # v1` on those two repositories. dropbox has no
  such policy and can use the templates as written.
- ctan's `fixtures/` are git-excluded, so "move" meant copying the engine-relevant subset
  into lib as committed files; ctan's own stay on the laptop, untracked.

## Corrections from Phase B, read before D and E

- **The report fallback belongs in `report-mirror`, not `ping-fail`.** The toolbox's
  `sync` runs `report STATUS=failed` before `ping-fail`, so a `report-phase` fallback in
  `ping-fail` would write `.run/report.md` after the summary had been appended, and a run
  that died before its report phase would reach the job page without its report.
  dropbox's `report-mirror` runs the migrator's report when the file is missing
  (`|| true`), then appends it; `ping-fail` stays `python -m migrator ping fail`.
- **A mirror that excludes `clock` must still write `.run/start.txt`**, or the toolbox's
  `Started` row reads "took 0 min". dropbox's `clock` is the migrator's clock plus
  `date -u '+%s %H %u' > .run/start.txt`, and that line is the whole render diff.
- **`plan` needs no exclude.** The `cat .run/report.md` moved into `plan-pipeline`, so the
  toolbox's `plan -- K=v` serves as is.
- **The compliance block's verb loop flags a toolbox-only mirror's `state`, `batches` and
  `reconcile`.** They are the vocabulary used with its meaning, and with no engine include
  there is nothing to collide with. For a mirror without an engine include the loop should
  run over the toolbox's names only; the block above is left as written, and dropbox
  passes every other line of it.
- **The toolbox's `run` reads `CLI_ARGS_LIST`; `op` reads `ARGS`.** A mirror verb that
  wraps `run` re-invokes it from the shell, `task run -- python -m pytest {{.CLI_ARGS}}`,
  as `op` itself does; a call-site `vars: {CLI_ARGS_LIST: [...]}` also works on 3.53.1,
  but that is a special var overridden. A verb that wraps `op` passes `vars: {ARGS: ...}`.
- **The OS environment beats Taskfile `env:` on go-task 3.53.1**, an empty value
  included. So `RECONCILE` and `RUN_BUDGET_MIN` are task vars mapped to env at the root
  and never in `PASS`: the host's `task` exports the empty mapping to its own commands,
  the container boundary drops it, and inside the image `task pipeline RECONCILE=true`
  renders the mapping fresh. Had `RECONCILE` also crossed by name, the host's empty value
  would have won.
- **dropbox has no `CLAUDE.md`** and never had one; B.1's docs list has a file fewer.
- **The image swap is a go-task bump and nothing else.** dropbox's lock and lib's agree on
  Python, `proton-drive`, `age`, boto3, requests, pytest and ruff; go-task goes 3.45.4 to
  3.53.1. The old Dockerfile's `PROTON_DRIVE_LOG_LEVEL=INFO` is a root `env:` line of the
  Taskfile now; its `PROTON_DRIVE_CACHE_DIR` and `PROTON_DRIVE_CREDENTIALS_STORE` the
  migrator sets itself at every phase, and `MIGRATOR_TOOLCHAIN_LOCK` nothing ever read.
- **A non-silent `report-mirror` renders.** Called from the silent `report`, its own
  commands still appear in `render.txt`; the A and C note holds for a silent hook only.
- **Gate B.2.3 needs a 1Password session on the laptop**, which an autonomous session
  cannot open. Everything before it is provable offline; push, dispatch and watch wait
  behind it. When the owner ran it, `task plan` got through `clock` and `session` and was
  interrupted at `state` behind a screen of Apple container 1.3.1 failing to forward
  signal 28 (a terminal resize) into the container, and Ctrl-C failed to forward the same
  way; task force-quit and the container went away with the client. The same phase took
  11 seconds in the Actions run, so the stall was not the phase. The old Taskfile ran the
  same `container run` flags, so this is the laptop's engine, not the migration; the
  first production run stood in for the gate.

## Corrections from Phase D, read before E

- **The D.2 `env:` block needs `AWS_REGION: auto`.** The old workflow exported it and the
  CLI signs with a region; the block as written had the three `R2_*` mappings and the
  config file only. tlnet's carries it.
- **The `FILTER` value renders its globs unquoted into the shell.** `--exclude=*` and the
  `***` include reach `sh` bare; nothing in `/work` matches them, so the listing was right
  either way, but the old `fetch` quoted them and tlnet quotes them:
  `--exclude='*.r[0-9]*.tar.xz' ... --exclude='*'`.
- **The subtree's root files are ordinary batch entries, not decision-batch ones.**
  `split` sends `TL/tlpkg/` and slash-less keys to the last batch; `install-tl*` and
  `update-tlmgr-latest.*` carry slashes, so they ride the batch their sort order gives
  them, each with its `.sha512` and `.asc` beside it by the extension rule, which is what
  `verify` needs. ctan has verified this subtree the same way every hour.
- **D.3.2's "a few thousand" is 17,000 lines**, 6.79 GB, 14,898 of them under `archive/`;
  the raw listing has 429 directory lines and no symlink lines, so `-L` resolved every
  stable name and the excludes dropped every revision-stamped one.
- **The gate commands run one at a time here.** The permission classifier refused the
  listing gate joined to its checks in one command, and the ruleset `PUT`; the plain
  `task run -- task list` and the read-only checks after it went through.

## Footguns

- **`task sync KEY=value` sets a host var and does nothing inside.** It is `task sync --
  KEY=value`. The reusable workflow does this; hand-typed commands are where it slips.
- **A library `vars:` value cannot be overridden from a mirror's root `vars:`.** `RUN`,
  `ENGINE`, `PASS_ENV`, `VARIANT`, `TOP`, `PREFIX` in the toolbox; `S3`, `URL`, `STATE`,
  `STAGING`, `RSYNC`, `CURL`, `AWS_FLAGS` and the awk helpers in the engine. A CLI var
  still overrides (`RUN=/work/fixtures/run-root`). This is why the engine's tunables are
  inline defaults and why ctan's `run/` becomes `.run/`.
- **Two includes, one namespace.** A verb defined in both the toolbox and the engine is
  a parse error. `report-engine` is defined in both on purpose: the engine consumer's
  toolbox include must carry `excludes: [report-engine]`. Add it to the templates in
  the appendix for ctan and tlnet, never for dropbox.
- **`--dry --force` renders `status:`-gated verbs**, so `rebuild`, `reconcile`, `prepare`
  and the `TL_KEY` guard all appear in every `render.txt`. Correct.
- **`render` runs `sh:` vars.** `BATCHES` (`ls`), `TS` (`awk`), the engine's helpers: all
  local. Nothing may call `aws` or the network in a `sh:` var.
- **The caller must grant `actions: write`** or the chain step fails with 403 after a
  green run. A called workflow can only lower the token's permissions.
- **`check / check`** is the reusable check's name. The ctan ruleset must require that.
- **`secrets: inherit` exports every repository secret into the sync step.** GitHub
  masks them in logs. Never `env | sort` anywhere in a pipeline, a test or a report.
- **Scratch runs ping the production healthcheck** unless `HEALTHCHECK_URL` is unset,
  and a failing scratch run would send `/fail`.
- **A scratch bucket under the no-seed model fills itself**: cap with `MAX_BATCHES=1
  BATCH_GB=1` and empty it afterwards.
- **tlnet's `FILTER` order matters.** rsync applies filter rules first match wins:
  the two excludes for revision-stamped files come before the includes, the catch-all
  `--exclude=*` last. Gate D.3.2 is the test.
- **tlnet's first reconcile deletes what upstream no longer has** and what the old
  pipeline never removed. The old `stale` did the same, so the set should be small.
  Read `orphans.txt` in the first summary before trusting the schedule.
- **`reconcile` keys on hour 03** from `start.txt` field 2. tlnet at 03:30 reconciles
  daily; ctan once a day. Neither `clock` nor the schedule changes.
- **dispatch is untouched** and sends `workflow_dispatch` to `sync.yml` on the default
  branch with no inputs. Workflow file name, trigger and default branch must not change.
- **The container has no tty and no `-i`.** Nothing may prompt. dropbox's `empty-trash`
  prompts on the host before `op`; it is fine.
- **`GITHUB_STEP_SUMMARY` is mounted at its own path.** Reports write to
  `${GITHUB_STEP_SUMMARY:-/dev/stdout}`.
- **The include is fetched over the network on the host once per run and the image is
  offline.** A raw.githubusercontent.com outage fails the run before anything happens.
- **Never create a repository at an old name.** GitHub deletes the redirect.
- **A change that belongs in lib goes in lib**, as a patch release. Do not paper over an
  engine gap in a mirror; three mirrors would each carry the patch.

## Compliance block, per mirror

```sh
ok=1; f() { echo "FAIL: $1"; ok=0; }
grep -q 'katoptra/lib/v1/toolbox.yml' Taskfile.yml      || f "include not pinned to v1"
grep -q 'flatten: true' Taskfile.yml                    || f "include not flattened"
grep -qs raw.githubusercontent.com .taskrc.yml          || f ".taskrc.yml missing or untrusted"
grep -qx '\.run/' .gitignore && grep -qx '\.task/' .gitignore || f ".gitignore lacks .run/ or .task/"
test -s render.txt                                      || f "render.txt missing"
test ! -d docker                                        || f "docker/ still present"
grep -rqs 'setup-task\|toolchain.lock\|task_linux_amd64' .github/ && f "old installer in workflows"
grep -q '^  \(ENGINE\|RUNNER\|PASS_ENV\|RUN\):' Taskfile.yml      && f "toolbox vars redefined in Taskfile"
grep -q 'IMAGE:' Taskfile.yml && ! grep -q 'IMAGE: ghcr.io/katoptra/toolbox:' Taskfile.yml && f "IMAGE is not the GHCR image"
grep -qi 'docker/' README.md CLAUDE.md                  && f "docs still mention docker/"
grep -qi 'seed' Taskfile.yml                            && f "seed still in Taskfile"
grep -qE 'katoptra/lib/.github/workflows/sync.yml@(v1|[0-9a-f]{40} # v1)' .github/workflows/sync.yml   || f "sync.yml does not call lib at v1"
grep -qE 'katoptra/lib/.github/workflows/check.yml@(v1|[0-9a-f]{40} # v1)' .github/workflows/check.yml || f "check.yml does not call lib at v1"
grep -q 'secrets: inherit' .github/workflows/sync.yml   || f "sync.yml lacks secrets: inherit"
grep -q 'actions: write' .github/workflows/sync.yml     || f "sync.yml lacks actions: write"
grep -q 'workflow_dispatch' .github/workflows/sync.yml  || f "sync.yml lacks workflow_dispatch"
grep -q 'schedule:' .github/workflows/sync.yml          && f "sync.yml has a schedule"
for v in default image image-build image-clean run op sync plan render check render-update clean clock ping ping-fail report report-engine report-mirror \
         list normalise state rebuild diff split batches batch fetch publish merge checkpoint remove delete reconcile retry prepare verify index smoke; do
  grep -q "^  $v:" Taskfile.yml && ! grep -q "excludes:.*\b$v\b" Taskfile.yml && f "verb $v collides and is not excluded"
done
grep -q '^  pipeline:' Taskfile.yml && grep -q '^  plan-pipeline:' Taskfile.yml || f "pipeline or plan-pipeline missing"
task --list 2>/dev/null | grep -q 'render-update'       || f "library verbs do not resolve"
task >/dev/null 2>&1                                    || f "menu does not print"
task check >/dev/null 2>&1                              || f "task check fails"
test $ok = 1 && echo "compliant: $(basename "$PWD")"
```

For an engine consumer, additionally: `grep -q 'katoptra/lib/v1/engines/rsync.yml'
Taskfile.yml` and `grep -q 'excludes:.*report-engine' Taskfile.yml`. Note the loop
flags a mirror's `verify`, `smoke`, `index` or `prepare` only when the engine include
does not exclude them, which is the rule.

## End state, checked over the following day

| | ctan | tlnet | dropbox |
|---|---|---|---|
| Three consecutive scheduled runs green | three hours | three nights | three chained or manual runs |
| Healthcheck pinged on schedule, no `/fail` | yes | yes | yes |
| Fresh | `curl -s https://ctan.ijosh.com/timestamp` within the hour | the tlpdb sha512 read back equals the run's | report's percent mirrored |
| No unexpected deletions | orphans 0 outside 03; deletes a handful | orphans only stale keys; `index.html` present | trash count normal |
| Storage | within a batch of yesterday | under 10 GB | one new history object per run |
| Summary has base, engine and mirror rows | yes | yes | base rows then the migrator's report |
| `check / check` green on a PR | yes | yes | yes, plus `tests` |
| Fresh clone: `task` prints the menu, `task check` passes | yes | yes | yes |
| Compliance block passes | yes | yes | yes |
| Repo holds only: Taskfile, `.taskrc.yml`, `render.txt`, two callers, docs, own files | fixtures, `aws.config`, docs | `site/`, `aws.config` | `src/`, `tests/`, `config/`, `op.env` |

## What the report back looks like

1. lib: the release, the engine's verb count, the two example checks, the ruleset change.
2. Per mirror: the commit or PR, the render diff with every remaining line justified
   (or, for tlnet, the read-through), the scratch summary or the reason it was skipped,
   the first production run's summary and ping time.
3. Anything changed in lib during B to D, and the patch tag that carries it.
4. Anything in this document that was wrong. The next migration reads that list.

## Appendix: the caller workflows and the normaliser

`.github/workflows/sync.yml`, whole file:

```yaml
name: sync
on:
  workflow_dispatch:
    inputs:
      vars:
        description: 'KEY=value pairs for the pipeline, e.g. "RECONCILE=true MAX_BATCHES=8"'
        type: string
        default: ''
permissions:
  contents: read
  actions: write   # the called workflow chains the next run; a called workflow cannot raise this
concurrency: {group: sync, cancel-in-progress: false}
jobs:
  sync:
    uses: katoptra/lib/.github/workflows/sync.yml@v1
    with: {vars: '${{ inputs.vars }}', timeout-minutes: 355}
    secrets: inherit
```

On ctan and tlnet, whose Actions policy requires a full commit SHA on every `uses:`, the
`uses:` line in both callers reads `katoptra/lib/.github/workflows/<x>.yml@<release sha>
# vX.Y.Z`, today `04f7901cf1aa7551bc43db5ff801a225a189c42a # v1.0.2`, and Dependabot
bumps it. dropbox uses the templates as written.

`.github/workflows/check.yml`, whole file (dropbox adds the `tests` job):

```yaml
name: check
on: {pull_request: {}}
permissions: {contents: read}
jobs:
  check:
    uses: katoptra/lib/.github/workflows/check.yml@v1
```

The include block for an engine consumer:

```yaml
includes:
  toolbox:
    taskfile: https://raw.githubusercontent.com/katoptra/lib/v1/toolbox.yml
    flatten: true
    excludes: [report-engine, report-mirror]
    vars: {NAME: ctan, DESC: an hourly mirror of CTAN at https://ctan.ijosh.com/, IMAGE: ghcr.io/katoptra/toolbox:rsync-v1, PASS: AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_ENDPOINT_URL AWS_REGION}
  rsync:
    taskfile: https://raw.githubusercontent.com/katoptra/lib/v1/engines/rsync.yml
    flatten: true
    excludes: [index, smoke]
```

The normaliser for before-and-after render diffs:

```sh
norm() {
  sed -E 's/\[sync\]/[pipeline]/; s/\[plan\]/[split]/; s/\[tlpdb\]/[prepare]/; s/\[render\]/[pages]/; s#/work/run#/work/.run#g' "$1" \
  | grep '^task: \[' | grep -vE '^task: \[(image|run|op|default|report|report-engine|report-mirror)\]'
}
diff <(norm /tmp/<mirror>-before.txt) <(norm .run/render.txt)
```
