# Quick Start Guide - Web-Based Login

This is the simplest way to get started with Claude Code in Docker without an API key.

## Step-by-Step

### 1. Run Setup

```bash
cd claude-code-docker
./setup.sh
```

This takes a few minutes the first time and will check dependencies and build the container.

### 2. Run Claude Code

From any project directory:

```bash
/path/to/claude-code-docker/claude-safe.sh .
```

**What happens automatically:**
- Your project directory is mounted into the container
- Claude Code starts in your project with `--dangerously-skip-permissions` enabled
- You're ready to work immediately!

### 3. Login via Browser

When Claude Code starts for the first time, you'll see:

```
Please visit this URL to authenticate:
https://api.anthropic.com/oauth/authorize?...

Waiting for authentication...
```

**Do this:**
1. Copy the entire URL
2. Open it in your browser (on your host machine, not in the container)
3. Login with your Claude.ai account
4. Authorize the application
5. Your browser will redirect to `localhost:38714/callback`
6. Claude Code automatically receives the token and starts!

### 4. Exiting Claude Code

When you're done, simply type `exit` or press Ctrl+D:

```bash
exit
```

The container automatically stops and removes itself. Your authentication and history are preserved in Docker volumes, so next time you run it, you won't need to login again!

### 5. Future Sessions

You only need to login once! The authentication is saved in a Docker volume (`claude-code-config`), so subsequent sessions will work immediately:

```bash
./claude-safe.sh /path/to/project
# Claude starts automatically, no login needed!
```

## Common Issues

**"Connection refused" on callback:**
- Make sure port 38714 is exposed (check `docker-compose.yml`)
- Make sure no other service is using port 38714 on your host

**Firewall blocking authentication:**
- The firewall whitelist includes `api.anthropic.com`
- Check with: `curl https://api.anthropic.com` inside container

**Need to re-authenticate:**
Delete the config volume:
```bash
docker-compose down -v
# Next run will ask for authentication again
```

## What About API Keys?

API keys are optional! Only use them if:
- You're using Claude Code in CI/CD
- You need programmatic access
- Your organization requires API key auth

For personal development, web-based login is easier and more secure.
