#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# TERMUX CONFIG RESET
# ==============================================================================
CONFIG_PATH="$TERMUX_CONFIG_PATH"

source "$CONFIG_PATH/helpers/colors-standard.sh"
source "$CONFIG_PATH/helpers/printer.sh"
source "$CONFIG_PATH/helpers/pkg-list.sh"
source "$CONFIG_PATH/helpers/dotfiles-helper.sh"
source "$CONFIG_PATH/helpers/wpm-helper.sh"
source "$CONFIG_PATH/helpers/yearwall-helper.sh"
source "$CONFIG_PATH/helpers/blk-helper.sh"

SERVICE_BASE_DIR="$PREFIX/var/service"
WPM_CONFIG_DIR="$HOME/.config/termux-config-files/wpm"

# ==============================================================================
# START
# ==============================================================================

printfc "$CYAN" "\n┌────────────────┐"
printfc "$CYAN" "│  Termux Reset  │"
printfc "$CYAN" "└────────────────┘"
printfc "$YELLOW" "This will undo setup changes."
printfc -n "$YELLOW" "Proceed with reset? [y/N]: "
read -r confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "\nAborted.\n"; exit 0; }

# ==============================================================================
# 1. REMOVE SYMLINKS
# ==============================================================================

printfc "$BLUE" "\n>Removing Symlinks"

_unlink_dotfiles "$CONFIG_PATH"
for link in "${_DOT_REMOVED[@]}"; do
    printfc "$GREEN" "Removed: %s" "$link"
done
for link in "${_DOT_SKIPPED[@]}"; do
    printfc "$YELLOW" "Skipped: %s" "$link"
done
for rel in "${_DOT_RESTORED[@]}"; do
    printfc "$GREEN" "Restored backup: %s" "$rel"
done

if [ -L "$HOME/.termux/font.ttf" ]; then
    rm -f "$HOME/.termux/font.ttf"
    printfc "$GREEN" "Font link removed."
else
    printfc "$YELLOW" "Font link missing."
fi

mkdir -p "$HOME/.termux"

# ==============================================================================
# 2. BOOT SCRIPTS & BINARIES
# ==============================================================================
for main_script in "$CONFIG_PATH"/tools/*.sh; do
    name="$(basename "$main_script" .sh)"
    if [ -L "$PREFIX/bin/$name" ]; then
        rm -f "$PREFIX/bin/$name"
        printfc "$GREEN" "Removed: %s" "$name"
    else
        printfc "$YELLOW" "Missing: %s" "$name"
    fi
done

# ==============================================================================
# 2c. PURGE GLOBAL CONFIG PATH SYSTEM ENVIRONMENT
# ==============================================================================

printfc "$BLUE" "\n>System Config Environment Purge"

CONFIG_ENV_FILE="$PREFIX/etc/profile.d/termux_config.sh"

if [ -f "$CONFIG_ENV_FILE" ]; then
    rm -f "$CONFIG_ENV_FILE"
    printfc "$GREEN" "Removed system profile drop-in: %s" "$CONFIG_ENV_FILE"

    unset TERMUX_CONFIG_PATH
    printfc "$GREEN" "Unset TERMUX_CONFIG_PATH from current terminal layer."
else
    printfc "$YELLOW" "No system-wide configuration path profile found."
fi

# ==============================================================================
# 3. WPM BACKUP AND REMOVAL
# ==============================================================================

printfc "$BLUE" "\n>Wireproxy Manager(wpm) Removal"

declare -a services=("$SERVICE_BASE_DIR"/*-wpm)
if [[ ! -d "${services[0]}" ]]; then
    printfc "$YELLOW" "No tunnels found."
else
    printfc -n "$YELLOW" "Remove all tunnels and back up config? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        for s in "${services[@]}"; do
            [[ -d "$s" ]] || continue
            s_name=$(basename "$s")
            conf_file="$WPM_CONFIG_DIR/${s_name%-wpm}.conf"

            [ -f "$conf_file" ] && printfc "$GREEN" "Backup: ~/wpm-backups/%s" "$(basename "$conf_file")"
            _remove_wpm_tunnel "$s_name" "$WPM_CONFIG_DIR" "$SERVICE_BASE_DIR" || printfc "$YELLOW" "Disable failed: %s" "$s_name"
            printfc "$GREEN" "Removed: %s" "$s_name"
        done
    else
        printfc "$YELLOW" "Skipped removal."
        kept_wpm=1
    fi
fi

# ==============================================================================
# 4. YEARWALL REMOVAL
# ==============================================================================

printfc "$BLUE" "\n>Lock Screen Year Progress Wallpaper Setup(yearwall) Removal"

YEARWALL_DIR="$HOME/.config/termux-config-files/yearwall"
YEARWALL_BOOT_SCRIPT="$HOME/.termux/boot/50-yearwall.sh"
YEARWALL_PROFILE_SCRIPT="$PREFIX/etc/profile.d/yearwall-catchup.sh"

if [ -f "$YEARWALL_DIR/yearwall_update.sh" ]; then
    printfc -n "$YELLOW" "Remove setup? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        had_boot_script=0
        had_profile_script=0
        [ -f "$YEARWALL_BOOT_SCRIPT" ] && had_boot_script=1
        [ -f "$YEARWALL_PROFILE_SCRIPT" ] && had_profile_script=1

        _remove_yearwall_setup "$YEARWALL_DIR" "$YEARWALL_BOOT_SCRIPT" "$CONFIG_PATH/data/wallpaper/wallpaper.png" "$YEARWALL_PROFILE_SCRIPT"

        printfc "$GREEN" "Generated wallpaper and update script removed."
        [ "$had_boot_script" -eq 1 ] && printfc "$GREEN" "Boot persistence script removed."
        [ "$had_profile_script" -eq 1 ] && printfc "$GREEN" "Session catch-up script removed."
        printfc "$GREEN" "Wallpaper restored to default."

        if command -v crontab &>/dev/null; then
            printfc "$GREEN" "Crontab cleared."
        else
            printfc "$YELLOW" "Crontab missing. Skipped cron removal."
        fi
    else
        printfc "$YELLOW" "Skipped removal. Wallpaper and boot scripts preserved."
        kept_yearwall=1
    fi
else
    printfc "$YELLOW" "No wallpaper setup found."
fi

# ==============================================================================
# 4b. FONT CACHE CLEANUP
# ==============================================================================

printfc "$BLUE" "\n>Nerd Font Cache Cleanup"

FONT_DIR="$HOME/.config/termux-config-files/fonts"

if [ -d "$FONT_DIR" ]; then
    if [ "$kept_yearwall" = 1 ]; then
        printfc "$YELLOW" "Skipped: font still used by yearwall wallpaper generation."
    else
        rm -rf "$FONT_DIR"
        printfc "$GREEN" "Font cache removed."
    fi
else
    printfc "$YELLOW" "No font cache found."
fi

# ==============================================================================
# 4c. TRASH FOLDER (optional)
# ==============================================================================

printfc "$BLUE" "\n>Trash Folder"

TRASH_DIR="$HOME/.trash"
if [ -d "$TRASH_DIR" ]; then
    printfc -n "$YELLOW" "Remove ~/.trash (emptying it permanently)? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$TRASH_DIR"
        printfc "$GREEN" "Trash folder removed."
    else
        printfc "$YELLOW" "Skipped trash folder removal."
    fi
else
    printfc "$YELLOW" "No trash folder found."
fi

# ==============================================================================
# 5. SERVICES (optional)
# ==============================================================================

printfc "$BLUE" "\n>Service Termination"

if command -v sv-disable &>/dev/null; then
    printfc -n "$YELLOW" "Disable SSH service? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if sv-disable sshd > /dev/null 2>&1; then
            printfc "$GREEN" "SSH disabled."
        else
            printfc "$RED" "Failed to disable SSH service."
            kept_ssh=1
        fi
    else
        printfc "$YELLOW" "Skipped SSH changes."
        kept_ssh=1
    fi
else
    printfc "$YELLOW" "termux-services missing."
fi

# ==============================================================================
# 5b. BOOT SERVICES SCRIPT CLEANUP
# ==============================================================================

printfc "$BLUE" "\n>Boot Services Script Cleanup"

BOOT_SERVICES="$HOME/.termux/boot/10-services.sh"

if [ -f "$BOOT_SERVICES" ]; then
    if [ "$kept_wpm" = 1 ] || [ "$kept_yearwall" = 1 ] || [ "$kept_ssh" = 1 ]; then
        printfc "$YELLOW" "Skipped: still needed to start services for kept setup(s) on boot."
    else
        rm -f "$BOOT_SERVICES"
        printfc "$GREEN" "Boot services script removed."
    fi
else
    printfc "$YELLOW" "Boot services script not found."
fi

# ==============================================================================
# 6. NEOVIM CONFIGURATION
# ==============================================================================

printfc "$BLUE" "\n>Neovim Cleanup"
if [ -d "$HOME/.config/nvim" ] && [ -z "$(ls -A "$HOME/.config/nvim")" ]; then
    rmdir "$HOME/.config/nvim"
    printfc "$GREEN" "Removed empty nvim directory."
fi

# ==============================================================================
# 6b. BLK APP BLOCKER CLEANUP & RESTORATION
# ==============================================================================

printfc "$BLUE" "\n>BLK App Blocker Cleanup"

BLK_CONFIG_DIR="$HOME/.config/termux-config-files/blk"
BLOCKED_FILE="$BLK_CONFIG_DIR/blocked_pkgs"
CONFIG_FILE="$BLK_CONFIG_DIR/config"
CONTACTS_STATE_FILE="$BLK_CONFIG_DIR/wa_contacts_state"

if [ -d "$BLK_CONFIG_DIR" ]; then
    # Load API Key if available to allow intent broadcast
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

    if [ -s "$BLOCKED_FILE" ] && [ -n "$API_KEY" ]; then
        echo ""
        printfc "$YELLOW" "Sending unblock intents..."
        unblock_failed=0
        while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            if _blk_send_intent "$API_KEY" "UNSUSPEND" "$pkg"; then
                echo "-> $pkg"
            else
                printfc "$RED" "-> %s (broadcast failed)" "$pkg"
                unblock_failed=1
            fi
        done < "$BLOCKED_FILE"
        if [ "$unblock_failed" -eq 0 ]; then
            printfc "$GREEN" "All apps unblocked successfully."
        else
            printfc "$RED" "Some unblock intents failed to dispatch. Check manually before assuming apps are unblocked."
        fi
        echo ""
    fi

    if [ -f "$CONTACTS_STATE_FILE" ] && [ -n "$API_KEY" ] && [ "$(cat "$CONTACTS_STATE_FILE")" = "denied" ]; then
        printfc "$YELLOW" "Restoring WhatsApp Contacts permission..."
        if _blk_send_intent "$API_KEY" "SET_PERMISSION_GRANTED" "com.whatsapp" "android.permission.READ_CONTACTS"; then
            printfc "$GREEN" "WhatsApp Contacts permission restored."
        else
            printfc "$RED" "Failed to restore WhatsApp Contacts permission. Check manually."
        fi
        echo ""
    fi

    if [ -n "$API_KEY" ]; then
        printfc -n "$YELLOW" "Delete the API key? [y/N]: "
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$BLK_CONFIG_DIR"
            printfc "$GREEN" "BLK local configuration data purged."
        else
            rm -f "$BLOCKED_FILE"
            printfc "$GREEN" "Blocked app list cleared. API key preserved."
        fi
    else
        printfc "$YELLOW" "No API key found. Nothing to clean up."
    fi
else
    printfc "$YELLOW" "No BLK config directory found."
fi

# ==============================================================================
# DONE
# ==============================================================================

echo ""
printfc "$GREEN" "Reset complete. Run exit and relaunch Termux."
echo ""
printfc "$YELLOW" "Note: Uninstall these manually if you no longer use them:"
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
    if [ "$kept_ssh" = 1 ]; then
        case "$pkg" in
            termux-services|openssh)
                [ -n "$keep" ] && keep="$keep, ssh" || keep="ssh"
                ;;
        esac
    fi
    if [ -n "$keep" ]; then
        printfc "$YELLOW" "  - %s (keep — still used by: %s)" "$pkg" "$keep"
    else
        printfc "$YELLOW" "  - %s" "$pkg"
    fi
done
echo ""
