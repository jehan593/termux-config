#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# WIREPROXY MANAGER
# ==============================================================================
source "$TERMUX_CONFIG_PATH/helpers/common-helpers.sh"
source "$TERMUX_CONFIG_PATH/scripts/wpm/wpm-helper.sh"

_test_dependencies "wireproxy" "sv" "sv-enable" "fzf" || exit 1

SERVICE_BASE_DIR="$PREFIX/var/service"
CONFIG_DIR="$HOME/.config/termux-config-files/wpm"

# --- Internal Helpers ---

# Shared fzf picker used across start, stop, restart, and remove actions
_select_tunnels_fzf() {
    local prompt_msg="$1"
    local -a services=("$SERVICE_BASE_DIR"/*-wpm)

    [[ -d "${services[0]}" ]] || {
        _print_status "info" "No tunnels found."
        echo ""
        return 1
    }

    local menu_items=""
    for s in "${services[@]}"; do
        [[ -d "$s" ]] || continue
        local s_name=$(basename "$s")
        local state=$(sv status "$s_name" 2>/dev/null | awk '{sub(/:$/,"",$1); print $1}')

        local base_name="${s_name%-wpm}"
        local conf_file="$CONFIG_DIR/${base_name}.conf"

        local port="???"
        [ -f "$conf_file" ] && port=$(grep "BindAddress" "$conf_file" | cut -d':' -f2)

        menu_items+="$(printf "%-18s | %-4s | :%s\n" "$base_name" "[$state]" "$port")\n"
    done

    local selections
    selections=$(echo -e "$menu_items" | sed '/^\s*$/d' | fzf -m \
        --header="TAB to select, CTRL-A to toggle all, ENTER to confirm" \
        --prompt="$prompt_msg" \
        --bind="ctrl-a:toggle-all" \
        --color="16,header:4,prompt:6,pointer:2,hl:2")

    if [[ -z "$selections" ]]; then
        _print_status "info" "Cancelled."
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
    _print_header "Active Tunnels" ""

    local -a services=("$SERVICE_BASE_DIR"/*-wpm)
    [[ -d "${services[0]}" ]] || {
        _print_status "info" "No active tunnels."
        echo ""
        return 0
    }

    printf "${NORD_D_BLUE}%-25s %-10s %-8s %-6s${RST}\n" "SERVICE" "STATUS" "PORT" "TEST"
    echo -e "${NORD_POLAR_4}─────────────────────────────────────────────────${RST}"

    for s in "${services[@]}"; do
        [[ -d "$s" ]] || continue

        local s_name=$(basename "$s")
        local state=$(sv status "$s_name" 2>/dev/null | awk '{sub(/:$/,"",$1); print $1}')

        # Service name is "name-wpm", but the conf file is just "name.conf"
        local base_name="${s_name%-wpm}"
        local conf_file="$CONFIG_DIR/${base_name}.conf"

        local port="???"
        [ -f "$conf_file" ] && port=$(grep "BindAddress" "$conf_file" | cut -d':' -f2)

        local s_color="${NORD_RED}"
        [[ "$state" == "run" ]] && s_color="${NORD_GREEN}"

        local test_result="${NORD_POLAR_4}--${RST}"
        if [[ "$state" == "run" && "$port" != "???" ]]; then
            if curl -s --socks5-hostname "127.0.0.1:$port" https://google.com --connect-timeout 2 > /dev/null; then
                test_result="${NORD_GREEN}PASS${RST}"
            else
                test_result="${NORD_RED}FAIL${RST}"
            fi
        fi

        printf "${NORD_BLUE}%-25s${RST} ${s_color}%-10s${RST} ${NORD_SNOW_1}%-8s${RST} %b\n" \
            "$s_name" "$state" "$port" "$test_result"
    done

    echo ""
}

add_proxy() {
    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        _print_status "warning" "Usage: wpm add <name> <config> <port>"
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
        _print_status "error" "A tunnel or config with the name '$custom_name' already exists."
        return 1
    fi

    # Validate source configuration file
    if [ ! -f "$wg_path" ]; then
        _print_status "error" "Config not found: $wg_path"
        return 1
    fi

    # Check for duplicate ports across existing configurations (now scanning clean *.conf files)
    if [ -d "$CONFIG_DIR" ]; then
        for conf in "$CONFIG_DIR"/*.conf; do
            [ -e "$conf" ] || break
            local existing_port
            existing_port=$(grep "BindAddress" "$conf" | cut -d':' -f2)
            if [ "$existing_port" = "$proxy_port" ]; then
                _print_status "error" "Port $proxy_port is already in use by $(basename "$conf")"
                return 1
            fi
        done
    fi

    _print_header "Installing Tunnel: $custom_name" ""

    mkdir -p "$CONFIG_DIR"

    # Save and modify config based on whether [Socks5] configuration exists
    if grep -q "^\[Socks5\]" "$wg_path"; then
        command cp "$wg_path" "$FINAL_CONFIG"
        local existing_port=$(grep "BindAddress" "$wg_path" | cut -d':' -f2)
        _print_status "info" "Socks5 configuration block detected."
        _print_status "info" "Port: ${existing_port:-unknown}"

        if [ "$existing_port" != "$proxy_port" ]; then
            _print_status "warning" "Note: Embedded config port ($existing_port) differs from request ($proxy_port)."
        fi
    else
        {
            echo "[Socks5]"
            echo "BindAddress = 127.0.0.1:$proxy_port"
            echo ""
            cat "$wg_path"
        } > "$FINAL_CONFIG"
        _print_status "info" "Config saved as $(basename "$FINAL_CONFIG")"
        _print_status "info" "Port: ${proxy_port}"
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
        _print_status "success" "Tunnel enabled: $service_name"
    else
        _print_status "error" "Failed to enable tunnel."
    fi
    echo ""
}

start_proxy() {
    _print_header "Start Tunnels" ""
    local selections
    selections=$(_select_tunnels_fzf "Select tunnel(s) to start: ") || return 0

    echo ""
    while read -r line; do
        [[ -z "$line" ]] && continue
        local s_name=$(echo "$line" | awk '{print $1}')
        _print_status "info" "Starting: $s_name"
        sv start "$s_name" > /dev/null 2>&1 && _print_status "success" "Started: $s_name" || _print_status "error" "Failed to start: $s_name"
    done <<< "$selections"
    echo ""
}

stop_proxy() {
    _print_header "Stop Tunnels" ""
    local selections
    selections=$(_select_tunnels_fzf "Select tunnel(s) to stop: ") || return 0

    echo ""
    while read -r line; do
        [[ -z "$line" ]] && continue
        local s_name=$(echo "$line" | awk '{print $1}')
        _print_status "info" "Stopping: $s_name"
        sv stop "$s_name" > /dev/null 2>&1 && _print_status "success" "Stopped: $s_name" || _print_status "error" "Failed to stop: $s_name"
    done <<< "$selections"
    echo ""
}

restart_proxy() {
    _print_header "Restart Tunnels" ""
    local selections
    selections=$(_select_tunnels_fzf "Select tunnel(s) to restart: ") || return 0

    echo ""
    while read -r line; do
        [[ -z "$line" ]] && continue
        local s_name=$(echo "$line" | awk '{print $1}')
        _print_status "info" "Restarting: $s_name"
        sv restart "$s_name" > /dev/null 2>&1 && _print_status "success" "Restarted: $s_name" || _print_status "error" "Failed to restart: $s_name"
    done <<< "$selections"
    echo ""
}

remove_proxy() {
    _print_header "Uninstall Tunnels" ""
    local selections
    selections=$(_select_tunnels_fzf "Select tunnel(s) to remove: ") || return 0

    echo ""
    while read -r line; do
        [[ -z "$line" ]] && continue
        local s_name=$(echo "$line" | awk '{print $1}')

        # Service name is "name-wpm", but the conf file to delete/backup is just "name.conf"
        local base_name="${s_name%-wpm}"
        local conf_file="$CONFIG_DIR/${base_name}.conf"

        [ -f "$conf_file" ] && _print_status "success" "Backup: ~/wpm-backups/${base_name}.conf"
        _remove_wpm_tunnel "$s_name" "$CONFIG_DIR" "$SERVICE_BASE_DIR" || _print_status "warning" "Disable failed: $s_name"
        _print_status "success" "Removed: $s_name"
    done <<< "$selections"
    echo ""
}

refresh_proxies() {
    _print_header "Restarting All Tunnels" ""

    local -a services=("$SERVICE_BASE_DIR"/*-wpm)
    [[ -d "${services[0]}" ]] || {
        _print_status "info" "No tunnels to restart."
        echo ""
        return 0
    }

    local failed=0
    for s in "${services[@]}"; do
        [[ -d "$s" ]] || continue
        local s_name=$(basename "$s")
        _print_status "info" "Restarting: $s_name"
        sv restart "$s_name" || ((failed++))
    done

    echo ""
    if [ "$failed" -eq 0 ]; then
        _print_status "success" "All tunnels restarted."
    else
        _print_status "warning" "Failed to restart $failed tunnel(s)."
    fi
    echo ""
}

# --- Router ---
case "$1" in
    add)     add_proxy "$2" "$3" "$4" ;;
    rm)      remove_proxy ;;
    start)   start_proxy ;;
    stop)    stop_proxy ;;
    restart) restart_proxy ;;
    ls)      list_proxies ;;
    refresh) refresh_proxies ;;
    *)
        _print_header "Wireproxy Manager(wpm)" ""
        printf "${NORD_CYAN}%-28s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "add <name> <conf> <port>" "Add a proxy"
        printf "${NORD_CYAN}%-28s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "rm"                "Remove a proxy"
        printf "${NORD_CYAN}%-28s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "start"             "Start target proxy service(s)"
        printf "${NORD_CYAN}%-28s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "stop"              "Stop target proxy service(s)"
        printf "${NORD_CYAN}%-28s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "restart"           "Restart target proxy service(s)"
        printf "${NORD_CYAN}%-28s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "ls"                "List proxies"
        printf "${NORD_CYAN}%-28s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "refresh"           "Restart All Proxy Services"
        echo ""
        exit 1
        ;;
esac