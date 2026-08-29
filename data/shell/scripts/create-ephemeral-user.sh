#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# create-ephemeral-user — pre-built ADB script for `shell scripts`
#
# Creates an ephemeral (auto-removed on reboot) secondary user with the
# SetupWizard skipped, then installs com.aurora.store and helium314.keyboard
# into that user — but ONLY if each app is already installed in the current
# (owner) user; otherwise that app is skipped automatically.
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

PKGS_TO_INSTALL="com.aurora.store helium314.keyboard"

# 0. Pick a name that doesn't collide with an existing user (Android requires
#    user names to be unique), so running this repeatedly always works.
BASE_USER_LABEL="ephemeral"
label="$BASE_USER_LABEL"
existing=$(_shell_cmd "pm list users")
while echo "$existing" | grep -qE "\{[0-9]+:${label}:"; do
    printfc "$NORD_YELLOW" "User '%s' already exists; trying unique name…" "$label"
    label="${BASE_USER_LABEL}-$(( ${RANDOM} % 1000 ))"
done

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
_shell_cmd "settings put secure user_setup_complete 1 --user $new_uid"
_shell_cmd "settings put global device_provisioned 1"
printfc "$NORD_GREEN" "Setup wizard marked as complete for user %s." "$new_uid"

# 3. Install each package into the new user, but only if it already exists in
#    the current (owner) user — otherwise skip it automatically.
printfc "$NORD_BLUE" "\n>Installing packages into user %s" "$new_uid"
for pkg in $PKGS_TO_INSTALL; do
    if _shell_cmd "pm list packages --user 0 $pkg" | grep -q "package:$pkg"; then
        if _shell_cmd "pm install-existing --user $new_uid $pkg" | grep -qi "Success"; then
            printfc "$NORD_GREEN" "Installed: %s" "$pkg"
        else
            printfc "$NORD_RED" "Failed to install %s for user %s." "$pkg" "$new_uid"
        fi
    else
        printfc "$NORD_YELLOW" "Skipped: %s not installed in current user." "$pkg"
    fi
done

echo ""
printfc "$NORD_GREEN" "Done. User %s is ephemeral (removed on reboot) and ready." "$new_uid"
echo ""
