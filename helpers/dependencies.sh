# ==============================================================================
# DEPENDENCY CHECK — requires printfc and NORD_RED
# ==============================================================================

_test_dependencies() {
    if [ $# -eq 0 ]; then
        printfc "$NORD_RED" "Error: No commands specified to test.\n"
        return 1
    fi

    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    if [ ${#missing[@]} -gt 0 ]; then
        for app in "${missing[@]}"; do
            printfc "$NORD_RED" "Missing dependency: %s\n" "$app"
        done
        return 1
    fi
    return 0
}
