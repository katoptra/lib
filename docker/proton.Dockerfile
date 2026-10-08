# syntax=docker/dockerfile:1.7
# The proton toolbox: Python, the Proton Drive CLI, age and git. It is for the mirrors
# that send their bytes to Proton Drive. The engine of such a mirror can be
# engines/proton.yml, or a Python package in the mirror. A bind mount puts the repo at
# /work, and PYTHONPATH finds its src/. This file pins the base image with its digest.
# toolchain.lock.toml at the build context supplies each tool, but apt supplies git and
# curl.
FROM python:3.13.15-slim-bookworm@sha256:ed86c82274b3c69b52fb5820f358f0bd7df0b603332063cb5c6e32bd220c3e6e AS fetch

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
COPY toolchain.lock.toml /etc/toolchain.lock.toml
COPY docker/lock.py /usr/local/bin/lock

# The build gets the architecture from the image. BuildKit sets TARGETARCH, but Apple
# container does not. An arg with a default can install amd64 binaries into an arm64
# image.
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

# ponytail: botocore has 432 service models, and s3 uses one. Thus, this step keeps only
# s3, sts and the *.json files at the data root. Ceiling: a boto3 client for a different
# service stops with an error when it cannot find its model. For a different service, add
# the service to the keep list. After this step installs the pinned packages, it removes
# pip, because a runtime image must not install packages.
RUN python - <<'PY'
import pathlib, shutil, subprocess, tomllib
lock = tomllib.load(open("/etc/toolchain.lock.toml", "rb"))
pins = [f"{k}=={v}" for t in ("packages", "test_packages") for k, v in lock["python"][t].items()]
subprocess.check_call(["pip", "install", "--no-cache-dir", "--no-deps", *pins])
subprocess.check_call(["pip", "uninstall", "-y", "pip"])
import botocore
for p in (pathlib.Path(botocore.__file__).parent / "data").iterdir():
    if p.is_dir() and p.name not in ("s3", "sts"):
        shutil.rmtree(p)
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
# s3 exits 2 when it prints how to use it. Thus, boto3 imports.
assert subprocess.run(["s3"], capture_output=True).returncode == 2
assert subprocess.run(["python", "-m", "pip"], capture_output=True).returncode == 1
import boto3; boto3.client("s3", region_name="auto", aws_access_key_id="x", aws_secret_access_key="x")
PY

# In a run, there is no network for Taskfiles. The bind mount supplies the .task/remote
# cache of the mirror. R2 has one region, and it rejects the default checksum headers of
# the SDK. These values are literals, not secrets. The image has no keyring. Thus, the
# Proton CLI keeps its session as files.
ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/work/src \
    TASK_REMOTE_OFFLINE=1 \
    AWS_REGION=auto \
    AWS_REQUEST_CHECKSUM_CALCULATION=when_required \
    AWS_RESPONSE_CHECKSUM_VALIDATION=when_required \
    PROTON_DRIVE_CREDENTIALS_STORE=unsafe_file
WORKDIR /work
