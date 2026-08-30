#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# WIREPROXY MANAGER
# ==============================================================================
source "$TERMUX_CONFIG_PATH/helpers/colors-nord.sh"
source "$TERMUX_CONFIG_PATH/helpers/printer.sh"
source "$TERMUX_CONFIG_PATH/helpers/dep-checker.sh"
source "$TERMUX_CONFIG_PATH/helpers/wpm-helper.sh"

if ! _test_dependencies "wireproxy" "sv" "sv-enable" "fzf"; then
    printfc "$NORD_RED" "Missing dependencies: %s" "${_MISSING_DEPS[*]}"
    exit 1
fi

SERVICE_BASE_DIR="$PREFIX/var/service"
CONFIG_DIR="$HOME/.config/termux-config-files/wpm"

# --- Internal Helpers ---

# Resolve the SOCKS5 bind port for a tunnel from its config; "???" when the
# config is missing.
_tunnel_port() {
    local s_name="$1"
    local base_name="${s_name%-wpm}"
    local conf_file="$CONFIG_DIR/${base_name}.conf"
    [ -f "$conf_file" ] || { printf '%s\n' "???"; return 0; }
    grep "BindAddress" "$conf_file" | cut -d':' -f2
}

# Shared fzf picker used across start, stop, restart, and remove actions
_select_tunnels_fzf() {
    local prompt_msg="$1"
    local -a services=("$SERVICE_BASE_DIR"/*-wpm)

    [[ -d "${services[0]}" ]] || {
        printfc "$NORD_YELLOW" "No tunnels found."
        echo ""
        return 1
    }

    local menu_items=""
    for s in "${services[@]}"; do
        [[ -d "$s" ]] || continue
        local s_name=$(basename "$s")
        local state=$(sv status "$s_name" 2>/dev/null | awk '{sub(/:$/,"",$1); print $1}')

        local base_name="${s_name%-wpm}"
        local port=$(_tunnel_port "$s_name")

        menu_items+="$(printf "%-18s | %-4s | :%s\n" "$base_name" "[$state]" "$port")\n"
    done

    local selections
    selections=$(echo -e "$menu_items" | sed '/^\s*$/d' | fzf -m \
        --header="TAB to select, CTRL-A to toggle all, ENTER to confirm" \
        --prompt="$prompt_msg" \
        --bind="ctrl-a:toggle-all" \
        --color="16,header:4,prompt:6,pointer:2,hl:2")

    if [[ -z "$selections" ]]; then
        printfc "$NORD_YELLOW" "Cancelled."
        echo ""
        return 1
    fi

    local mapped_selections=""
    while read -r line; do
        [[ -z "$line" ]] && continue
        local selected_base=$(echo "$line" | awk '{print $1}')
        mapped_selections+="${selected_base}-wpm\n"
    done <<< "$selections"

    echo -e "$mapped_selections" | sed '/^\s*$/d'
}

# --- Actions ---

list_proxies() {
    local -a services=("$SERVICE_BASE_DIR"/*-wpm)
    [[ -d "${services[0]}" ]] || {
        printfc "$NORD_YELLOW" "No active tunnels."
        echo ""
        return 0
    }

    printfc "$NORD_SNOW_1" "\n%-25s %-10s %-8s %-6s" "SERVICE" "STATUS" "PORT" "TEST"
    printfc "$NORD_POLAR_4" "─────────────────────────────────────────────────"

    for s in "${services[@]}"; do
        [[ -d "$s" ]] || continue

        local s_name=$(basename "$s")
        local state=$(sv status "$s_name" 2>/dev/null | awk '{sub(/:$/,"",$1); print $1}')

        # Service name is "name-wpm", but the conf file is just "name.conf"
        local port=$(_tunnel_port "$s_name")

        local test_result="--"
        if [[ "$state" == "run" && "$port" != "???" ]]; then
            if curl -s --socks5-hostname "127.0.0.1:$port" https://google.com --connect-timeout 2 > /dev/null; then
                test_result="PASS"
            else
                test_result="FAIL"
            fi
        fi

        local row_color="$NORD_RED"
        [[ "$state" == "run" ]] && row_color="$NORD_GREEN"

        printfc "$row_color" "%-25s %-10s %-8s %-6s" "$s_name" "$state" "$port" "$test_result"
    done

    echo ""
}

add_proxy() {
    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        printfc "$NORD_YELLOW" "Usage: wpm add <name> <config> <port>"
        return 1
    fi

    local custom_name="$1"
    local wg_path="$2"
    local proxy_port="$3"

    # Clean the custom name format
    custom_name=$(echo "$custom_name" | sed 's/[^a-zA-Z0-9_-]//g')

    local service_name="${custom_name}-wpm"
    local FINAL_CONFIG="$CONFIG_DIR/${custom_name}.conf"
    local SERVICE_DIR="$SERVICE_BASE_DIR/$service_name"

    # Check for duplicate name
    if [ -d "$SERVICE_DIR" ] || [ -f "$FINAL_CONFIG" ]; then
        printfc "$NORD_RED" "A tunnel or config with the name '%s' already exists." "$custom_name"
        return 1
    fi

    # Validate source configuration file
    if [ ! -f "$wg_path" ]; then
        printfc "$NORD_RED" "Config not found: %s" "$wg_path"
        return 1
    fi

    # Check for duplicate ports across existing configurations (now scanning clean *.conf files)
    if [ -d "$CONFIG_DIR" ]; then
        for conf in "$CONFIG_DIR"/*.conf; do
            [ -e "$conf" ] || break
            local existing_port
            existing_port=$(grep "BindAddress" "$conf" | cut -d':' -f2)
            if [ "$existing_port" = "$proxy_port" ]; then
                printfc "$NORD_RED" "Port %s is already in use by %s" "$proxy_port" "$(basename "$conf")"
                return 1
            fi
        done
    fi
    mkdir -p "$CONFIG_DIR"

    # Save and modify config based on whether [Socks5] configuration exists
    if grep -q "^\[Socks5\]" "$wg_path"; then
        command cp "$wg_path" "$FINAL_CONFIG"
        local existing_port=$(grep "BindAddress" "$wg_path" | cut -d':' -f2)
        printfc "$NORD_SNOW_1" "Socks5 configuration block detected."
        printfc "$NORD_SNOW_1" "Port: %s" "${existing_port:-unknown}"

        if [ "$existing_port" != "$proxy_port" ]; then
            printfc "$NORD_YELLOW" "Note: Embedded config port (%s) differs from request (%s)." "$existing_port" "$proxy_port"
        fi
    else
        {
            echo "[Socks5]"
            echo "BindAddress = 127.0.0.1:$proxy_port"
            echo ""
            cat "$wg_path"
        } > "$FINAL_CONFIG"
        printfc "$NORD_SNOW_1" "Config saved as %s" "$(basename "$FINAL_CONFIG")"
        printfc "$NORD_SNOW_1" "Port: %s" "${proxy_port}"
    fi

    echo ""
    mkdir -p "$SERVICE_DIR"
    cat > "$SERVICE_DIR/run" << RUNEOF
#!/data/data/com.termux/files/usr/bin/sh
exec wireproxy -c $FINAL_CONFIG 2>&1
RUNEOF
    chmod +x "$SERVICE_DIR/run"

    local waited=0
    until [ -p "$SERVICE_DIR/supervise/ok" ] || [ "$waited" -ge 50 ]; do
        sleep 0.1
        ((waited++))
    done

    local enabled=0
    for attempt in 1 2 3; do
        if sv-enable "$service_name" > /dev/null 2>&1; then
            enabled=1
            break
        fi
        sleep 0.3
    done

    if [ "$enabled" -eq 1 ]; then
        printfc "$NORD_GREEN" "Tunnel enabled: %s" "$service_name"
    else
        printfc "$NORD_RED" "Failed to enable tunnel."
    fi
    echo ""
}

_tunnel_action() {
    local verb="$1" gerund="$2" past="$3"
    local selections
    selections=$(_select_tunnels_fzf "Select tunnel(s) to $verb: ") || return 0

    echo ""
    while read -r line; do
        [[ -z "$line" ]] && continue
        local s_name=$(echo "$line" | awk '{print $1}')
        printfc "$NORD_SNOW_1" "$gerund: %s" "$s_name"
        sv "$verb" "$s_name" && printfc "$NORD_GREEN" "$past: %s" "$s_name" || printfc "$NORD_RED" "Failed to $verb: %s" "$s_name"
    done <<< "$selections"
    echo ""
}

remove_proxy() {
    local selections
    selections=$(_select_tunnels_fzf "Select tunnel(s) to remove: ") || return 0

    echo ""
    while read -r line; do
        [[ -z "$line" ]] && continue
        local s_name=$(echo "$line" | awk '{print $1}')

        # Service name is "name-wpm", but the conf file to delete/backup is just "name.conf"
        local base_name="${s_name%-wpm}"
        local conf_file="$CONFIG_DIR/${base_name}.conf"

        [ -f "$conf_file" ] && printfc "$NORD_GREEN" "Backup: ~/wpm-backups/%s.conf" "$base_name"
        if _remove_wpm_tunnel "$s_name" "$CONFIG_DIR" "$SERVICE_BASE_DIR"; then
            printfc "$NORD_GREEN" "Removed: %s" "$s_name"
        else
            printfc "$NORD_YELLOW" "Removed files for %s, but sv-disable reported failure." "$s_name"
        fi
    done <<< "$selections"
    echo ""
}

refresh_proxies() {
    local -a services=("$SERVICE_BASE_DIR"/*-wpm)
    [[ -d "${services[0]}" ]] || {
        printfc "$NORD_YELLOW" "No tunnels to restart."
        echo ""
        return 0
    }

    local failed=0
    for s in "${services[@]}"; do
        [[ -d "$s" ]] || continue
        local s_name=$(basename "$s")
        printfc "$NORD_SNOW_1" "Restarting: %s" "$s_name"
        sv restart "$s_name" || ((failed++))
    done

    echo ""
    if [ "$failed" -eq 0 ]; then
        printfc "$NORD_GREEN" "All tunnels restarted."
    else
        printfc "$NORD_RED" "Failed to restart %s tunnel(s)." "$failed"
    fi
    echo ""
}

# --- Router ---
case "$1" in
    add)     add_proxy "$2" "$3" "$4" ;;
    rm)      remove_proxy ;;
    start)   _tunnel_action "start" "Starting" "Started" ;;
    stop)    _tunnel_action "stop" "Stopping" "Stopped" ;;
    restart) _tunnel_action "restart" "Restarting" "Restarted" ;;
    ls)      list_proxies ;;
    refresh) refresh_proxies ;;
    *)
        printfc "$NORD_SNOW_1" "add <name> <conf> <port>     Add a proxy"
        printfc "$NORD_SNOW_1" "rm                           Remove a proxy"
        printfc "$NORD_SNOW_1" "start                        Start target proxy service(s)"
        printfc "$NORD_SNOW_1" "stop                         Stop target proxy service(s)"
        printfc "$NORD_SNOW_1" "restart                      Restart target proxy service(s)"
        printfc "$NORD_SNOW_1" "ls                           List proxies"
        printfc "$NORD_SNOW_1" "refresh                      Restart All Proxy Services"
        echo ""
        exit 1
        ;;
esac
