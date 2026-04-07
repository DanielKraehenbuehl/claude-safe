#!/usr/bin/env bats

# Source only the function definitions; inline execution is guarded by BATS_TESTING=1.
load_functions() {
    # shellcheck source=/dev/null
    BATS_TESTING=1 source "$START_CLAUDE"
}

setup() {
    START_CLAUDE="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/start-claude.sh"
    FAKE_HOST="$(mktemp -d)"
    FAKE_TARGET="$(mktemp -d)"
    export START_CLAUDE FAKE_HOST FAKE_TARGET
}

teardown() {
    [ -n "${FAKE_HOST:-}"   ] && rm -rf "$FAKE_HOST"
    [ -n "${FAKE_TARGET:-}" ] && rm -rf "$FAKE_TARGET"
    [ -n "${FAKE_GIT_CFG:-}" ] && rm -f "$FAKE_GIT_CFG"
    unset GH_TOKEN AZURE_FEED_PAT _TEST_ASKPASS GIT_CONFIG_GLOBAL
    unset _TEST_HOST_SSH _TEST_TARGET_SSH
    unset _TEST_GITCONFIG_SRC _TEST_GITCONFIG_TARGET
    unset _TEST_HOST_CLAUDE _TEST_TARGET_CLAUDE _TEST_CLAUDE_SETTINGS
}

# ---------------------------------------------------------------------------
# extract_worktree_name
# ---------------------------------------------------------------------------

@test "extract_worktree_name: returns basename of forward-slash path" {
    load_functions
    result="$(extract_worktree_name "/some/path/to/feat-branch")"
    [ "$result" = "feat-branch" ]
}

@test "extract_worktree_name: converts backslashes before extracting basename" {
    load_functions
    result="$(extract_worktree_name 'D:\repos\myproject\.git\worktrees\my-feature')"
    [ "$result" = "my-feature" ]
}

@test "extract_worktree_name: mixed slashes" {
    load_functions
    result="$(extract_worktree_name 'D:/repos/project/.git/worktrees/fix-123')"
    [ "$result" = "fix-123" ]
}

# ---------------------------------------------------------------------------
# sync_host_ssh
# ---------------------------------------------------------------------------

@test "sync_host_ssh: does nothing when host-ssh directory does not exist" {
    load_functions
    export _TEST_HOST_SSH="$FAKE_HOST/nonexistent"
    export _TEST_TARGET_SSH="$FAKE_TARGET/ssh"
    sync_host_ssh
    [ ! -d "$FAKE_TARGET/ssh" ]
}

@test "sync_host_ssh: copies SSH keys and sets permissions" {
    load_functions
    export _TEST_HOST_SSH="$FAKE_HOST/ssh"
    export _TEST_TARGET_SSH="$FAKE_TARGET/ssh"
    mkdir -p "$FAKE_HOST/ssh"
    echo "PRIVATE KEY" > "$FAKE_HOST/ssh/id_ed25519"
    echo "PUBLIC KEY"  > "$FAKE_HOST/ssh/id_ed25519.pub"
    sync_host_ssh
    [ -d "$FAKE_TARGET/ssh" ]
    [ "$(stat -c '%a' "$FAKE_TARGET/ssh")" = "700" ]
    [ -f "$FAKE_TARGET/ssh/id_ed25519" ]
    [ -f "$FAKE_TARGET/ssh/id_ed25519.pub" ]
    [ "$(stat -c '%a' "$FAKE_TARGET/ssh/id_ed25519")" = "600" ]
    [ "$(stat -c '%a' "$FAKE_TARGET/ssh/id_ed25519.pub")" = "600" ]
}

@test "sync_host_ssh: merges known_hosts without duplicates" {
    load_functions
    export _TEST_HOST_SSH="$FAKE_HOST/ssh"
    export _TEST_TARGET_SSH="$FAKE_TARGET/ssh"
    mkdir -p "$FAKE_HOST/ssh" "$FAKE_TARGET/ssh"
    echo "github.com ssh-ed25519 AAAA1111" >  "$FAKE_HOST/ssh/known_hosts"
    echo "github.com ssh-ed25519 AAAA1111" >  "$FAKE_TARGET/ssh/known_hosts"
    echo "gitlab.com ssh-ed25519 BBBB2222" >> "$FAKE_HOST/ssh/known_hosts"
    sync_host_ssh
    # Should contain both unique lines, but not the duplicate
    count="$(grep -c "github.com" "$FAKE_TARGET/ssh/known_hosts")"
    [ "$count" -eq 1 ]
    grep -q "gitlab.com" "$FAKE_TARGET/ssh/known_hosts"
}

@test "sync_host_ssh: skips known_hosts and known_hosts.old as regular files" {
    load_functions
    export _TEST_HOST_SSH="$FAKE_HOST/ssh"
    export _TEST_TARGET_SSH="$FAKE_TARGET/ssh"
    mkdir -p "$FAKE_HOST/ssh"
    echo "entry" > "$FAKE_HOST/ssh/known_hosts"
    echo "entry" > "$FAKE_HOST/ssh/known_hosts.old"
    sync_host_ssh
    # known_hosts.old should NOT be copied as a regular file (only known_hosts
    # is handled via the merge path; known_hosts.old is explicitly skipped)
    [ ! -f "$FAKE_TARGET/ssh/known_hosts.old" ]
}

# ---------------------------------------------------------------------------
# sync_host_gitconfig
# ---------------------------------------------------------------------------

@test "sync_host_gitconfig: warns when src is a directory (Docker empty-mount)" {
    load_functions
    export _TEST_GITCONFIG_SRC="$FAKE_HOST/gitconfig-dir"
    export _TEST_GITCONFIG_TARGET="$FAKE_TARGET/.gitconfig"
    mkdir -p "$FAKE_HOST/gitconfig-dir"
    run sync_host_gitconfig
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [ ! -f "$FAKE_TARGET/.gitconfig" ]
}

@test "sync_host_gitconfig: copies file and strips credential section" {
    load_functions
    export _TEST_GITCONFIG_SRC="$FAKE_HOST/.gitconfig"
    export _TEST_GITCONFIG_TARGET="$FAKE_TARGET/.gitconfig"
    cat > "$FAKE_HOST/.gitconfig" << 'EOF'
[user]
    name = Test User
    email = test@example.com
[credential]
    helper = manager
EOF
    sync_host_gitconfig
    [ -f "$FAKE_TARGET/.gitconfig" ]
    grep -q "Test User" "$FAKE_TARGET/.gitconfig"
    grep -q "test@example.com" "$FAKE_TARGET/.gitconfig"
    # credential section must be removed
    ! grep -q "helper" "$FAKE_TARGET/.gitconfig"
}

@test "sync_host_gitconfig: does nothing when src does not exist" {
    load_functions
    export _TEST_GITCONFIG_SRC="$FAKE_HOST/no-such-file"
    export _TEST_GITCONFIG_TARGET="$FAKE_TARGET/.gitconfig"
    sync_host_gitconfig
    [ ! -f "$FAKE_TARGET/.gitconfig" ]
}

# ---------------------------------------------------------------------------
# setup_git_credentials
# ---------------------------------------------------------------------------

@test "setup_git_credentials: does not create askpass when no tokens set" {
    load_functions
    FAKE_GIT_CFG="$(mktemp)"
    export GIT_CONFIG_GLOBAL="$FAKE_GIT_CFG"
    export _TEST_ASKPASS="$FAKE_TARGET/git-askpass"
    unset GH_TOKEN AZURE_FEED_PAT
    setup_git_credentials
    [ ! -f "$FAKE_TARGET/git-askpass" ]
}

@test "setup_git_credentials: creates executable askpass when GH_TOKEN is set" {
    load_functions
    FAKE_GIT_CFG="$(mktemp)"
    export GIT_CONFIG_GLOBAL="$FAKE_GIT_CFG"
    export _TEST_ASKPASS="$FAKE_TARGET/git-askpass"
    export GH_TOKEN="ghp_test123"
    # Call directly (not via `run`) so GIT_ASKPASS export is visible in this shell.
    setup_git_credentials
    [ -f "$FAKE_TARGET/git-askpass" ]
    [ -x "$FAKE_TARGET/git-askpass" ]
    [ "$GIT_ASKPASS" = "$FAKE_TARGET/git-askpass" ]
}

@test "setup_git_credentials: askpass echoes GH_TOKEN for github.com prompts" {
    load_functions
    FAKE_GIT_CFG="$(mktemp)"
    export GIT_CONFIG_GLOBAL="$FAKE_GIT_CFG"
    export _TEST_ASKPASS="$FAKE_TARGET/git-askpass"
    export GH_TOKEN="ghp_secret"
    setup_git_credentials
    result="$(GH_TOKEN=ghp_secret "$FAKE_TARGET/git-askpass" "Password for github.com")"
    [ "$result" = "ghp_secret" ]
}

@test "setup_git_credentials: askpass echoes AZURE_FEED_PAT for dev.azure.com prompts" {
    load_functions
    FAKE_GIT_CFG="$(mktemp)"
    export GIT_CONFIG_GLOBAL="$FAKE_GIT_CFG"
    export _TEST_ASKPASS="$FAKE_TARGET/git-askpass"
    export AZURE_FEED_PAT="azure_secret"
    setup_git_credentials
    result="$(AZURE_FEED_PAT=azure_secret "$FAKE_TARGET/git-askpass" "Password for dev.azure.com")"
    [ "$result" = "azure_secret" ]
}

@test "setup_git_credentials: askpass echoes AZURE_FEED_PAT for visualstudio.com prompts" {
    load_functions
    FAKE_GIT_CFG="$(mktemp)"
    export GIT_CONFIG_GLOBAL="$FAKE_GIT_CFG"
    export _TEST_ASKPASS="$FAKE_TARGET/git-askpass"
    export AZURE_FEED_PAT="vs_secret"
    setup_git_credentials
    result="$(AZURE_FEED_PAT=vs_secret "$FAKE_TARGET/git-askpass" "Password for myorg.visualstudio.com")"
    [ "$result" = "vs_secret" ]
}

# ---------------------------------------------------------------------------
# sync_host_claude_auth
# ---------------------------------------------------------------------------

@test "sync_host_claude_auth: does nothing when credentials file missing" {
    load_functions
    export _TEST_HOST_CLAUDE="$FAKE_HOST/claude"
    export _TEST_TARGET_CLAUDE="$FAKE_TARGET/claude"
    mkdir -p "$FAKE_HOST/claude"
    sync_host_claude_auth
    [ ! -f "$FAKE_TARGET/claude/.credentials.json" ]
}

@test "sync_host_claude_auth: copies credentials with mode 600" {
    load_functions
    export _TEST_HOST_CLAUDE="$FAKE_HOST/claude"
    export _TEST_TARGET_CLAUDE="$FAKE_TARGET/claude"
    mkdir -p "$FAKE_HOST/claude"
    echo '{"token":"abc"}' > "$FAKE_HOST/claude/.credentials.json"
    sync_host_claude_auth
    [ -f "$FAKE_TARGET/claude/.credentials.json" ]
    [ "$(stat -c '%a' "$FAKE_TARGET/claude/.credentials.json")" = "600" ]
    grep -q '"token"' "$FAKE_TARGET/claude/.credentials.json"
}

# ---------------------------------------------------------------------------
# sync_host_claude_settings
# ---------------------------------------------------------------------------

@test "sync_host_claude_settings: does nothing when settings file missing" {
    load_functions
    export _TEST_HOST_CLAUDE="$FAKE_HOST/claude"
    export _TEST_TARGET_CLAUDE="$FAKE_TARGET/claude"
    mkdir -p "$FAKE_HOST/claude"
    sync_host_claude_settings
    [ ! -f "$FAKE_TARGET/claude/settings.json" ]
}

@test "sync_host_claude_settings: copies settings with mode 644" {
    load_functions
    export _TEST_HOST_CLAUDE="$FAKE_HOST/claude"
    export _TEST_TARGET_CLAUDE="$FAKE_TARGET/claude"
    mkdir -p "$FAKE_HOST/claude"
    echo '{"theme":"dark"}' > "$FAKE_HOST/claude/settings.json"
    sync_host_claude_settings
    [ -f "$FAKE_TARGET/claude/settings.json" ]
    [ "$(stat -c '%a' "$FAKE_TARGET/claude/settings.json")" = "644" ]
    grep -q '"theme"' "$FAKE_TARGET/claude/settings.json"
}

# ---------------------------------------------------------------------------
# ensure_superpowers_plugin
# ---------------------------------------------------------------------------

@test "ensure_superpowers_plugin: creates settings.json with plugin enabled when missing" {
    load_functions
    export _TEST_TARGET_CLAUDE="$FAKE_TARGET/claude"
    export _TEST_CLAUDE_SETTINGS="$FAKE_TARGET/claude/settings.json"
    ensure_superpowers_plugin
    [ -f "$FAKE_TARGET/claude/settings.json" ]
    grep -q '"superpowers@claude-plugins-official"' "$FAKE_TARGET/claude/settings.json"
    grep -q 'true' "$FAKE_TARGET/claude/settings.json"
}

@test "ensure_superpowers_plugin: adds plugin to existing settings without overwriting other keys" {
    load_functions
    export _TEST_TARGET_CLAUDE="$FAKE_TARGET/claude"
    export _TEST_CLAUDE_SETTINGS="$FAKE_TARGET/claude/settings.json"
    mkdir -p "$FAKE_TARGET/claude"
    echo '{"theme":"dark","enabledPlugins":{}}' > "$FAKE_TARGET/claude/settings.json"
    ensure_superpowers_plugin
    grep -q '"theme"' "$FAKE_TARGET/claude/settings.json"
    grep -q '"superpowers@claude-plugins-official".*true' "$FAKE_TARGET/claude/settings.json"
}

@test "ensure_superpowers_plugin: is idempotent when plugin already enabled" {
    load_functions
    export _TEST_TARGET_CLAUDE="$FAKE_TARGET/claude"
    export _TEST_CLAUDE_SETTINGS="$FAKE_TARGET/claude/settings.json"
    mkdir -p "$FAKE_TARGET/claude"
    echo '{"enabledPlugins":{"superpowers@claude-plugins-official":true}}' > "$FAKE_TARGET/claude/settings.json"
    ensure_superpowers_plugin
    count="$(grep -c '"superpowers@claude-plugins-official"' "$FAKE_TARGET/claude/settings.json")"
    [ "$count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# check_credentials_expiry
# ---------------------------------------------------------------------------

@test "check_credentials_expiry: warns when credentials file is absent" {
    load_functions
    export _TEST_CREDS="$FAKE_TARGET/no-such-file.json"
    run check_credentials_expiry
    [ "$status" -eq 0 ]
    [[ "$output" == *"No Claude credentials found"* ]]
}

@test "check_credentials_expiry: warns when token is expired" {
    load_functions
    CREDS="$FAKE_TARGET/creds.json"
    # expiresAt in the past (epoch 1 in ms)
    echo '{"claudeAiOauth":{"expiresAt":1}}' > "$CREDS"
    export _TEST_CREDS="$CREDS"
    run check_credentials_expiry
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXPIRED"* ]]
}

@test "check_credentials_expiry: silent when token is still valid" {
    load_functions
    CREDS="$FAKE_TARGET/creds.json"
    # expiresAt far in the future (year 2099 in ms)
    echo '{"claudeAiOauth":{"expiresAt":4070908800000}}' > "$CREDS"
    export _TEST_CREDS="$CREDS"
    run check_credentials_expiry
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "check_credentials_expiry: silent when credentials have no expiresAt" {
    load_functions
    CREDS="$FAKE_TARGET/creds.json"
    echo '{"claudeAiOauth":{}}' > "$CREDS"
    export _TEST_CREDS="$CREDS"
    run check_credentials_expiry
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "check_credentials_expiry: silent when credentials use API key format (no oauth block)" {
    load_functions
    CREDS="$FAKE_TARGET/creds.json"
    echo '{"apiKey":"sk-ant-test"}' > "$CREDS"
    export _TEST_CREDS="$CREDS"
    run check_credentials_expiry
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
