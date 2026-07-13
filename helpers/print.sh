# ==============================================================================
# PRINT
# ==============================================================================
export RST=$'\e[0m'

# Usage: printfc "$COLOR" "format" [args...]     — adds a trailing newline
#        printfc -n "$COLOR" "format" [args...]  — no trailing newline (e.g. same-line prompts)
printfc() {
    local newline=1
    if [ "$1" = "-n" ]; then
        newline=0
        shift
    fi
    local color="$1"
    local fmt="$2"
    shift 2
    if [ "$newline" -eq 1 ]; then
        printf "${color}${fmt}${RST}\n" "$@"
    else
        printf "${color}${fmt}${RST}" "$@"
    fi
}
