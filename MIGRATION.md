# Migrating a mirror onto the toolbox

How ctan, tlnet and dropbox move from their own copies of the toolbox to
`katoptra/lib`. One agent per mirror, in parallel, each in its own repository. Nothing
here touches lib, dispatch, healthchecks, terraform or the buckets.

**These mirrors are production.** Real users install TeX from ctan and tlnet every hour
and dropbox is the only copy of a Dropbox account. The migration must not cause a
missed run, a failed run, a changed upload, a changed deletion, or a changed schedule.
The tools for that are in section 5: prove the new pipeline renders the same commands
as the old one before it runs, run it against scratch where scratch exists, and merge
in the window right after a green run.

## 0. Before any agent starts, once, by hand

These are lib-side and shared. An agent that finds one undone stops and reports.

- [ ] `katoptra/lib` is tagged `v1.0.0` and the `release` workflow is green. `v1` exists
      as a git tag and `katoptra/lib/.github/workflows/sync.yml@v1` resolves.
- [ ] `ghcr.io/katoptra/toolbox:rsync-v1` and `proton-v1` pull anonymously:
      `docker manifest inspect ghcr.io/katoptra/toolbox:rsync-v1` from a logged-out
      shell. If it asks for credentials the package is private: make it public in the
      package settings (github.com/orgs/katoptra/packages).
- [ ] The org Actions policy allows reusable workflows from the org and leaves the
      default token read-only. The caller grants `actions: write` itself (section 2).
- [ ] The ctan branch ruleset's required status check is renamed from `check` to
      `check / check`. A reusable workflow's check reports as `<caller job> / <called
      job>`, and a required check that never reports blocks every pull request. Run
      `gh api repos/katoptra/<repo>/rules/branches/<default>` for the other two; only
      ctan has a rule today.
- [ ] Each agent has `gh` authenticated with `repo` and `workflow` scope, task 3.51 or
      newer on the host, Docker or Apple container running, and for a live test the
      mirror's credentials exported in the shell.

## 1. What the toolbox owns and what the mirror keeps

Read `README.md` first. The rule: a verb or file that does the same thing in every
mirror is the library's; a mirror keeps only what is specific to what it mirrors.

| Leaves the mirror, comes from lib | Stays in the mirror |
|---|---|
| `docker/` and the image build; the `IMAGE`, `ENGINE`, `RUNNER`, `PASS_ENV` vars | Root vars: `SOURCE`, `BUCKET`, `HOST`, and every tunable it owns |
| `image`, `image-clean`, `run`, `op`, `clean`, `sync`, `plan`, `render`, `check` verbs | `pipeline` and `plan-pipeline`, the ordered step lists |
| The hand-drawn menu (`default`); extra lines go in the `MENU` var | Every engine verb, until the rsync engine is extracted in a later release |
| `ping`, `ping-fail`, `clock` (a mirror may keep its own, excluded) | Verbs with mirror-specific meaning: `verify`, `index`, `page`, `smoke`, `tlpdb` |
| The workflow body; installer scripts; the toolchain lock | The caller workflows, ten lines each; `op.env`; `render.txt`; fixtures |

The engine is not extracted in this migration. ctan's `list`, `diff`, `batches` and the
rest stay in ctan's Taskfile. That is a later lib release with its own plan.

## 2. The changes, per mirror

### 2.1 Every mirror

1. **`.taskrc.yml`** at the root:
   ```yaml
   remote:
     trusted-hosts: [raw.githubusercontent.com]
     expiry: 1h
   ```
2. **`.gitignore`** gains `.run/` and `.task/`. The library's `RUN` is
   `{{.ROOT_DIR}}/.run`, and a mirror cannot override it: a library `vars:` value
   shadows the mirror's root value. A mirror that used another run directory moves to
   `.run` (ctan: `run/`, and every doc, menu line and fixture path that names it).
3. **The include**, flattened, with `NAME`, `DESC`, `IMAGE`, and `PASS` for the host
   environment names the pipeline reads (secrets that are not in an `op.env`, and any
   env the code reads directly). `excludes:` lists the library verbs the mirror keeps
   its own version of. A duplicate name without `excludes` is a parse error.
4. **Rename colliding verbs.** These names are the library's and a mirror's verb with
   the same name must be renamed or excluded: `default`, `image`, `image-build`,
   `image-clean`, `run`, `op`, `sync`, `plan`, `render`, `check`, `render-update`,
   `clean`, `clock`, `ping`, `ping-fail`. The mirror's whole run becomes `pipeline`, its
   read-only half `plan-pipeline`.
5. **Delete** `docker/`, the image vars and verbs, the installer step in the workflows,
   the mirror's toolchain lock if it has one, and the `docker` ecosystem in
   `.github/dependabot.yml` if present.
6. **Caller workflows.** The whole of `.github/workflows/sync.yml`:
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
     actions: write   # the called workflow chains the next run; it cannot raise this itself
   concurrency: {group: sync, cancel-in-progress: false}
   jobs:
     sync:
       uses: katoptra/lib/.github/workflows/sync.yml@v1
       with: {vars: '${{ inputs.vars }}', timeout-minutes: 355}
       secrets: inherit
   ```
   And `check.yml`:
   ```yaml
   name: check
   on: {pull_request: {}}
   permissions: {contents: read}
   jobs:
     check:
       uses: katoptra/lib/.github/workflows/check.yml@v1
   ```
   `secrets: inherit` is what makes both the 1Password token and the repository-secrets
   fallback reach the run. `permissions` in the caller is the ceiling for the called
   workflow; without `actions: write` the chain step fails with 403 after a green run.
   Old boolean inputs (`reconcile`, `max_batches`, `seed`) become `vars`:
   `gh workflow run sync.yml -f vars='RECONCILE=true MAX_BATCHES=8'`.
7. **Vars after the dashes.** `task sync -- MAX_BATCHES=8` sets task vars for the
   pipeline inside the image. A `KEY=value` before the dashes is a host-side var and
   never reaches the container. `PASS` is for environment variables only.
8. **Secrets.** With an `op.env`, one `op run` resolves it around the whole run. Without
   one, the reusable workflow exports every repository secret into the sync step's
   environment by name and the ones in `PASS` cross into the container. The `op.env`
   route is where every mirror ends up (the org checklist's phase 3); the secrets route
   is the zero-change first step for ctan and tlnet.
9. **`render.txt`**: `task render-update` once, commit it. `task check` from then on.
10. **Docs**: README (how it runs, want your own, the secrets table), CLAUDE.md,
    CONTRIBUTING.md, and any runbook. Remove every mention of `docker/`, the old
    installer, the old verb names and the old inputs. Describe the current system only,
    never the migration.

### 2.2 ctan

The biggest. 704 lines, of which about 120 remain.

- **Verbs renamed**: `sync` to `pipeline`, `plan` to `split` (the batch planner), `render`
  to `pages` (the directory-page renderer). Every reference in `desc:` strings, the
  menu, CLAUDE.md, `docs/reference.md` and the fixtures' menu lines follows. The
  `desc:` of the old `sync` is the new `pipeline` desc with the renamed verbs.
- **Verbs deleted**: `default`, `image`, `run`, `ping`. The library's are identical in
  effect. `ping` reads `HEALTHCHECK_URL`, which always crosses.
- **Verbs kept and excluded**: `clock`. ctan's clears `publish.txt`, `orphans.txt` and
  `chain` before writing `start.txt`, and `reconcile` keys on field 2 of that file. The
  library's clock writes a third field and clears nothing. Keep ctan's:
  `excludes: [clock]`.
- **Vars deleted**: `IMAGE`, `ENGINE`, `RUNNER`, `RUN`. `S3`, `URL`, `STATE`, `INDEXED`,
  `INDEX`, `STAGING`, `SLASH`, `TL`, `TL_KEY`, `CEILING_GB`, `BATCH_GB`, `MAX_BATCHES`,
  `RECONCILE`, `RETRY_BASE`, `RSYNC`, `CURL`, `AWS_FLAGS`, and the awk helpers stay as
  root vars. `SLASH` and everything built on `RUN` now resolve under `.run`.
- **`run/` becomes `.run/`** in `.gitignore`, the workflow's chain step (`run/chain` is
  now `.run/chain`, which the reusable workflow already reads), and every doc. The
  fixtures under `fixtures/run-root` and `fixtures/run-seed` are inputs passed as
  `RUN=/work/fixtures/run-root` on the command line; a CLI var overrides the library's,
  so they keep working. Verify with `task run -- task diff RUN=/work/fixtures/run-root`.
- **`aws.config` stays**, with the root `env: AWS_CONFIG_FILE: '{{.ROOT_DIR}}/aws.config'`.
  The library image does not carry it. Inside the container the path is
  `/work/aws.config`.
- **Secrets**: no `op.env` yet. `PASS: AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
  AWS_ENDPOINT_URL AWS_REGION`. The image sets `AWS_REGION=auto` as well, so the secret
  is redundant but harmless. `HEALTHCHECK_URL` crosses on its own.
- **Image parity**: ctan's Dockerfile and lib's `rsync.Dockerfile` install the same
  tools at the same versions (task 3.53.1, AWS CLI 2.36.24 trimmed to s3 and sts,
  rsync, gnupg, xz, curl, perl). The `s3api delete-objects` call uses the s3 model, which
  is kept. Confirm with `task run -- sh -c 'aws s3api help >/dev/null && echo ok'`.
- **Menu**: the environment table at the bottom of ctan's menu (which secrets are set)
  has no home in the library's menu. Drop it or fold one line into `MENU`.
- **Workflow inputs**: `reconcile` and `max_batches` become `vars`. dispatch sends no
  inputs, so the Taskfile defaults (`RECONCILE=auto`, `MAX_BATCHES=4`) apply, exactly as
  today. Update `docs/reference.md` where it shows `-f reconcile=true`.
- **The ruleset** (section 0) or the migration pull request cannot merge.
- **Timeout**: `timeout-minutes: 355` in the caller (was 350; both under the limit).
- **Colour**: the old workflow ran `task --color`. The library does not; the job log is
  plain. Cosmetic; leave it.

### 2.3 tlnet

The smallest, and the only one that runs on the bare runner today. Moving it into the
image is the largest behavioural change of the three, so section 5's render comparison
matters most here.

- **Verbs renamed**: `sync` to `pipeline`. `plan-pipeline` is `fetch`, `verify`, `guard`:
  it downloads but publishes nothing.
- **Verbs deleted**: `default`, `ping`.
- **Verbs kept**: `fetch`, `verify`, `guard`, `page`, `publish`, `stale`, `smoke`,
  `report`. None collide.
- **Vars**: `RUN: /tmp/tlnet-run` is shadowed by the library's `.run`, which is fine:
  `report` reads the files the same run wrote. Drop the var. `STAGING` stays.
- **Bucket names are hard-coded** in `page` (`s3://tlnet/index.html`) and `publish`
  (`s3://tlnet/{}`) beside the `BUCKET` var. Introduce `BUCKET_NAME: tlnet` and derive
  `BUCKET: s3://{{.BUCKET_NAME}}/{{.PREFIX}}`; use `{{.BUCKET_NAME}}` in both. This is
  what makes a scratch run possible (`task sync -- BUCKET_NAME=tlnet-scratch`).
- **Secrets are named differently.** tlnet has `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`,
  `R2_ACCOUNT_ID` and the workflow built `AWS_ENDPOINT_URL` from the account id. The
  pipeline reads `AWS_*`. Add the four `AWS_*` repository secrets beside the `R2_*` ones
  (`AWS_ENDPOINT_URL` is `https://<account-id>.r2.cloudflarestorage.com`), set `PASS`
  to the four names, and delete the `R2_*` secrets after the first green scheduled run.
  Nothing else in the org reads them.
- **`aws.config` stays**, with the root `env:` line, as in ctan.
- **The runner's AWS CLI is gone.** tlnet ran whatever `ubuntu-latest` shipped; now it is
  2.36.24 from the lock, and `aws s3 sync` semantics are what the Taskfile's comments
  assume. `gpgv`, `shasum`, `xz`, `cmp`, `comm` are all in the image.
- **Timeout**: `with: {timeout-minutes: 30}` in the caller. The reusable default is 355.
- **Landing page**: `page` runs after `ping` today, on purpose (a broken page is one
  email on a fresh mirror). Keep that order in `pipeline`.
- **`check.yml`** ran `task --dry sync` on the runner. The library's renders inside the
  image against `render.txt`, which is stricter. Commit the render.

### 2.4 dropbox

Already toolbox-shaped: it is where most of `toolbox.yml` came from. The migration is
mostly deletion, plus three behavioural seams.

- **Verbs deleted**: `default`, `image`, `image-clean`, `clean`, `run`, `op`, `render`,
  `sync`. The library's do the same.
- **Verbs kept and excluded**: `clock`, `ping`, `ping-fail` (the migrator owns them) and
  `plan` (dropbox's cats `.run/report.md` after the read-only half; the library's does
  not). `excludes: [clock, ping, ping-fail, plan]`.
- **Verbs kept**: `pipeline`, `plan-pipeline`, the phase verbs, `test`, `lint`, `fmt`,
  `status`, `empty-trash`, `state-rollback`, `session-seal`. Rewrite `test`, `lint`,
  `fmt` and the operator verbs to call the library's `run` and `op` the same way they
  do now (`task: run` with `CLI_ARGS`). List every operator verb in `MENU`.
- **Seam 1, inputs become vars.** The migrator reads `RECONCILE` and `RUN_BUDGET_MIN`
  from the environment; the workflow set them from inputs. The reusable workflow cannot
  set env for the job, so the Taskfile maps task vars to env at the root:
  ```yaml
  env:
    RECONCILE: '{{.RECONCILE | default ""}}'
    RUN_BUDGET_MIN: '{{.RUN_BUDGET_MIN | default ""}}'
  ```
  and a manual run is `gh workflow run sync.yml -f vars='RECONCILE=true'`. Confirm the
  migrator treats an empty string as unset. `PASS: MIRROR_VERBOSE` for the one env name
  that is set by hand.
- **Seam 2, the report.** The old workflow appended `.run/report.md` to the job summary
  on every exit and ran `report-phase` first if the run died early. The reusable
  workflow does neither. `report-phase` appends to `$GITHUB_STEP_SUMMARY` itself (the
  library mounts it at its own path), and dropbox's `ping-fail`, which the library's
  `sync` calls when `pipeline` fails, runs `report-phase` first when `.run/report.md` is
  missing, then pings. Both files are inside the container where the secrets are.
- **Seam 3, `test_taskfile.py`.** It slices the Taskfile between `default:` and
  `  image:` to check the banner names every operator verb. Neither anchor exists after
  the migration. Rewrite it to read the `MENU` var, or delete it; do not leave it
  failing.
- **`check.yml`** keeps a job for `task test` and `task lint` (the library's check
  renders only) and adds a job that calls the library's check. Both must be green.
- **The toolchain lock** in `config/` and the installer step in both workflows go. The
  library's proton image carries the same proton-drive, age and Python packages at the
  same versions; the one difference is task 3.45.4 to 3.53.1 inside the image. The
  `.taskrc.yml` `remote:` section needs 3.51 or newer on the host, which the action
  installs.
- **`IMAGE`**: `ghcr.io/katoptra/toolbox:proton-v1`. The local `dropbox:toolbox` tag
  is gone with the Dockerfile.
- **The state id** in `config/mirror.toml` stays `dropbox-mirror`; it is the primary
  key of the state database. Do not touch it.
- **Chain**: dropbox already writes `.run/chain`; the reusable workflow reads it.
- **Schedule**: nothing in dispatch triggers dropbox and it has no `schedule:`. Not
  part of this migration; do not add one.

## 3. Footguns

Things that pass a local check and break in production, or the other way round.

- **The include is fetched over the network on the host, once, then cached under
  `.task/remote`, and the image runs offline.** A fresh checkout in Actions fetches
  once per run. If raw.githubusercontent.com is down the run fails before doing
  anything, which is safe; the healthcheck catches the missing ping.
- **`task sync KEY=value` does nothing useful.** It is `task sync -- KEY=value`. The
  workflow already does this; a hand-typed command is where it goes wrong.
- **A library `vars:` value cannot be overridden from the mirror's root `vars:`.**
  Today that is `RUN`, `ENGINE`, `PASS_ENV`, `VARIANT`, `TOP`, `PREFIX`. A CLI var still
  overrides (`RUN=/work/fixtures/run-root`).
- **Scratch runs ping the production healthcheck** if `HEALTHCHECK_URL` is exported.
  Run scratch tests with it unset. A scratch run that fails would otherwise send `/fail`
  and page you; one that succeeds would mask a stalled production run.
- **A scratch run under the no-seed model fills the scratch bucket.** An empty bucket
  rebuilds to an empty state and the delta is the whole tree. Cap it: for ctan
  `MAX_BATCHES=1 BATCH_GB=1`; for tlnet the tree is 10 GB and `fetch` is the cost.
  Empty the scratch bucket afterwards.
- **`render` runs `sh:` vars.** A dynamic var that calls `aws` or the network fails the
  offline render. ctan's and tlnet's are awk, `ls` and `date`; keep it that way.
- **`--dry --force` renders status-gated verbs too.** ctan's `rebuild` and `reconcile`
  appear in `render.txt` every time. That is correct and expected.
- **The chain step needs `actions: write` in the caller**, and `gh workflow run` needs
  the workflow file to still be named `sync.yml`.
- **`secrets: inherit` exports every repository secret into the sync step.** GitHub
  masks the values in the log. Do not `env | sort` in a pipeline, in a test, or in a
  report.
- **The reusable check's job name is `check / check`.** A ruleset requiring `check`
  never sees it (section 0).
- **dispatch is untouched** and keeps sending `workflow_dispatch` to `sync.yml` on the
  default branch with no inputs. The workflow file name, the trigger and the default
  branch must not change. The old inputs are gone; dispatch never sent them.
- **The container has no tty and no `-i`.** Anything that prompted (`prompt:` in a task,
  `aws` pagination) hangs or dies. dropbox's `empty-trash` has a `prompt:`; it runs on
  the host before `op`, so it still prompts there. Nothing else does.
- **User and group inside the container are the host's**, `HOME=/tmp`. The AWS CLI
  writes its cache under `/tmp`. Files the run writes under `/work` are owned by the
  runner user, as today.
- **`GITHUB_STEP_SUMMARY` is mounted at its own path.** A report that writes to it works
  in Actions and to stdout on a laptop only if it uses `${GITHUB_STEP_SUMMARY:-/dev/stdout}`
  as ctan and tlnet do.
- **Two mirrors reconciling in the same hour** is not a migration concern (ctan at 03,
  tlnet has no reconcile) but keep ctan's `03` when touching `clock`.
- **Never create a repository at an old name** (`jshvn/ctan`, `jshvn/dropbox-mirror`).
  GitHub deletes the redirect permanently.
- **Do not fix lib from a mirror.** An agent that needs a library change (a missing tool,
  a verb that should be shared, a workflow input) stops, writes down exactly what and
  why, and reports. A library release moves `v1` for all three mirrors at once.

## 4. Compliance: the checks every repo passes at the end

Run in the mirror's root after the migration commit. Every line is a test with a
pass condition; the block is meant to be pasted.

```sh
ok=1; f() { echo "FAIL: $1"; ok=0; }
# The include, its trust file, the ignores, the committed render
grep -q 'katoptra/lib/v1/toolbox.yml' Taskfile.yml      || f "include not pinned to v1"
grep -q 'flatten: true' Taskfile.yml                    || f "include not flattened"
grep -qs raw.githubusercontent.com .taskrc.yml          || f ".taskrc.yml missing or untrusted"
grep -qx '\.run/' .gitignore && grep -qx '\.task/' .gitignore || f ".gitignore lacks .run/ or .task/"
test -s render.txt                                      || f "render.txt missing"
# Nothing of the old toolbox remains
test ! -d docker                                        || f "docker/ still present"
grep -rqs 'setup-task\|toolchain.lock\|task_linux_amd64' .github/ && f "old installer in workflows"
grep -q '^  \(ENGINE\|RUNNER\|PASS_ENV\):' Taskfile.yml       && f "old toolbox vars in Taskfile"
grep -q 'IMAGE:' Taskfile.yml && ! grep -q 'IMAGE: ghcr.io/katoptra/toolbox:' Taskfile.yml && f "IMAGE is not the GHCR image"
grep -qi 'docker/' README.md CLAUDE.md                  && f "docs still mention docker/"
grep -qi 'seed' Taskfile.yml                            && f "seed still in Taskfile"
# The callers
grep -q 'katoptra/lib/.github/workflows/sync.yml@v1' .github/workflows/sync.yml   || f "sync.yml does not call lib@v1"
grep -q 'katoptra/lib/.github/workflows/check.yml@v1' .github/workflows/check.yml || f "check.yml does not call lib@v1"
grep -q 'secrets: inherit' .github/workflows/sync.yml   || f "sync.yml lacks secrets: inherit"
grep -q 'actions: write' .github/workflows/sync.yml     || f "sync.yml lacks actions: write"
grep -q 'workflow_dispatch' .github/workflows/sync.yml  || f "sync.yml lacks workflow_dispatch"
grep -q 'schedule:' .github/workflows/sync.yml          && f "sync.yml has a schedule"
# Reserved names: a mirror verb with a library name must be excluded
for v in default image image-build image-clean run op sync plan render check render-update clean clock ping ping-fail; do
  grep -q "^  $v:" Taskfile.yml && ! grep -q "excludes:.*\b$v\b" Taskfile.yml && f "verb $v collides and is not excluded"
done
# The contract verbs exist, the library's resolve, the menu prints, the render is current
grep -q '^  pipeline:' Taskfile.yml && grep -q '^  plan-pipeline:' Taskfile.yml || f "pipeline or plan-pipeline missing"
task --list 2>/dev/null | grep -q 'render-update'       || f "library verbs do not resolve"
task >/dev/null 2>&1                                    || f "menu does not print"
task check >/dev/null 2>&1                              || f "task check fails"
test $ok = 1 && echo "compliant: $(basename "$PWD")"
```

And on GitHub, per repo:

```sh
r=katoptra/<repo>
gh secret list --repo $r                                   # what the run can see
gh api repos/$r/rules/branches/$(gh api repos/$r --jq .default_branch) --jq '.[].type'
gh workflow list --repo $r                                 # sync and check, nothing else
gh run list --repo $r --workflow sync.yml --limit 3        # the last runs, green
```

Across the three at once, from lib's root: every mirror renders against the tag it
pins, which is what a lib release will check from now on.

```sh
for r in ctan tlnet dropbox; do (cd ../$r && task check) || echo "FAIL $r"; done
```

## 5. Verification: does the pipeline still run?

In order. Each step is a gate; a failure means stop and understand, not retry.

### 5.1 Same commands, before and after (offline, no credentials)

The strongest check, and it needs the old Taskfile. Before changing anything:

```sh
git stash list >/dev/null; git switch -c josh/toolbox
task run -- task --dry --force sync 2>&1 > /tmp/before.txt      # ctan, dropbox: inside the old image
task --dry sync > /tmp/before.txt 2>&1                          # tlnet: on the host, as check.yml did
```

After the migration, `task render` writes `.run/render.txt`. Normalise both and diff:

```sh
norm() { sed -E 's/\[sync\]/[pipeline]/; s/\[plan\]/[split]/; s/\[render\]/[pages]/; s#/work/run#/work/.run#g; s#/tmp/tlnet-run#/work/.run#g; /^task: \[(image|run|op|default)\]/d' "$1" | grep '^task: \[' ; }
diff <(norm /tmp/before.txt) <(norm .run/render.txt)
```

The diff must be empty except for lines you can name and justify: the renamed verbs
above, `.run` for `run`, the bucket-name var in tlnet's `page` and `publish`, dropbox's
report-phase appending to the summary. Any other difference is a behaviour change and
the migration is not done. Commit the justified render as `render.txt`.

### 5.2 The image has the tools (offline)

```sh
task run -- sh -c 'rsync --version | head -1; aws --version; gpgv --version | head -1; xz --version | head -1; shasum --version'   # rsync image
task run -- sh -c 'python --version; proton-drive version | head -1; age --version; python -c "import boto3, requests"'         # proton image
task run -- sh -c 'echo offline=$TASK_REMOTE_OFFLINE region=$AWS_REGION; test -r aws.config && echo aws.config ok'
```

### 5.3 The offline fixtures still pass (ctan, dropbox)

ctan: every line of the old menu's "offline checks" block, with `RUN=/work/fixtures/...`.
dropbox: `task test` and `task lint`, 153 tests.

### 5.4 Scratch (ctan, tlnet; credentials exported, `HEALTHCHECK_URL` unset)

```sh
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_ENDPOINT_URL=...; unset HEALTHCHECK_URL
task run -- task pipeline BUCKET=ctan-scratch MAX_BATCHES=1 BATCH_GB=1        # ctan
task run -- task fetch verify guard publish BUCKET_NAME=tlnet-scratch          # tlnet, up to publish
```

Pass: the run reaches `report` (ctan) or `publish` finishes (tlnet); the scratch bucket
holds the state file and the batch's keys; `.run/chain` exists for ctan. The `smoke`
and `page` verbs need the real domain and are proven by the production run. Empty the
scratch bucket afterwards. dropbox has no scratch: `task plan` is the read-only proof
(session, state fetch, inventory, delta, plan) and it must print the report.

### 5.5 The pull request

Push the branch, open the PR. `check / check` must be green: it renders inside the
image on the runner and diffs `render.txt`, which proves the include resolves from
GitHub, the image pulls from GHCR, and the render matches what 5.1 justified. dropbox's
test job must be green too.

### 5.6 The merge window

- **ctan**: the run fires at :42 and takes 3 to 5 minutes. Merge between :50 and :30.
  Note the id of the last green run first: `gh run list --workflow sync.yml --limit 1`.
- **tlnet**: fires at 03:30 UTC. Merge any time except 03:00 to 04:30.
- **dropbox**: nothing scheduled. Merge when no run is in progress
  (`gh run list --workflow sync.yml --limit 1` shows completed).

Then, before the schedule does: `gh workflow run sync.yml` and watch it.

```sh
gh workflow run sync.yml && sleep 20 && gh run watch --exit-status $(gh run list --workflow sync.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

Pass: green; the job summary shows the report with numbers in the usual range (ctan: a
few hundred uploads and a handful of deletes in an hour, not thousands; tlnet: storage
within the limit, signature line present; dropbox: the run row closed, percent mirrored
unchanged or up). The healthcheck received a ping. `df` in the log shows the image
pulled, not built.

### 5.7 Rollback

`git revert <merge commit>` on the default branch restores the old Taskfile, image and
workflow in one commit. Nothing in the migration changes what is in the bucket, the
state file's format or its key, so the old pipeline resumes from the same state. Revert,
`gh workflow run sync.yml`, watch it green, then work out what happened.

## 6. Testing the end state

After the merge, over the following day, per mirror. All of these should be true
without anyone touching anything.

| Check | ctan | tlnet | dropbox |
|---|---|---|---|
| Three consecutive scheduled runs green | hourly, so three hours | three nights | three chained or manual runs |
| Healthcheck shows pings at the schedule, no `/fail` | yes | yes | yes |
| The mirror is fresh | `curl -s https://ctan.ijosh.com/timestamp` within the hour | `tlnet.ijosh.com/systems/texlive/tlnet/tlpkg/texlive.tlpdb.sha512` matches the run's | report's percent mirrored |
| No unexpected deletions | run summary delete count normal; `orphans.txt` empty outside 03 | `stale.txt` lines are real removals | trash count normal |
| Storage unchanged | bucket size within a batch of yesterday's | under `LIMIT_MB` | R2 state history has one new object per run |
| A pull request runs `check / check` green | yes | yes | yes, plus tests |
| `task` on a laptop prints the menu and `task check` passes from a fresh clone | yes | yes | yes |
| The repo is: Taskfile, `.taskrc.yml`, `render.txt`, two ten-line callers, docs, and its own files | fixtures, `aws.config`, docs | `site/`, `aws.config` | `src/`, `tests/`, `config/`, `op.env` |
| Section 4's block passes | yes | yes | yes |

When all three columns are complete, update the org checklist's phase 5 items, and
lib's README loses the sentence that says the rsync engine lives in ctan only once the
engine is actually extracted, which is the next plan, not this one.

## 7. What each agent reports back

One message per mirror, in this shape, so the three can be compared:

1. The migration commit and the PR link.
2. The 5.1 diff, with every remaining line justified.
3. The scratch run's summary (or dropbox's plan report).
4. The first production run's summary and the healthcheck ping time.
5. Anything found that belongs in lib, with the exact verb, tool or input, and why.
6. Anything in this document that was wrong or missing.
