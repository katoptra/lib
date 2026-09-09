#!/usr/bin/env python3
"""lock KEY [FILE]: one value of toolchain.lock.toml, KEY dotted (task.linux_arm64.sha256).

The one reader the Dockerfiles and the toolbox action share; FILE defaults to where the
images keep the lock.
"""

import functools
import sys
import tomllib

path = sys.argv[2] if len(sys.argv) > 2 else "/etc/toolchain.lock.toml"
with open(path, "rb") as f:
    lock = tomllib.load(f)
print(functools.reduce(lambda d, k: d[k], sys.argv[1].split("."), lock))
