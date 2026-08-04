# ==============================================================================
# yearwall-helper.sh — shared by tools/yearwall.sh and reset.sh
# ==============================================================================

# Removes the generated wallpaper/update script, restores the default
# wallpaper, and clears boot persistence + session catch-up + crontab entries
# if present.
_remove_yearwall_setup() {
    local yearwall_dir="$1" boot_script="$2" default_wallpaper="$3" profile_script="$4"

    rm -f "$yearwall_dir/yearwall_update.sh"
    rm -f "$yearwall_dir/yearwall_generated.png"

    termux-wallpaper -f "$default_wallpaper" -l

    if [ -f "$boot_script" ]; then
        rm -f "$boot_script"
    fi

    if [ -f "$profile_script" ]; then
        rm -f "$profile_script"
    fi

    if command -v crontab &>/dev/null; then
        crontab -l 2>/dev/null | grep -v "yearwall_update.sh" | crontab -
    fi
}
