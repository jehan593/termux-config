#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# BLK: Minimalist App Blocker for Termux
# ==============================================================================
source "$TERMUX_CONFIG_PATH/helpers/common-helpers.sh"
_test_dependencies "fzf" "am" "cmd" || exit 1

CONFIG_DIR="$HOME/.config/termux-config-files/blk"
CONFIG_FILE="$CONFIG_DIR/config"
BLOCKED_FILE="$CONFIG_DIR/blocked_pkgs"
RECEIVER="com.bintianqi.owndroid/.ApiReceiver"

command mkdir -p "$CONFIG_DIR"
[ -f "$BLOCKED_FILE" ] || : > "$BLOCKED_FILE"

PREVIEW_CMD="if [ -s '$BLOCKED_FILE' ]; then cat '$BLOCKED_FILE'; else echo '(No apps currently blocked)'; fi"

_load_api_key() { [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"; }
_save_api_key() { echo "API_KEY=\"$1\"" > "$CONFIG_FILE" && chmod 600 "$CONFIG_FILE"; }

_ensure_api_key() {
    _load_api_key
    if [ -z "$API_KEY" ]; then
        _print_header "API Key Setup"
        _print_status "warning" "No API key found."
        read -p "$(echo -e "${NORD_BLUE}Enter API key: ${RST}")" new_key
        [ -z "$new_key" ] && { _print_status "error" "Aborted."; exit 1; }
        _save_api_key "$new_key" && API_KEY="$new_key"
        _print_status "success" "Key saved."
        echo ""
    fi
}

set_api_key() {
    _print_header "API Key Management"
    _load_api_key
    [ -n "$API_KEY" ] && _print_status "success" "Current: ${API_KEY:0:4}************"
    read -p "$(echo -e "${NORD_BLUE}Enter new API key (or press Enter to cancel): ${RST}")" new_key
    if [ -n "$new_key" ]; then
        _save_api_key "$new_key"
        _print_status "success" "Key updated."
    else
        _print_status "warning" "Cancelled."
    fi
    echo ""
}

# --- Intent Sender ---
send_intent() {
    local action=$1 package=$2 permission=$3
    local args=(-a "com.bintianqi.owndroid.action.$action" \
        -n "$RECEIVER" \
        --es "key" "$API_KEY" \
        --es "package" "$package")
    [ -n "$permission" ] && args+=(--es "permission" "$permission")
    am broadcast "${args[@]}" > /dev/null 2>&1
}

CONTACTS_STATE_FILE="$CONFIG_DIR/wa_contacts_state"

# --- WhatsApp Contact Toggle ---
toggle_whatsapp_contacts() {
    _print_header "WhatsApp Contacts Permission"
    _ensure_api_key
    local wa_pkg="com.whatsapp"
    local perm="android.permission.READ_CONTACTS"

    if ! cmd package list packages | grep -qFx "package:$wa_pkg"; then
        _print_status "error" "WhatsApp ($wa_pkg) is not installed."
        echo ""
        exit 1
    fi

    local current_state="granted"
    [ -f "$CONTACTS_STATE_FILE" ] && current_state=$(cat "$CONTACTS_STATE_FILE")

    if [ "$current_state" = "granted" ]; then
        _print_status "warning" "Revoking Contacts permission from WhatsApp..."
        if send_intent "SET_PERMISSION_DENIED" "$wa_pkg" "$perm"; then
            echo "denied" > "$CONTACTS_STATE_FILE"
            _print_status "success" "Permission blocked successfully."
        else
            _print_status "error" "Intent broadcast failed. Permission state left unchanged."
        fi
    else
        _print_status "warning" "Granting Contacts permission to WhatsApp..."
        if send_intent "SET_PERMISSION_GRANTED" "$wa_pkg" "$perm"; then
            echo "granted" > "$CONTACTS_STATE_FILE"
            _print_status "success" "Permission allowed successfully."
        else
            _print_status "error" "Intent broadcast failed. Permission state left unchanged."
        fi
    fi
    echo ""
}

# --- Main Block Interface ---
manage_blocks() {
    _ensure_api_key
    _print_header "App Blocker"

    # 1. Gather all 3rd party apps
    local all_pkgs=$(cmd package list packages -3 | sed 's/^package://' | sort)
    local currently_blocked=$(cat "$BLOCKED_FILE" | sort)

    # 2. Format list for fzf
    local menu_lines=""
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        if echo "$currently_blocked" | grep -qFx "$pkg"; then
            menu_lines+="$pkg [BLOCKED]\n"
        else
            menu_lines+="$pkg\n"
        fi
    done <<< "$all_pkgs"

    # 3. Present fzf ui
    local choice=$(echo -e "$menu_lines" | fzf --multi \
        --header="TAB to select, CTRL-A to toggle all, ENTER to toggle status" \
        --bind="ctrl-a:toggle-all" \
        --preview "$PREVIEW_CMD" --preview-window=top:40%:wrap \
        --preview-label="Currently Blocked Apps")

    [ -z "$choice" ] && { echo ""; _print_status "warning" "No changes applied."; echo ""; return 0; }

    # Extract the clean package names from the user's choice
    local targeted_pkgs=$(echo "$choice" | awk '{print $1}')

    # Process each selected package individually to toggle its state
    local to_block=""
    local to_unblock=""

    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        if echo "$currently_blocked" | grep -qFx "$pkg"; then
            to_unblock+="$pkg\n"
        else
            to_block+="$pkg\n"
        fi
    done <<< "$targeted_pkgs"

    # 4. Apply blocks
    if [ -n "$to_block" ]; then
        echo ""
        _print_status "warning" "Blocking apps..."
        while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            if send_intent "SUSPEND" "$pkg"; then
                echo "-> $pkg"
                currently_blocked=$(echo -e "$currently_blocked\n$pkg" | sort -u)
            else
                _print_status "error" "-> $pkg (broadcast failed, not marked blocked)"
            fi
        done <<< "$(echo -e "$to_block")"
    fi

    # 5. Apply unblocks
    if [ -n "$to_unblock" ]; then
        echo ""
        _print_status "success" "Unblocking apps..."
        while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            if send_intent "UNSUSPEND" "$pkg"; then
                echo "-> $pkg"
                currently_blocked=$(echo "$currently_blocked" | grep -vFx "$pkg")
            else
                _print_status "error" "-> $pkg (broadcast failed, still marked blocked)"
            fi
        done <<< "$(echo -e "$to_unblock")"
    fi

    # 6. Save final cleaned state back to file
    echo "$currently_blocked" | sed '/^$/d' > "$BLOCKED_FILE"
    echo ""
    _print_status "success" "Blocklist updated successfully."
    echo ""
}

# --- Router ---
case "$1" in
    key) set_api_key ;;
    wa)  toggle_whatsapp_contacts ;;
    "")  manage_blocks ;;
    *)   _print_status "error" "Unknown command: $1"; echo "Usage: blk [key|wa]"; exit 1 ;;
esac