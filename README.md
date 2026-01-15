# Claude Code Safe

Run [Claude Code](https://github.com/anthropics/claude-code) in a sandboxed Docker container with network restrictions and skip-permission mode.

## Why Use This?

- **Security**: Run Claude Code with dangerously-skip-permissions safely in an isolated container
- **Network Restrictions**: Firewall limits access to GitHub, npm, Anthropic API, and essential services only
- **Zero-Friction**: One command to run - Claude starts automatically with skip permissions
- **Easy Setup**: No API key required - login with your Claude.ai account
- **Persistent Config**: Authentication and history saved between sessions

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/DanielKraehenbuehl/claude-safe.git
cd claude-safe
./setup.sh
```

That's it! The setup script will check dependencies and build the container.

### 2. Run Claude Code on Your Project

From your project directory:

```bash
cd /path/to/your/project
/path/to/claude-safe/claude-safe.sh
```

Or specify a project path:

```bash
./claude-safe.sh /path/to/your/project
```

That's it! Claude Code starts automatically with `--dangerously-skip-permissions` enabled.

### 3. First-Time Login

On first run, Claude will show an authentication URL:

```
Please visit this URL to authenticate:
https://api.anthropic.com/oauth/authorize?...
```

1. Copy the URL and open it in your browser
2. Login with your Claude.ai account
3. Authorize the application
4. Done! Your authentication is saved for future sessions

### 4. Create an Alias (Recommended)

For easier access, create a `claude` alias that points to the containerized version. This is especially useful if Claude Code is not installed on your host machine.

**Add to your shell config** (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
alias claude='/path/to/claude-safe/claude-safe.sh'
```

**Reload your shell:**
```bash
source ~/.bashrc  # or ~/.zshrc
```

**Now you can run from any project directory:**
```bash
cd ~/my-project
claude  # Runs containerized Claude Code in current directory
```

**VS Code Integration:**
With the alias in place, VS Code and other tools can invoke the containerized Claude Code when they try to run the `claude` command. This gives you the benefits of:
- Container isolation and security
- Network restrictions via firewall
- Consistent environment across projects
- No need to install Claude Code on your host

## How It Works

- Your project directory is **automatically mounted** at `/workspace`
- Claude starts in your project directory with skip permissions enabled
- Changes Claude makes are **immediately visible** on your host machine
- Authentication persists in a Docker volume (login once, use forever)
- Network firewall restricts outbound connections to approved domains
- Container runs as non-root user for additional security

**Example:**
```bash
# Option 1: Specify a project path
./claude-safe.sh ~/my-app

# Option 2: Run from your project directory
cd ~/my-app
/path/to/claude-safe/claude-safe.sh

# Claude automatically starts in /workspace (which is ~/my-app)
# Any files Claude creates/modifies appear instantly in ~/my-app
```

**Exiting:**
When you exit Claude Code (type `exit` or Ctrl+D), the container automatically stops and removes itself. Don't worry - your authentication and command history are preserved in Docker volumes for next time!

## Using get-shit-done Workflows

The container includes the **get-shit-done (GSD)** framework for structured, spec-driven development. GSD solves "context rot" by maintaining project specifications and breaking work into atomic tasks with isolated execution.

### Why Use GSD?

- **Structured Planning**: Define requirements, create roadmaps, and plan phases systematically
- **Quality Consistency**: Each task runs in a fresh context window, preventing quality degradation
- **Atomic Commits**: Individual tasks produce separate, traceable git commits
- **Parallel Execution**: Run multiple agents concurrently for faster development
- **Session Persistence**: Project state persists across container restarts

### Available Commands

**Project Setup:**
- `/gsd:new-project` - Extract project ideas through guided questioning
- `/gsd:research-project` - Investigate domain ecosystems and best practices
- `/gsd:define-requirements` - Scope features across versions (MVP, v2, v3...)
- `/gsd:create-roadmap` - Structure development phases with requirement mapping
- `/gsd:map-codebase` - Analyze existing codebases for brownfield projects

**Execution & Delivery:**
- `/gsd:plan-phase` - Generate atomic task plans with XML structure
- `/gsd:execute-phase` - Run parallel agents for concurrent work
- `/gsd:execute-plan` - Interactive single-plan execution
- `/gsd:complete-milestone` - Ship versions and prepare next iterations

**Phase Management:**
- `/gsd:add-phase` - Add new phase to roadmap
- `/gsd:insert-phase` - Insert phase at specific position
- `/gsd:verify-work` - Verify completed work meets requirements
- `/gsd:plan-fix` - Plan fixes for verification failures

**Session Persistence:**
- `/gsd:pause-work` - Save current state for later
- `/gsd:resume-work` - Resume from saved state

### Quick Start Workflow

```bash
cd ~/my-new-app
/path/to/claude-safe/claude-safe.sh

# Inside Claude Code:
/gsd:new-project
# Answer guided questions about your project vision

/gsd:define-requirements
# Define features for MVP and future versions

/gsd:create-roadmap
# Structure implementation into logical phases

/gsd:plan-phase
# Generate detailed task plan for Phase 1

/gsd:execute-phase
# Execute all tasks with atomic git commits

/gsd:complete-milestone
# Ship MVP and prepare for next version
```

### How GSD Works in claude-safe

**Context Management:**
GSD maintains these specification files in your project:
- `PROJECT.md` - Project vision and overview
- `REQUIREMENTS.md` - Versioned feature requirements
- `ROADMAP.md` - Phase structure and task mapping
- `STATE.md` - Current execution state

**Persistent Storage:**
- Global GSD config stored in Docker volume (`~/.claude/`)
- Project-specific files stored in `/workspace` (your mounted directory)
- Both survive container restarts

**Execution Model:**
- Each task runs in a fresh 200k-token context
- Parallel agents execute concurrently for speed
- All operations respect claude-safe's firewall restrictions
- Atomic commits enable surgical version control

### Example: Building a New Feature

```bash
# Plan a new authentication feature
/gsd:add-phase
# Name: "User Authentication"
# Add requirements: login, signup, password reset

/gsd:plan-phase
# Review generated XML plan with atomic tasks

/gsd:execute-phase
# Watch parallel agents implement tasks
# Each task creates a separate git commit

/gsd:verify-work
# Run tests and verify requirements met
```

### Tips for Using GSD

- **Start Small**: Begin with `/gsd:new-project` even for existing projects to document vision
- **Version Everything**: Use `/gsd:define-requirements` to plan MVP, v2, v3 upfront
- **Atomic Tasks**: Keep tasks small and focused for better parallel execution
- **Verify Often**: Use `/gsd:verify-work` after each phase to catch issues early
- **Commit Messages**: GSD generates descriptive commits automatically

### Learn More

- **GSD Repository**: https://github.com/glittercowboy/get-shit-done
- **Help Command**: Type `/gsd:help` inside Claude Code
- **Troubleshooting**: See GSD section in Troubleshooting below

## Advanced Usage

### Using an API Key Instead

If you prefer using an API key:

```bash
echo "ANTHROPIC_API_KEY=your-key-here" > .env
./claude-safe.sh  # Uses current directory, or specify a path
```

### Docker Compose Directly

```bash
PROJECT_DIR=/path/to/project docker-compose run --rm claude-code
```

### Read-Only Project Mount

To prevent Claude from modifying your files, edit `docker-compose.yml`:

```yaml
volumes:
  - ${PROJECT_DIR:-.}:/workspace:ro
```

### Resource Limits

Add to `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
```

### VS Code Integration

**Option 1: Using the Alias (Recommended)**

If you've created the `claude` alias as described in the Quick Start, VS Code extensions and integrated terminals can invoke the containerized Claude Code directly. This works seamlessly with:
- VS Code's integrated terminal
- Extensions that call the `claude` command
- Task runners and build scripts

**Option 2: Dev Container**

For a full VS Code development environment inside the container, copy the included `devcontainer.json` to `.devcontainer/` in your project, then use VS Code's "Reopen in Container" command.

## Configuration

### Environment Variables

Create a `.env` file (optional):

```bash
# Authentication (leave empty for web-based login)
ANTHROPIC_API_KEY=

# Your timezone
TZ=America/New_York

# Claude Code version
CLAUDE_CODE_VERSION=latest

# Project directory
PROJECT_DIR=/path/to/your/project
```

### Customize Allowed Domains

The firewall allows these domains by default:
- **GitHub** (api.github.com, github.com, raw.githubusercontent.com)
- **npm** (registry.npmjs.org)
- **Anthropic** (api.anthropic.com)
- **Microsoft** (packages.microsoft.com) - for .NET SDK
- **Python** (pypi.org, files.pythonhosted.org) - for pip packages

To add custom domains, edit `init-firewall.sh` around line 67:

```bash
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "your-custom-domain.com"; do
```

Then rebuild the container with `./setup.sh`.

## Container Lifecycle

### Images vs Containers

**Image** = Template/blueprint (built by `setup.sh`)
**Container** = Running instance (created by `claude-safe.sh`)

### When to Run setup.sh

Run `./setup.sh` to build/update the image:
- ✅ First time installation
- ✅ After `git pull` (pulling updates)
- ✅ After modifying Dockerfile
- ❌ NOT needed before every run

**Speed:** First run takes 2-5 minutes. Subsequent runs are fast (5-30 seconds) thanks to Docker's layer caching.

### Each Run Creates Fresh Container

**Starting:** `./claude-safe.sh` (uses current directory) or `./claude-safe.sh /path/to/project` - creates NEW container from image

**Stopping:** Type `exit` or Ctrl+D - container stops and auto-deletes (`--rm` flag)

**What's Preserved:**
- ✅ Your authentication (in `claude-code-config` volume)
- ✅ Command history (in `claude-code-bashhistory` volume)
- ✅ All project files (in your mounted directory)

**What's Cleaned:**
- Container itself (removed with `--rm` flag)
- Temporary container files
- Network connections

You get a fresh container every time, but your config persists!

## Troubleshooting

### Known Issues

**Double Echo in Docker (WSL/Windows)**

When running in Docker on WSL, you may see your input appear twice after pressing Enter:

```
❯ test


❯ test
```

This is a cosmetic issue caused by Docker's TTY layer and **does not affect functionality**. Claude receives your input correctly and works normally.

**Workaround:** If this bothers you, run Claude Code directly on your WSL host instead of in Docker (you'll lose container isolation but avoid the double echo).

### Code Colors/Syntax Highlighting Missing

If code blocks appear without colors, rebuild the container:

```bash
./setup.sh
```

The container is now configured with proper color support (`TERM=xterm-256color`).

**Verify colors work:**
```bash
# Inside container
ls --color=auto  # Should show colored output
```

### Copy-Paste Not Working

Docker containers don't share clipboard with your host by default.

**WSL Users:**
- Use Windows Terminal: `Ctrl+Shift+C` to copy, `Ctrl+Shift+V` to paste
- After rebuild with `./setup.sh`, use `copy` and `paste` commands inside container:
  ```bash
  echo "text" | copy    # Copy to Windows clipboard
  paste                 # Paste from Windows clipboard
  ```
- Enable "Automatically copy selection to clipboard" in Windows Terminal settings

**macOS Users:**
- Select text with mouse, then `Cmd+C` / `Cmd+V`

**Linux Users:**
- Select text with mouse → auto-copied
- `Shift+Insert` to paste

**Or use files (works everywhere):**
```bash
# Inside container
echo "output" > /workspace/result.txt

# On host
cat /path/to/project/result.txt
```

### Web Login Fails

Check that port 38714 is exposed:

```bash
docker ps
# Should show: 0.0.0.0:38714->38714/tcp
```

### Need to Re-authenticate

Remove the config volume:

```bash
docker-compose down -v
```

### Firewall Blocking Required Site

Inside container:

```bash
# Test if a site is accessible
curl https://example.com

# Should work
curl https://api.github.com

# Should fail (blocked)
curl https://google.com
```

### get-shit-done Commands Not Found

If `/gsd:*` commands don't work:

**Verify GSD is installed:**
```bash
ls -la ~/.claude/skills/
# Should see gsd-related directories
```

**Reinstall if needed:**
```bash
npx get-shit-done-cc --global
```

**Check Claude Code version:**
```bash
claude --version
# GSD requires Claude Code with skill support
```

### GSD State Not Persisting

If GSD forgets your project state between container restarts:

**Check volume mounts:**
```bash
docker volume ls
# Should see: claude-code-config
```

**Verify PROJECT.md exists:**
```bash
ls -la /workspace/PROJECT.md
# Should exist in your mounted project directory
```

### GSD Agents Slow or Timeout

If GSD parallel execution is slow:

**Add resource limits** in `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 8G
```

**Check network restrictions:**
```bash
# GSD agents may need additional domains
# Review init-firewall.sh and add if needed
```

### Permission Errors

The container runs as the `node` user with passwordless sudo access to common package managers:

**Allowed without password:**
- `sudo apt-get`, `sudo apt`, `sudo dpkg` (install system packages like .NET)
- `sudo pip3`, `sudo pip` (install Python packages like Robot Framework)
- `sudo npm` (install Node packages globally)
- `sudo add-apt-repository` (add package repositories)

**Example:**
```bash
# Claude can run these directly
sudo apt-get install dotnet-sdk-8.0
sudo pip3 install robotframework
sudo npm install -g typescript
```

For full root access (if needed):
```bash
docker-compose run --rm --user root claude-code
```

## What's Included

- **Node.js 20** with npm
- **Python 3.11** with pip3
- **Git** with GitHub CLI (`gh`)
- **Docker CLI** with BuildX and Compose plugins (BuildKit enabled by default)
- **Development tools**: zsh, fzf, vim, nano, jq, wget, curl
- **Network tools**: iptables, ipset for firewall
- **Claude Code** (latest version)
- **get-shit-done framework** - Structured development workflows with slash commands
- **pre-commit** - Git hook framework for code quality
- **Sudo access** to package managers (apt, pip, npm) for installing additional tools

## Security Considerations

Even with Docker + firewall + skip permissions:

- ✅ Claude **can** modify/delete files in mounted project
- ✅ Claude **can** execute commands in the container
- ✅ Claude **can** consume resources (set limits if needed)
- ❌ Claude **cannot** access files outside mounted volumes
- ❌ Claude **cannot** install packages on your host
- ❌ Claude **cannot** access most internet sites (firewall restricted)

## Files in This Repo

```
.
├── setup.sh               # One-command setup script
├── claude-safe.sh         # Run Claude safely in container
├── setup-clipboard.sh     # Clipboard integration setup
├── docker-compose.yml     # Docker orchestration
├── Dockerfile             # Container image definition
├── init-firewall.sh       # Network firewall script
├── devcontainer.json      # VS Code Dev Container config
├── .env.example           # Environment variables template
├── .gitignore             # Git ignore rules
├── LICENSE                # MIT License
├── CONTRIBUTORS.md        # Author and contributors
└── README.md              # This file
```

## Requirements

- Docker Engine 20.10+
- Docker Compose 2.0+
- A Claude.ai account or Anthropic API key

## License

This setup is based on the official [Claude Code repository](https://github.com/anthropics/claude-code)'s `.devcontainer` configuration.

## Contributing

Issues and pull requests welcome! Please ensure:
- Scripts remain simple and portable
- Security features are preserved
- Documentation stays beginner-friendly

## Author

**Daniel Krähenbühl** - Hamilton Medical AG

## Credits

Built from the official Claude Code `.devcontainer` setup by Anthropic.
