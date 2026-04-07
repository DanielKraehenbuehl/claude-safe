# CLAUDE.md — Claude Code Safe

Project guidance for Claude Code working in this repository.

## What This Project Does

**Claude Code Safe** wraps [Claude Code](https://github.com/anthropics/claude-code) in a Docker container with:
- Network firewall (iptables/ipset) that whitelists specific domains only
- Automatic `--dangerously-skip-permissions` mode (safe because of container isolation)
- Transparent browser OAuth relay so authentication works without `docker exec`
- Multi-repository mounting and automatic git worktree detection
- SSH key and git credential forwarding

The two most important scripts are:
- [claude-safe.sh](claude-safe.sh) — host-side entry point; parses args, builds docker compose overrides, starts the container
- [start-claude.sh](start-claude.sh) — container entrypoint; syncs credentials, configures git, initialises firewall, launches Claude Code

## Architecture

```
Host
└── claude-safe.sh
    ├── Parses paths, detects worktrees, builds compose overrides
    ├── Starts OAuth relay listener (port 38714 ↔ Unix socket)
    └── docker compose run --rm claude-code
            └── start-claude.sh (inside container)
                ├── Syncs SSH keys, git config, Claude credentials
                ├── Configures GIT_ASKPASS for GitHub/Azure tokens
                ├── sudo init-firewall.sh  (iptables rules)
                └── claude --dangerously-skip-permissions
```

**Multi-repo mode**: when more than one path is given, a temp directory is created and each repo is bind-mounted as a named subdirectory under `/workspace`.

**Git worktree mode**: `claude-safe.sh` auto-detects `.git` files (worktree pointers), resolves the parent repo, and mounts it at `/git-parent-repo` so git commands work inside the container.

## Running Tests

```bash
bash tests/run_tests.sh
```

Uses [bats-core](https://github.com/bats-core/bats-core) — installed automatically if missing.

- **Unit tests** (`tests/unit/`) — pure shell logic (path normalization, Windows→WSL conversion)
- **Integration tests** (`tests/integration/`) — script behaviour with mocked docker and compose stubs

Run a single test file during development:
```bash
bats tests/integration/git_worktree.bats
```

Test helpers live in [tests/helpers/](tests/helpers/):
- `common.bash` — shared setup/teardown, script runner utilities
- `stubs.bash` — mock `docker`, `docker-compose`, and other CLI tools

## Key Conventions

- **Shell scripts use `bash`** with `set -euo pipefail`. Keep that discipline.
- **Line endings must be LF** — enforced by `.gitattributes`. Do not introduce CRLF.
- **No host-side root required** — the container acquires `NET_ADMIN`/`NET_RAW` capabilities; the host user needs only docker group membership.
- **Firewall domain list** lives in [init-firewall.sh](init-firewall.sh) in the DNS-resolved `for domain in \` loop. GitHub uses a separate live-fetch path via `api.github.com/meta`. Rebuild the image (`./setup.sh`) after changing DNS-resolved domains.
- **`.env` is gitignored** — never commit secrets. Use `.env.example` as the template.
- **Docker volumes** (`claude-code-config`, `claude-code-bashhistory`) persist authentication and shell history across container runs.
- **Testability pattern in `start-claude.sh`** — hardcoded paths are overridable via `_TEST_*` env vars (e.g. `_TEST_HOST_SSH`, `_TEST_TARGET_CLAUDE`). Add a `_TEST_*` override whenever introducing a new hardcoded path. The script also guards its runtime section with `if [ "${BATS_TESTING:-}" = "1" ]; then return 0; fi` so tests can source it to load only the function definitions.

## Common Tasks

### Add a whitelisted domain
Edit [init-firewall.sh](init-firewall.sh) — add the domain to the DNS-resolved `for domain in \` loop, then rebuild:
```bash
./setup.sh
```

> **Note:** GitHub IPs are handled separately. At container startup, `init-firewall.sh` fetches live CIDR ranges from `api.github.com/meta` (`.web`, `.api`, `.git`), validates them, aggregates with `aggregate -q`, and inserts them into the ipset. Do not add GitHub domains to the DNS loop.

### Rebuild the image from scratch
```bash
./setup.sh --force
```

### Run with multiple repos
```bash
./claude-safe.sh /path/to/repo-a /path/to/repo-b
```

### Run without browser auto-open
```bash
./claude-safe.sh --no-browser /path/to/project
```

### Override the compose file locally
Create `docker-compose.override.yml` (gitignored) — docker compose merges it automatically.

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | _(empty)_ | Skip web login; use API key instead |
| `CLAUDE_CODE_VERSION` | `latest` | Pin a specific Claude Code npm version |
| `TZ` | `America/Los_Angeles` | Container timezone |
| `PROJECT_DIR` | current dir | Project to mount at `/workspace` |
| `GIT_PARENT_REPO` | _(auto)_ | Parent repo path for git worktrees |
| `GSD_DEFAULT_MODEL` | `sonnet` | Model used by get-shit-done framework |
| `GH_TOKEN` / `GITHUB_TOKEN` | _(host env)_ | Forwarded as git credential for GitHub |
| `AZURE_DEVOPS_TOKEN` | _(host env)_ | Forwarded as git credential for Azure |

## Security Model

| Capability | Allowed |
|---|---|
| Modify files in mounted volumes | Yes |
| Execute commands in container | Yes |
| Access files outside mounted volumes | No |
| Install packages on host | No |
| Access internet beyond whitelisted domains | No |
| Persist changes after container exit | Only via mounted volumes and Docker volumes |
