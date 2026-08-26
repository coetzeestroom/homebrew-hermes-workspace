# AGENTS.md — homebrew-hermes-workspace

## What this repo is

A **Homebrew tap** — a single-formula repository that installs the `hermes-workspace` package (a native web workspace for Hermes Agent) via `brew install outsourc-e/hermes-workspace/hermes-workspace`.

The actual source code is **not here**. The formula fetches a tarball from `https://github.com/outsourc-e/hermes-workspace/releases`. This repo only contains the formula definition and CI config.

## Directory structure

```
Formula/hermes-workspace.rb   # The only formula — single .rb file
.github/
  dependabot.yml              # Weekly GitHub Actions dependency bumps
  workflows/
    tests.yml                 # brew test-bot CI (macOS + Ubuntu)
    autobump.yml              # Daily scheduled bump of formula version
```

## Key commands

| Command | Purpose |
|---|---|
| `brew test-bot --only-tap-syntax` | Validate formula syntax |
| `brew test-bot --only-formulae` | Full formula test (install, test, uninstall) |
| `brew style` | Lint the formula Ruby style |
| `brew audit --new-formula Formula/hermes-workspace.rb` | Audit formula compliance |
| `brew bump --no-fork --open-pr --formulae --tap="$TAP"` | Bump formula to latest upstream version |

## Formula anatomy

- **Class**: `HermesWorkspace` inherits `Formula`
- **Dependencies**: `node@22`, `pnpm`
- **Build steps**: `pnpm install --frozen-lockfile` then `pnpm build`
- **Install**: copies `dist/`, `electron/`, `server-entry.js`, `package.json`, `pnpm-lock.yaml` into `libexec`
- **Wrappers**: `hermes-workspace` (production via `node server-entry.js`) and `hermes-workspace-dev` (via `pnpm dev`)
- **Service**: runs as a `brew services` daemon with keep-alive, logs to `/var/log/hermes-workspace/`
- **Env vars**: `HERMES_HOME` (default: `/var/lib/hermes-workspace`), `HERMES_WORKSPACE_PORT` (default: 3000)
- **Post-install**: creates `var/lib/hermes-workspace` and `var/log/hermes-workspace` directories

## CI behavior

- **tests.yml**: Runs on push to `main` and PRs. Matrix: `macos-26` (native) + `ubuntu-latest` (Homebrew Docker container). Runs cleanup, setup, tap syntax check, then formula install/test on PRs only. Uploads bottles as artifacts.
- **autobump.yml**: Runs daily at 14:10 UTC on `main`. Uses `brew bump` to auto-create PRs when upstream releases new versions.
- **dependabot.yml**: Weekly updates for GitHub Actions.

## Gotchas

- **Source code lives elsewhere**: Don't look for source files here — the actual app is in `outsourc-e/hermes-workspace` on GitHub. Changes to this repo are formula-level only.
- **Version bumps**: When upstream releases a new version, update both the `url` version tag AND the `sha256` of the tarball. The autobump workflow can do this automatically.
- **`brew test`**: The test block only checks that `hermes-workspace --help` runs and outputs `HERMES_HOME`. It does not start the actual server.
- **`head` branch**: Set to `main`, allowing `brew install --HEAD` for bleeding-edge installs from the main branch tarball.
- **CI shell**: All CI steps use `bash -xeuo pipefail` — strict mode is enforced.
- **Perlmisssions**: Autobump needs `contents: write` + `pull-requests: write`; test-bot only needs read permissions.
- **Container mode**: Ubuntu CI runs inside `ghcr.io/homebrew/brew:main` with `--privileged` (required for `brew test-bot`).

## Conventions

- Single formula per tap (this repo will never have more than one formula)
- Follows standard Homebrew Ruby DSL — no external gems, no custom Ruby logic
- Uses `libexec` for installed files, `bin/` for wrapper scripts
- Wrapper scripts use `exec` to replace the shell process
- `var/` paths for persistent data and logs (Homebrew convention for services)