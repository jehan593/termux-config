#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# TERMUX CONFIG INSTALLER
# ==============================================================================

CONFIG_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CONFIG_PATH/helpers/colors-standard.sh"
source "$CONFIG_PATH/helpers/printer.sh"
source "$CONFIG_PATH/helpers/pkg-list.sh"
source "$CONFIG_PATH/helpers/dotfiles-helper.sh"
source "$CONFIG_PATH/helpers/font.sh"

# ==============================================================================
# START
# ==============================================================================

printfc "$CYAN" "\n┌────────────────────┐"
printfc "$CYAN" "│  Termux Installer  │"
printfc "$CYAN" "└────────────────────┘"

had_error=0

# ==============================================================================
# 0. PREREQUISITES CHECK
# ==============================================================================

printfc "$BLUE" "\n>Prerequisites Check"

printfc "$YELLOW" "Ensure all of the following are installed via F-Droid or GitHub Releases (NOT Play Store):"
echo -e "  - Termux, Termux:API, Termux:Boot, and Termux:Styling"
printfc "$YELLOW" "Select a single repository mirror via 'termux-change-repo' (not mandatory but recommended)"
echo ""

read -r -p "Are these ready? [y/N] " prereq_confirm
case "$prereq_confirm" in
    [yY]|[yY][eE][sS])
        printfc "$GREEN" "Prerequisites ready."
        ;;
    *)
        printfc "$RED" "Aborted."
        exit 1
        ;;
esac

# ==============================================================================
# 0b. Storage Permission
# ==============================================================================

if [ ! -d ~/storage ]; then
    termux-setup-storage
    printfc "$YELLOW" "Allow storage access in prompt..."
    # Wait for the directory to appear instead of a fixed sleep — returns as
    # soon as permission is granted (up to 30s, then continues anyway).
    for i in $(seq 1 30); do
        [ -d ~/storage ] && break
        sleep 1
    done
fi
if [ -d ~/storage ]; then
    printfc "$GREEN" "Storage configured."
else
    printfc "$YELLOW" "Storage access not granted - continuing anyway."
fi

# ==============================================================================
# 1. DEPENDENCIES
# ==============================================================================

printfc "$BLUE" "\n>Installing Dependencies"

pkg update -y -o Dpkg::Use-Pty=0 || {
    printfc "$YELLOW" "Could not refresh the package list. Try running setup again."
    had_error=1
}

# Collect missing packages first, then install them in a single apt
# transaction — one 'pkg install' per package would pay the full apt startup
# cost for each one.
missing=""
for pkg in $SETUP_PKGS; do
    if dpkg -s "$pkg" &>/dev/null; then
        printfc "$GREEN" "%s already installed." "$pkg"
    else
        missing+="$pkg "
    fi
done

if [ -n "$missing" ]; then
    if pkg install -y $missing; then
        printfc "$GREEN" "Installed: %s" "$missing"
    else
        # Batch failed: retry one by one so a single bad package doesn't
        # mask the ones that would otherwise succeed.
        for pkg in $missing; do
            if pkg install -y "$pkg"; then
                printfc "$GREEN" "Installed %s" "$pkg"
            else
                printfc "$RED" "Failed: %s" "$pkg"
                had_error=1
            fi
        done
    fi
fi

# ==============================================================================
# 2. DOTFILE LINKS
# ==============================================================================

printfc "$BLUE" "\n>Linking Configuration Files"

_link_dotfiles "$CONFIG_PATH"
for rel in "${_DOT_DISCARDED[@]}"; do
    printfc "$YELLOW" "Backup already exists, discarding current file: %s" "$rel"
done
for rel in "${_DOT_BACKED_UP[@]}"; do
    printfc "$YELLOW" "Backed up existing file: %s -> %s.bak" "$rel" "$rel"
done
for rel in "${_DOT_LINKED[@]}"; do
    printfc "$GREEN" "Linked: %s" "$rel"
done

# ==============================================================================
# 2b. EXPORT GLOBAL CONFIG PATH SYSTEM-WIDE
# ==============================================================================

printfc "$BLUE" "\n>Configuring Global Environment Variables"

SYSTEM_PROFILE_DIR="$PREFIX/etc/profile.d"
CONFIG_ENV_FILE="$SYSTEM_PROFILE_DIR/termux_config.sh"

mkdir -p "$SYSTEM_PROFILE_DIR"

printfc "$GREEN" "Deploying TERMUX_CONFIG_PATH into system environment..."

cat > "$CONFIG_ENV_FILE" << EOF
# Global Configuration Path Environment Variable
export TERMUX_CONFIG_PATH="$CONFIG_PATH"
EOF

chmod 755 "$CONFIG_ENV_FILE"
printfc "$GREEN" "Created system profile script: %s" "$CONFIG_ENV_FILE"
source "$CONFIG_ENV_FILE"

# ==============================================================================
# 3. TEALDEER
# ==============================================================================

printfc "$BLUE" "\n>Tealdeer (tldr) Cache"

if command -v tldr &>/dev/null; then
    if tldr --update; then
        printfc "$GREEN" "tldr cache updated."
    else
        printfc "$RED" "tldr cache update failed."
        had_error=1
    fi
else
    printfc "$YELLOW" "tldr binary missing. Skipped cache update."
fi

# ==============================================================================
# 4. SERVICE & BOOT SETUP
# ==============================================================================

printfc "$BLUE" "\n>Services & Boot Setup"

mkdir -p "$HOME/.termux/boot"

BOOT_SERVICES="$HOME/.termux/boot/10-services.sh"
if [ ! -f "$BOOT_SERVICES" ]; then
    cat > "$BOOT_SERVICES" << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
source /data/data/com.termux/files/usr/etc/profile.d/start-services.sh
EOF
    chmod +x "$BOOT_SERVICES"
    printfc "$GREEN" "Boot script created: 10-services.sh"
else
    printfc "$GREEN" "Boot script exists."
fi

if command -v sv-enable &>/dev/null; then
    source "$BOOT_SERVICES"
    # No fixed sleep here: the sv up retry loop below waits for runsvdir to
    # pick up the service.
    sv-enable sshd
    ssh_up=0
    for i in $(seq 1 10); do
        sv up sshd &>/dev/null && { ssh_up=1; break; }
        sleep 1
    done
    if [ "$ssh_up" -eq 1 ]; then
        printfc "$GREEN" "SSH enabled."
    else
        printfc "$RED" "SSH failed to start. Check with 'sv status sshd'."
        had_error=1
    fi
else
    printfc "$YELLOW" "termux-services missing. Skipped SSH."
fi

# ==============================================================================
# 5. GLOBAL SCRIPTS
# ==============================================================================

printfc "$BLUE" "\n>Mapping Global Scripts"

for main_script in "$CONFIG_PATH"/tools/*.sh; do
    name="$(basename "$main_script" .sh)"
    if [ -f "$main_script" ]; then
        chmod +x "$main_script"
        rm -f "$PREFIX/bin/$name"
        ln -s "$main_script" "$PREFIX/bin/$name"
        printfc "$GREEN" "Mapped %s." "$name"
    else
        printfc "$YELLOW" "Missing: %s.sh" "$name"
    fi
done

# ==============================================================================
# 6. SECURITY CHECK
# ==============================================================================

printfc "$BLUE" "\n>Password Configuration"

if [ -f "$HOME/.termux_authinfo" ]; then
    printfc "$GREEN" "Password set."
else
    while [ ! -f "$HOME/.termux_authinfo" ]; do
        printfc "$YELLOW" "Set a password:"
        passwd
        if [ ! -f "$HOME/.termux_authinfo" ]; then
            printfc "$RED" "Passwords didn't match, try again."
        fi
    done
    printfc "$GREEN" "Password set."
fi

# ==============================================================================
# 7. WALLPAPER
# ==============================================================================

printfc "$BLUE" "\n>Applying Wallpaper"

WALLPAPER="$CONFIG_PATH/data/wallpaper/wallpaper.png"
if [ -f "$WALLPAPER" ]; then
    if termux-wallpaper -f "$WALLPAPER"; then
        # Preserve the lock-screen wallpaper when yearwall is installed.
        if [ ! -f "$HOME/.config/termux-config-files/yearwall/yearwall_update.sh" ]; then
            termux-wallpaper -f "$WALLPAPER" -l
        fi
        printfc "$GREEN" "Wallpaper applied."
    else
        printfc "$RED" "Failed to apply wallpaper."
        had_error=1
    fi
else
    printfc "$YELLOW" "Missing: wallpaper.png"
fi

# ==============================================================================
# 8. FONT
# ==============================================================================

printfc "$BLUE" "\n>Downloading Nerd Font"

_font_setup
case $? in
    0)
        printfc "$GREEN" "Font downloaded."
        printfc "$GREEN" "Font linked."
        ;;
    1)
        printfc "$GREEN" "Font already up to date."
        printfc "$GREEN" "Font linked."
        ;;
    2)
        printfc "$RED" "Download failed. Check internet."
        exit 1
        ;;
    3)
        printfc "$RED" "Font asset not found."
        exit 1
        ;;
esac

# ==============================================================================
# DONE
# ==============================================================================

echo ""
if [ "$had_error" -eq 1 ]; then
    printfc "$YELLOW" "Setup finished with some errors — review the messages above."
else
    printfc "$GREEN" "Setup complete! Run exit and relaunch Termux."
fi
echo ""
