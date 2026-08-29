# ==============================================================================
# shell-helper.sh — shared by tools/shell.sh and reset.sh
# ==============================================================================

# Paths for the Shizuku remote-shell binaries. `rish` is the Android shell
# (uid 2000) launched through the Shizuku daemon; the .dex is its loader.
SHELL_RISH="$PREFIX/bin/rish"
SHELL_DEX="$PREFIX/bin/rish_shizuku.dex"

# Run a single command inside the Shizuku-backed Android shell.
# Usage: _shell_cmd '<adb shell command>'
# Both stdout and stderr pass through (Android shell errors go to stderr, and
# callers often need them); rish prints an "Entering shell..." banner on stdout.
_shell_cmd() {
    "$SHELL_RISH" -c "$1"
}

# Verifies the Shizuku-backed shell is reachable and running as the Android
# `shell` uid (2000), i.e. that the shizuku server is up and Termux has been
# granted the "Use Shizuku in terminal apps" shell permission.
# Sets _SHELL_OK=0/1, _SHELL_UID to the reported uid on success, and _SHELL_ERR
# to rish's captured stderr on failure (for diagnostics). Callers own output.
_verify_shizuku() {
    _SHELL_OK=0
    _SHELL_UID=""
    _SHELL_ERR=""
    if [ ! -x "$SHELL_RISH" ] || [ ! -f "$SHELL_DEX" ]; then
        return 1
    fi
    local uid out
    # Although `rish -c` reports via exit code, its stdout carries a banner
    # ("Entering shell...") before the real output, so pull the uid off a line
    # that is exactly a number instead of comparing the whole stream.
    out=$("$SHELL_RISH" -c 'id -u' 2>&1)
    uid=$(printf '%s\n' "$out" | sed -n 's/^\([0-9][0-9]*\)$/\1/p' | tail -1)
    if [[ "$uid" == "2000" ]]; then
        _SHELL_OK=1
        _SHELL_UID="$uid"
        return 0
    fi
    _SHELL_ERR="$out"
    return 1
}

# Used by reset.sh: removes the Shizuku shell binaries placed by `shell setup`.
_remove_shell_binaries() {
    local removed=0
    [ -f "$SHELL_DEX" ] && rm -f "$SHELL_DEX" && removed=1
    [ -f "$SHELL_RISH" ] && rm -f "$SHELL_RISH" && removed=1
    return "$removed"
}
