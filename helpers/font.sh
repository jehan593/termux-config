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
#   _font_check          report only: is a newer release available?
#
# _font_setup exit codes:
#   0 = font installed or updated
#   1 = cache current (or offline with a cached copy), nothing to do
#   2 = download/extract failed
#   3 = font asset not found in archive
#
# _font_check exit codes:
#   0 = update available
#   1 = up to date, or release tag unresolvable (offline)
# ==============================================================================

# Resolves the latest nerd-fonts release tag. Prints the tag on success;
# fails when unreachable or the response doesn't look like a tag.
_font_remote_tag() {
    local tag
    tag=$(curl -fsILo /dev/null -w '%{url_effective}' \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest" 2>/dev/null)
    tag="${tag##*/}"
    case "$tag" in
        v[0-9]*) printf '%s\n' "$tag" ;;
        *) return 1 ;;
    esac
}

# Update probe: compares the cached .version against the latest release tag.
_font_check() {
    local version_file="$HOME/.config/termux-config-files/fonts/.version"
    local remote_version cached_version=""

    remote_version=$(_font_remote_tag) || return 1
    [ -f "$version_file" ] && cached_version=$(<"$version_file")

    [ "$cached_version" != "$remote_version" ]
}

_font_setup() {
    local force=0
    [ "$1" = "--force" ] && force=1

    local font_dir="$HOME/.config/termux-config-files/fonts"
    local font_file="$font_dir/MartianMonoNerdFontMono-Regular.ttf"
    local version_file="$font_dir/.version"
    local font_dest="$HOME/.termux/font.ttf"
    local asset_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/MartianMono.tar.xz"

    # Resolve latest release tag; empty when unreachable (e.g. offline)
    local remote_version=""
    remote_version=$(_font_remote_tag) || remote_version=""

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
