# Contributing

The [organization's rules](https://github.com/katoptra/.github/blob/main/CONTRIBUTING.md)
apply. This repository adds three.

- **No `vars:` default for anything a mirror owns.** A default declared in this file's
  `vars:` block shadows the mirror's root value. Defaults go inline in the command as
  `{{.X | default N}}`.
- **The verb names in `toolbox.yml` are reserved.** Host-side and in-container verbs
  share one namespace when flattened into a mirror. Renaming one is a major version.
- **A change to a verb is a change to a `render.txt`.** A toolbox verb changes both
  examples' files, an engine verb changes `examples/rsync/render.txt`. Run `task
  render-update` in each example and commit the result with the change. The pull
  request diff is the review. A verb that is `silent` renders nothing, so `report`'s
  rows are reviewed in the diff of the file itself.

## Checking a change

```sh
cd examples/rsync  && task image-build && task run -- task tools && task check && task run -- task offline
cd examples/proton && task image-build && task run -- task tools && task check
```

CI runs the same commands per image on every pull request.
