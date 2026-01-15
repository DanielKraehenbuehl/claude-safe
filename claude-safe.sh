#!/bin/bash
set -euo pipefail

# Run Claude Code safely in a sandboxed Docker container
# with network restrictions and skip-permissions enabled
#
# Author: Daniel Krähenbühl - Hamilton Medical AG

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Use current directory if no project path is provided
if [ $# -eq 0 ]; then
    PROJECT_DIR="."
else
    PROJECT_DIR="$1"
fi
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

# Choose Docker Compose (v1 or v2)
COMPOSE_CMD=()
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD=(docker-compose)
elif docker compose version &> /dev/null; then
    COMPOSE_CMD=(docker compose)
else
    echo "❌ Error: Docker Compose is not installed"
    echo "   Please install Docker Compose from: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Error: Directory not found: $PROJECT_DIR"
    exit 1
fi

# Convert to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Check if .env file exists, create empty one if not
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "Creating .env file..."
    echo "# Leave empty to use web-based login" > "$SCRIPT_DIR/.env"
    echo "ANTHROPIC_API_KEY=" >> "$SCRIPT_DIR/.env"
fi

# Export PROJECT_DIR for docker-compose
export PROJECT_DIR

echo "🐳 Starting Claude Code..."
echo "📁 Project: $PROJECT_DIR"
echo "⚡ Running with --dangerously-skip-permissions"
echo ""

# Run the container with Claude Code automatically starting
"${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" run --rm claude-code

# Cleanup
echo ""
echo "✅ Claude Code session ended"
