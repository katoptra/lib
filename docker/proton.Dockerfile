# syntax=docker/dockerfile:1.7
# The proton toolbox: Python plus the Proton Drive CLI, age and git, for the mirrors whose
# sink is Proton Drive, whether their engine is engines/proton.yml or a Python package of
# their own. The repo is bind-mounted at /work; PYTHONPATH finds its src/. Base pinned by
# digest; every tool from toolchain.lock.toml at the build context, git and curl from apt.
FROM python:3.13.15-slim-bookworm@sha256:ed86c82274b3c69b52fb5820f358f0bd7df0b603332063cb5c6e32bd220c3e6e AS fetch

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
COPY toolchain.lock.toml /etc/toolchain.lock.toml
COPY docker/lock.py /usr/local/bin/lock

# Architecture from the image itself: BuildKit sets TARGETARCH, Apple container does
# not, and a defaulted arg would install amd64 binaries into an arm64 image.
RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64|arm64) ;; *) echo "unsupported architecture: $arch" >&2; exit 1 ;; esac; \
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

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git \
 && rm -rf /var/lib/apt/lists/*
COPY --from=fetch /usr/local/bin/proton-drive /usr/local/bin/age /usr/local/bin/age-keygen /usr/local/bin/task /usr/local/bin/
COPY toolchain.lock.toml /etc/toolchain.lock.toml
COPY docker/s3.py /usr/local/bin/s3

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
assert first(["git", "--version"]).startswith("git version 2.")
assert subprocess.run(["s3"], capture_output=True).returncode == 2   # usage; boto3 imports
PY

# Inside a run there is no network for Taskfiles: the mirror's .task/remote cache rides
# in with the bind mount. R2 has one region and rejects the SDK's default checksum
# headers; both values are literals, not secrets.
ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/work/src \
    TASK_REMOTE_OFFLINE=1 \
    AWS_REGION=auto \
    AWS_REQUEST_CHECKSUM_CALCULATION=when_required \
    AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
WORKDIR /work
