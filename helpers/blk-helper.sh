# ==============================================================================
# blk-helper.sh — shared by tools/blk.sh and reset.sh
# ==============================================================================

_BLK_RECEIVER="com.bintianqi.owndroid/.ApiReceiver"

# Broadcasts a suspend/unsuspend/permission intent to OwnDroid's ApiReceiver.
_blk_send_intent() {
    local api_key="$1" action="$2" package="$3" permission="$4"
    local args=(-a "com.bintianqi.owndroid.action.$action" \
        -n "$_BLK_RECEIVER" \
        --es "key" "$api_key" \
        --es "package" "$package")
    [ -n "$permission" ] && args+=(--es "permission" "$permission")
    am broadcast "${args[@]}" > /dev/null 2>&1
}
