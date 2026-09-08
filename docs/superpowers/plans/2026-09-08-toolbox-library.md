# Toolbox Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seed `katoptra/lib` so that a mirror repository can include `toolbox.yml` by URL and get the menu, the container, the secrets model, the dry-run check and the workflows without copying anything.

**Architecture:** One go-task include (`toolbox.yml`) carries every host-side and in-container primitive. Two container images built from one lock file carry the tools. Two reusable workflows and one composite action carry CI. Two example consumers inside the repo prove the include resolves and the images run, and their committed `render.txt` is the check.

**Tech Stack:** go-task 3.53.1 (remote includes, flatten, excludes, `.taskrc.yml`), Apple `container` or Docker, GitHub Actions, GHCR, 1Password CLI, AWS CLI v2, proton-drive CLI, age.

**Spec:** `docs/superpowers/specs/2026-09-08-toolbox-library-design.md`

## Global Constraints

- Default branch `main`. Commit format `<type>(<scope>): <summary>`, imperative, under 75 characters. No attribution trailers.
- No emojis outside markdown. No em-dashes in prose.
- Every action pinned to a full commit SHA with the version in a trailing comment.
- No library `vars:` default for anything a mirror owns; defaults go inline as `{{.X | default N}}`.
- Host-side verbs and in-container verbs share one namespace; the names in the spec's two tables are reserved.
- Every tool in an image comes from `toolchain.lock.toml` and is checksum-verified, except the AWS CLI installer zip, which is HTTPS and version-pinned only, marked with a `ponytail:` comment.
- The one check is `task check` in each example: render inside the image, diff against `render.txt`.
- Local clone lives at `~/Git/katoptra/lib`. Nothing in this plan pushes to GitHub; creating the remote repository, pushing and tagging `v1.0.0` are the hand-off.

---

### Task 1: Repository skeleton

**Files:**
- Create: `LICENSE`, `.gitignore`, `.github/dependabot.yml`, `README.md` (stub, finished in Task 8)

**Interfaces:**
- Produces: the repo layout every later task writes into.

- [x] **Step 1: Copy the MIT license from the site repo and write the ignore file**

```sh
cd ~/Git/katoptra/lib
cp ~/Git/katoptra/site/LICENSE LICENSE
cat > .gitignore <<'EOF'
.run/
.task/
EOF
```

- [x] **Step 2: Write dependabot for actions**

`.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    groups:
      actions:
        patterns: ['*']
```

- [x] **Step 3: Write the README stub**

```markdown
# lib

The toolbox every katoptra mirror includes. Finished in Task 8.
```

- [x] **Step 4: Verify and commit**

Run: `git add -A && git status --short`
Expected: four files staged.

```sh
git commit -m "chore: seed the repository"
```

---

### Task 2: The toolchain lock

**Files:**
- Create: `toolchain.lock.toml`

**Interfaces:**
- Produces: tables `task`, `op`, `awscli`, `ubuntu`, `python`, `proton_drive_cli`, `age`, each with `version`, and per-arch tables `linux_amd64` and `linux_arm64` carrying `sha256` or `sha512`. Read by both Dockerfiles (Task 3) and the composite action (Task 5) with the same `lock` helper.

- [x] **Step 1: Write the lock**

```toml
# One lock for the family. Each Dockerfile and the toolbox action read the tables they
# need. Bumping a tool means bumping its version and every checksum beneath it.

[ubuntu]
image = "ubuntu:24.04"
# pinned 2026-08-26: `container image pull ubuntu:24.04`, then the first digest
# `container image inspect ubuntu:24.04` prints.
digest = "sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517"

[python]
version = "3.13.15"
image = "python:3.13.15-slim-bookworm"
digest = "sha256:ed86c82274b3c69b52fb5820f358f0bd7df0b603332063cb5c6e32bd220c3e6e"

[python.packages]
requests = "2.34.2"
certifi = "2026.7.22"
charset-normalizer = "3.5.1"
idna = "3.19"
urllib3 = "2.7.0"
boto3 = "1.43.88"
botocore = "1.43.88"
s3transfer = "0.19.2"
jmespath = "1.1.0"
python-dateutil = "2.9.0.post0"
six = "1.17.0"

[python.test_packages]
pytest = "8.4.2"
ruff = "0.16.4"
iniconfig = "2.3.0"
packaging = "26.3"
pluggy = "1.6.0"
pygments = "2.21.0"

[task]
version = "3.53.1"
base_url = "https://github.com/go-task/task/releases/download/v3.53.1"

[task.linux_amd64]
archive = "task_linux_amd64.tar.gz"
sha256 = "a54a408f6861ff921f6e87774180db31bacd8c1e7c944ca696db9fea49a82fc7"

[task.linux_arm64]
archive = "task_linux_arm64.tar.gz"
sha256 = "e3ad19101493a0112e1f22ae8ccc54bf03e533b1076a0ca1e6c782a09ad2e588"

[op]
version = "2.39.0"
base_url = "https://cache.agilebits.com/dist/1P/op2/pkg/v2.39.0"

[op.linux_amd64]
archive = "op_linux_amd64_v2.39.0.zip"
sha256 = "6fba7f376b6c6dec49f41b06408930a43ad064cce103c6a2ce5b3d0413a86434"

[op.linux_arm64]
archive = "op_linux_arm64_v2.39.0.zip"
sha256 = "829baeff1c07e055cfa132031b1d9f2282ccdf5076258e482caf2fda70aea5d0"

[awscli]
# ponytail: the installer zip carries a PGP signature this lock does not record; HTTPS
# and the version pin are the guarantee. Ceiling: a poisoned CDN. Upgrade path: import
# AWS's public key in the fetch stage and gpg --verify the zip.
version = "2.36.24"
url = "https://awscli.amazonaws.com/awscli-exe-linux-{arch}-{version}.zip"

[proton_drive_cli]
version = "0.8.0"

[proton_drive_cli.linux_amd64]
url = "https://proton.me/download/drive/cli/0.8.0/linux-x64/proton-drive"
sha512 = "cf61c2688c45e1055d8add6221d9471a5a5b64bf3bcdb86460f5cb18414596cc4df3cdb6627c9097c94bec32a3c9915ada3211ef2ae5be33c46ebbc996ccaa28"

[proton_drive_cli.linux_arm64]
url = "https://proton.me/download/drive/cli/0.8.0/linux-arm64/proton-drive"
sha512 = "27a1aec1d2095fd4a1a81e1d47cd1f9fd4901bd579ffe50342d15e2e52078d6e8b2dddcf58a4a386438dc7562017778be26c1ba62399f901ae82c7430e2140a3"

[age]
version = "1.2.1"
base_url = "https://github.com/FiloSottile/age/releases/download/v1.2.1"

[age.linux_amd64]
archive = "age-v1.2.1-linux-amd64.tar.gz"
sha256 = "7df45a6cc87d4da11cc03a539a7470c15b1041ab2b396af088fe9990f7c79d50"

[age.linux_arm64]
archive = "age-v1.2.1-linux-arm64.tar.gz"
sha256 = "57fd79a7ece5fe501f351b9dd51a82fbee1ea8db65a8839db17f5c080245e99f"
```

- [x] **Step 2: Verify it parses**

Run: `python3 -c 'import tomllib; d = tomllib.load(open("toolchain.lock.toml","rb")); print(sorted(d))'`
Expected: `['age', 'awscli', 'op', 'proton_drive_cli', 'python', 'task', 'ubuntu']`

- [x] **Step 3: Commit**

```sh
git add toolchain.lock.toml
git commit -m "feat(lock): pin every tool the images and the action install"
```

---

### Task 3: The two images

**Files:**
- Create: `docker/rsync.Dockerfile`, `docker/proton.Dockerfile`

**Interfaces:**
- Consumes: `toolchain.lock.toml` (Task 2), copied to `/etc/toolchain.lock.toml` in each image.
- Produces: images that `toolbox.yml` (Task 4) runs with `-v <repo>:/work -w /work`. Both export `TASK_REMOTE_OFFLINE=1`, `AWS_REGION=auto`, `WORKDIR /work`, and have `task`, `curl` on PATH.

- [x] **Step 1: Write `docker/rsync.Dockerfile`**

```dockerfile
# syntax=docker/dockerfile:1.7
# The rsync toolbox: what every rsync-to-R2 mirror runs inside, on a laptop and in
# Actions alike. The repo is bind-mounted at /work. Base pinned by digest; every tool
# comes from toolchain.lock.toml at the repo root, which is the build context.
FROM ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517 AS fetch

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip python3 \
 && rm -rf /var/lib/apt/lists/*
COPY toolchain.lock.toml /tmp/lock.toml

# Architecture from the image itself: BuildKit sets TARGETARCH, Apple container does
# not, and a defaulted arg would install amd64 binaries into an arm64 image.
RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64|arm64) ;; *) echo "unsupported architecture: $arch" >&2; exit 1 ;; esac; \
    lock() { python3 -c "import functools,sys,tomllib; x=tomllib.load(open('/tmp/lock.toml','rb')); print(functools.reduce(lambda d,k: d[k], sys.argv[1].split('.'), x))" "$1"; }; \
    curl -fsSL "$(lock task.base_url)/$(lock task.linux_${arch}.archive)" -o /tmp/task.tgz; \
    echo "$(lock task.linux_${arch}.sha256)  /tmp/task.tgz" | sha256sum -c -; \
    tar -xzf /tmp/task.tgz -C /tmp task; install -m 0755 /tmp/task /usr/local/bin/task; \
    case "$arch" in amd64) m=x86_64 ;; arm64) m=aarch64 ;; esac; \
    url="$(lock awscli.url)"; url="${url/\{arch\}/$m}"; url="${url/\{version\}/$(lock awscli.version)}"; \
    curl -fsSL "$url" -o /tmp/awscli.zip; \
    cd /tmp && unzip -q awscli.zip && ./aws/install; \
    d=/usr/local/aws-cli/v2/current/dist/awscli; \
    mkdir /tmp/keep; for k in s3 sts; do mv "$d/botocore/data/$k" /tmp/keep/; done; \
    mv "$d/botocore/data"/*.json /tmp/keep/; rm -rf "$d/botocore/data"; mv /tmp/keep "$d/botocore/data"; \
    rm -rf "$d/examples" "$d/topics" "$d/data/ac.index"

FROM ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517 AS toolbox

# perl carries shasum. Each RUN deletes its own scratch: a layer keeps what it leaves.
RUN apt-get update && apt-get install -y --no-install-recommends \
      rsync gnupg xz-utils curl ca-certificates perl python3 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=fetch /usr/local/bin/task /usr/local/bin/task
COPY --from=fetch /usr/local/aws-cli /usr/local/aws-cli
RUN ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws
COPY toolchain.lock.toml /etc/toolchain.lock.toml

# ponytail: botocore ships 432 service models and the pipelines call one, so all but s3,
# sts and the data-root *.json stay behind. Ceiling: an `aws` call to any other service
# dies on a model lookup; add it to the keep list in the fetch stage.
RUN set -eu; \
    lock() { python3 -c "import functools,sys,tomllib; x=tomllib.load(open('/etc/toolchain.lock.toml','rb')); print(functools.reduce(lambda d,k: d[k], sys.argv[1].split('.'), x))" "$1"; }; \
    task --version | grep -q "$(lock task.version)"; \
    aws --version | grep -q "aws-cli/$(lock awscli.version)"; \
    aws s3 ls s3://x --no-sign-request --endpoint-url http://127.0.0.1:1 2>&1 | grep -qiE 'connect|endpoint|refused'; \
    rsync --version | head -1; gpgv --version | head -1; xz --version | head -1; shasum --version

# Inside a run there is no network for Taskfiles: the mirror's .task/remote cache rides
# in with the bind mount. R2 has one region; the value is a literal, not a secret.
ENV TASK_REMOTE_OFFLINE=1 \
    AWS_REGION=auto
WORKDIR /work
```

- [x] **Step 2: Write `docker/proton.Dockerfile`**

```dockerfile
# syntax=docker/dockerfile:1.7
# The proton toolbox: Python plus the Proton Drive CLI and age, for the mirrors whose
# engine is a Python package. The repo is bind-mounted at /work; PYTHONPATH finds its
# src/. Base pinned by digest; every tool from toolchain.lock.toml at the build context.
FROM python:3.13.15-slim-bookworm@sha256:ed86c82274b3c69b52fb5820f358f0bd7df0b603332063cb5c6e32bd220c3e6e AS fetch

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
COPY toolchain.lock.toml /tmp/lock.toml

RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64|arm64) ;; *) echo "unsupported architecture: $arch" >&2; exit 1 ;; esac; \
    lock() { python -c "import functools,sys,tomllib; x=tomllib.load(open('/tmp/lock.toml','rb')); print(functools.reduce(lambda d,k: d[k], sys.argv[1].split('.'), x))" "$1"; }; \
    curl -fsSL "$(lock proton_drive_cli.linux_${arch}.url)" -o /tmp/proton-drive; \
    echo "$(lock proton_drive_cli.linux_${arch}.sha512)  /tmp/proton-drive" | sha512sum -c -; \
    install -m 0755 /tmp/proton-drive /usr/local/bin/proton-drive; \
    curl -fsSL "$(lock age.base_url)/$(lock age.linux_${arch}.archive)" -o /tmp/age.tgz; \
    echo "$(lock age.linux_${arch}.sha256)  /tmp/age.tgz" | sha256sum -c -; \
    tar -xzf /tmp/age.tgz -C /tmp; install -m 0755 /tmp/age/age /tmp/age/age-keygen /usr/local/bin/; \
    curl -fsSL "$(lock task.base_url)/$(lock task.linux_${arch}.archive)" -o /tmp/task.tgz; \
    echo "$(lock task.linux_${arch}.sha256)  /tmp/task.tgz" | sha256sum -c -; \
    tar -xzf /tmp/task.tgz -C /tmp task; install -m 0755 /tmp/task /usr/local/bin/task

FROM python:3.13.15-slim-bookworm@sha256:ed86c82274b3c69b52fb5820f358f0bd7df0b603332063cb5c6e32bd220c3e6e AS toolbox

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
COPY --from=fetch /usr/local/bin/proton-drive /usr/local/bin/age /usr/local/bin/age-keygen /usr/local/bin/task /usr/local/bin/
COPY toolchain.lock.toml /etc/toolchain.lock.toml

RUN python - <<'PY'
import subprocess, tomllib
lock = tomllib.load(open("/etc/toolchain.lock.toml", "rb"))
pins = [f"{k}=={v}" for t in ("packages", "test_packages") for k, v in lock["python"][t].items()]
subprocess.check_call(["pip", "install", "--no-cache-dir", "--no-deps", *pins])
PY

RUN python - <<'PY'
import importlib.metadata, platform, subprocess, tomllib
lock = tomllib.load(open("/etc/toolchain.lock.toml", "rb"))
assert platform.python_version() == lock["python"]["version"]
for table in ("packages", "test_packages"):
    for name, version in lock["python"][table].items():
        assert importlib.metadata.version(name) == version, name
first = lambda argv: subprocess.check_output(argv, text=True).splitlines()[0]
assert "@" + lock["proton_drive_cli"]["version"] in first(["proton-drive", "version"])
assert lock["age"]["version"] in first(["age", "--version"])
assert lock["task"]["version"] in subprocess.check_output(["task", "--version"], text=True)
PY

ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/work/src \
    TASK_REMOTE_OFFLINE=1 \
    AWS_REGION=auto
WORKDIR /work
```

- [x] **Step 3: Build both images locally on the arm64 laptop**

Run:

```sh
cd ~/Git/katoptra/lib
container build -t ghcr.io/katoptra/toolbox:rsync-dev -f docker/rsync.Dockerfile .
container build -t ghcr.io/katoptra/toolbox:proton-dev -f docker/proton.Dockerfile .
```

Expected: both builds finish; the self-test RUN stages print the tool versions and exit 0. Substitute `docker build` when Docker is the engine.

- [x] **Step 4: Prove the offline env var is set**

Run: `container run --rm ghcr.io/katoptra/toolbox:rsync-dev sh -c 'echo $TASK_REMOTE_OFFLINE $AWS_REGION; task --version'`
Expected: `1 auto` then `Task version: v3.53.1`.

- [x] **Step 5: Commit**

```sh
git add docker/
git commit -m "feat(docker): rsync and proton toolbox images from the lock"
```

---

### Task 4: toolbox.yml and the two examples

**Files:**
- Create: `toolbox.yml`
- Create: `examples/rsync/Taskfile.yml`, `examples/rsync/.taskrc.yml`, `examples/rsync/op.env`, `examples/rsync/render.txt`
- Create: `examples/proton/Taskfile.yml`, `examples/proton/.taskrc.yml`, `examples/proton/op.env`, `examples/proton/render.txt`

**Interfaces:**
- Consumes: images tagged as `IMAGE` (Task 3).
- Produces: every verb in the spec's two tables, by exact name. Consumers must define `pipeline` and `plan-pipeline`. Include vars: `NAME`, `DESC`, `IMAGE`, optional `PASS` (space-separated env names), optional `MENU` (extra menu lines), optional `LIB_DIR` (for `image-build`).

- [x] **Step 1: Write `toolbox.yml`**

```yaml
# The toolbox: every verb a katoptra mirror has whatever moves its bytes. A mirror
# includes this file flattened, passes NAME, DESC and IMAGE on the include, keeps its
# identity in its own root vars, and defines two verbs: pipeline and plan-pipeline,
# both of which run inside IMAGE. A verb listed under the include's excludes: and
# defined in the mirror replaces the one here.
#
# Rules this file keeps: no vars: default for anything a mirror owns (it would shadow
# the mirror's value; defaults go inline), and host-side and in-container verbs share
# one namespace, so the names below are reserved.
version: '3'

vars:
  RUN: '{{.ROOT_DIR}}/.run'
  # The container runtime, not the sync engine: Apple container when its daemon is up,
  # else Docker. ENGINE=docker forces Docker.
  ENGINE:
    sh: |
      if [ -n "$ENGINE" ]; then echo "$ENGINE"
      elif command -v container >/dev/null 2>&1 && container system status >/dev/null 2>&1; then echo container
      else echo docker; fi
  # Names cross into the container; values never appear on a command line. op.env
  # names, the mirror's PASS list, and what the Actions job summary needs.
  PASS_ENV:
    sh: |
      { test -f {{.ROOT_DIR}}/op.env && grep -v '^#' {{.ROOT_DIR}}/op.env | sed -n 's/=.*//p'; true; } | sed 's/^/-e /' | tr '\n' ' '
      for v in {{.PASS}} GITHUB_STEP_SUMMARY GITHUB_RUN_ID HEALTHCHECK_URL; do printf '%s %s ' -e "$v"; done
  # The image variant is the tag up to its version: ghcr.io/katoptra/toolbox:rsync-v1 -> rsync.
  VARIANT:
    sh: echo "{{.IMAGE}}" | sed 's/.*://; s/-v[0-9].*//; s/-dev$//'
  # The repository's top level rides in at /work and the Taskfile's directory is the
  # working directory. For a mirror the two are the same; for the examples in
  # katoptra/lib the include one level up must be reachable.
  TOP:
    sh: git -C {{.ROOT_DIR}} rev-parse --show-toplevel 2>/dev/null || echo {{.ROOT_DIR}}
  PREFIX:
    sh: git -C {{.ROOT_DIR}} rev-parse --show-prefix 2>/dev/null || true

tasks:
  default:
    desc: Print the menu
    silent: true
    # ponytail: hand-maintained listing -- go-task can neither group nor annotate, so a
    # new verb means a line below. `task --list` stays the generated view.
    cmds:
      - |
        b=$(printf '\033[1m'); c=$(printf '\033[1;36m'); d=$(printf '\033[2m'); r=$(printf '\033[0m')
        printf '%s\n' \
          "" \
          "${b}{{.NAME}}${r}   ${d}{{.DESC}}${r}" \
          "" \
          "${c}pipeline -- needs the vault (op.env) or the secrets in your environment${r}" \
          "  task sync                 One run: task pipeline inside the toolbox" \
          "  task plan                 The read-only half: task plan-pipeline inside the toolbox" \
          "" \
          "${c}checks -- offline, no credentials${r}" \
          "  task check                Render every command of the pipeline and diff it against render.txt" \
          "  task render-update        Accept the current render as render.txt" \
          "  task --list               The pipeline's own verbs" \
          "" \
          "${c}toolbox -- {{.ENGINE}}, image {{.IMAGE}}${r}" \
          "  task image                Pull it (a no-op while it exists locally)" \
          "  task image-build          Build it from a local checkout of katoptra/lib (LIB_DIR=../lib)" \
          "  task image-clean          Remove it, so the next task pulls or builds again" \
          "  task run -- <cmd>         Run anything inside it, with this repo at /work" \
          "  task op -- <cmd>          Same, with secrets resolved by name from op.env" \
          "  task clean                Delete .run, the Taskfile cache and every other ignored file" \
          {{.MENU}} \
          ""

  # ---- toolbox ----
  image:
    desc: Pull the toolbox image
    run: once
    status: ['{{.ENGINE}} image inspect {{.IMAGE}} >/dev/null 2>&1']
    cmds:
      - '{{.ENGINE}} pull {{.IMAGE}}'

  image-build:
    desc: 'Build the toolbox image from a local katoptra/lib checkout: task image-build LIB_DIR=../lib'
    cmds:
      - '{{.ENGINE}} build -t {{.IMAGE}} -f {{.LIB_DIR | default "../lib"}}/docker/{{.VARIANT}}.Dockerfile {{.LIB_DIR | default "../lib"}}'

  image-clean:
    desc: Remove the toolbox image
    cmds:
      - '{{.ENGINE}} image rm {{.IMAGE}}'

  run:
    desc: 'Run a command inside the toolbox with the repo at /work: task run -- task --list'
    deps: [image]
    # Neither -i nor -t: Apple container leaves the host terminal non-blocking after a
    # run that attaches stdin or a tty. Output still streams and Ctrl-C still stops it.
    # GITHUB_STEP_SUMMARY is a host path, mounted at the very path its value names.
    # Each argument re-quoted, so task run -- sh -c 'a; b' arrives intact.
    cmds:
      - >-
        {{.ENGINE}} run --rm
        --user $(id -u):$(id -g)
        -v "{{.TOP}}":/work -w /work/{{.PREFIX}}
        ${GITHUB_STEP_SUMMARY:+-v "$GITHUB_STEP_SUMMARY":"$GITHUB_STEP_SUMMARY"}
        -e HOME=/tmp {{.PASS_ENV}}
        {{.IMAGE}} {{range .CLI_ARGS_LIST}}{{shellQuote .}} {{end}}

  op:
    desc: 'Run a command inside the toolbox with secrets from 1Password: task op -- task pipeline'
    cmds:
      # No op.env means the secrets are already in the environment (GitHub secrets, say).
      - |
        if test -f op.env; then op run --env-file=op.env -- task run -- {{range .CLI_ARGS_LIST}}{{shellQuote .}} {{end}}
        else task run -- {{range .CLI_ARGS_LIST}}{{shellQuote .}} {{end}}; fi

  clean:
    desc: Delete every file git ignores
    cmds:
      - git clean -fdX

  # ---- pipeline ----
  sync:
    desc: One run, inside the toolbox
    cmds:
      - task: op
        vars: {CLI_ARGS: task pipeline}

  plan:
    desc: The read-only half, inside the toolbox
    cmds:
      - task: op
        vars: {CLI_ARGS: task plan-pipeline}

  # ---- checks ----
  render:
    desc: Render every command of the pipeline inside the toolbox, run none, save to .run/render.txt
    deps: [image]
    # Not via `run`: the output is the artifact, so it is captured, not streamed, and a
    # dry run needs no secrets, so no names cross into the container. task writes the
    # rendered commands to stderr; the redirect inside the container folds them into
    # stdout, so the engine's own progress lines on the host's stderr stay out of the file.
    cmds:
      - mkdir -p {{.RUN}}
      - >-
        {{.ENGINE}} run --rm --user $(id -u):$(id -g) -v "{{.TOP}}":/work -w /work/{{.PREFIX}}
        -e HOME=/tmp {{.IMAGE}} sh -c 'task --dry --force pipeline 2>&1' > {{.RUN}}/render.txt
      - cat {{.RUN}}/render.txt

  check:
    desc: render, then diff against the committed render.txt
    cmds:
      - task: render
      - 'diff -u render.txt {{.RUN}}/render.txt && echo "check: render matches render.txt"'

  render-update:
    desc: render, then accept it as render.txt
    cmds:
      - task: render
      - cp {{.RUN}}/render.txt render.txt

  # ---- inside the toolbox ----
  clock:
    desc: Record the run's start as "epoch UTC-hour weekday" in .run/start.txt
    cmds:
      - mkdir -p {{.RUN}} && date -u '+%s %H %u' > {{.RUN}}/start.txt

  ping:
    desc: Dead man's switch; healthchecks.io emails when its grace passes without this (skipped if HEALTHCHECK_URL is unset)
    cmds:
      - test -z "$HEALTHCHECK_URL" || curl -fsS -m 10 --retry 3 -o /dev/null "$HEALTHCHECK_URL"

  ping-fail:
    desc: Tell healthchecks.io the run failed (skipped if HEALTHCHECK_URL is unset)
    cmds:
      - test -z "$HEALTHCHECK_URL" || curl -fsS -m 10 --retry 3 -o /dev/null "$HEALTHCHECK_URL/fail"
```

- [x] **Step 2: Write the rsync example**

`examples/rsync/Taskfile.yml`:

```yaml
# A consumer of the toolbox with the rsync image. Inside this repo the include is a
# path; a mirror includes https://raw.githubusercontent.com/katoptra/lib/v1/toolbox.yml.
version: '3'
vars:
  SOURCE: rsync://rsync.example.org/pub/
  BUCKET: example
  HOST: example.ijosh.com
includes:
  toolbox:
    taskfile: ../../toolbox.yml
    flatten: true
    vars:
      NAME: example-rsync
      DESC: the rsync toolbox, exercised
      IMAGE: ghcr.io/katoptra/toolbox:rsync-dev
      LIB_DIR: ../..
      PASS: SEED MAX_BATCHES
tasks:
  pipeline:
    cmds:
      - {task: clock}
      - {task: tools}
      - {task: list}
      - {task: ping}
  plan-pipeline:
    cmds:
      - {task: clock}
      - {task: tools}
      - {task: list}
  tools:
    desc: Every tool the rsync image promises, by version
    cmds:
      - rsync --version | head -1
      - aws --version
      - gpgv --version | head -1
      - xz --version | head -1
      - shasum --version
  list:
    cmds:
      - rsync --list-only {{.SOURCE}} > {{.RUN}}/listing.txt
```

`examples/rsync/.taskrc.yml`:

```yaml
remote:
  trusted-hosts: [raw.githubusercontent.com]
  expiry: 1h
```

`examples/rsync/op.env`:

```
# op:// references only; `op run --env-file=op.env` resolves them at run time.
AWS_ACCESS_KEY_ID=op://VAULT/r2/access_key_id
AWS_SECRET_ACCESS_KEY=op://VAULT/r2/secret_access_key
AWS_ENDPOINT_URL=op://VAULT/r2/endpoint
HEALTHCHECK_URL=op://VAULT/healthcheck/url
```

- [x] **Step 3: Write the proton example**

`examples/proton/Taskfile.yml`:

```yaml
# A consumer of the toolbox with the proton image.
version: '3'
includes:
  toolbox:
    taskfile: ../../toolbox.yml
    flatten: true
    vars:
      NAME: example-proton
      DESC: the proton toolbox, exercised
      IMAGE: ghcr.io/katoptra/toolbox:proton-dev
      LIB_DIR: ../..
    excludes: [clock]   # a Python engine keeps its own clock
tasks:
  pipeline:
    cmds:
      - {task: clock}
      - {task: tools}
      - {task: ping}
  plan-pipeline:
    cmds:
      - {task: clock}
      - {task: tools}
  clock:
    cmds:
      - python -c 'import time; print(int(time.time()))'
  tools:
    desc: Every tool the proton image promises, by version
    cmds:
      - python --version
      - proton-drive version | head -1
      - age --version
      - python -c 'import boto3, requests; print(boto3.__version__, requests.__version__)'
      - ruff --version
      - pytest --version
```

`examples/proton/.taskrc.yml` and `examples/proton/op.env`: the same two files as the rsync example.

- [x] **Step 4: Render and accept both examples**

Run:

```sh
cd ~/Git/katoptra/lib/examples/rsync && task render-update && cat render.txt
cd ~/Git/katoptra/lib/examples/proton && task render-update && cat render.txt
```

Expected: each `render.txt` lists every command of `pipeline` as `task: [verb] command` lines with `/work/.run` paths, and no line from `image` or `run` themselves. The rsync one names `rsync --list-only rsync://rsync.example.org/pub/`.

- [x] **Step 5: Run the tools verb for real in each image**

Run:

```sh
cd ~/Git/katoptra/lib/examples/rsync && task run -- task tools
cd ~/Git/katoptra/lib/examples/proton && task run -- task tools
```

Expected: version lines from every tool; exit 0. This is the image's runtime check and the `run` verb's plumbing check in one.

- [x] **Step 6: Prove check catches a change**

Run: `cd ~/Git/katoptra/lib/examples/rsync && sed -i '' 's|rsync.example.org|changed.example.org|' Taskfile.yml && task check; git checkout Taskfile.yml`
Expected: `task check` exits nonzero with a unified diff whose changed line is the `list` command.

- [x] **Step 7: Prove the trust rule and the offline rule**

Run: `cd ~/Git/katoptra/lib/examples/rsync && task run -- sh -c 'echo $TASK_REMOTE_OFFLINE'`
Expected: `1`.

- [x] **Step 8: Commit**

```sh
git add toolbox.yml examples/
git commit -m "feat(toolbox): the shared verbs, with an example consumer per image"
```

---

### Task 5: The composite action

**Files:**
- Create: `.github/actions/toolbox/action.yml`

**Interfaces:**
- Consumes: `toolchain.lock.toml` at `${{ github.action_path }}/../../../toolchain.lock.toml`, which is where GitHub checks the action's repository out.
- Produces: `task` and `op` on the runner PATH at the lock's versions. Used by Tasks 6 and 7.

- [x] **Step 1: Write the action**

```yaml
name: toolbox
description: Install go-task and the 1Password CLI at the versions in katoptra/lib's toolchain.lock.toml
runs:
  using: composite
  steps:
    - shell: bash
      env:
        LOCK: ${{ github.action_path }}/../../../toolchain.lock.toml
      run: |
        set -eu
        lock() { python3 -c 'import functools,sys,tomllib; x=tomllib.load(open(sys.argv[2],"rb")); print(functools.reduce(lambda d,k: d[k], sys.argv[1].split("."), x))' "$1" "$LOCK"; }
        arch="$(dpkg --print-architecture)"
        curl -fsSL "$(lock task.base_url)/$(lock task.linux_${arch}.archive)" -o /tmp/task.tgz
        echo "$(lock task.linux_${arch}.sha256)  /tmp/task.tgz" | sha256sum -c -
        sudo tar -xzf /tmp/task.tgz -C /usr/local/bin task
        curl -fsSL "$(lock op.base_url)/$(lock op.linux_${arch}.archive)" -o /tmp/op.zip
        echo "$(lock op.linux_${arch}.sha256)  /tmp/op.zip" | sha256sum -c -
        sudo unzip -q -o /tmp/op.zip op -d /usr/local/bin
        task --version && op --version
```

- [x] **Step 2: Verify the lock path logic locally**

Run: `cd ~/Git/katoptra/lib && LOCK=.github/actions/toolbox/../../../toolchain.lock.toml python3 -c 'import os,tomllib; print(tomllib.load(open(os.environ["LOCK"],"rb"))["task"]["version"])'`
Expected: `3.53.1`.

- [x] **Step 3: Commit**

```sh
git add .github/actions/toolbox/action.yml
git commit -m "feat(action): install task and op at the lock's versions"
```

---

### Task 6: The reusable sync and check workflows

**Files:**
- Create: `.github/workflows/sync.yml`, `.github/workflows/check.yml`

**Interfaces:**
- Consumes: the toolbox action (Task 5) at the same ref as the workflow, via `uses: katoptra/lib/.github/actions/toolbox@v1`. Inside this repository's own CI the path form `./.github/actions/toolbox` is used instead.
- Produces: `workflow_call` workflows a mirror calls with `uses: katoptra/lib/.github/workflows/sync.yml@v1`.

- [x] **Step 1: Write `sync.yml`**

```yaml
# Reusable: one mirror, one run. The caller is a ten-line workflow_dispatch that
# jshvn/dispatch triggers; it passes `vars` through and inherits its repository secret.
name: sync
on:
  workflow_call:
    inputs:
      vars:
        description: 'KEY=value pairs appended to task sync, e.g. "SEED=true MAX_BATCHES=8"'
        type: string
        default: ''
      timeout-minutes:
        type: number
        default: 355
    secrets:
      OP_SERVICE_ACCOUNT_TOKEN:
        required: false
permissions:
  contents: read
  actions: write   # chain: gh workflow run
jobs:
  sync:
    runs-on: ubuntu-latest
    timeout-minutes: ${{ inputs.timeout-minutes }}
    env:
      OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: katoptra/lib/.github/actions/toolbox@v1
      - run: df -h . && task image
      - run: task sync ${{ inputs.vars }}
      - name: Ping /fail unless the job succeeded
        if: failure()
        run: task op -- task ping-fail
      - name: Chain the next run
        if: success()
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          if [ -f .run/chain ]; then
            gh workflow run sync.yml --ref "$GITHUB_REF_NAME"
            echo "chained: next run queued" >> "$GITHUB_STEP_SUMMARY"
          fi
```

- [x] **Step 2: Write `check.yml`**

```yaml
# Reusable: render the mirror's pipeline inside its image and diff it against render.txt.
name: check
on:
  workflow_call: {}
permissions:
  contents: read
jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: katoptra/lib/.github/actions/toolbox@v1
      - run: task check
```

- [x] **Step 3: Verify both parse**

Run: `for f in .github/workflows/sync.yml .github/workflows/check.yml; do ruby -ryaml -e 'YAML.load_file(ARGV[0]); puts "ok #{ARGV[0]}"' "$f"; done`
Expected: `ok` for both. macOS ships ruby; GitHub validates the schema on push.

- [x] **Step 4: Commit**

```sh
git add .github/workflows/sync.yml .github/workflows/check.yml
git commit -m "feat(workflows): reusable sync and check for every mirror"
```

---

### Task 7: This repository's CI and release

**Files:**
- Create: `.github/workflows/ci.yml`, `.github/workflows/release.yml`

**Interfaces:**
- Consumes: the examples (Task 4), the Dockerfiles (Task 3), the action (Task 5) by path.
- Produces: images at `ghcr.io/katoptra/toolbox:<variant>-<tag>` and `<variant>-v<major>`, and a moved `v<major>` git tag, on every `v*.*.*` tag push.

- [x] **Step 1: Write `ci.yml`**

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  images:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    strategy:
      matrix:
        variant: [rsync, proton]
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: ./.github/actions/toolbox
      - name: Build the image the example names
        run: docker build -t ghcr.io/katoptra/toolbox:${{ matrix.variant }}-dev -f docker/${{ matrix.variant }}.Dockerfile .
      - name: The example's tools resolve inside the image
        working-directory: examples/${{ matrix.variant }}
        run: task run -- task tools
      - name: The example's render matches its render.txt
        working-directory: examples/${{ matrix.variant }}
        run: task check
```

- [x] **Step 2: Write `release.yml`**

```yaml
# On a semver tag: build each image for amd64 and arm64, push both tags, move the
# floating major tag. Mirrors pin v<major> in the include URL and the image name, so
# moving it is the rollout.
name: release
on:
  push:
    tags: ['v[0-9]+.[0-9]+.[0-9]+']
permissions:
  contents: write
  packages: write
jobs:
  images:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    strategy:
      matrix:
        variant: [rsync, proton]
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: docker/setup-qemu-action@1f40c72289eff860ee54a304f1438e3cff362e0a # v4.3.0
      - uses: docker/setup-buildx-action@37fe631027851001ddb9b187196cc803df7f5f0e # v4.3.0
      - uses: docker/login-action@dbcb813823bdd20940b903addbd779551569679f # v4.6.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Tags
        id: tags
        run: |
          tag="${GITHUB_REF_NAME}"; major="${tag%%.*}"
          echo "semver=ghcr.io/katoptra/toolbox:${{ matrix.variant }}-${tag}" >> "$GITHUB_OUTPUT"
          echo "major=ghcr.io/katoptra/toolbox:${{ matrix.variant }}-${major}" >> "$GITHUB_OUTPUT"
      - uses: docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a # v7.3.0
        with:
          context: .
          file: docker/${{ matrix.variant }}.Dockerfile
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ${{ steps.tags.outputs.semver }}
            ${{ steps.tags.outputs.major }}
  tag:
    needs: images
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Move the floating major tag
        run: |
          major="${GITHUB_REF_NAME%%.*}"
          git tag -f "$major" "$GITHUB_SHA"
          git push -f origin "refs/tags/$major"
```

The docker action SHAs above were resolved from each action's latest release tag on 2026-09-08 with `git ls-remote`. Dependabot keeps them current afterwards.

- [x] **Step 3: Commit**

```sh
git add .github/workflows/ci.yml .github/workflows/release.yml
git commit -m "ci: build and check the examples; release images and the major tag"
```

---

### Task 8: README, CONTRIBUTING, CLAUDE.md

**Files:**
- Modify: `README.md`
- Create: `CONTRIBUTING.md`, `CLAUDE.md`

**Interfaces:**
- Consumes: everything above.
- Produces: the documentation a mirror author reads to consume the library, in the org's README format (badges, How it works, Working on it, Want your own?, Pull requests are welcome, MIT line).

- [x] **Step 1: Write `README.md`**

```markdown
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

Beside it, a `.taskrc.yml` so nothing prompts and the include is fetched at most hourly:

```yaml
remote:
  trusted-hosts: [raw.githubusercontent.com]
  expiry: 1h
```

An `op.env` of `op://` references, if the secrets live in 1Password. And the two
caller workflows:

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
```

- [x] **Step 2: Write `CONTRIBUTING.md`**

```markdown
# Contributing

The [organization's rules](https://github.com/katoptra/.github/blob/main/CONTRIBUTING.md)
apply. This repository adds three.

- **No `vars:` default for anything a mirror owns.** A default declared in this file's
  `vars:` block shadows the mirror's root value. Defaults go inline in the command as
  `{{.X | default N}}`.
- **The verb names in `toolbox.yml` are reserved.** Host-side and in-container verbs
  share one namespace when flattened into a mirror. Renaming one is a major version.
- **A change to a verb is a change to both `render.txt` files.** Run `task render-update`
  in each example and commit the result with the change. The pull request diff is the
  review.

## Checking a change

```sh
cd examples/rsync  && task image-build && task run -- task tools && task check
cd examples/proton && task image-build && task run -- task tools && task check
```

CI runs the same three commands per image on every pull request.
```

- [x] **Step 3: Write `CLAUDE.md`**

```markdown
# lib

The toolbox every katoptra mirror includes by URL. Read `README.md` for the contract and
`docs/superpowers/specs/2026-09-08-toolbox-library-design.md` for the decisions.

## Constraints

- `toolbox.yml` declares no `vars:` default for anything a mirror owns. Defaults go
  inline. This is a go-task fact, verified: a library `vars:` default shadows the
  mirror's root value.
- Verb names are reserved across host and container. `plan` is the host-side read-only
  run; an engine's batch planner is `split`.
- Every tool in an image comes from `toolchain.lock.toml` with a checksum. The AWS CLI
  zip is the marked exception.
- Images set `TASK_REMOTE_OFFLINE=1`. Inside a run the include resolves from the
  mirror's `.task/remote` cache, bind-mounted with the repo, never from the network.
- Actions pinned to a full SHA with the version in a trailing comment.

## Verifying a change

```sh
cd examples/rsync  && task image-build && task run -- task tools && task check
cd examples/proton && task image-build && task run -- task tools && task check
```

A verb change updates both `render.txt` files via `task render-update`.
```

- [x] **Step 4: Commit**

```sh
git add README.md CONTRIBUTING.md CLAUDE.md
git commit -m "docs: the contract, how to work on it, how to release"
```

---

### Task 9: Hand-off

Not automated. After the plan is executed locally:

1. `gh repo create katoptra/lib --public --source ~/Git/katoptra/lib --push` with the description "The toolbox every katoptra mirror includes: verbs, images, workflows".
2. Confirm the org allows workflows to write packages (Settings, Packages) so `release.yml` can push to GHCR.
3. Push, watch `ci` pass, then `git tag v1.0.0 && git push origin v1.0.0` and watch `release` publish `ghcr.io/katoptra/toolbox:rsync-v1` and `proton-v1`, and move `v1`.
4. Make the two packages public in the org's package settings, or runs cannot pull them.
5. Then one migration plan per mirror, tlnet first because it is smallest.
