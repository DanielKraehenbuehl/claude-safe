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

@test "--no-browser skips xhost call" {
    run run_script --no-browser /tmp
    [ "$status" -eq 0 ]
    # xhost should NOT have been called
    ! stub_called "xhost"
}

@test "no browser setup when xdg-open not in PATH" {
    # Don't create xdg-open stub, so it's absent from PATH
    # Run without --no-browser flag
    run run_script /tmp
    [ "$status" -eq 0 ]
    # xhost should NOT have been called since xdg-open is absent
    ! stub_called "xhost"
    # compose-env.sh should not have CLAUDE_BROWSER_SOCKET set
    if [ -f "$STUB_CALLS_DIR/compose-env.sh" ]; then
        source "$STUB_CALLS_DIR/compose-env.sh"
        [ -z "${CLAUDE_BROWSER_SOCKET:-}" ]
    fi
}

@test "browser setup passes socket to docker-compose when xdg-open and xhost available" {
    make_stub "xdg-open"
    make_stub "xhost"
    # Run without --no-browser, DISPLAY set to :0
    DISPLAY=:0 run run_script /tmp
    [ "$status" -eq 0 ]
    # EXTRA_ARGS recorded by the stub should include CLAUDE_BROWSER_SOCKET
    [ -f "$STUB_CALLS_DIR/compose-env.sh" ]
    source "$STUB_CALLS_DIR/compose-env.sh"
    [[ "$EXTRA_ARGS" == *"CLAUDE_BROWSER_SOCKET"* ]]
}

@test "xhost failure doesn't prevent script from running" {
    make_stub "xdg-open"
    # xhost stub exits 1 (failure)
    make_stub "xhost" 1
    DISPLAY=:0 run run_script /tmp
    [ "$status" -eq 0 ]
}
