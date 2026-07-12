#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# SHARED HELPERS — sourced by setup.sh and reset.sh
# ==============================================================================

# Colors (Nord/Basic hybrid ANSI)
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
CYAN='\e[36m'
RST='\e[0m'

# Packages installed by setup.sh (referenced by reset.sh for its removal note)
SETUP_PKGS="termux-api procps git openssh termux-services zoxide starship fzf imagemagick cronie wireproxy fd neovim topgrade tealdeer python-trash-cli"

_print_header() {
    echo -e "\n${CYAN}${1}${RST}"
    echo -e "${CYAN}────────────────────────────────────────${RST}"
}

ok() {
    echo -e "${GREEN}${1}${RST}"
}

err() {
    echo -e "${RED}${1}${RST}"
}

warn() {
    echo -e "${YELLOW}${1}${RST}"
}

ask() {
    printf "${YELLOW}%s [y/N]: ${RST}" "$1"
    read -r _ans
    [[ "$_ans" =~ ^[Yy]$ ]]
}