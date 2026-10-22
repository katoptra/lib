# Contributing

The [rules of the organization](https://github.com/katoptra/.github/blob/main/CONTRIBUTING.md)
are applicable to this repository. This repository adds three rules:

- **Do not put a `vars:` default in `toolbox.yml` or in an engine for a var that a mirror
  sets.** If a `vars:` block has a default, the run uses that default, not the root value
  of the mirror. Put each default inline in the command: `{{.X | default N}}`. If two
  commands of a verb read the var, put the default in a task var with a different name
  (`BATCH_SIZE: '{{.BATCH_GB | default 4}}'` in `split`). `IMAGE` is different: each
  engine sets `IMAGE: '{{.IMAGE | default "..."}}'` in `vars:`. Thus, if the toolbox entry
  of `includes:` gives `IMAGE`, the run uses that value.
- **Do not change the name of a verb in `toolbox.yml` or in an engine.** A mirror includes
  these files with `flatten: true`. Then the host verbs and the verbs in the container use
  one namespace.
  A new name for one of these verbs is a new major version.
- **A change to a verb that a pipeline runs is a change to a `render.txt`.** `render` makes
  a dry run of the `pipeline` of each example. A change to a verb changes these files:
  - A toolbox verb: the `render.txt` of each example that runs it
  - A verb of the rsync engine: `examples/rsync/render.txt`
  - A verb of the proton engine: `examples/proton/render.txt`.

  A host verb, for example `run` or `session-seal`, is not in a render. Run
  `task render-update` in each example. Commit the result with the change. The diff of the
  pull request is the review. A verb with `silent: true` renders no command. Thus, for
  `report` and `report-engine`, the review of their rows is in the diff of the file that
  has the verb.

## Checking a change

```sh
cd examples/rsync  && task image-build && task run -- task tools && task check && task run -- task offline
cd examples/proton && task image-build && task run -- task tools && task check && task run -- task offline
sh .github/validate-vars.sh --check && sh .github/chain-file.sh --check && sh docker/gpg-gate-check.sh
awk 'length > 110 { print FILENAME ":" FNR ": " length " characters"; bad = 1 } END { exit bad }' engines/rsync.yml
```

CI does these steps for each image, on each pull request and on each push to `main`:

1. It builds the image.
2. It runs `task run -- task tools`.
3. It runs `task check`.
4. It runs `task run -- task offline`.

It also runs the three guards one time, in the job of the `rsync` image. That job also
makes sure that no line of `engines/rsync.yml` is longer than 110 characters. To make a
line shorter, use the methods that the file uses:

- A `desc:` becomes a folded block (`desc: >-`). YAML joins its lines with spaces, and the
  text does not change.
- A shell line in a `>-` block breaks at a space. A line with more spaces than the lines
  around it keeps its newline. Thus, do not break such a line inside a quoted string.
- A long awk line breaks after `;` or `{`, before `else`, or with a backslash at the end of
  the line. A string can become two strings, one after the other.
- An `echo` gets several arguments. It puts one space between two arguments, and the
  output does not change.
