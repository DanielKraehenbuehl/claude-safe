#!/bin/bash
set -euo pipefail

# Simple setup script for Claude Code Docker
# Usage: ./setup.sh
#
# Author: Daniel Krähenbühl - Hamilton Medical AG

echo "======================================"
echo "Claude Code Docker Setup"
echo "======================================"
echo ""

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed"
    echo "   Please install Docker from: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check for Docker Compose (v1 or v2)
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

echo "✅ Docker found"
echo "✅ Docker Compose found"
echo ""

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cat > .env << 'EOF'
# Leave empty to use web-based login
ANTHROPIC_API_KEY=
EOF
    echo "✅ Created .env file"
else
    echo "✅ .env file already exists"
fi

echo ""
echo "Building Docker image..."
echo "(This may take a few minutes on first run)"
echo ""

# Check if we should force rebuild
FORCE_REBUILD=""
if [ "${1:-}" = "--force" ] || [ "${1:-}" = "--no-cache" ]; then
    echo "⚠️  Forcing clean rebuild (no cache)..."
    FORCE_REBUILD="--no-cache"
    echo ""
fi

if "${COMPOSE_CMD[@]}" build $FORCE_REBUILD; then
    echo ""
    echo "======================================"
    echo "✅ Setup Complete!"
    echo "======================================"
    echo ""
    echo "To run Claude Code on a project:"
    echo ""
    echo "  cd /path/to/your/project && $(pwd)/claude-safe.sh"
    echo ""
    echo "Or specify a project path:"
    echo ""
    echo "  ./claude-safe.sh /path/to/your/project"
    echo ""
    echo "Claude Code will start automatically with --dangerously-skip-permissions"
    echo ""
    echo "💡 Tip: Create an alias for easier access:"
    echo ""
    echo "  echo \"alias claude='$(pwd)/claude-safe.sh'\" >> ~/.bashrc"
    echo "  source ~/.bashrc"
    echo ""
    echo "Then just run 'claude' from any project directory!"
    echo ""
    echo "For more info, see README.md"
    echo ""
else
    echo ""
    echo "❌ Build failed"
    echo "   Check the error messages above"
    exit 1
fi
