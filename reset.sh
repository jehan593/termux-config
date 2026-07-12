#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# TERMUX CONFIG RESET
# ==============================================================================
CONFIG_PATH="$TERMUX_CONFIG_PATH"

source "$CONFIG_PATH/helpers/setup-helpers.sh"
source "$CONFIG_PATH/scripts/wpm/wpm-helper.sh"
source "$CONFIG_PATH/scripts/yearwall/yearwall-helper.sh"

SERVICE_BASE_DIR="$PREFIX/var/service"
WPM_CONFIG_DIR="$HOME/.config/termux-config-files/wpm"

# ==============================================================================
# START
# ==============================================================================

_print_header "Termux Reset"
warn "This will undo setup changes."
ask "Proceed with reset?" || { echo -e "\nAborted.\n"; exit 0; }

# ==============================================================================
# 1. REMOVE SYMLINKS
# ==============================================================================

_print_header "Removing Symlinks"

while IFS= read -r -d '' src; do
    rel="${src#"$CONFIG_PATH/home/"}"
    link="$HOME/$rel"
    if [ -L "$link" ]; then
        rm -f "$link"
        ok "Removed: $link"
    else
        warn "Skipped: $link"
    fi

    if [ -e "$link.bak" ] || [ -L "$link.bak" ]; then
        mv -f "$link.bak" "$link"
        ok "Restored backup: $rel"
    fi
done < <(find "$CONFIG_PATH/home" -type f -print0)

if [ -L "$HOME/.termux/font.ttf" ]; then
    rm -f "$HOME/.termux/font.ttf"
    ok "Font link removed."
else
    warn "Font link missing."
fi

mkdir -p "$HOME/.termux"

# ==============================================================================
# 2. BOOT SCRIPTS & BINARIES
# ==============================================================================
for dir in "$CONFIG_PATH"/scripts/*/; do
    name="$(basename "$dir")"
    if [ -L "$PREFIX/bin/$name" ]; then
        rm -f "$PREFIX/bin/$name"
        ok "Removed: $name"
    else
        warn "Missing: $name"
    fi
done

# ==============================================================================
# 2c. PURGE GLOBAL CONFIG PATH SYSTEM ENVIRONMENT
# ==============================================================================

_print_header "System Config Environment Purge"

CONFIG_ENV_FILE="$PREFIX/etc/profile.d/termux_config.sh"

if [ -f "$CONFIG_ENV_FILE" ]; then
    rm -f "$CONFIG_ENV_FILE"
    ok "Removed system profile drop-in: $CONFIG_ENV_FILE"

    unset TERMUX_CONFIG_PATH
    ok "Unset TERMUX_CONFIG_PATH from current terminal layer."
else
    warn "No system-wide configuration path profile found."
fi

# ==============================================================================
# 3. WPM BACKUP AND REMOVAL
# ==============================================================================

_print_header "Wireproxy Manager(wpm) Removal"

declare -a services=("$SERVICE_BASE_DIR"/*-wpm)
if [[ ! -d "${services[0]}" ]]; then
    warn "No tunnels found."
else
    if ask "Remove all tunnels and back up config?"; then
        echo ""
        for s in "${services[@]}"; do
            [[ -d "$s" ]] || continue
            s_name=$(basename "$s")
            conf_file="$WPM_CONFIG_DIR/${s_name%-wpm}.conf"

            [ -f "$conf_file" ] && ok "Backup: ~/wpm-backups/$(basename "$conf_file")"
            _remove_wpm_tunnel "$s_name" "$WPM_CONFIG_DIR" "$SERVICE_BASE_DIR" || warn "Disable failed: $s_name"
            ok "Removed: $s_name"
        done
    else
        warn "Skipped removal."
        kept_wpm=1
    fi
fi

# ==============================================================================
# 4. YEARWALL REMOVAL
# ==============================================================================

_print_header "Lock Screen Year Progress Wallpaper Setup(yearwall) Removal"

YEARWALL_DIR="$HOME/.config/termux-config-files/yearwall"
YEARWALL_BOOT_SCRIPT="$HOME/.termux/boot/50-yearwall.sh"

if [ -f "$YEARWALL_DIR/yearwall_update.sh" ]; then
    if ask "Remove setup?"; then
        echo ""
        had_boot_script=0
        [ -f "$YEARWALL_BOOT_SCRIPT" ] && had_boot_script=1

        _remove_yearwall_setup "$YEARWALL_DIR" "$YEARWALL_BOOT_SCRIPT" "$CONFIG_PATH/data/wallpaper/wallpaper.png"

        ok "Generated wallpaper and update script removed."
        [ "$had_boot_script" -eq 1 ] && ok "Boot persistence script removed."
        ok "Wallpaper restored to default."

        if command -v crontab &>/dev/null; then
            ok "Crontab cleared."
        else
            warn "Crontab missing. Skipped cron removal."
        fi
    else
        warn "Skipped removal. Wallpaper and boot scripts preserved."
        kept_yearwall=1
    fi
else
    warn "No wallpaper setup found."
fi

# ==============================================================================
# 4b. FONT CACHE CLEANUP
# ==============================================================================

_print_header "Nerd Font Cache Cleanup"

FONT_DIR="$HOME/.config/termux-config-files/fonts"

if [ -d "$FONT_DIR" ]; then
    if [ "$kept_yearwall" = 1 ]; then
        warn "Skipped: font still used by yearwall wallpaper generation."
    else
        rm -rf "$FONT_DIR"
        ok "Font cache removed."
    fi
else
    warn "No font cache found."
fi

# ==============================================================================
# 4c. TRASH FOLDER (optional)
# ==============================================================================

_print_header "Trash Folder"

TRASH_DIR="$HOME/.trash"
if [ -d "$TRASH_DIR" ]; then
    if ask "Remove ~/.trash (emptying it permanently)?"; then
        rm -rf "$TRASH_DIR"
        ok "Trash folder removed."
    else
        warn "Skipped trash folder removal."
    fi
else
    warn "No trash folder found."
fi

# ==============================================================================
# 5. SERVICES (optional)
# ==============================================================================

_print_header "Service Termination"

if command -v sv-disable &>/dev/null; then
    if ask "Disable SSH service?"; then
        if sv-disable sshd > /dev/null 2>&1; then
            ok "SSH disabled."
        else
            err "Failed to disable SSH service."
        fi
    else
        warn "Skipped SSH changes."
    fi
else
    warn "termux-services missing."
fi

# ==============================================================================
# 6. NEOVIM CONFIGURATION
# ==============================================================================

_print_header "Neovim Cleanup"
if [ -d "$HOME/.config/nvim" ] && [ -z "$(ls -A "$HOME/.config/nvim")" ]; then
    rmdir "$HOME/.config/nvim"
    ok "Removed empty nvim directory."
fi

# ==============================================================================
# 6b. BLK APP BLOCKER CLEANUP & RESTORATION
# ==============================================================================

_print_header "BLK App Blocker Cleanup"

BLK_CONFIG_DIR="$HOME/.config/termux-config-files/blk"
BLOCKED_FILE="$BLK_CONFIG_DIR/blocked_pkgs"
CONFIG_FILE="$BLK_CONFIG_DIR/config"
RECEIVER="com.bintianqi.owndroid/.ApiReceiver"

if [ -d "$BLK_CONFIG_DIR" ]; then
    # Load API Key if available to allow intent broadcast
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

    if [ -s "$BLOCKED_FILE" ] && [ -n "$API_KEY" ]; then
        echo ""
        warn "Sending unblock intents..."
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
            ok "All apps unblocked successfully."
        else
            warn "Some unblock intents failed to dispatch. Check manually before assuming apps are unblocked."
        fi
        echo ""
    fi

    if [ -n "$API_KEY" ]; then
        if ask "Delete the API key?"; then
            rm -rf "$BLK_CONFIG_DIR"
            ok "BLK local configuration data purged."
        else
            rm -f "$BLOCKED_FILE"
            ok "Blocked app list cleared. API key preserved."
        fi
    else
        warn "No API key found. Nothing to clean up."
    fi
else
    warn "No BLK config directory found."
fi

# ==============================================================================
# DONE
# ==============================================================================

echo ""
ok "Reset complete. Run exit and relaunch Termux."
echo ""
warn "Note: Uninstall these manually if you no longer use them:"
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
        echo -e "${YELLOW}  - $pkg (keep — still used by: $keep)${RST}"
    else
        echo -e "${YELLOW}  - $pkg${RST}"
    fi
done
echo ""
