# ==============================================================================
# FONT SETUP — downloads the MartianMono Nerd Font into the runtime cache and
# links it as ~/.termux/font.ttf. Silent: communicates via exit code only, so
# callers own all presentation (setup.sh uses colors-standard, .bashrc uses
# colors-nord).
#
#   _font_setup          install if not cached (no-op otherwise)
#   _font_setup --force  re-download even if cached
#
# Exit codes:
#   0 = font installed or updated
#   1 = already cached, nothing to do (link still ensured)
#   2 = download/extract failed
#   3 = font asset not found in archive
# ==============================================================================

_font_setup() {
    local force=0
    [ "$1" = "--force" ] && force=1

    local font_dir="$HOME/.config/termux-config-files/fonts"
    local font_file="$font_dir/MartianMonoNerdFontMono-Regular.ttf"
    local font_dest="$HOME/.termux/font.ttf"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/MartianMono.tar.xz"

    if [ -f "$font_file" ] && [ "$force" -eq 0 ]; then
        if [ ! -e "$font_dest" ]; then
            mkdir -p "$(dirname "$font_dest")"
            ln -s "$font_file" "$font_dest"
        fi
        return 1
    fi

    mkdir -p "$font_dir"

    local tmp
    tmp=$(mktemp -d)
    if ! curl -fsSL "$font_url" -o "$tmp/MartianMono.tar.xz"; then
        rm -rf "$tmp"
        return 2
    fi

    if ! tar -xf "$tmp/MartianMono.tar.xz" -C "$tmp"; then
        rm -rf "$tmp"
        return 2
    fi

    local extracted
    extracted=$(find "$tmp" -name "MartianMonoNerdFontMono-Regular.ttf" | head -n1)
    if [ -z "$extracted" ]; then
        rm -rf "$tmp"
        return 3
    fi

    cp -f "$extracted" "$font_file"
    rm -rf "$tmp"

    rm -f "$font_dest"
    ln -s "$font_file" "$font_dest"
    return 0
}
