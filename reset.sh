#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# TERMUX CONFIG RESET
# ==============================================================================
CONFIG_PATH="$TERMUX_CONFIG_PATH"

source "$CONFIG_PATH/helpers/colors-standard.sh"
source "$CONFIG_PATH/helpers/print.sh"
source "$CONFIG_PATH/helpers/packages.sh"
source "$CONFIG_PATH/scripts/wpm/wpm-helper.sh"
source "$CONFIG_PATH/scripts/yearwall/yearwall-helper.sh"

SERVICE_BASE_DIR="$PREFIX/var/service"
WPM_CONFIG_DIR="$HOME/.config/termux-config-files/wpm"

# ==============================================================================
# START
# ==============================================================================

printfc "$CYAN" "\n┌────────────────┐\n"
printfc "$CYAN" "│  Termux Reset  │\n"
printfc "$CYAN" "└────────────────┘\n"
printfc "$YELLOW" "This will undo setup changes.\n"
printfc "$YELLOW" "Proceed with reset? [y/N]: "
read -r confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "\nAborted.\n"; exit 0; }

# ==============================================================================
# 1. REMOVE SYMLINKS
# ==============================================================================

printfc "$BLUE" "\n>Removing Symlinks\n"

while IFS= read -r -d '' src; do
    rel="${src#"$CONFIG_PATH/home/"}"
    link="$HOME/$rel"
    if [ -L "$link" ]; then
        rm -f "$link"
        printfc "$GREEN" "Removed: %s\n" "$link"
    else
        printfc "$YELLOW" "Skipped: %s\n" "$link"
    fi

    if [ -e "$link.bak" ] || [ -L "$link.bak" ]; then
        mv -f "$link.bak" "$link"
        printfc "$GREEN" "Restored backup: %s\n" "$rel"
    fi
done < <(find "$CONFIG_PATH/home" -type f -print0)

if [ -L "$HOME/.termux/font.ttf" ]; then
    rm -f "$HOME/.termux/font.ttf"
    printfc "$GREEN" "Font link removed.\n"
else
    printfc "$YELLOW" "Font link missing.\n"
fi

mkdir -p "$HOME/.termux"

# ==============================================================================
# 2. BOOT SCRIPTS & BINARIES
# ==============================================================================
for dir in "$CONFIG_PATH"/scripts/*/; do
    name="$(basename "$dir")"
    if [ -L "$PREFIX/bin/$name" ]; then
        rm -f "$PREFIX/bin/$name"
        printfc "$GREEN" "Removed: %s\n" "$name"
    else
        printfc "$YELLOW" "Missing: %s\n" "$name"
    fi
done

# ==============================================================================
# 2c. PURGE GLOBAL CONFIG PATH SYSTEM ENVIRONMENT
# ==============================================================================

printfc "$BLUE" "\n>System Config Environment Purge\n"

CONFIG_ENV_FILE="$PREFIX/etc/profile.d/termux_config.sh"

if [ -f "$CONFIG_ENV_FILE" ]; then
    rm -f "$CONFIG_ENV_FILE"
    printfc "$GREEN" "Removed system profile drop-in: %s\n" "$CONFIG_ENV_FILE"

    unset TERMUX_CONFIG_PATH
    printfc "$GREEN" "Unset TERMUX_CONFIG_PATH from current terminal layer.\n"
else
    printfc "$YELLOW" "No system-wide configuration path profile found.\n"
fi

# ==============================================================================
# 3. WPM BACKUP AND REMOVAL
# ==============================================================================

printfc "$BLUE" "\n>Wireproxy Manager(wpm) Removal\n"

declare -a services=("$SERVICE_BASE_DIR"/*-wpm)
if [[ ! -d "${services[0]}" ]]; then
    printfc "$YELLOW" "No tunnels found.\n"
else
    printfc "$YELLOW" "Remove all tunnels and back up config? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        for s in "${services[@]}"; do
            [[ -d "$s" ]] || continue
            s_name=$(basename "$s")
            conf_file="$WPM_CONFIG_DIR/${s_name%-wpm}.conf"

            [ -f "$conf_file" ] && printfc "$GREEN" "Backup: ~/wpm-backups/%s\n" "$(basename "$conf_file")"
            _remove_wpm_tunnel "$s_name" "$WPM_CONFIG_DIR" "$SERVICE_BASE_DIR" || printfc "$YELLOW" "Disable failed: %s\n" "$s_name"
            printfc "$GREEN" "Removed: %s\n" "$s_name"
        done
    else
        printfc "$YELLOW" "Skipped removal.\n"
        kept_wpm=1
    fi
fi

# ==============================================================================
# 4. YEARWALL REMOVAL
# ==============================================================================

printfc "$BLUE" "\n>Lock Screen Year Progress Wallpaper Setup(yearwall) Removal\n"

YEARWALL_DIR="$HOME/.config/termux-config-files/yearwall"
YEARWALL_BOOT_SCRIPT="$HOME/.termux/boot/50-yearwall.sh"

if [ -f "$YEARWALL_DIR/yearwall_update.sh" ]; then
    printfc "$YELLOW" "Remove setup? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        had_boot_script=0
        [ -f "$YEARWALL_BOOT_SCRIPT" ] && had_boot_script=1

        _remove_yearwall_setup "$YEARWALL_DIR" "$YEARWALL_BOOT_SCRIPT" "$CONFIG_PATH/data/wallpaper/wallpaper.png"

        printfc "$GREEN" "Generated wallpaper and update script removed.\n"
        [ "$had_boot_script" -eq 1 ] && printfc "$GREEN" "Boot persistence script removed.\n"
        printfc "$GREEN" "Wallpaper restored to default.\n"

        if command -v crontab &>/dev/null; then
            printfc "$GREEN" "Crontab cleared.\n"
        else
            printfc "$YELLOW" "Crontab missing. Skipped cron removal.\n"
        fi
    else
        printfc "$YELLOW" "Skipped removal. Wallpaper and boot scripts preserved.\n"
        kept_yearwall=1
    fi
else
    printfc "$YELLOW" "No wallpaper setup found.\n"
fi

# ==============================================================================
# 4b. FONT CACHE CLEANUP
# ==============================================================================

printfc "$BLUE" "\n>Nerd Font Cache Cleanup\n"

FONT_DIR="$HOME/.config/termux-config-files/fonts"

if [ -d "$FONT_DIR" ]; then
    if [ "$kept_yearwall" = 1 ]; then
        printfc "$YELLOW" "Skipped: font still used by yearwall wallpaper generation.\n"
    else
        rm -rf "$FONT_DIR"
        printfc "$GREEN" "Font cache removed.\n"
    fi
else
    printfc "$YELLOW" "No font cache found.\n"
fi

# ==============================================================================
# 4c. TRASH FOLDER (optional)
# ==============================================================================

printfc "$BLUE" "\n>Trash Folder\n"

TRASH_DIR="$HOME/.trash"
if [ -d "$TRASH_DIR" ]; then
    printfc "$YELLOW" "Remove ~/.trash (emptying it permanently)? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$TRASH_DIR"
        printfc "$GREEN" "Trash folder removed.\n"
    else
        printfc "$YELLOW" "Skipped trash folder removal.\n"
    fi
else
    printfc "$YELLOW" "No trash folder found.\n"
fi

# ==============================================================================
# 5. SERVICES (optional)
# ==============================================================================

printfc "$BLUE" "\n>Service Termination\n"

if command -v sv-disable &>/dev/null; then
    printfc "$YELLOW" "Disable SSH service? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if sv-disable sshd > /dev/null 2>&1; then
            printfc "$GREEN" "SSH disabled.\n"
        else
            printfc "$RED" "Failed to disable SSH service.\n"
        fi
    else
        printfc "$YELLOW" "Skipped SSH changes.\n"
    fi
else
    printfc "$YELLOW" "termux-services missing.\n"
fi

# ==============================================================================
# 6. NEOVIM CONFIGURATION
# ==============================================================================

printfc "$BLUE" "\n>Neovim Cleanup\n"
if [ -d "$HOME/.config/nvim" ] && [ -z "$(ls -A "$HOME/.config/nvim")" ]; then
    rmdir "$HOME/.config/nvim"
    printfc "$GREEN" "Removed empty nvim directory.\n"
fi

# ==============================================================================
# 6b. BLK APP BLOCKER CLEANUP & RESTORATION
# ==============================================================================

printfc "$BLUE" "\n>BLK App Blocker Cleanup\n"

BLK_CONFIG_DIR="$HOME/.config/termux-config-files/blk"
BLOCKED_FILE="$BLK_CONFIG_DIR/blocked_pkgs"
CONFIG_FILE="$BLK_CONFIG_DIR/config"
RECEIVER="com.bintianqi.owndroid/.ApiReceiver"

if [ -d "$BLK_CONFIG_DIR" ]; then
    # Load API Key if available to allow intent broadcast
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

    if [ -s "$BLOCKED_FILE" ] && [ -n "$API_KEY" ]; then
        echo ""
        printfc "$YELLOW" "Sending unblock intents...\n"
        unblock_failed=0
        while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            if am broadcast -a "com.bintianqi.owndroid.action.UNSUSPEND" \
                -n "$RECEIVER" \
                --es "key" "$API_KEY" \
                --es "package" "$pkg" > /dev/null 2>&1; then
                echo "-> $pkg"
            else
                echo "-> $pkg (broadcast failed)"
                unblock_failed=1
            fi
        done < "$BLOCKED_FILE"
        if [ "$unblock_failed" -eq 0 ]; then
            printfc "$GREEN" "All apps unblocked successfully.\n"
        else
            printfc "$YELLOW" "Some unblock intents failed to dispatch. Check manually before assuming apps are unblocked.\n"
        fi
        echo ""
    fi

    if [ -n "$API_KEY" ]; then
        printfc "$YELLOW" "Delete the API key? [y/N]: "
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$BLK_CONFIG_DIR"
            printfc "$GREEN" "BLK local configuration data purged.\n"
        else
            rm -f "$BLOCKED_FILE"
            printfc "$GREEN" "Blocked app list cleared. API key preserved.\n"
        fi
    else
        printfc "$YELLOW" "No API key found. Nothing to clean up.\n"
    fi
else
    printfc "$YELLOW" "No BLK config directory found.\n"
fi

# ==============================================================================
# DONE
# ==============================================================================

echo ""
printfc "$GREEN" "Reset complete. Run exit and relaunch Termux.\n"
echo ""
printfc "$YELLOW" "Note: Uninstall these manually if you no longer use them:\n"
for pkg in $SETUP_PKGS; do
    keep=""
    if [ "$kept_wpm" = 1 ]; then
        case "$pkg" in
            termux-services|wireproxy) keep="wpm" ;;
        esac
    fi
    if [ "$kept_yearwall" = 1 ]; then
        case "$pkg" in
            termux-api|termux-services|imagemagick|cronie)
                [ -n "$keep" ] && keep="$keep, wallpaper" || keep="wallpaper"
                ;;
        esac
    fi
    if [ -n "$keep" ]; then
        printfc "$YELLOW" "  - %s (keep — still used by: %s)\n" "$pkg" "$keep"
    else
        printfc "$YELLOW" "  - %s\n" "$pkg"
    fi
done
echo ""
