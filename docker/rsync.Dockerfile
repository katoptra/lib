# syntax=docker/dockerfile:1.7
# The rsync toolbox: the image in which each rsync-to-R2 mirror operates, on a laptop and
# in Actions. A bind mount puts the repo at /work. This file pins the base image with its
# digest. toolchain.lock.toml at the root of the repo (the build context) supplies each
# tool.
FROM ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517 AS fetch

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip python3 gnupg gpgv \
 && rm -rf /var/lib/apt/lists/*
COPY toolchain.lock.toml /etc/toolchain.lock.toml
COPY docker/lock.py /usr/local/bin/lock
# The trust root for the AWS CLI zip. Upstream publishes the zip with a signature and no
# checksum. The key is ASCII-armored. Thus, a change of the key shows as a diff. The build
# does not keep this stage. Thus, gnupg and the key do not go into the toolbox image.
COPY docker/aws-cli.pub /etc/aws-cli.pub

# The build gets the architecture from the image. BuildKit sets TARGETARCH, but Apple
# container does not. An arg with a default can install amd64 binaries into an arm64
# image.
RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64) m=x86_64 ;; arm64) m=aarch64 ;; *) echo "unsupported architecture: $arch" >&2; exit 1 ;; esac; \
    curl -fsSL "$(lock task.base_url)/$(lock task.linux_${arch}.archive)" -o /tmp/task.tgz; \
    echo "$(lock task.linux_${arch}.sha256)  /tmp/task.tgz" | sha256sum -c -; \
    tar -xzf /tmp/task.tgz -C /tmp task; install -m 0755 /tmp/task /usr/local/bin/task; \
    url="$(lock awscli.url | sed "s/{arch}/$m/; s/{version}/$(lock awscli.version)/")"; \
    curl -fsSL "$url" -o /tmp/awscli.zip; \
    curl -fsSL "$url.sig" -o /tmp/awscli.zip.sig; \
    gpg --batch --dearmor -o /tmp/aws-cli.gpg /etc/aws-cli.pub; \
    gpgv --status-fd 1 --keyring /tmp/aws-cli.gpg /tmp/awscli.zip.sig /tmp/awscli.zip \
      | awk -v k="$(lock awscli.key_fingerprint)" '/^\[GNUPG:\] GOODSIG /{g=1} /^\[GNUPG:\] VALIDSIG / && $NF == k {v=1} END{exit !(g&&v)}'; \
    cd /tmp && unzip -q awscli.zip && ./aws/install; \
    d=/usr/local/aws-cli/v2/current/dist/awscli; \
    mkdir /tmp/keep; for k in s3 sts; do mv "$d/botocore/data/$k" /tmp/keep/; done; \
    mv "$d/botocore/data"/*.json /tmp/keep/; rm -rf "$d/botocore/data"; mv /tmp/keep "$d/botocore/data"; \
    rm -rf "$d/examples" "$d/topics" "$d/data/ac.index"

FROM ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517 AS toolbox

# perl contains shasum. The image has gpgv and not gnupg, because the engine examines
# signatures and does not make them. Each RUN removes its temporary files, because a
# layer keeps each file that its RUN does not remove.
RUN apt-get update && apt-get install -y --no-install-recommends \
      rsync gpgv xz-utils curl ca-certificates perl python3 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=fetch /usr/local/bin/task /usr/local/bin/task
COPY --from=fetch /usr/local/aws-cli /usr/local/aws-cli
RUN ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws
COPY toolchain.lock.toml /etc/toolchain.lock.toml
COPY docker/lock.py /usr/local/bin/lock

# ponytail: botocore has 432 service models, and the pipelines use one. Thus, the fetch
# stage keeps only s3, sts and the *.json files at the data root. Ceiling: an `aws`
# command for a different service stops with an error when it cannot find its model. For a
# different service, add the service to the keep list in the fetch stage.
RUN set -eu; \
    task --version | grep -q "$(lock task.version)"; \
    aws --version | grep -q "aws-cli/$(lock awscli.version)"; \
    aws s3 ls s3://x --no-sign-request --endpoint-url http://127.0.0.1:1 2>&1 | grep -qiE 'connect|endpoint|refused'; \
    rsync --version | head -1; gpgv --version | head -1; xz --version | head -1; shasum --version

# In a run, there is no network for Taskfiles. The bind mount supplies the .task/remote
# cache of the mirror. R2 has one region. The value is a literal, not a secret. Each
# aws command reads its multipart and retry configuration from /etc/aws.config.
COPY docker/aws.config /etc/aws.config
ENV TASK_REMOTE_OFFLINE=1 \
    AWS_REGION=auto \
    AWS_CONFIG_FILE=/etc/aws.config
WORKDIR /work
