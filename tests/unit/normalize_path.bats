#!/usr/bin/env bats

load '../helpers/common'

setup() {
    # Source both helper functions from the script
    eval "$(sed -n '/^win_to_wsl_path()/,/^}$/p' "$SCRIPT")"
    eval "$(sed -n '/^normalize_path()/,/^}$/p' "$SCRIPT")"
}

@test "resolves valid linux directory to absolute path" {
    result=$(normalize_path "/tmp")
    [ "$result" = "/tmp" ]
}

@test "returns error for nonexistent directory" {
    run normalize_path "/no/such/dir/xyz123"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: Directory not found"* ]]
}

@test "resolves WSL UNC path wsl\$ style" {
    # //wsl$/Ubuntu/tmp -> strip distro (Ubuntu), get /tmp
    result=$(normalize_path "//wsl\$/Ubuntu/tmp")
    [ "$result" = "/tmp" ]
}

@test "resolves WSL UNC path wsl.localhost style" {
    # //wsl.localhost/Ubuntu/tmp -> /tmp
    result=$(normalize_path "//wsl.localhost/Ubuntu/tmp")
    [ "$result" = "/tmp" ]
}

@test "resolves WSL UNC bare distro to root" {
    # //wsl$/Ubuntu (no path after distro) -> /
    result=$(normalize_path "//wsl\$/Ubuntu")
    [ "$result" = "/" ]
}

@test "returns error for network UNC path" {
    run normalize_path "//myserver/share"
    [ "$status" -ne 0 ]
    [[ "$output" == *"UNC network paths"* ]]
}

@test "converts Windows drive path before resolving - errors when drive not mounted" {
    # /mnt/c probably doesn't exist on this Linux system
    run normalize_path "C:/tmp"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Directory not found"* ]]
    [[ "$output" == *"/mnt/c"* ]]
}
