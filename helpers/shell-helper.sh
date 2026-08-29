# ==============================================================================
# shell-helper.sh — shared by tools/shell.sh and reset.sh
# ==============================================================================

# Paths for the Shizuku remote-shell binaries. `rish` is the Android shell
# (uid 2000) launched through the Shizuku daemon; the .dex is its loader.
SHELL_RISH="$PREFIX/bin/rish"
SHELL_DEX="$PREFIX/bin/rish_shizuku.dex"

# Run a single command inside the Shizuku-backed Android shell.
# Usage: _shell_cmd '<adb shell command>'
_shell_cmd() {
    "$SHELL_RISH" -c "$1" 2>/dev/null
}

# Verifies the Shizuku-backed shell is reachable and running as the Android
# `shell` uid (2000), i.e. that the shizuku server is up and Termux has been
# granted the "Use Shizuku in terminal apps" shell permission.
# Sets _SHELL_OK=0/1 and _SHELL_UID to the reported uid on success.
# Callers own all colored output.
_verify_shizuku() {
    _SHELL_OK=0
    _SHELL_UID=""
    if [ ! -x "$SHELL_RISH" ] || [ ! -f "$SHELL_DEX" ]; then
        return 1
    fi
    local uid
    uid=$(_shell_cmd 'id -u')
    if [[ "$uid" == "2000" ]]; then
        _SHELL_OK=1
        _SHELL_UID="$uid"
        return 0
    fi
    return 1
}

# Used by reset.sh: removes the Shizuku shell binaries placed by `shell setup`.
_remove_shell_binaries() {
    local removed=0
    [ -f "$SHELL_DEX" ] && rm -f "$SHELL_DEX" && removed=1
    [ -f "$SHELL_RISH" ] && rm -f "$SHELL_RISH" && removed=1
    return "$removed"
}
