# ==============================================================================
# FONT SETUP — downloads the MartianMono Nerd Font into the runtime cache and
# links it as ~/.termux/font.ttf. Silent: communicates via exit code only, so
# callers own all presentation (setup.sh uses colors-standard, .bashrc uses
# colors-nord).
#
# The installed release tag is tracked in <cache>/.version. Each run resolves
# the latest tag from GitHub (via the /releases/latest redirect) and skips the
# download unless it differs from the cached one.
#
#   _font_setup          install/update only when a new release is out
#   _font_setup --force  re-download regardless of version
#
# Exit codes:
#   0 = font installed or updated
#   1 = cache current (or offline with a cached copy), nothing to do
#   2 = download/extract failed
#   3 = font asset not found in archive
# ==============================================================================

_font_setup() {
    local force=0
    [ "$1" = "--force" ] && force=1

    local font_dir="$HOME/.config/termux-config-files/fonts"
    local font_file="$font_dir/MartianMonoNerdFontMono-Regular.ttf"
    local version_file="$font_dir/.version"
    local font_dest="$HOME/.termux/font.ttf"
    local latest_url="https://github.com/ryanoasis/nerd-fonts/releases/latest"
    local asset_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/MartianMono.tar.xz"

    # Resolve latest release tag; empty when unreachable (e.g. offline)
    local remote_version=""
    remote_version=$(curl -fsILo /dev/null -w '%{url_effective}' "$latest_url" 2>/dev/null)
    remote_version="${remote_version##*/}"
    case "$remote_version" in
        v[0-9]*) ;;
        *) remote_version="" ;;
    esac

    if [ -f "$font_file" ] && [ "$force" -eq 0 ]; then
        local cached_version=""
        [ -f "$version_file" ] && cached_version=$(<"$version_file")
        if [ -z "$remote_version" ] || [ "$cached_version" = "$remote_version" ]; then
            mkdir -p "$(dirname "$font_dest")"
            rm -f "$font_dest"
            ln -s "$font_file" "$font_dest"
            return 1
        fi
    fi

    mkdir -p "$font_dir"

    local tmp
    tmp=$(mktemp -d)
    if ! curl -fsSL "$asset_url" -o "$tmp/MartianMono.tar.xz"; then
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

    if [ -n "$remote_version" ]; then
        printf '%s\n' "$remote_version" > "$version_file"
    else
        rm -f "$version_file"
    fi

    mkdir -p "$(dirname "$font_dest")"
    rm -f "$font_dest"
    ln -s "$font_file" "$font_dest"
    return 0
}
