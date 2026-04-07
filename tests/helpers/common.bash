SCRIPT_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$SCRIPT_REPO_DIR/claude-safe.sh"

make_script_dir() {
    TMPSCRIPTDIR="$(mktemp -d)"
    cp "$SCRIPT" "$TMPSCRIPTDIR/claude-safe.sh"
    cp "$SCRIPT_REPO_DIR/docker-compose.yml" "$TMPSCRIPTDIR/docker-compose.yml"
    # Create minimal .env (no PROJECT_DIR, no GIT_PARENT_REPO)
    echo "ANTHROPIC_API_KEY=" > "$TMPSCRIPTDIR/.env"
}

cleanup_script_dir() {
    [ -n "${TMPSCRIPTDIR:-}" ] && rm -rf "$TMPSCRIPTDIR" || true
}

run_script() {
    bash "${TMPSCRIPTDIR:-$SCRIPT_REPO_DIR}/claude-safe.sh" "$@"
}
