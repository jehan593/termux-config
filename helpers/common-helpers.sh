# ==============================================================================
# NORD COLOR PALETTE — sourced by anything that sources common-helpers.sh:
# bashrc, blk.sh, wpm.sh, yearwall.sh
# ==============================================================================
export NORD_POLAR_1=$'\e[38;2;46;52;64m'
export NORD_POLAR_4=$'\e[38;2;76;86;106m'
export NORD_SNOW_1=$'\e[38;2;216;222;233m'
export NORD_SNOW_3=$'\e[38;2;236;239;244m'
export NORD_CYAN=$'\e[38;2;143;188;187m'
export NORD_BLUE=$'\e[38;2;136;192;208m'
export NORD_D_BLUE=$'\e[38;2;129;161;193m'
export NORD_GREEN=$'\e[38;2;163;190;140m'
export NORD_YELLOW=$'\e[38;2;235;203;139m'
export NORD_RED=$'\e[38;2;191;97;106m'
export NORD_ORANGE=$'\e[38;2;208;135;112m'
export RST=$'\e[0m'

_print_header() {
    echo -e "\n${NORD_CYAN}${1}${NORD_SNOW_1}${2}${RST}"
    echo -e "${NORD_POLAR_4}────────────────────────────────────────${RST}"
}

_print_status() {
    local color
    case "$1" in
        "success") color=$NORD_GREEN  ;;
        "error")   color=$NORD_RED    ;;
        "warning") color=$NORD_ORANGE ;;
        *)         color=$NORD_BLUE    ;;
    esac
    echo -e "${color}${2}${RST}"
}

_test_dependencies() {
    if [ $# -eq 0 ]; then
        _print_status "error" "Error: No commands specified to test."
        return 1
    fi

    local missing=()

    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        for app in "${missing[@]}"; do
            _print_status "error" "Missing dependency: $app"
        done
        return 1
    fi
    return 0
}
