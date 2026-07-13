#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# TERMUX CONFIG INSTALLER
# ==============================================================================

CONFIG_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CONFIG_PATH/helpers/colors-standard.sh"
source "$CONFIG_PATH/helpers/print.sh"
source "$CONFIG_PATH/helpers/packages.sh"

# ==============================================================================
# START
# ==============================================================================

printfc "$CYAN" "\n┌────────────────────┐\n"
printfc "$CYAN" "│  Termux Installer  │\n"
printfc "$CYAN" "└────────────────────┘\n"

# ==============================================================================
# 0. PREREQUISITES CHECK
# ==============================================================================

printfc "$BLUE" "\n>Prerequisites Check\n"

printfc "$YELLOW" "Ensure all of the following are installed via F-Droid or GitHub Releases (NOT Play Store):\n"
echo -e "  - Termux, Termux:API, Termux:Boot, and Termux:Styling"
printfc "$YELLOW" "Select a single repository mirror via 'termux-change-repo' (not mandatory but recommended)\n"
echo ""

read -r -p "Are these ready? [y/N] " prereq_confirm
case "$prereq_confirm" in
    [yY]|[yY][eE][sS])
        printfc "$GREEN" "Prerequisites ready.\n"
        ;;
    *)
        printfc "$RED" "Aborted.\n"
        exit 1
        ;;
esac

# ==============================================================================
# 0b. Storage Permission
# ==============================================================================

if [ ! -d ~/storage ]; then
    termux-setup-storage
    printfc "$YELLOW" "Allow storage access in prompt...\n"
    sleep 3
else
    printfc "$GREEN" "Storage configured.\n"
fi

# ==============================================================================
# 1. DEPENDENCIES
# ==============================================================================

printfc "$BLUE" "\n>Installing Dependencies\n"

pkg update -y -o Dpkg::Use-Pty=0

for pkg in $SETUP_PKGS; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        if pkg install -y "$pkg"; then
            printfc "$GREEN" "Installed %s\n" "$pkg"
        else
            printfc "$RED" "Failed: %s\n" "$pkg"
        fi
    else
        printfc "$GREEN" "%s already installed.\n" "$pkg"
    fi
done

# ==============================================================================
# 2. DOTFILE LINKS
# ==============================================================================

printfc "$BLUE" "\n>Linking Configuration Files\n"

while IFS= read -r -d '' src; do
    rel="${src#"$CONFIG_PATH/home/"}"
    dest="$HOME/$rel"
    mkdir -p "$(dirname "$dest")"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
            rm -f "$dest"
        elif [ -e "$dest.bak" ] || [ -L "$dest.bak" ]; then
            printfc "$YELLOW" "Backup already exists, discarding current file: %s\n" "$rel"
            rm -rf "$dest"
        else
            mv "$dest" "$dest.bak"
            printfc "$YELLOW" "Backed up existing file: %s -> %s.bak\n" "$rel" "$rel"
        fi
    fi

    ln -s "$src" "$dest"
    printfc "$GREEN" "Linked: %s\n" "$rel"
done < <(find "$CONFIG_PATH/home" -type f -print0)

# ==============================================================================
# 2b. EXPORT GLOBAL CONFIG PATH SYSTEM-WIDE
# ==============================================================================

printfc "$BLUE" "\n>Configuring Global Environment Variables\n"

SYSTEM_PROFILE_DIR="$PREFIX/etc/profile.d"
CONFIG_ENV_FILE="$SYSTEM_PROFILE_DIR/termux_config.sh"

mkdir -p "$SYSTEM_PROFILE_DIR"

printfc "$GREEN" "Deploying TERMUX_CONFIG_PATH into system environment...\n"

cat > "$CONFIG_ENV_FILE" << EOF
# Global Configuration Path Environment Variable
export TERMUX_CONFIG_PATH="$CONFIG_PATH"
EOF

chmod 755 "$CONFIG_ENV_FILE"
printfc "$GREEN" "Created system profile script: %s\n" "$CONFIG_ENV_FILE"
source "$CONFIG_ENV_FILE"

# ==============================================================================
# 3. TEALDEER
# ==============================================================================

printfc "$BLUE" "\n>Tealdeer (tldr) Cache\n"

if command -v tldr &>/dev/null; then
    if tldr --update; then
        printfc "$GREEN" "tldr cache updated.\n"
    else
        printfc "$RED" "tldr cache update failed.\n"
    fi
else
    printfc "$YELLOW" "tldr binary missing. Skipped cache update.\n"
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
    printfc "$GREEN" "Boot script created: 10-services.sh\n"
else
    printfc "$GREEN" "Boot script exists.\n"
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
        printfc "$GREEN" "SSH enabled.\n"
    else
        printfc "$RED" "SSH did not come up after enabling. Check 'sv status sshd' manually.\n"
    fi
else
    printfc "$YELLOW" "termux-services missing. Skipped SSH.\n"
fi

# ==============================================================================
# 5. GLOBAL SCRIPTS
# ==============================================================================

printfc "$BLUE" "\n>Mapping Global Scripts\n"

for dir in "$CONFIG_PATH"/scripts/*/; do
    name="$(basename "$dir")"
    main_script="$dir$name.sh"
    if [ -f "$main_script" ]; then
        chmod +x "$main_script"
        rm -f "$PREFIX/bin/$name"
        ln -s "$main_script" "$PREFIX/bin/$name"
        printfc "$GREEN" "Mapped %s.\n" "$name"
    else
        printfc "$YELLOW" "Missing: %s.sh\n" "$name"
    fi
done

# ==============================================================================
# 6. SECURITY CHECK
# ==============================================================================

printfc "$BLUE" "\n>Password Configuration\n"

if [ -f "$HOME/.termux_authinfo" ]; then
    printfc "$GREEN" "Password set.\n"
else
    printfc "$YELLOW" "Set a password:\n"
    passwd
fi

# ==============================================================================
# 7. WALLPAPER
# ==============================================================================

printfc "$BLUE" "\n>Applying Wallpaper\n"

WALLPAPER="$CONFIG_PATH/data/wallpaper/wallpaper.png"
if [ -f "$WALLPAPER" ]; then
    termux-wallpaper -f "$WALLPAPER"
    termux-wallpaper -f "$WALLPAPER" -l
    printfc "$GREEN" "Wallpaper applied.\n"
else
    printfc "$YELLOW" "Missing: wallpaper.png\n"
fi

# ==============================================================================
# 8. FONT
# ==============================================================================

printfc "$BLUE" "\n>Downloading Nerd Font\n"

FONT_DIR="$HOME/.config/termux-config-files/fonts"
FONT_FILE="$FONT_DIR/MartianMonoNerdFontMono-Regular.ttf"
FONT_DEST="$HOME/.termux/font.ttf"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/MartianMono.tar.xz"

mkdir -p "$FONT_DIR"

if [ ! -f "$FONT_FILE" ]; then
    printfc "$YELLOW" "Downloading Nerd Font...\n"
    FONT_TMP=$(mktemp -d)
    if curl -fsSL "$FONT_URL" -o "$FONT_TMP/MartianMono.tar.xz"; then
        tar -xf "$FONT_TMP/MartianMono.tar.xz" -C "$FONT_TMP"
        EXTRACTED=$(find "$FONT_TMP" -name "MartianMonoNerdFontMono-Regular.ttf" | head -n1)
        if [ -n "$EXTRACTED" ]; then
            cp "$EXTRACTED" "$FONT_FILE"
            printfc "$GREEN" "Font cached.\n"
        else
            printfc "$RED" "Font asset not found.\n"
            rm -rf "$FONT_TMP"
            exit 1
        fi
    else
        printfc "$RED" "Download failed. Check internet.\n"
        rm -rf "$FONT_TMP"
        exit 1
    fi
    rm -rf "$FONT_TMP"
else
    printfc "$GREEN" "Font already cached.\n"
fi

rm -f "$FONT_DEST"
ln -s "$FONT_FILE" "$FONT_DEST"
printfc "$GREEN" "Font linked.\n"

# ==============================================================================
# DONE
# ==============================================================================

echo ""
printfc "$GREEN" "Setup complete! Run exit and relaunch Termux.\n"
echo ""
