# ==============================================================================
# TERMINAL CONFIGURATION (Nord Aesthetic)
# ==============================================================================
source "$TERMUX_CONFIG_PATH/helpers/colors-nord.sh"
source "$TERMUX_CONFIG_PATH/helpers/printer.sh"
source "$TERMUX_CONFIG_PATH/helpers/dep-checker.sh"

if ! _test_dependencies "starship" "zoxide" "nvim" "fzf" "fd" "trash-put" "trash-empty" "termux-open-url"; then
    printfc "$NORD_RED" "Skipping shell configuration. Run setup.sh to install missing dependencies."
    unset PROMPT_COMMAND
    PS1='\u@\h:\w\$ '
    return 1
fi

# --- History Settings ---
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# --- Default Editor ---
export EDITOR=nvim

eval "$(starship init bash)"
eval "$(zoxide init bash)"

# --- System Functions ---

_termux_age_days() {
    local install_epoch=$(stat -c %Y "$PREFIX")
    echo $(( ($(date +%s) - install_epoch) / 86400 ))
}

tage() {
    printfc "$NORD_SNOW_1" "%s day(s)" "$(_termux_age_days)"
}

sys() {
    # 1. Data Gathering
    local pkg_count=$(dpkg --get-selections 2>/dev/null | wc -l)
    local ker=$(uname -r | cut -d'-' -f1)
    local cuser=$(whoami)
    local mem=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
    local uptime_str=$(uptime -p | sed 's/up //')
    local storage=$(df -h /data 2>/dev/null | awk 'NR==2{print $3 " / " $2 " (" $5 " used)"}')

    # 2. Battery Logic
    local batt_raw=$(timeout 2 termux-battery-status 2>/dev/null)
    local batt_pct batt_state
    eval "$(echo "$batt_raw" | awk -F'[:,]' '
        /percentage/ { gsub(/ /,"",$2); print "batt_pct=" $2 }
        /status/     { gsub(/[" ]/,"",$2); print "batt_state=" $2 }
    ')"

    if [[ -z "$batt_pct" ]]; then
        local batt_status="N/A"
    else
        local batt_status="${batt_pct}% (${batt_state,,})"
    fi

    # 3. Network Logic
    local ip_addr=$(timeout 2 termux-wifi-connectioninfo 2>/dev/null | grep -i '"ip"' | awk -F'"' '{print $4}' | grep -v '^0')
    [[ -z "$ip_addr" ]] && ip_addr="-"

    # 4. Formatting and Output
    printfc "$NORD_SNOW_1" "\n%s  %-12s %s" "󰩟" "Local IP"   "$ip_addr"
    printfc "$NORD_SNOW_1" "%s  %-12s %s" ""  "User"       "$cuser"
    printfc "$NORD_SNOW_1" "%s  %-12s %s" "󱑎" "Uptime"     "$uptime_str"
    printfc "$NORD_SNOW_1" "%s  %-12s %s" "󰟾" "Kernel"     "$ker"
    printfc "$NORD_SNOW_1" "%s  %-12s %s" "󰍛" "Memory"     "$mem"
    printfc "$NORD_SNOW_1" "%s  %-12s %s" "󰋊" "Storage"    "$storage"
    printfc "$NORD_SNOW_1" "%s  %-12s %s" "󰏖" "Packages"   "$pkg_count"
    printfc "$NORD_SNOW_1" "%s  %-12s %s" "󰃭" "Age"        "$(_termux_age_days) day(s)"
    printfc "$NORD_SNOW_1" "%s  %-12s %s" "󱊟" "Battery"    "$batt_status"
    printfc "$NORD_SNOW_1" "%s  %-12s %s" ""  "Shell"      "Bash ${BASH_VERSION%%(*}"

    echo ""
}

cup() {
    printfc "$NORD_BLUE" "\n>Checking Updates"

    pkg update -y -o Dpkg::Use-Pty=0 > /dev/null 2>&1
    local upgradable=$(apt list --upgradable 2>/dev/null | grep '\[upgradable')

    if [ -z "$upgradable" ]; then
        printfc "$NORD_GREEN" "Up to date."
    else
        printfc "$NORD_YELLOW" "\nUpgradable Packages:"
        echo "$upgradable" | awk -F'/' '{print $1}' | while read -r pkg; do
            printfc "$NORD_SNOW_1" "- %s" "$pkg"
        done
    fi
    echo ""
}

upp() {
    printfc "$NORD_BLUE" "\n>Upgrading Packages\n"
    if pkg upgrade -y; then
        printfc "$NORD_GREEN" "Upgrade complete."
    else
        printfc "$NORD_RED" "Upgrade failed."
    fi
    echo ""
}

upall() {
    upp
    upc
}

upc() {
    printfc "$NORD_BLUE" "\n>Syncing Dotfiles\n"
    if git -C "$TERMUX_CONFIG_PATH" pull --rebase --autostash; then
        printfc "$NORD_GREEN" "Sync complete."
        printfc "$NORD_YELLOW" "Run 'reload' to apply updated configuration."
        echo ""
    else
        printfc "$NORD_RED" "Sync failed."
        echo ""
    fi
}

inst() {
    local selected=$(apt-cache pkgnames 2>/dev/null | sort | fzf \
        -m \
        --header='(TAB: Select, Enter: Install)' \
        --prompt="Install > " \
        --preview='apt-cache show {1} 2>/dev/null' \
        --preview-window=down:10:hidden:wrap \
        --bind 'ctrl-p:toggle-preview' | tr '\n' ' ' | sed 's/ $//')

    [[ -z "$selected" ]] && return 0

    local count=$(echo "$selected" | wc -w)

    printfc "$NORD_YELLOW" "\nSelected to install:"
    echo "$selected" | sed 's/ /\n/g; s/^/+ /'
    echo ""

    printfc "$NORD_BLUE" "\n>Installing Packages\n"
    history -s "pkg install -y $selected"
    if pkg install -y $selected; then
        printfc "$NORD_GREEN" "Installed successfully."
    else
        printfc "$NORD_RED" "Installation failed."
    fi
}

uinst() {
    local selected=$(dpkg --get-selections 2>/dev/null | grep -v deinstall | awk '{print $1}' | sort | fzf \
        -m \
        --header='(TAB: Select, Enter: Uninstall)' \
        --prompt="Uninstall > " \
        --preview='apt-cache show {1} 2>/dev/null' \
        --preview-window=down:10:hidden:wrap \
        --bind 'ctrl-p:toggle-preview' | tr '\n' ' ' | sed 's/ $//')

    [[ -z "$selected" ]] && return 0

    local count=$(echo "$selected" | wc -w)

    printfc "$NORD_YELLOW" "\nSelected for removal:"
    echo "$selected" | sed 's/ /\n/g; s/^/- /'
    echo ""

    printfc "$NORD_BLUE" "\n>Uninstalling Packages\n"
    history -s "pkg uninstall -y $selected"
    if pkg uninstall -y $selected; then
        printfc "$NORD_GREEN" "Uninstall complete."
    else
        printfc "$NORD_YELLOW" "Cancelled."
        echo ""
    fi
}

cleanup() {
    printfc "$NORD_BLUE" "\n>System Cleanup\n"
    pkg clean
    if apt autoremove -y; then
        printfc "$NORD_GREEN" "Cleanup complete."
    else
        printfc "$NORD_RED" "Cleanup failed."
    fi

    if [ -d "$HOME/.trash" ] && [ -n "$(ls -A "$HOME/.trash" 2>/dev/null)" ]; then
        local trash_size=$(du -sh "$HOME/.trash" 2>/dev/null | awk '{print $1}')
        yes | trash-empty --trash-dir "$HOME/.trash" 0
        printfc "$NORD_GREEN" "Trash emptied."
    fi
    echo ""
}

sz() {
    if [ -z "$1" ]; then
        printfc "$NORD_YELLOW" "Usage: sz <file/folder>"
        return 1
    fi
    if [ ! -e "$1" ]; then
        printfc "$NORD_RED" "Path not found: %s" "$1"
        return 1
    fi
    local size=$(du -sh "$1" | awk '{print $1}')
    printfc "$NORD_SNOW_1" "%s → %s" "$1" "$size"
}

trash() {
    local targets=()
    for arg in "$@"; do
        if [[ -e "$arg" || -L "$arg" ]]; then
            targets+=("$arg")
        else
            echo "Error: Path not found: $arg"
        fi
    done

    [[ ${#targets[@]} -eq 0 ]] && return 1
    command mkdir -p "$HOME/.trash"
    for item in "${targets[@]}"; do
        if trash-put --trash-dir "$HOME/.trash" "$item"; then
            echo "Trashed: $item"
        else
            echo "Failed to trash: $item"
        fi
    done
}

# --- Navigation & Utilities ---

alias ls='ls --color=auto -F'
alias lsl='ls -lh'
alias lsa='ls -a'
alias lsla='ls -lah'
alias rmr='rm -r'
alias rmrf='rm -rf'
alias cpr='cp -r'
alias cpa='cp -a'
alias ..='cd ..'
alias ...='cd ../..'
alias sd='cd ~/storage/shared'
alias reload='source ~/.bashrc && printfc "$NORD_GREEN" "Shell reloaded."'
alias clear='clear && sys'

ff() {
    if [ -z "$1" ]; then
        printfc "$NORD_YELLOW" "Usage: ff <path>"
        return 1
    fi

    local search_path="$1"

    if [ ! -e "$search_path" ]; then
        printfc "$NORD_RED" "Path not found: %s" "$search_path"
        return 1
    fi

    local selection
    if command -v fd > /dev/null 2>&1; then
        selection=$(fd --hidden --color never . "$search_path" 2>/dev/null | fzf --no-multi --layout=reverse --height=40% --header="Searching: $search_path")
    else
        selection=$(find "$search_path" 2>/dev/null | fzf --no-multi --layout=reverse --height=40% --header="Searching: $search_path")
    fi

    if [ -n "$selection" ]; then
        local escaped="\"${selection}\""
        printfc "$NORD_YELLOW" "Selected: %s" "$escaped"

        if command -v termux-clipboard-set >/dev/null 2>&1; then
            echo -n "$escaped" | termux-clipboard-set
            printfc "$NORD_GREEN" "Copied to clipboard."
        fi
    fi
}

_fhist() {
    local selections=$(history | awk '{$1=""; print substr($0,2)}' | tac | awk '!seen[$0]++' | fzf \
        -m \
        --header='(Enter: Run)' \
        --prompt="History > " \
    )

    if [ -n "$selections" ]; then
        local cmd=""
        while IFS= read -r line; do
            if [ -z "$cmd" ]; then
                cmd="$line"
            else
                cmd="$cmd & $line"
            fi
        done <<< "$selections"

        READLINE_LINE="$cmd"
        READLINE_POINT=${#cmd}
    fi
}
bind -x '"\C-h": _fhist'

wa() {
    if [[ -z "$1" ]]; then
        printfc "$NORD_YELLOW" "Usage: wa <phone_number>"
        printfc "$NORD_SNOW_1" "Example: wa 0771234567"
        return 1
    fi

    local number="${1//[^0-9+]/}"

    if [[ -z "$number" ]]; then
        printfc "$NORD_RED" "Invalid number: %s" "$1"
        return 1
    fi

    if [[ "$number" != +* ]]; then
        number="${number#0}"
        [[ "$number" != 94* ]] && number="94${number}"
    fi

    local url="https://wa.me/${number}"
    local display="${number#+}"
    printfc "$NORD_SNOW_1" "Opening WhatsApp chat → +%s" "$display"
    termux-open-url "$url"
}

# --- Initialization ---
sys
