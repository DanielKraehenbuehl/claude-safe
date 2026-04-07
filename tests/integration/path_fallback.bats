#!/usr/bin/env bats

load '../helpers/common'
load '../helpers/stubs'

setup() {
    make_script_dir
    setup_stubs
    make_docker_compose_stub
}

teardown() {
    cleanup_script_dir
    teardown_stubs
}

@test "uses current directory when no args given" {
    # Run with --no-browser from /tmp so cwd resolves to /tmp
    run bash -c "cd /tmp && bash '$TMPSCRIPTDIR/claude-safe.sh' --no-browser"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$PROJECT_DIR" = "/tmp" ]
}

@test "explicit path overrides cwd" {
    run run_script --no-browser /tmp
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$PROJECT_DIR" = "/tmp" ]
}

@test "reads PROJECT_DIR from .env when no args given" {
    # Write PROJECT_DIR to .env
    printf "ANTHROPIC_API_KEY=\nPROJECT_DIR=/tmp\n" > "$TMPSCRIPTDIR/.env"
    # Run with --no-browser but no path args (subshell to avoid cwd affecting things)
    run bash -c "cd / && bash '$TMPSCRIPTDIR/claude-safe.sh' --no-browser"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$PROJECT_DIR" = "/tmp" ]
}

@test "explicit path overrides PROJECT_DIR from .env" {
    # Write a different dir to .env
    printf "ANTHROPIC_API_KEY=\nPROJECT_DIR=/var\n" > "$TMPSCRIPTDIR/.env"
    run run_script --no-browser /tmp
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$PROJECT_DIR" = "/tmp" ]
}

@test "reads double-quoted PROJECT_DIR from .env" {
    printf 'ANTHROPIC_API_KEY=\nPROJECT_DIR="/tmp"\n' > "$TMPSCRIPTDIR/.env"
    run bash -c "cd / && bash '$TMPSCRIPTDIR/claude-safe.sh' --no-browser"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$PROJECT_DIR" = "/tmp" ]
}

@test "reads single-quoted PROJECT_DIR from .env" {
    printf "ANTHROPIC_API_KEY=\nPROJECT_DIR='/tmp'\n" > "$TMPSCRIPTDIR/.env"
    run bash -c "cd / && bash '$TMPSCRIPTDIR/claude-safe.sh' --no-browser"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$PROJECT_DIR" = "/tmp" ]
}
