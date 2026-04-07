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

@test "--help exits 0 and shows usage" {
    run run_script --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "-h exits 0 and shows usage" {
    run run_script -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "--no-browser is accepted without error" {
    run run_script --no-browser /tmp
    [ "$status" -eq 0 ]
}

@test "invalid path exits nonzero with error message" {
    run run_script --no-browser /no/such/path/xyz987
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error"* ]]
}

@test "valid path argument is accepted" {
    run run_script --no-browser /tmp
    [ "$status" -eq 0 ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [ "$PROJECT_DIR" = "/tmp" ]
}
