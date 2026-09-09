# syntax=docker/dockerfile:1.7
# The rsync toolbox: what every rsync-to-R2 mirror runs inside, on a laptop and in
# Actions alike. The repo is bind-mounted at /work. Base pinned by digest; every tool
# comes from toolchain.lock.toml at the repo root, which is the build context.
FROM ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517 AS fetch

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip python3 \
 && rm -rf /var/lib/apt/lists/*
COPY toolchain.lock.toml /etc/toolchain.lock.toml
COPY docker/lock.py /usr/local/bin/lock

# Architecture from the image itself: BuildKit sets TARGETARCH, Apple container does
# not, and a defaulted arg would install amd64 binaries into an arm64 image.
RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64) m=x86_64 ;; arm64) m=aarch64 ;; *) echo "unsupported architecture: $arch" >&2; exit 1 ;; esac; \
    curl -fsSL "$(lock task.base_url)/$(lock task.linux_${arch}.archive)" -o /tmp/task.tgz; \
    echo "$(lock task.linux_${arch}.sha256)  /tmp/task.tgz" | sha256sum -c -; \
    tar -xzf /tmp/task.tgz -C /tmp task; install -m 0755 /tmp/task /usr/local/bin/task; \
    url="$(lock awscli.url | sed "s/{arch}/$m/; s/{version}/$(lock awscli.version)/")"; \
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
COPY docker/lock.py /usr/local/bin/lock

# ponytail: botocore ships 432 service models and the pipelines call one, so all but s3,
# sts and the data-root *.json stay behind. Ceiling: an `aws` call to any other service
# dies on a model lookup; add it to the keep list in the fetch stage.
RUN set -eu; \
    task --version | grep -q "$(lock task.version)"; \
    aws --version | grep -q "aws-cli/$(lock awscli.version)"; \
    aws s3 ls s3://x --no-sign-request --endpoint-url http://127.0.0.1:1 2>&1 | grep -qiE 'connect|endpoint|refused'; \
    rsync --version | head -1; gpgv --version | head -1; xz --version | head -1; shasum --version

# Inside a run there is no network for Taskfiles: the mirror's .task/remote cache rides
# in with the bind mount. R2 has one region; the value is a literal, not a secret.
ENV TASK_REMOTE_OFFLINE=1 \
    AWS_REGION=auto
WORKDIR /work
