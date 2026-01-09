# Claude Code Docker Container

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

```bash
./claude-safe.sh /path/to/your/project
```

Or from your project directory:

```bash
/path/to/claude-code-docker/claude-safe.sh .
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

## How It Works

- Your project directory is **automatically mounted** at `/workspace`
- Claude starts in your project directory with skip permissions enabled
- Changes Claude makes are **immediately visible** on your host machine
- Authentication persists in a Docker volume (login once, use forever)
- Network firewall restricts outbound connections to approved domains
- Container runs as non-root user for additional security

**Example:**
```bash
# You run this on your host
./claude-safe.sh ~/my-app

# Claude automatically starts in /workspace (which is ~/my-app)
# Any files Claude creates/modifies appear instantly in ~/my-app
```

**Exiting:**
When you exit Claude Code (type `exit` or Ctrl+D), the container automatically stops and removes itself. Don't worry - your authentication and command history are preserved in Docker volumes for next time!

## Advanced Usage

### Using an API Key Instead

If you prefer using an API key:

```bash
echo "ANTHROPIC_API_KEY=your-key-here" > .env
./claude-safe.sh /path/to/project
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

### VS Code Dev Container

Copy these files to `.devcontainer/` in your project, then use VS Code's "Reopen in Container" command.

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

Edit `init-firewall.sh` around line 67 to add domains:

```bash
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "your-custom-domain.com"; do
```

Then rebuild the container.

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

**Starting:** `./claude-safe.sh /path/to/project` - creates NEW container from image

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

### Permission Errors

The container runs as the `node` user. For root access:

```bash
docker-compose run --rm --user root claude-code
```

## What's Included

- **Node.js 20** with npm
- **Python 3.11** (pip not included by default)
- **Git** with GitHub CLI (`gh`)
- **Development tools**: zsh, fzf, vim, nano, jq
- **Network tools**: iptables, ipset for firewall
- **Claude Code** (latest version)

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
