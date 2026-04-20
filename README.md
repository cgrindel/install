# install

Bootstrap install scripts for Chuck's dev machines.

## Scripts

### `gw_install.sh` — Glydways Coder workspaces

Clones [`cgrindel/dev-machine`][dev-machine] into `~/code/cgrindel/dev-machine`
and hands off to its `gw_setup` script, which installs `zsh` (not present on
Coder images by default) and then runs the full `setup`.

#### Requirements

- Ubuntu-based Glydways Coder workspace.
- An SSH key on the workspace with access to `cgrindel`'s private GitHub
  repos (the standard Glydways Coder provisioning).

#### One-liner

Paste this into a fresh Coder workspace shell:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/cgrindel/install/HEAD/gw_install.sh)"
```

The script is re-run safe: if `~/code/cgrindel/dev-machine` already exists,
it will `git pull --ff-only` instead of re-cloning.

[dev-machine]: https://github.com/cgrindel/dev-machine
