#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# SHELL MANAGER — Shizuku-backed ADB shell for Termux
# ==============================================================================
source "$TERMUX_CONFIG_PATH/helpers/colors-nord.sh"
source "$TERMUX_CONFIG_PATH/helpers/printer.sh"
source "$TERMUX_CONFIG_PATH/helpers/dep-checker.sh"
source "$TERMUX_CONFIG_PATH/helpers/shell-helper.sh"

if ! _test_dependencies "fzf"; then
    printfc "$NORD_RED" "Missing dependencies: %s" "${_MISSING_DEPS[*]}"
    exit 1
fi

SCRIPTS_DIR="$TERMUX_CONFIG_PATH/data/shell/scripts"
SHIZUKU_PKG="moe.shizuku.privileged.api"

# --- Actions ---

# Open an interactive ADB shell backed by Shizuku (rish).
open_shell() {
    if ! _verify_shizuku; then
        printfc "$NORD_RED" "Shizuku shell unavailable. Run 'shell setup' first."
        exit 1
    fi
    printfc "$NORD_GREEN" "Entering Shizuku ADB shell (uid=shell). Type 'exit' to return."
    echo ""
    "$SHELL_RISH"
}

# Verify rish is in place and that Shizuku is running + granted; if not, launch
# the Shizuku grant flow and re-verify.
setup_shell() {
    printfc "$NORD_BLUE" "\n>Preflight"

    if [ ! -x "$SHELL_RISH" ]; then
        printfc "$NORD_RED" "rish not found at %s." "$SHELL_RISH"
        printfc "$NORD_YELLOW" "Import it: Shizuku app → 'Use Shizuku in terminal apps' → 'Export files'."
        printfc "$NORD_YELLOW" "Copy the exported 'rish' and 'rish_shizuku.dex' into %s ." "$PREFIX/bin"
        return 1
    fi
    if [ ! -f "$SHELL_DEX" ]; then
        printfc "$NORD_RED" "rish_shizuku.dex not found at %s." "$SHELL_DEX"
        return 1
    fi
    printfc "$NORD_GREEN" "rish binaries present."

    if _verify_shizuku; then
        printfc "$NORD_GREEN" "Shizuku running with shell permission (uid=%s)." "$_SHELL_UID"
        printfc "$NORD_GREEN" "Setup complete. Run 'shell' to enter the ADB shell."
        echo ""
        return 0
    fi

    printfc "$NORD_YELLOW" "Shizuku not running or shell permission not granted yet."
    printfc -n "$NORD_SNOW_1" "Open the Shizuku app to start the server and grant permission? [Y/n]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        printfc "$NORD_YELLOW" "Skipped. Run 'shell setup' again after granting permission."
        echo ""
        return 1
    fi

    printfc "$NORD_SNOW_1" "Opening Shizuku…"
    if command -v am >/dev/null 2>&1; then
        am start -n "$SHIZUKU_PKG/moe.shizuku.privileged.api.MainActivity" >/dev/null 2>&1
    elif command -v termux-open >/dev/null 2>&1; then
        termux-open "app://$SHIZUKU_PKG" >/dev/null 2>&1
    else
        printfc "$NORD_YELLOW" "Please open the Shizuku app manually."
    fi

    printfc "$NORD_SNOW_1" "In Shizuku: start the server, then enable/confirm 'Use Shizuku in terminal apps' for Termux."
    printfc -n "$NORD_SNOW_1" "Press Enter once granted…"
    read -r

    if _verify_shizuku; then
        printfc "$NORD_GREEN" "Shizuku running with shell permission (uid=%s)." "$_SHELL_UID"
        printfc "$NORD_GREEN" "Setup complete. Run 'shell' to enter the ADB shell."
    else
        printfc "$NORD_RED" "Still unavailable. Confirm Shizuku is running and Termux is granted, then retry."
    fi
    echo ""
}

# Pick and run a pre-built ADB command script.
run_scripts() {
    local scripts
    if ! compgen -G "$SCRIPTS_DIR/*.sh" >/dev/null; then
        printfc "$NORD_YELLOW" "No scripts found in %s" "$SCRIPTS_DIR"
        echo ""
        return 0
    fi

    scripts=$(for f in "$SCRIPTS_DIR"/*.sh; do
        printf "%s\n" "$(basename "$f" .sh)"
    done | sort | fzf \
        --header="Select an ADB script to run (ENTER to run, ESC to cancel)" \
        --prompt="Script > " \
        --color="16,header:4,prompt:6,pointer:2,hl:2")

    if [ -z "$scripts" ]; then
        printfc "$NORD_YELLOW" "Cancelled."
        echo ""
        return 0
    fi

    local script_file="$SCRIPTS_DIR/${scripts}.sh"
    if [ ! -f "$script_file" ]; then
        printfc "$NORD_RED" "Script not found: %s" "$script_file"
        return 1
    fi

    bash "$script_file"
}

# --- Router ---
case "$1" in
    setup)   setup_shell ;;
    scripts) run_scripts ;;
    *)
        if _verify_shizuku; then
            open_shell
        else
            echo "setup     Verify/request Shizuku permission and install rish"
            echo "scripts   Pick and run a pre-built ADB script (fzf)"
            echo ""
            printfc "$NORD_RED" "Shizuku shell unavailable. Run 'shell setup' first."
            exit 1
        fi
        ;;
esac
