#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# create-ephemeral-user — pre-built ADB script for `shell scripts`
#
# Creates an ephemeral (auto-removed on reboot) secondary user with the
# SetupWizard skipped, then installs com.aurora.store — but ONLY if it's
# already installed in the current (owner) user; otherwise it's skipped.
#
# Uses the Shizuku-backed `rish` remote shell, so Shizuku must be running and
# `shell setup` must have succeeded first.
# ==============================================================================
source "$TERMUX_CONFIG_PATH/helpers/colors-nord.sh"
source "$TERMUX_CONFIG_PATH/helpers/printer.sh"
source "$TERMUX_CONFIG_PATH/helpers/dep-checker.sh"
source "$TERMUX_CONFIG_PATH/helpers/shell-helper.sh"

if ! _test_dependencies "rish"; then
    printfc "$NORD_RED" "Missing: rish. Run 'shell setup' first."
    exit 1
fi

_verify_shizuku || {
    printfc "$NORD_RED" "Shizuku shell unavailable. Run 'shell setup'."
    exit 1
}

PKGS_TO_INSTALL="com.aurora.store"

# 0. Reuse a stable label so any earlier ephemeral user is easy to spot in the
#    user list; more than one can exist at once. If a label already exists,
#    pick the next free one (ephemeral, ephemeral2, ephemeral3, …) so the new
#    user's label never collides.
BASE_USER_LABEL="ephemeral"
label="$BASE_USER_LABEL"

existing=$(_shell_cmd "pm list users")
existing_names=$(printf '%s\n' "$existing" \
    | grep -oE "[0-9]+:${BASE_USER_LABEL}[^:]*" \
    | cut -d: -f2 \
    | sort -u)
if [ -n "$existing_names" ]; then
    existing_name=$(printf '%s\n' "$existing_names" | head -1)
    n=2
    while printf '%s\n' "$existing_names" | grep -qxF "$label"; do
        label="${BASE_USER_LABEL}$n"
        n=$((n + 1))
    done
    printfc "$NORD_YELLOW" "An ephemeral user already exists (%s)." "$existing_name"
    printfc "$NORD_YELLOW" "Creating a uniquely-named one instead: %s" "$label"
    echo ""
fi

printfc "$NORD_BLUE" "\n>Creating ephemeral user: %s" "$label"

# 1. Create the ephemeral secondary user; the returned line is
#    "Entering shell..." (banner) then "Success: created user id <id>".
create_out=$(_shell_cmd "pm create-user --ephemeral $label")
new_uid=$(echo "$create_out" | sed -n 's/.*user id \([0-9][0-9]*\).*/\1/p' | tail -1)

if [ -z "$new_uid" ]; then
    printfc "$NORD_RED" "Failed to create user. Output: %s" "$create_out"
    exit 1
fi
printfc "$NORD_GREEN" "Created user: id=%s (%s)" "$new_uid" "$label"

# 2. Skip the setup wizard for the new user.
printfc "$NORD_BLUE" "\n>Skipping setup wizard"
if _shell_cmd "settings put secure user_setup_complete 1 --user $new_uid" >/dev/null 2>&1 \
   && _shell_cmd "settings put global device_provisioned 1" >/dev/null 2>&1; then
    printfc "$NORD_GREEN" "Setup wizard marked as complete for user %s." "$new_uid"
else
    printfc "$NORD_RED" "Failed to mark the setup wizard as complete for user %s." "$new_uid"
fi

# 3. Install each package into the new user, but only if it already exists in
#    the current (owner) user — otherwise skip it automatically.
printfc "$NORD_BLUE" "\n>Installing packages into user %s" "$new_uid"
for pkg in $PKGS_TO_INSTALL; do
    if _shell_cmd "pm list packages --user 0 $pkg" | grep -q "package:$pkg"; then
        install_out=$(_shell_cmd "pm install-existing --user $new_uid $pkg")
        if printf '%s' "$install_out" | grep -qi "installed for user"; then
            printfc "$NORD_GREEN" "Installed: %s" "$pkg"
        else
            printfc "$NORD_RED" "Failed to install %s for user %s." "$pkg" "$new_uid"
            printfc "$NORD_YELLOW" "  Output: %s" "$install_out"
        fi
    else
        printfc "$NORD_YELLOW" "Skipped: %s not installed in current user." "$pkg"
    fi
done

echo ""
printfc "$NORD_GREEN" "Done. User %s is ephemeral (removed on reboot) and ready." "$new_uid"
echo ""
