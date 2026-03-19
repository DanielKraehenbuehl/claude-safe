#!/bin/bash
# Wrapper script to start Claude with proper terminal settings

sync_host_ssh() {
    local host_ssh="/host-ssh"
    local target_ssh="/home/node/.ssh"
    local file
    local base

    if [ ! -d "$host_ssh" ]; then
        return
    fi

    mkdir -p "$target_ssh"
    chmod 700 "$target_ssh"
    shopt -s nullglob dotglob

    for file in "$host_ssh"/*; do
        base="$(basename "$file")"
        case "$base" in
            .|..|known_hosts|known_hosts.old)
                continue
                ;;
        esac
        if [ -d "$file" ]; then
            cp -a "$file" "$target_ssh/"
            chmod 700 "$target_ssh/$base" 2>/dev/null || true
            continue
        fi

        if [ -f "$file" ] || [ -L "$file" ]; then
            cp -a "$file" "$target_ssh/"
            chmod 600 "$target_ssh/$base" 2>/dev/null || true
        fi
    done

    shopt -u nullglob dotglob

    if [ -f "$host_ssh/known_hosts" ]; then
        touch "$target_ssh/known_hosts"
        awk '!seen[$0]++' "$target_ssh/known_hosts" "$host_ssh/known_hosts" > "$target_ssh/known_hosts.tmp"
        mv "$target_ssh/known_hosts.tmp" "$target_ssh/known_hosts"
    fi

    chmod 600 "$target_ssh"/known_hosts 2>/dev/null || true
}

sync_host_claude_auth() {
    local host_claude="/host-claude"
    local source_credentials="$host_claude/.credentials.json"
    local target_claude="/home/node/.claude"

    if [ ! -f "$source_credentials" ]; then
        return
    fi

    mkdir -p "$target_claude"
    install -m 600 "$source_credentials" "$target_claude/.credentials.json"
}

extract_worktree_name() {
    local gitdir_path="$1"
    local normalized_path="${gitdir_path//\\//}"
    basename "$normalized_path"
}

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

sync_host_ssh
sync_host_claude_auth

# Fix git worktree paths when running inside Docker
# Git worktrees use a .git file (not directory) containing a gitdir pointer to
# the main repo's .git/worktrees/<name> directory. When mounted from a Windows
# host, this path doesn't exist in the container. We fix this by setting GIT_DIR
# and GIT_WORK_TREE to point to the mounted parent repo instead.
if [ -f /workspace/.git ]; then
    GITDIR_LINE=$(cat /workspace/.git)
    GITDIR_PATH="${GITDIR_LINE#gitdir: }"

    # Detect Windows paths (D:/... or D:\...) or non-existent Linux paths
    if [[ "$GITDIR_PATH" =~ ^[A-Za-z]:[/\\] ]] || [ ! -d "$GITDIR_PATH" ]; then
        WORKTREE_NAME=$(extract_worktree_name "$GITDIR_PATH")
        PARENT_WORKTREE_DIR="/git-parent-repo/.git/worktrees/$WORKTREE_NAME"

        if [ -d "$PARENT_WORKTREE_DIR" ]; then
            # Copy the worktree admin dir so we can fix the reverse pointer
            # without mutating the mounted host repository metadata.
            CONTAINER_WORKTREE_DIR=$(mktemp -d /tmp/git-worktree-XXXXXX)
            cp -a "$PARENT_WORKTREE_DIR/." "$CONTAINER_WORKTREE_DIR/"

            GITDIR_FILE="$CONTAINER_WORKTREE_DIR/gitdir"
            if [ -f "$GITDIR_FILE" ]; then
                echo "/workspace/.git" > "$GITDIR_FILE"
            fi

            COMMONDIR_FILE="$CONTAINER_WORKTREE_DIR/commondir"
            if [ -f "$COMMONDIR_FILE" ]; then
                echo "/git-parent-repo/.git" > "$COMMONDIR_FILE"
            fi

            export GIT_DIR="$CONTAINER_WORKTREE_DIR"
            export GIT_WORK_TREE="/workspace"
            echo "Git worktree detected: $WORKTREE_NAME -> $CONTAINER_WORKTREE_DIR"
        else
            echo "WARNING: Git worktree detected but parent repo not accessible."
            echo "  Set GIT_PARENT_REPO=<path-to-main-repo> in your .env file"
            echo "  Example: GIT_PARENT_REPO=D:/doc/git/ventsight"
            echo "  The .git file references: $GITDIR_PATH"
        fi
    fi
fi

# Initialize firewall
sudo /usr/local/bin/init-firewall.sh

# Start Claude Code
exec claude --dangerously-skip-permissions
