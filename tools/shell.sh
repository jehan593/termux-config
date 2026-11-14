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

# Patch a rish script so its app id points at Termux. Modern exports use
# `RISH_APPLICATION_ID="PKG"`, older ones a bare `PKG="..."` line — handle both,
# and both the `PKG` placeholder and an already-set (possibly wrong) value.
# Returns 1 if no app id line was found to patch.
_set_app_id() {
    local file="$1"
    if grep -q 'RISH_APPLICATION_ID=' "$file"; then
        sed -i 's/RISH_APPLICATION_ID="[^"]*"/RISH_APPLICATION_ID="com.termux"/' "$file"
        sed -i "s/RISH_APPLICATION_ID='[^']*'/RISH_APPLICATION_ID='com.termux'/" "$file"
        printfc "$NORD_YELLOW" "Set RISH_APPLICATION_ID to com.termux in %s." "$(basename "$file")"
        return 0
    fi
    if grep -qE '^\s*PKG=' "$file"; then
        sed -i 's/^\([[:space:]]*\)PKG="[^"]*"/\1PKG="com.termux"/' "$file"
        printfc "$NORD_YELLOW" "Set application id to com.termux in %s." "$(basename "$file")"
        return 0
    fi
    return 1
}

# Copy the two exported Shizuku files out of ~/storage/shared/Download/rish/
# into $PREFIX/bin, fixing the application id and permissions so `rish` works
# with Termux (uid 2000). Returns 0 on success.
install_rish() {
    local export_dir rish_src dex_src

    printfc "$NORD_BLUE" "\n>Locating Shizuku files"
    printfc "$NORD_SNOW_1" "Export them first: Shizuku app → 'Use Shizuku in terminal apps' → 'Export files'."
    printfc "$NORD_SNOW_1" "Put 'rish' and 'rish_shizuku.dex' into a folder named 'rish' in Downloads."
    echo ""

    export_dir="$HOME/storage/shared/Download/rish"
    if [ ! -d "$export_dir" ]; then
        printfc "$NORD_RED" "Folder not found: %s" "$export_dir"
        printfc "$NORD_YELLOW" "Create it and drop the two exported files in there, then re-run 'shell setup'."
        echo ""
        return 1
    fi

    rish_src="$export_dir/rish"
    dex_src="$export_dir/rish_shizuku.dex"
    if [ ! -f "$rish_src" ] || [ ! -f "$dex_src" ]; then
        printfc "$NORD_RED" "Expected 'rish' and 'rish_shizuku.dex' in %s" "$export_dir"
        echo ""
        return 1
    fi

    # 1. Point the rish script at Termux.
    printfc "$NORD_BLUE" "\n>Installing"
    _set_app_id "$rish_src"

    # 2. Copy both files into $PREFIX/bin.
    cp "$rish_src" "$SHELL_RISH" || { printfc "$NORD_RED" "Failed to copy rish."; return 1; }
    cp "$dex_src" "$SHELL_DEX" || { printfc "$NORD_RED" "Failed to copy rish_shizuku.dex."; return 1; }
    chmod 755 "$SHELL_RISH"

    # 3. On Android 14+ app_process refuses to load a writable dex, so drop
    #    the write bit (Termux owns this file and is allowed to).
    chmod 444 "$SHELL_DEX" 2>/dev/null

    printfc "$NORD_GREEN" "Installed rish and rish_shizuku.dex into %s." "$PREFIX/bin"
    return 0
}

# Makes sure the Shizuku rish binaries are in place and that the Shizuku server
# is running. Skips the copy prompt if the files are already installed.
setup_shell() {
    printfc "$NORD_BLUE" "\n>Preflight"

    local installed=0
    if [ -x "$SHELL_RISH" ] && [ -f "$SHELL_DEX" ]; then
        installed=1
    fi

    if [ "$installed" -eq 0 ]; then
        printfc "$NORD_YELLOW" "Shizuku rish binaries not installed."
        printfc -n "$NORD_SNOW_1" "Install them now? [Y/n]: "
        read -r confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            printfc "$NORD_YELLOW" "Skipped. Run 'shell setup' again when ready."
            echo ""
            return 1
        fi
        install_rish || { echo ""; return 1; }
    else
        printfc "$NORD_GREEN" "rish already installed."
        # Re-apply the app id; an earlier broken run may have left the
        # placeholder (PKG) in place, which makes rish fail to connect.
        _set_app_id "$SHELL_RISH" || true
    fi

    if _verify_shizuku; then
        printfc "$NORD_GREEN" "Shizuku running — ADB shell available (uid=%s)." "$_SHELL_UID"
        printfc "$NORD_GREEN" "Setup complete. Run 'shell' to enter the ADB shell."
        echo ""
        return 0
    fi

    # There's no per-app permission inside Shizuku to grant here — once the
    # server is running, rish just works with whatever app id is baked into the
    # rish script. The only remaining step is starting the server.
    printfc "$NORD_YELLOW" "rish is installed but the Shizuku server is not responding."
    printfc "$NORD_SNOW_1" "Open the Shizuku app and tap the 'Start' button to launch the server."
    printfc -n "$NORD_SNOW_1" "Press Enter after starting it…"
    read -r

    if _verify_shizuku; then
        printfc "$NORD_GREEN" "Shizuku running — ADB shell available (uid=%s)." "$_SHELL_UID"
        printfc "$NORD_GREEN" "Setup complete. Run 'shell' to enter the ADB shell."
        echo ""
        return 0
    else
        printfc "$NORD_RED" "Still not responding."
        [ -n "$_SHELL_ERR" ] && printfc "$NORD_YELLOW" "rish said: %s" "$_SHELL_ERR"
        printfc "$NORD_RED" "Common causes:"
        printfc "$NORD_RED" "  - RISH_APPLICATION_ID mismatch (re-run 'shell setup' to fix the id)."
        printfc "$NORD_RED" "  - The Shizuku server is not running for this app (open Shizuku, start it)."
        printfc "$NORD_RED" "  - Battery optimization blocking the connection (disable for Termux + Shizuku)."
        echo ""
        return 1
    fi
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
    ""|open)
        if _verify_shizuku; then
            open_shell
        else
            printfc "$NORD_RED" "Shizuku shell unavailable. Run 'shell setup' first."
            exit 1
        fi
        ;;
    *)
        printfc "$NORD_SNOW_1" "setup          Verify/request Shizuku permission and install rish"
        printfc "$NORD_SNOW_1" "scripts        Pick and run a pre-built ADB script (fzf)"
        printfc "$NORD_SNOW_1" "open           Enter the Shizuku ADB shell (default)"
        echo ""
        exit 1
        ;;
esac
