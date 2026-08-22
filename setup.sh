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
    sleep 3
else
    printfc "$GREEN" "Storage configured."
fi

# ==============================================================================
# 1. DEPENDENCIES
# ==============================================================================

printfc "$BLUE" "\n>Installing Dependencies\n"

pkg update -y -o Dpkg::Use-Pty=0

for pkg in $SETUP_PKGS; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        if pkg install -y "$pkg"; then
            printfc "$GREEN" "Installed %s" "$pkg"
        else
            printfc "$RED" "Failed: %s" "$pkg"
        fi
    else
        printfc "$GREEN" "%s already installed." "$pkg"
    fi
done

# ==============================================================================
# 2. DOTFILE LINKS
# ==============================================================================

printfc "$BLUE" "\n>Linking Configuration Files\n"

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
    fi
else
    printfc "$YELLOW" "tldr binary missing. Skipped cache update."
fi

# ==============================================================================
# 4. SERVICE & BOOT SETUP
# ==============================================================================

printfc "$BLUE" "\n>Services & Boot Setup\n"

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
    sleep 3
    sv-enable sshd
    ssh_up=0
    for i in $(seq 1 10); do
        sv up sshd &>/dev/null && { ssh_up=1; break; }
        sleep 1
    done
    if [ "$ssh_up" -eq 1 ]; then
        printfc "$GREEN" "SSH enabled."
    else
        printfc "$RED" "SSH did not come up after enabling. Check 'sv status sshd' manually."
    fi
else
    printfc "$YELLOW" "termux-services missing. Skipped SSH."
fi

# ==============================================================================
# 5. GLOBAL SCRIPTS
# ==============================================================================

printfc "$BLUE" "\n>Mapping Global Scripts\n"

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
    termux-wallpaper -f "$WALLPAPER"
    if [ ! -f "$HOME/.config/termux-config-files/yearwall/yearwall_update.sh" ]; then
        termux-wallpaper -f "$WALLPAPER" -l
    fi
    printfc "$GREEN" "Wallpaper applied."
else
    printfc "$YELLOW" "Missing: wallpaper.png"
fi

# ==============================================================================
# 8. FONT
# ==============================================================================

printfc "$BLUE" "\n>Downloading Nerd Font\n"

_font_setup
case $? in
    0)
        printfc "$GREEN" "Font cached."
        printfc "$GREEN" "Font linked."
        ;;
    1)
        printfc "$GREEN" "Font already cached."
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
printfc "$GREEN" "Setup complete! Run exit and relaunch Termux."
echo ""
