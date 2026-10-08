# Contributing

The [rules of the organization](https://github.com/katoptra/.github/blob/main/CONTRIBUTING.md)
are applicable to this repository. This repository adds three rules:

- **Do not put a `vars:` default in `toolbox.yml` or in an engine for a var that a mirror
  sets.** If a `vars:` block has a default, the run uses that default, not the root value
  of the mirror. Put each default inline in the command, as `{{.X | default N}}`. `IMAGE`
  is different: each engine sets `IMAGE: '{{.IMAGE | default "..."}}'` in `vars:`. Thus,
  if the toolbox include gives `IMAGE`, the run uses that value.
- **Do not change the name of a verb in `toolbox.yml` or in an engine.** When a mirror
  flattens the includes, the host verbs and the verbs in the container use one namespace.
  A new name for one of these verbs is a new major version.
- **A change to a verb that a pipeline runs is a change to a `render.txt`.** `render` makes
  a dry run of the `pipeline` of each example. A change to a verb changes these files:
  - A toolbox verb: the `render.txt` of each example that runs it
  - A verb of the rsync engine: `examples/rsync/render.txt`
  - A verb of the proton engine: `examples/proton/render.txt`.

  A host verb, for example `run` or `session-seal`, is not in a render. Run
  `task render-update` in each example, and commit the result with the change. The diff of
  the pull request is the review. A verb with `silent: true` renders no command. Thus, for
  `report` and `report-engine`, the review of their rows is in the diff of the file that
  has the verb.

## Checking a change

```sh
cd examples/rsync  && task image-build && task run -- task tools && task check && task run -- task offline
cd examples/proton && task image-build && task run -- task tools && task check && task run -- task offline
sh .github/validate-vars.sh --check && sh .github/chain-file.sh --check && sh docker/gpg-gate-check.sh
```

CI does the same steps for each image, on each pull request and on each push to `main`. It
builds the image, and then it runs `task run -- task tools`, `task check` and
`task run -- task offline`. It also runs the three guards one time, in the job of the
`rsync` image.
