# lib

This repository is the toolbox that all katoptra mirrors include from a URL. `README.md` is
the manual. It has sections about the layers, the verbs, the engines, the secrets, the
storage, the images and the workflows. It also tells how a mirror uses these parts and how
a mirror changes them. This file gives the items that a change must not break. Each item is
a verified fact about go-task or a platform, and each fact cost a session to find.

Writing: obey ASD-STE100 and the rules in the
[Writing section of the org CONTRIBUTING](https://github.com/katoptra/.github/blob/main/CONTRIBUTING.md#writing).
Read that section before you write.

## Hazards

- Do not read a call var in a global var. Task renders a global var that reads a different
  var one time. It uses the values of the root and of the command line, and not a call
  var. Thus, `GPGCHECK` gets the fingerprint as an awk `-v` at each use, where the call var
  `TL_KEY` is available.
- A var with a different name that reads a tunable, for example `BATCHES_MAX` from
  `MAX_BATCHES`, also sees the command line (verified). Thus, write each default one time,
  inline.
- Do not put `dir:` on an engine verb. In a flattened include that task reads from a path,
  task adds each `dir:` to the directory of the include, also an absolute `dir:` (verified,
  3.53.1). Thus, `verify` starts each command with `cd {{.STAGING}}`.
- Use only the keys `trusted-hosts` and `cache-expiry` in `.taskrc.yml`. Task ignores a key
  that it does not know, and it shows no warning. Then it downloads the remote Taskfiles
  again each time that it runs.
- Each tool in an image is from `toolchain.lock.toml`. `docker/lock.py` reads the lock for
  the Dockerfiles and for the toolbox action, and the build examines each tool before it
  uses it. Most tools have a recorded sha256. The AWS CLI zip has no sha256, because
  upstream publishes only a detached PGP signature for it. Thus, the fetch stage verifies
  that signature with `docker/aws-cli.pub`, and it must find the fingerprint that the lock
  pins. It uses the same GOODSIG and VALIDSIG awk check as the engine uses for TeX Live.
- The images set `TASK_REMOTE_OFFLINE=1`. In a run, task gets the include from the
  `.task/remote` cache of the mirror, which goes into the container with the repository (a
  bind mount). Task does not get the include from the network.
- `run` and `render` put the git top level of the repository at `/work` (a bind mount).
  They set the working directory to the subdirectory of the Taskfile. For a mirror, the two
  directories are the same. For the examples in this repository, this lets task find
  `../../toolbox.yml`.
- `render` gets the dry run of task in the container, with `sh -c 'task ... 2>&1'`. Thus,
  the progress lines of the container runtime do not go into `render.txt`.
- In a `sh:` var, do not use `printf -- '-e %s'`. It prints dashes, because the built-in
  shell of task reads the `--` as the format. Use `printf '%s %s ' -e "$v"`.
- The built-in shell of task runs each command with `set -e`, and an assignment gets the
  exit of its command substitution: `x=$(cat missing)` stops the command (verified,
  3.53.1).
- The built-in shell of task keeps `set -e` in a subshell when `||` reads the status of
  that subshell. `( false; echo on ) || echo caught` prints only `caught` (verified,
  3.53.1), but bash and dash print `on`. For a guard that must operate in all these shells,
  make each step exit manually.
- The built-in shell of task has no `umask`. To make a file with the mode 0600, use
  `install -m 600 /dev/null "$f"`. Then write the file, as the `age` verb of the proton
  engine does.
- Each Proton CLI call goes through `pd`. After each call, with all exit codes, `pd`
  examines the session, and it writes the session back to the bucket if the refresh token
  changed. The token changes at each use. If a run keeps a changed token and does not write
  it back, Proton rejects the token of the next run. A new login is then necessary. For the
  same cause, two mirrors do not use one session.
- Pin each action to a full SHA, with the version in a comment at the end of the line. A
  mirror pins the two reusable workflows in this method. Each reusable workflow does a
  checkout of this repository at the commit of the workflow (`github.job_workflow_sha`) for
  the toolbox action and the lock. Thus, the pin of the workflow is the only pin. The
  include and the image use the `v2` tag, and the tag moves. A move of that tag sends a
  release to all mirrors.
- Give `-r` to each `xargs` if a filter can make its input empty. GNU `xargs` runs its
  command one time on empty input. A guard on the file that a pipe reads is not a guard on
  the input of `xargs`. For example, the `SLASH` awk of `pages` removes the root, which has
  no key without a slash. Thus, if the only changed directory of a run is the root, that
  awk sends no line to `xargs`.
- A `>-` folded block keeps a newline if a line that continues the previous line starts
  with more spaces than the lines around it. The awk programs of `pages` use this. End a
  shell line that must continue with a backslash. `task check` shows how the block renders.
- On a macOS disk, two directory names that are different only in uppercase and lowercase
  letters are one directory. Thus, the pages that a laptop writes from a listing of
  upstream are not complete if upstream has two such directories. For example, CTAN has
  `obsolete/support/TeXshell/` and `texshell/`. The runner uses ext4, and it writes the two
  directories.
- Put a YAML scalar that contains a literal `: ` between single quotation marks (`'`).
  Write each `'` in it two times. Without the quotation marks, YAML reads the `: ` as a
  key, also in `sed` and `awk` text in the line.
- In `verify`, make each read or write in `.run/tl` operate only on a batch with a `TL`
  path. If not, a redirect into a directory that no step made can stop a live run. The
  status gate of `prepare` reads all of `changed.txt`, not the batch. Thus, `prepare` runs
  on almost all runs, and only the decision-batch branch of `verify` reads the batch. But
  if the delta of a run has no `TL` path, `prepare` does not run, and `.run/tl` is not
  there. This condition does not occur in the fixtures or in CI.
- Do not make a task internal if a host verb starts it by name in the image. go-task does
  not start an internal task from the command line. For example, `empty-trash` starts
  `empty-trash-pipeline` through `task op`. Thus, `empty-trash-pipeline` is not internal.
- go-task reads the global vars of the includes of one Taskfile in a random sequence at
  each run (verified, 3.53.1 and 3.54.0). Thus, an engine global var that reads a toolbox
  var (`RUN`) can see that var with no value in the tasks of a mirror. For this cause,
  `SESSION` and `UPLOAD` in `proton.yml` give `ROOT_DIR/.run` in full. Also, if a mirror
  sets `IMAGE` in its root vars, a run can use the default of the engine. If the include
  sets `IMAGE`, the run always uses the value on the include.

## Verifying a change

```sh
cd examples/rsync  && task image-build && task run -- task tools && task check && task run -- task offline
cd examples/proton && task image-build && task run -- task tools && task check && task run -- task offline
sh .github/validate-vars.sh --check && sh .github/chain-file.sh --check && sh docker/gpg-gate-check.sh
```

After a change to a verb, run `task render-update` to update the `render.txt` files.
`offline` is the check of each engine.

The rsync check runs on `examples/rsync/fixtures/`:

- The list diff on `run-root` and `run-empty`
- The exit codes of `retry`
- `pages` on `run-pages`. Its `want/` is the page set of ctan, and the result must agree
  with it byte for byte.
- The page read-back of `smoke` on `run-smoke`
- `prepare` and `verify` on `tree/`, a signed subtree. A test key, which the example pins,
  signs its tlpdb.
- `label`, `label-trees` and `fresh`, on files that the check writes. The check examines
  their names and their first bytes. Thus, if a change to the `mime.types` of the image
  changes a label, the check stops there, before an upload.

Make the tree again, with a new key, only to change its shape. There is no copy of the
private half of the test key.

The proton check runs `confirm` on `examples/proton/fixtures/`: an upload summary that it
accepts and one that it rejects. It also encrypts and decrypts a file with the `age` verb
and a test identity. Then it does a dry run of `empty-trash-pipeline` by name.

`task check` cannot see a change to `README.md`. For that change, the review is the check.
Seven repositories link to headings of `README.md`: ctan, dropbox, github, gnu, nongnu, site
and tlnet. Do not change the text of these headings, because the links from these
repositories cannot then find them:

- `#secrets`
- `#storage`
- `#the-toolbox`
- `#the-rsync-engine`
- `#when-a-run-fails`
- `#content-types`
- `#the-proton-engine`
- `#the-session`
- `#r2-specifics`
- `#monitoring`
- `#rules-a-mirror-keeps`.
