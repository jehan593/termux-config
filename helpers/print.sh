# ==============================================================================
# PRINT
# ==============================================================================
export RST=$'\e[0m'

# Usage: printfc "$COLOR" "format" [args...] — same semantics as printf, wrapped in color
printfc() {
    local color="$1"
    local fmt="$2"
    shift 2
    printf "${color}${fmt}${RST}" "$@"
}
