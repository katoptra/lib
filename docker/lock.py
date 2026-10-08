#!/usr/bin/env python3
"""lock KEY [FILE]: one value of toolchain.lock.toml. KEY is dotted (task.linux_arm64.sha256).

The Dockerfiles and the toolbox action use this one script to read the lock. The default
FILE is the path where the images keep the lock.
"""

import functools
import sys
import tomllib

path = sys.argv[2] if len(sys.argv) > 2 else "/etc/toolchain.lock.toml"
with open(path, "rb") as f:
    lock = tomllib.load(f)
print(functools.reduce(lambda d, k: d[k], sys.argv[1].split("."), lock))
