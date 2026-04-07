#!/usr/bin/env bats

load '../helpers/common'
load '../helpers/stubs'

setup() {
    make_script_dir
    setup_stubs
    make_docker_compose_stub
    REPO_A="$(mktemp -d)"
    REPO_B="$(mktemp -d)"
    REPO_C="$(mktemp -d)"
}

teardown() {
    cleanup_script_dir
    teardown_stubs
    [ -n "${REPO_A:-}" ] && rm -rf "$REPO_A"
    [ -n "${REPO_B:-}" ] && rm -rf "$REPO_B"
    [ -n "${REPO_C:-}" ] && rm -rf "$REPO_C"
}

@test "single path sets PROJECT_DIR directly" {
    run run_script --no-browser "$REPO_A"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$PROJECT_DIR" = "$REPO_A" ]
    [ "${CLAUDE_WORKING_DIR:-}" = "" ]
}

@test "two paths creates temp workspace and sets CLAUDE_WORKING_DIR" {
    run run_script --no-browser "$REPO_A" "$REPO_B"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    # PROJECT_DIR should be a temp workspace, not REPO_A
    [ "$PROJECT_DIR" != "$REPO_A" ]
    [ "$PROJECT_DIR" != "$REPO_B" ]
    # CLAUDE_WORKING_DIR should be set to /workspace/<basename of REPO_A>
    _name_a="$(basename "$REPO_A")"
    [ "$CLAUDE_WORKING_DIR" = "/workspace/$_name_a" ]
}

@test "two paths - extra volume flags include both repos" {
    run run_script --no-browser "$REPO_A" "$REPO_B"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    # EXTRA_ARGS recorded by the stub contains all docker-compose run arguments
    [[ "$EXTRA_ARGS" == *"-v"* ]]
    [[ "$EXTRA_ARGS" == *"$REPO_A"* ]]
    [[ "$EXTRA_ARGS" == *"$REPO_B"* ]]
}

@test "three paths - all repos included in volume flags" {
    run run_script --no-browser "$REPO_A" "$REPO_B" "$REPO_C"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [[ "$EXTRA_ARGS" == *"$REPO_A"* ]]
    [[ "$EXTRA_ARGS" == *"$REPO_B"* ]]
    [[ "$EXTRA_ARGS" == *"$REPO_C"* ]]
}

@test "three paths - CLAUDE_WORKING_DIR set to first repo" {
    run run_script --no-browser "$REPO_A" "$REPO_B" "$REPO_C"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    _name_a="$(basename "$REPO_A")"
    [ "$CLAUDE_WORKING_DIR" = "/workspace/$_name_a" ]
}

@test "temp workspace is cleaned up after exit" {
    run run_script --no-browser "$REPO_A" "$REPO_B"
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    _temp_ws="$PROJECT_DIR"
    # The script should have removed the temp workspace on exit
    [ ! -d "$_temp_ws" ]
}
