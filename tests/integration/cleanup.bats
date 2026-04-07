#!/usr/bin/env bats

load '../helpers/common'
load '../helpers/stubs'

setup() {
    make_script_dir
    setup_stubs
    make_docker_compose_stub
    REPO_A="$(mktemp -d)"
    REPO_B="$(mktemp -d)"
}

teardown() {
    cleanup_script_dir
    teardown_stubs
    [ -n "${REPO_A:-}" ] && rm -rf "$REPO_A" 2>/dev/null || true
    [ -n "${REPO_B:-}" ] && rm -rf "$REPO_B" 2>/dev/null || true
}

@test "multi-repo temp workspace is removed after exit" {
    run run_script --no-browser "$REPO_A" "$REPO_B"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    _temp_ws="$PROJECT_DIR"
    # The temp workspace dir should be gone after the script exits
    [ ! -d "$_temp_ws" ]
}

@test "socket file is removed after exit" {
    make_stub "xdg-open"
    make_stub "xhost"
    DISPLAY=:0 run run_script "$REPO_A"
    [ "$status" -eq 0 ]
    if [ -f "$STUB_CALLS_DIR/compose-env.sh" ]; then
        source "$STUB_CALLS_DIR/compose-env.sh"
        # Extract socket path from EXTRA_ARGS: -e CLAUDE_BROWSER_SOCKET=/tmp/claude-browser-XXXXXX.sock
        _sock_path=""
        if [[ "$EXTRA_ARGS" =~ CLAUDE_BROWSER_SOCKET=([^[:space:]]+) ]]; then
            _sock_path="${BASH_REMATCH[1]}"
        fi
        if [ -n "$_sock_path" ]; then
            # Socket file should have been cleaned up by the trap
            [ ! -e "$_sock_path" ]
        fi
    fi
}
