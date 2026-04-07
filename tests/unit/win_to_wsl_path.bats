#!/usr/bin/env bats

load '../helpers/common'

setup() {
    # Source just the win_to_wsl_path function from the script
    eval "$(sed -n '/^win_to_wsl_path()/,/^}$/p' "$SCRIPT")"
}

@test "passes through plain linux paths unchanged" {
    result=$(win_to_wsl_path "/home/user/repo")
    [ "$result" = "/home/user/repo" ]
}

@test "converts Windows drive letter with forward slash" {
    result=$(win_to_wsl_path "D:/code/repo")
    [ "$result" = "/mnt/d/code/repo" ]
}

@test "converts Windows drive letter with backslash" {
    result=$(win_to_wsl_path 'D:\code\repo')
    [ "$result" = "/mnt/d/code/repo" ]
}

@test "converts uppercase drive letter to lowercase" {
    result=$(win_to_wsl_path "C:/Users/foo")
    [ "$result" = "/mnt/c/Users/foo" ]
}

@test "handles mixed slashes" {
    result=$(win_to_wsl_path 'D:\code/repo\sub')
    [ "$result" = "/mnt/d/code/repo/sub" ]
}

@test "handles root of drive" {
    result=$(win_to_wsl_path "C:/")
    [ "$result" = "/mnt/c/" ]
}
