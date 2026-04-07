setup_stubs() {
    STUB_DIR="$(mktemp -d)"
    STUB_CALLS_DIR="$(mktemp -d)"
    _ORIGINAL_PATH="$PATH"
    export STUB_DIR STUB_CALLS_DIR _ORIGINAL_PATH
    export PATH="$STUB_DIR:$PATH"
}

# Build a controlled PATH that excludes real docker/docker-compose binaries.
# Symlinks all /bin tools (except docker*) into STUB_DIR so scripts can find
# grep, mktemp, tr, etc. without picking up the system docker or docker-compose.
# Call AFTER setup_stubs so STUB_DIR is already set.
make_clean_docker_path() {
    _CLEAN_PATH_DIR="$(mktemp -d)"
    export _CLEAN_PATH_DIR
    # Symlink everything from /bin and /usr/bin (except docker*) into _CLEAN_PATH_DIR
    for _f in /bin/* /usr/bin/*; do
        _n="$(basename "$_f")"
        case "$_n" in
            docker*) ;;  # skip all docker binaries
            *) ln -sf "$_f" "$_CLEAN_PATH_DIR/$_n" 2>/dev/null || true ;;
        esac
    done
    export PATH="$STUB_DIR:$_CLEAN_PATH_DIR"
}

teardown_stubs() {
    # Restore original PATH before removing stub dirs so rm/etc. remain available
    [ -n "${_ORIGINAL_PATH:-}" ] && export PATH="$_ORIGINAL_PATH" || true
    [ -n "${STUB_DIR:-}" ] && rm -rf "$STUB_DIR" || true
    [ -n "${STUB_CALLS_DIR:-}" ] && rm -rf "$STUB_CALLS_DIR" || true
    [ -n "${_CLEAN_PATH_DIR:-}" ] && rm -rf "$_CLEAN_PATH_DIR" || true
}

make_stub() {
    local name="$1"
    local exit_code="${2:-0}"
    local stub_path="$STUB_DIR/$name"
    cat > "$stub_path" << EOF
#!/usr/bin/env bash
_calls_dir="\${STUB_CALLS_DIR:-/tmp}"
echo "\$*" >> "\$_calls_dir/${name}.calls"
exit ${exit_code}
EOF
    chmod +x "$stub_path"
}

make_docker_compose_stub() {
    local exit_code="${1:-0}"
    local stub_path="$STUB_DIR/docker-compose"
    cat > "$stub_path" << 'STUBEOF'
#!/usr/bin/env bash
_calls_dir="${STUB_CALLS_DIR:-/tmp}"
echo "$*" >> "$_calls_dir/docker-compose.calls"
# Capture env vars when "run" subcommand is used
for arg in "$@"; do
    if [ "$arg" = "run" ]; then
        printf "TEMP_WORKSPACE='%s'\n" "${TEMP_WORKSPACE:-}" >> "$_calls_dir/compose-env.sh"
        printf "PROJECT_DIR='%s'\n" "${PROJECT_DIR:-}" >> "$_calls_dir/compose-env.sh"
        printf "GIT_PARENT_REPO='%s'\n" "${GIT_PARENT_REPO:-}" >> "$_calls_dir/compose-env.sh"
        printf "CLAUDE_WORKING_DIR='%s'\n" "${CLAUDE_WORKING_DIR:-}" >> "$_calls_dir/compose-env.sh"
        printf "EXTRA_ARGS='%s'\n" "$*" >> "$_calls_dir/compose-env.sh"
        break
    fi
done
STUBEOF
    echo "exit ${exit_code}" >> "$stub_path"
    chmod +x "$stub_path"
}

make_docker_stub() {
    local compose_version_exit="${1:-0}"
    local run_exit="${2:-0}"
    local stub_path="$STUB_DIR/docker"
    cat > "$stub_path" << STUBEOF
#!/usr/bin/env bash
_calls_dir="\${STUB_CALLS_DIR:-/tmp}"
echo "\$*" >> "\$_calls_dir/docker.calls"

# Handle "compose version" subcommand
if [ "\$1" = "compose" ] && [ "\$2" = "version" ]; then
    exit ${compose_version_exit}
fi

# Handle "compose ... run ..." - capture env vars
if [ "\$1" = "compose" ]; then
    for arg in "\$@"; do
        if [ "\$arg" = "run" ]; then
            printf "TEMP_WORKSPACE='%s'\n" "\${TEMP_WORKSPACE:-}" >> "\$_calls_dir/compose-env.sh"
            printf "PROJECT_DIR='%s'\n" "\${PROJECT_DIR:-}" >> "\$_calls_dir/compose-env.sh"
            printf "GIT_PARENT_REPO='%s'\n" "\${GIT_PARENT_REPO:-}" >> "\$_calls_dir/compose-env.sh"
            printf "CLAUDE_WORKING_DIR='%s'\n" "\${CLAUDE_WORKING_DIR:-}" >> "\$_calls_dir/compose-env.sh"
            printf "EXTRA_ARGS='%s'\n" "\$*" >> "\$_calls_dir/compose-env.sh"
            exit ${run_exit}
        fi
    done
fi

exit 0
STUBEOF
    chmod +x "$stub_path"
}

# Shadow both docker-compose and docker with stubs that fail every check,
# simulating an environment where neither Docker Compose v1 nor v2 is available.
make_no_docker_stubs() {
    make_stub "docker-compose" 1
    make_stub "docker" 1
}

stub_calls() {
    local name="$1"
    local calls_file="${STUB_CALLS_DIR:-/tmp}/${name}.calls"
    if [ -f "$calls_file" ]; then
        cat "$calls_file"
    fi
}

stub_called() {
    local name="$1"
    local calls_file="${STUB_CALLS_DIR:-/tmp}/${name}.calls"
    [ -f "$calls_file" ] && [ -s "$calls_file" ]
}
