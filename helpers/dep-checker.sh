# ==============================================================================
# DEPENDENCY CHECK — silent: communicates via return code and _MISSING_DEPS,
# callers own presentation.
# ==============================================================================

_MISSING_DEPS=()

_test_dependencies() {
    _MISSING_DEPS=()
    local cmd
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || _MISSING_DEPS+=("$cmd")
    done
    [ ${#_MISSING_DEPS[@]} -eq 0 ]
}
