#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# TERMUX CONFIG INSTALLER
# ==============================================================================

CONFIG_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CONFIG_PATH/helpers/setup-helpers.sh"

# ==============================================================================
# START
# ==============================================================================

_print_header "Termux Installer"

# ==============================================================================
# 0. PREREQUISITES CHECK
# ==============================================================================

_print_header "Prerequisites Check"

warn "Ensure all of the following are installed via F-Droid or GitHub Releases (NOT Play Store):"
echo -e "  - Termux, Termux:API, Termux:Boot, and Termux:Styling"
warn "Select a single repository mirror via 'termux-change-repo' (not mandatory but recommended)"
echo ""

read -r -p "Are these ready? [y/N] " prereq_confirm
case "$prereq_confirm" in
    [yY]|[yY][eE][sS])
        ok "Prerequisites ready."
        ;;
    *)
        err "Aborted."
        exit 1
        ;;
esac

# ==============================================================================
# 0b. Storage Permission
# ==============================================================================

if [ ! -d ~/storage ]; then
    termux-setup-storage
    warn "Allow storage access in prompt..."
    sleep 3
else
    ok "Storage configured."
fi

# ==============================================================================
# 1. DEPENDENCIES
# ==============================================================================

_print_header "Installing Dependencies"

pkg update -y -o Dpkg::Use-Pty=0

for pkg in $SETUP_PKGS; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        if pkg install -y "$pkg"; then
            ok "Installed $pkg"
        else
            err "Failed: $pkg"
        fi
    else
        ok "$pkg already installed."
    fi
done

# ==============================================================================
# 2. DOTFILE LINKS
# ==============================================================================

_print_header "Linking Configuration Files"

while IFS= read -r -d '' src; do
    rel="${src#"$CONFIG_PATH/home/"}"
    dest="$HOME/$rel"
    mkdir -p "$(dirname "$dest")"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
            rm -f "$dest"
        elif [ -e "$dest.bak" ] || [ -L "$dest.bak" ]; then
            warn "Backup already exists, discarding current file: $rel"
            rm -rf "$dest"
        else
            mv "$dest" "$dest.bak"
            warn "Backed up existing file: $rel -> $rel.bak"
        fi
    fi

    ln -s "$src" "$dest"
    ok "Linked: $rel"
done < <(find "$CONFIG_PATH/home" -type f -print0)

# ==============================================================================
# 2b. EXPORT GLOBAL CONFIG PATH SYSTEM-WIDE
# ==============================================================================

_print_header "Configuring Global Environment Variables"

SYSTEM_PROFILE_DIR="$PREFIX/etc/profile.d"
CONFIG_ENV_FILE="$SYSTEM_PROFILE_DIR/termux_config.sh"

mkdir -p "$SYSTEM_PROFILE_DIR"

ok "Deploying TERMUX_CONFIG_PATH into system environment..."

cat > "$CONFIG_ENV_FILE" << EOF
# Global Configuration Path Environment Variable
export TERMUX_CONFIG_PATH="$CONFIG_PATH"
EOF

chmod 755 "$CONFIG_ENV_FILE"
ok "Created system profile script: $CONFIG_ENV_FILE"
source "$CONFIG_ENV_FILE"

# ==============================================================================
# 3. TEALDEER
# ==============================================================================

_print_header "Tealdeer (tldr) Cache"

if command -v tldr &>/dev/null; then
    if tldr --update; then
        ok "tldr cache updated."
    else
        err "tldr cache update failed."
    fi
else
    warn "tldr binary missing. Skipped cache update."
fi

# ==============================================================================
# 4. SERVICE & BOOT SETUP
# ==============================================================================

_print_header "Services & Boot Setup"

mkdir -p "$HOME/.termux/boot"

BOOT_SERVICES="$HOME/.termux/boot/10-services.sh"
if [ ! -f "$BOOT_SERVICES" ]; then
    cat > "$BOOT_SERVICES" << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
source /data/data/com.termux/files/usr/etc/profile.d/start-services.sh
EOF
    chmod +x "$BOOT_SERVICES"
    ok "Boot script created: 10-services.sh"
else
    ok "Boot script exists."
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
        ok "SSH enabled."
    else
        err "SSH did not come up after enabling. Check 'sv status sshd' manually."
    fi
else
    warn "termux-services missing. Skipped SSH."
fi

# ==============================================================================
# 5. GLOBAL SCRIPTS
# ==============================================================================

_print_header "Mapping Global Scripts"

for dir in "$CONFIG_PATH"/scripts/*/; do
    name="$(basename "$dir")"
    main_script="$dir$name.sh"
    if [ -f "$main_script" ]; then
        chmod +x "$main_script"
        rm -f "$PREFIX/bin/$name"
        ln -s "$main_script" "$PREFIX/bin/$name"
        ok "Mapped $name."
    else
        warn "Missing: $name.sh"
    fi
done

# ==============================================================================
# 6. SECURITY CHECK
# ==============================================================================

_print_header "Password Configuration"

if [ -f "$HOME/.termux_authinfo" ]; then
    ok "Password set."
else
    warn "Set a password:"
    passwd
fi

# ==============================================================================
# 7. WALLPAPER
# ==============================================================================

_print_header "Applying Wallpaper"

WALLPAPER="$CONFIG_PATH/data/wallpaper/wallpaper.png"
if [ -f "$WALLPAPER" ]; then
    termux-wallpaper -f "$WALLPAPER"
    termux-wallpaper -f "$WALLPAPER" -l
    ok "Wallpaper applied."
else
    warn "Missing: wallpaper.png"
fi

# ==============================================================================
# 8. FONT
# ==============================================================================

_print_header "Downloading Nerd Font"

FONT_DIR="$HOME/.config/termux-config-files/fonts"
FONT_FILE="$FONT_DIR/MartianMonoNerdFontMono-Regular.ttf"
FONT_DEST="$HOME/.termux/font.ttf"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/MartianMono.tar.xz"

mkdir -p "$FONT_DIR"

if [ ! -f "$FONT_FILE" ]; then
    warn "Downloading Nerd Font..."
    FONT_TMP=$(mktemp -d)
    if curl -fsSL "$FONT_URL" -o "$FONT_TMP/MartianMono.tar.xz"; then
        tar -xf "$FONT_TMP/MartianMono.tar.xz" -C "$FONT_TMP"
        EXTRACTED=$(find "$FONT_TMP" -name "MartianMonoNerdFontMono-Regular.ttf" | head -n1)
        if [ -n "$EXTRACTED" ]; then
            cp "$EXTRACTED" "$FONT_FILE"
            ok "Font cached."
        else
            err "Font asset not found."
            rm -rf "$FONT_TMP"
            exit 1
        fi
    else
        err "Download failed. Check internet."
        rm -rf "$FONT_TMP"
        exit 1
    fi
    rm -rf "$FONT_TMP"
else
    ok "Font already cached."
fi

rm -f "$FONT_DEST"
ln -s "$FONT_FILE" "$FONT_DEST"
ok "Font linked."

# ==============================================================================
# DONE
# ==============================================================================

echo ""
ok "Setup complete! Run exit and relaunch Termux."
echo ""