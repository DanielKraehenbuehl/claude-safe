#!/usr/bin/env bats

load '../helpers/stubs'

SCRIPT_REPO_DIR=""

setup() {
    SCRIPT_REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TMPSETUPDIR="$(mktemp -d)"
    cp "$SCRIPT_REPO_DIR/setup.sh" "$TMPSETUPDIR/setup.sh"
    setup_stubs
    export TMPSETUPDIR
}

teardown() {
    teardown_stubs
    [ -n "${TMPSETUPDIR:-}" ] && rm -rf "$TMPSETUPDIR"
}

run_setup() {
    bash "$TMPSETUPDIR/setup.sh" "$@"
}

# ---------------------------------------------------------------------------
# Docker not installed
# ---------------------------------------------------------------------------

@test "exits with error when docker is not installed" {
    make_clean_docker_path
    # Remove docker stub so 'docker' command is not found
    run run_setup
    [ "$status" -ne 0 ]
    [[ "$output" == *"Docker is not installed"* ]]
}

# ---------------------------------------------------------------------------
# Docker Compose detection
# ---------------------------------------------------------------------------

@test "exits with error when neither docker-compose nor docker compose available" {
    # Use a clean PATH (no real docker/docker-compose) then add a docker stub
    # that fails on 'compose version', simulating v2 being absent too.
    make_clean_docker_path
    cat > "$STUB_DIR/docker" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "compose" ] && [ "$2" = "version" ]; then exit 1; fi
exit 0
EOF
    chmod +x "$STUB_DIR/docker"
    run run_setup
    [ "$status" -ne 0 ]
    [[ "$output" == *"Docker Compose is not installed"* ]]
}

@test "accepts docker compose v2 when docker-compose not available" {
    make_clean_docker_path
    # docker stub: passes 'compose version', 'info', and 'compose build'
    cat > "$STUB_DIR/docker" << 'EOF'
#!/usr/bin/env bash
_calls_dir="${STUB_CALLS_DIR:-/tmp}"
echo "$*" >> "$_calls_dir/docker.calls"
exit 0
EOF
    chmod +x "$STUB_DIR/docker"
    run bash -c "cd '$TMPSETUPDIR' && bash '$TMPSETUPDIR/setup.sh'"
    [ "$status" -eq 0 ]
    stub_called "docker"
}

# ---------------------------------------------------------------------------
# Docker daemon connectivity
# ---------------------------------------------------------------------------

@test "exits with error when docker info fails" {
    make_docker_compose_stub
    # docker stub that fails on 'info'
    cat > "$STUB_DIR/docker" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "info" ]; then exit 1; fi
exit 0
EOF
    chmod +x "$STUB_DIR/docker"
    run run_setup
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot connect to the Docker daemon"* ]]
}

# ---------------------------------------------------------------------------
# .env creation
# ---------------------------------------------------------------------------

@test "creates .env file when it does not exist" {
    make_docker_compose_stub
    cat > "$STUB_DIR/docker" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$STUB_DIR/docker"
    rm -f "$TMPSETUPDIR/.env"
    run bash -c "cd '$TMPSETUPDIR' && bash '$TMPSETUPDIR/setup.sh'"
    [ "$status" -eq 0 ]
    [ -f "$TMPSETUPDIR/.env" ]
    grep -q "ANTHROPIC_API_KEY" "$TMPSETUPDIR/.env"
}

@test "does not overwrite existing .env file" {
    make_docker_compose_stub
    cat > "$STUB_DIR/docker" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$STUB_DIR/docker"
    echo "ANTHROPIC_API_KEY=existing_key" > "$TMPSETUPDIR/.env"
    run bash -c "cd '$TMPSETUPDIR' && bash '$TMPSETUPDIR/setup.sh'"
    [ "$status" -eq 0 ]
    grep -q "existing_key" "$TMPSETUPDIR/.env"
}

# ---------------------------------------------------------------------------
# Force rebuild flag
# ---------------------------------------------------------------------------

@test "passes --no-cache to build when --force flag given" {
    make_docker_compose_stub
    cat > "$STUB_DIR/docker" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$STUB_DIR/docker"
    run bash -c "cd '$TMPSETUPDIR' && bash '$TMPSETUPDIR/setup.sh' --force"
    [ "$status" -eq 0 ]
    [[ "$(stub_calls docker-compose)" == *"--no-cache"* ]]
}

@test "does not pass --no-cache without force flag" {
    make_docker_compose_stub
    cat > "$STUB_DIR/docker" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$STUB_DIR/docker"
    run bash -c "cd '$TMPSETUPDIR' && bash '$TMPSETUPDIR/setup.sh'"
    [ "$status" -eq 0 ]
    [[ "$(stub_calls docker-compose)" != *"--no-cache"* ]]
}
