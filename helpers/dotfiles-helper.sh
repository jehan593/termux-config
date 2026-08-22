# ==============================================================================
# dotfiles-helper.sh — shared by setup.sh and reset.sh
# Silent: communicates via result arrays, callers own presentation.
#
#   _link_dotfiles <config_path>   fills _DOT_LINKED, _DOT_BACKED_UP,
#                                  _DOT_DISCARDED        (relative paths)
#   _unlink_dotfiles <config_path> fills _DOT_REMOVED, _DOT_SKIPPED
#                                                        (absolute paths)
#                                  and  _DOT_RESTORED    (relative paths)
# ==============================================================================

# Symlinks every file under $config_path/home to the same relative path under
# $HOME. Backs up any real pre-existing file to <dest>.bak once.
_link_dotfiles() {
    local config_path="$1"

    _DOT_LINKED=()
    _DOT_BACKED_UP=()
    _DOT_DISCARDED=()

    while IFS= read -r -d '' src; do
        local rel="${src#"$config_path/home/"}"
        local dest="$HOME/$rel"
        mkdir -p "$(dirname "$dest")"

        if [ -e "$dest" ] || [ -L "$dest" ]; then
            if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
                rm -f "$dest"
            elif [ -e "$dest.bak" ] || [ -L "$dest.bak" ]; then
                _DOT_DISCARDED+=("$rel")
                rm -rf "$dest"
            else
                mv "$dest" "$dest.bak"
                _DOT_BACKED_UP+=("$rel")
            fi
        fi

        ln -s "$src" "$dest"
        _DOT_LINKED+=("$rel")
    done < <(find "$config_path/home" -type f -print0)
}

# Removes symlinks created by _link_dotfiles and restores any .bak backup.
_unlink_dotfiles() {
    local config_path="$1"

    _DOT_REMOVED=()
    _DOT_SKIPPED=()
    _DOT_RESTORED=()

    while IFS= read -r -d '' src; do
        local rel="${src#"$config_path/home/"}"
        local link="$HOME/$rel"

        if [ -L "$link" ]; then
            rm -f "$link"
            _DOT_REMOVED+=("$link")
        else
            _DOT_SKIPPED+=("$link")
        fi

        if [ -e "$link.bak" ] || [ -L "$link.bak" ]; then
            mv -f "$link.bak" "$link"
            _DOT_RESTORED+=("$rel")
        fi
    done < <(find "$config_path/home" -type f -print0)
}
