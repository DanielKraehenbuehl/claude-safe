#!/bin/bash
# Wrapper script to start Claude with proper terminal settings

# Fix Docker socket permissions if mounted
if [ -S /var/run/docker.sock ]; then
    DOCKER_SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
    CURRENT_DOCKER_GID=$(getent group docker | cut -d: -f3)

    if [ "$DOCKER_SOCKET_GID" != "$CURRENT_DOCKER_GID" ]; then
        echo "Fixing Docker group ID mismatch..."
        echo "  Docker socket GID: $DOCKER_SOCKET_GID"
        echo "  Container docker group GID: $CURRENT_DOCKER_GID"

        # Remove existing docker group and recreate with correct GID
        sudo groupdel docker 2>/dev/null || true
        sudo groupadd -g "$DOCKER_SOCKET_GID" docker
        sudo usermod -aG docker node

        echo "  Fixed: Docker group now has GID $DOCKER_SOCKET_GID"
    fi
fi

# Initialize firewall
sudo /usr/local/bin/init-firewall.sh

# Start Claude Code
exec claude --dangerously-skip-permissions
