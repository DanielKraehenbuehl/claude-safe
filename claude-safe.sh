#!/bin/bash
set -euo pipefail

# Run Claude Code safely in a sandboxed Docker container
# with network restrictions and skip-permissions enabled
#
# Author: Daniel Krähenbühl - Hamilton Medical AG

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if project path is provided
if [ $# -eq 0 ]; then
    echo "❌ Error: Project directory required"
    echo ""
    echo "Usage: $0 /path/to/project"
    echo ""
    echo "Example:"
    echo "  $0 ."
    echo "  $0 /home/user/my-project"
    exit 1
fi

PROJECT_DIR="$1"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

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
docker-compose -f "$COMPOSE_FILE" run --rm claude-code

# Cleanup
echo ""
echo "✅ Claude Code session ended"
