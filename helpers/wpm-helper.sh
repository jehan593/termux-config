# ==============================================================================
# wpm-helper.sh — shared by tools/wpm.sh and reset.sh
# ==============================================================================

# Backs up a tunnel's config and tears down its service.
# Returns 1 if sv-disable failed (caller decides how to report it); the
# filesystem cleanup always runs regardless, matching prior behavior.
_remove_wpm_tunnel() {
    local s_name="$1" conf_dir="$2" service_base_dir="$3"
    local base_name="${s_name%-wpm}"
    local conf_file="$conf_dir/${base_name}.conf"
    local disabled=0

    if [ -f "$conf_file" ]; then
        mkdir -p "$HOME/wpm-backups"
        cp "$conf_file" "$HOME/wpm-backups/${base_name}.conf"
    fi

    sv-disable "$s_name" > /dev/null 2>&1 || disabled=1
    rm -rf "$service_base_dir/$s_name"
    rm -f "$conf_file"

    return "$disabled"
}
