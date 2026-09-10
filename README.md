# My macOS Setup

[![Continuous integration](https://github.com/arunzone/my-macos-setup/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/arunzone/my-macos-setup/actions/workflows/main.yml)

## Building

### Including Bootstrapping

```
./prepare.sh && ./build.sh
```

Above sets up `brew`, `python`, `pipx` and `ansible` before running the `playbook.yml`.

### Ansible Only

```
./build.sh
```

Anything after `./build.sh` is passed to `ansible-playbook`, e.g. `./build.sh --tags cli-tools`.

Roles tagged `appstore` need an Apple ID signed in to the App Store; skip them with `--skip-tags appstore`.

iTerm2 is installed from iterm2.com and pinned to `iterm2_version` in `roles/iterm2/defaults/main.yml` with automatic update checks off, because 3.7 makes herdr freeze for seconds on every focus switch ([herdr#3266](https://github.com/herdrdev/herdr/issues/3266)). Bump the version and checksum once herdr ships the fix.

Hardware-specific roles are opt-in: `./build.sh --tags wacom` installs the last Wacom driver that supports the Intuos Pro PTH-651 (remove any newer driver with the Wacom Tablet Utility first).
On macOS 26 that Wacom driver's pen support is broken; `./build.sh --tags opentabletdriver` installs OpenTabletDriver instead, then grant it Accessibility and Input Monitoring when macOS asks.

Every role carries a tag of its own name, so a run that failed part-way can resume from that role with `--tags`, listing the roles from the failed one onward in playbook order. Do not use `--start-at-task`; it skips the pre-tasks that later roles depend on.

## Testing

Three layers, each a separate job in `.github/workflows/main.yml`:

| Layer | Where | Catches |
|---|---|---|
| `lint` | Ubuntu runner | ansible-lint findings, syntax errors |
| `existing-machine` | GitHub-hosted macOS runner | upgrade-path regressions on an already provisioned Mac |
| `fresh-machine` | self-hosted Apple Silicon runner, nightly and on manual dispatch | new-machine breakage: missing dependencies, ordering, first-run prompts |

### Fresh machine locally

`test/fresh-machine.sh` boots a vanilla macOS VM with [Tart](https://tart.run), copies the tracked files in, runs `prepare.sh` and `build.sh` over SSH, then runs the playbook a second time and lists any task that still reports a change.

```
test/fresh-machine.sh
```

Requires Apple Silicon, `tart` (installed by the `infrastructure-as-code` role), roughly 25 GB for the image and up to `VM_DISK_GB` for the VM.

| Variable | Default | Purpose |
|---|---|---|
| `TART_IMAGE` | `ghcr.io/cirruslabs/macos-tahoe-vanilla:latest` | base image |
| `VM_NAME` | `my-macos-setup-test` | VM name, deleted on exit |
| `VM_CPU` / `VM_MEMORY_MB` / `VM_DISK_GB` | `4` / `8192` / `80` | VM resources |
| `SKIP_TAGS` | `appstore` | roles that cannot run unattended |
| `STRICT_IDEMPOTENCY` | `0` | set to `1` to fail when the second run changes anything |
| `KEEP_VM` | `0` | set to `1` to leave the VM running for inspection |

### CI host

Register this Mac as the self-hosted runner once. The role is opt-in and never runs as part of a normal build:

```
./build.sh --tags github-runner
```

It downloads the latest runner, registers it against the repository detected by `gh`, labels it `tart`, and installs it as a launch agent. Override `github_runner_repo` or `github_runner_labels` with `-e` if needed.
