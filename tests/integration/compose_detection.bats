#!/usr/bin/env bats

load '../helpers/common'
load '../helpers/stubs'

setup() {
    make_script_dir
}

teardown() {
    cleanup_script_dir
    teardown_stubs
}

@test "uses docker-compose when available" {
    setup_stubs
    make_docker_compose_stub
    run run_script --no-browser /tmp
    [ "$status" -eq 0 ]
    stub_called "docker-compose"
}

@test "falls back to docker compose v2 when docker-compose not available" {
    setup_stubs
    # Build a controlled PATH that has no docker-compose binary at all,
    # then add only a docker stub that supports "compose version" and "compose run"
    make_clean_docker_path
    make_docker_stub 0 0
    run run_script --no-browser /tmp
    [ "$status" -eq 0 ]
    stub_called "docker"
}

@test "exits with error when neither docker-compose nor docker compose is available" {
    setup_stubs
    # Build controlled PATH with no docker or docker-compose, then add a docker stub
    # that fails for "compose version" so the script falls through to the error
    make_clean_docker_path
    make_docker_stub 1 1
    run run_script --no-browser /tmp
    [ "$status" -ne 0 ]
    [[ "$output" == *"Docker Compose is not installed"* ]]
}

@test "error message includes install URL" {
    setup_stubs
    make_clean_docker_path
    make_docker_stub 1 1
    run run_script --no-browser /tmp
    [ "$status" -ne 0 ]
    [[ "$output" == *"docker.com"* ]] || [[ "$output" == *"install"* ]]
}

@test "passes override compose file when docker-compose.override.yml exists" {
    setup_stubs
    make_docker_compose_stub
    touch "$TMPSCRIPTDIR/docker-compose.override.yml"
    run run_script --no-browser /tmp
    [ "$status" -eq 0 ]
    [[ "$(stub_calls docker-compose)" == *"docker-compose.override.yml"* ]]
}

@test "does not pass override file when docker-compose.override.yml is absent" {
    setup_stubs
    make_docker_compose_stub
    rm -f "$TMPSCRIPTDIR/docker-compose.override.yml"
    run run_script --no-browser /tmp
    [ "$status" -eq 0 ]
    [[ "$(stub_calls docker-compose)" != *"docker-compose.override.yml"* ]]
}
