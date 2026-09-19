# Shared cleanup for tools/yearwall.sh and reset.sh.

# Finish cleanup even if one step fails; callers report the final result.
_remove_yearwall_setup() {
    local yearwall_dir="$1" boot_script="$2" default_wallpaper="$3" profile_script="$4"
    local failed=0

    rm -f "$yearwall_dir/yearwall_update.sh" "$yearwall_dir/yearwall_generated.png" || failed=1
    termux-wallpaper -f "$default_wallpaper" -l || failed=1
    rm -f "$boot_script" "$profile_script" || failed=1

    if command -v crontab &>/dev/null; then
        crontab -l 2>/dev/null | grep -v "yearwall_update.sh" | crontab - || failed=1
    fi

    return "$failed"
}
