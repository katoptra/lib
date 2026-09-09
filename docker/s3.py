#!/usr/bin/env python3
"""s3 get KEY FILE | s3 put FILE KEY: one object of the bucket MIRROR_R2_BUCKET names.

The proton image's S3 client, for the mirrors whose engine keeps a Proton session in the
bucket. Credentials and the endpoint come from the environment as boto3 reads them:
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT_URL_S3. `get` exits 3 when the
key is absent, so a caller can tell a missing object from a failed read. A failure prints
its class alone: the message may carry the endpoint, and the logs are public.
"""

import os
import sys

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

MISSING = {"404", "NoSuchKey"}


def main(argv: list[str]) -> int:
    if len(argv) != 4 or argv[1] not in {"get", "put"}:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    names = ("MIRROR_R2_BUCKET", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_ENDPOINT_URL_S3")
    unset = [n for n in names if not os.environ.get(n)]
    if unset:
        print(f"s3: unset in the environment: {' '.join(unset)}", file=sys.stderr)
        return 2
    bucket = os.environ["MIRROR_R2_BUCKET"]
    client = boto3.client("s3", config=Config(retries={"max_attempts": 5, "mode": "standard"}))
    try:
        if argv[1] == "get":
            client.download_file(bucket, argv[2], argv[3])
        else:
            client.upload_file(argv[2], bucket, argv[3])
    except ClientError as exc:
        if argv[1] == "get" and exc.response.get("Error", {}).get("Code") in MISSING:
            return 3
        print(f"s3 {argv[1]} failed: {type(exc).__name__}", file=sys.stderr)
        return 1
    except BotoCoreError as exc:
        print(f"s3 {argv[1]} failed: {type(exc).__name__}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
