# ==============================================================================
# dotfiles-helper.sh — shared by setup.sh and reset.sh
# ==============================================================================

# Symlinks every file under $config_path/home to the same relative path under
# $HOME. Backs up any real pre-existing file to <dest>.bak once.
_link_dotfiles() {
    local config_path="$1"

    while IFS= read -r -d '' src; do
        local rel="${src#"$config_path/home/"}"
        local dest="$HOME/$rel"
        mkdir -p "$(dirname "$dest")"

        if [ -e "$dest" ] || [ -L "$dest" ]; then
            if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
                rm -f "$dest"
            elif [ -e "$dest.bak" ] || [ -L "$dest.bak" ]; then
                printfc "$YELLOW" "Backup already exists, discarding current file: %s" "$rel"
                rm -rf "$dest"
            else
                mv "$dest" "$dest.bak"
                printfc "$YELLOW" "Backed up existing file: %s -> %s.bak" "$rel" "$rel"
            fi
        fi

        ln -s "$src" "$dest"
        printfc "$GREEN" "Linked: %s" "$rel"
    done < <(find "$config_path/home" -type f -print0)
}

# Removes symlinks created by _link_dotfiles and restores any .bak backup.
_unlink_dotfiles() {
    local config_path="$1"

    while IFS= read -r -d '' src; do
        local rel="${src#"$config_path/home/"}"
        local link="$HOME/$rel"

        if [ -L "$link" ]; then
            rm -f "$link"
            printfc "$GREEN" "Removed: %s" "$link"
        else
            printfc "$YELLOW" "Skipped: %s" "$link"
        fi

        if [ -e "$link.bak" ] || [ -L "$link.bak" ]; then
            mv -f "$link.bak" "$link"
            printfc "$GREEN" "Restored backup: %s" "$rel"
        fi
    done < <(find "$config_path/home" -type f -print0)
}
