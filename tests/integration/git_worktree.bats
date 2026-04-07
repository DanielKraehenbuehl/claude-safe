#!/usr/bin/env bats

load '../helpers/common'
load '../helpers/stubs'

setup() {
    make_script_dir
    setup_stubs
    make_docker_compose_stub
    # Ensure GIT_PARENT_REPO is not set in environment
    unset GIT_PARENT_REPO
}

teardown() {
    cleanup_script_dir
    teardown_stubs
    [ -n "${FAKE_REPO:-}" ] && rm -rf "$FAKE_REPO" || true
    [ -n "${FAKE_PARENT:-}" ] && rm -rf "$FAKE_PARENT" || true
}

@test "regular repo - no worktree detection, GIT_PARENT_REPO equals primary path" {
    FAKE_REPO="$(mktemp -d)"
    mkdir "$FAKE_REPO/.git"
    run run_script --no-browser "$FAKE_REPO"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$GIT_PARENT_REPO" = "$FAKE_REPO" ]
}

@test "worktree - detects parent from .git file" {
    FAKE_PARENT="$(mktemp -d)"
    FAKE_REPO="$(mktemp -d)"
    mkdir -p "$FAKE_PARENT/.git/worktrees/feat"
    echo "gitdir: $FAKE_PARENT/.git/worktrees/feat" > "$FAKE_REPO/.git"
    run run_script --no-browser "$FAKE_REPO"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git worktree detected"* ]]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$GIT_PARENT_REPO" = "$FAKE_PARENT" ]
}

@test "GIT_PARENT_REPO env var takes precedence over worktree detection" {
    FAKE_PARENT="$(mktemp -d)"
    FAKE_REPO="$(mktemp -d)"
    mkdir "$FAKE_REPO/.git"
    export GIT_PARENT_REPO="$FAKE_PARENT"
    run run_script --no-browser "$FAKE_REPO"
    unset GIT_PARENT_REPO
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$GIT_PARENT_REPO" = "$FAKE_PARENT" ]
}

@test "GIT_PARENT_REPO from .env is used when env var not set" {
    FAKE_PARENT="$(mktemp -d)"
    FAKE_REPO="$(mktemp -d)"
    mkdir "$FAKE_REPO/.git"
    printf "ANTHROPIC_API_KEY=\nGIT_PARENT_REPO=%s\n" "$FAKE_PARENT" > "$TMPSCRIPTDIR/.env"
    run run_script --no-browser "$FAKE_REPO"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$GIT_PARENT_REPO" = "$FAKE_PARENT" ]
}
