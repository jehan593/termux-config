# ==============================================================================
# DEPENDENCY CHECK — requires printfc and NORD_RED
# ==============================================================================

_test_dependencies() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    if [ ${#missing[@]} -gt 0 ]; then
        for app in "${missing[@]}"; do
            printfc "$NORD_RED" "Missing dependency: %s" "$app"
        done
        return 1
    fi
    return 0
}
