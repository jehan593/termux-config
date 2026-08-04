#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# YEARWALL MANAGER
# ==============================================================================
source "$TERMUX_CONFIG_PATH/helpers/colors-nord.sh"
source "$TERMUX_CONFIG_PATH/helpers/printer.sh"
source "$TERMUX_CONFIG_PATH/helpers/dep-checker.sh"
source "$TERMUX_CONFIG_PATH/helpers/yearwall-helper.sh"

_test_dependencies "magick" "termux-wallpaper" || exit 1

YEARWALL_DIR="$HOME/.config/termux-config-files/yearwall"
YEARWALL_UPDATE_SCRIPT="$YEARWALL_DIR/yearwall_update.sh"
BOOT_DIR="$HOME/.termux/boot"
YEARWALL_BOOT_SCRIPT="$BOOT_DIR/50-yearwall.sh"
YEARWALL_PROFILE_SCRIPT="$PREFIX/etc/profile.d/yearwall-catchup.sh"

# --- Actions ---

check_status() {

    local is_setup=true

    # 1. Check Script & Directories
    if [ -f "$YEARWALL_UPDATE_SCRIPT" ] && [ -x "$YEARWALL_UPDATE_SCRIPT" ]; then
        printfc "$NORD_GREEN" "Core script: Configured and executable."
    else
        printfc "$NORD_RED" "Core script: Missing or not executable."
        is_setup=false
    fi

    # 2. Check Crontab Automation
    if command -v crontab &>/dev/null; then
        if crontab -l 2>/dev/null | grep -q "yearwall_update.sh"; then
            printfc "$NORD_GREEN" "Automation: Cron job active."
        else
            printfc "$NORD_YELLOW" "Automation: No cron job found."
            is_setup=false
        fi
    else
        printfc "$NORD_YELLOW" "Automation: crontab is not installed."
        is_setup=false
    fi

    # 3. Check Boot Persistence
    if [ -f "$YEARWALL_BOOT_SCRIPT" ] && [ -x "$YEARWALL_BOOT_SCRIPT" ]; then
        printfc "$NORD_GREEN" "Persistence: Boot script active."
    else
        printfc "$NORD_YELLOW" "Persistence: Boot script missing or not executable."
        is_setup=false
    fi

    # 4. Check Session Catch-up (covers cron misses when Termux wasn't running at midnight)
    if [ -f "$YEARWALL_PROFILE_SCRIPT" ] && [ -x "$YEARWALL_PROFILE_SCRIPT" ]; then
        printfc "$NORD_GREEN" "Persistence: Session catch-up script active."
    else
        printfc "$NORD_YELLOW" "Persistence: Session catch-up script missing or not executable."
        is_setup=false
    fi

    # 5. Summary Conclusion
    echo ""
    if [ "$is_setup" = true ]; then
        printfc "$NORD_GREEN" "Conclusion: Yearwall is fully installed and active."
    else
        printfc "$NORD_YELLOW" "Conclusion: Yearwall is incomplete or not installed."
    fi
    echo ""
}

setup_yearwall() {

    # 1. Create generator script
    mkdir -p "$YEARWALL_DIR"
    cat << 'EOF' > "$YEARWALL_UPDATE_SCRIPT"
#!/data/data/com.termux/files/usr/bin/bash
# 1. Get current date info
year=$(date +%Y)
current_day=$(( 10#$(date +%j) ))
total_days=$(( 10#$(date -d "$year-12-31" +%j) ))
# 2. Calculate percentage
percent=$(( 100 * current_day / total_days ))
# 3. Grid settings (21 columns for a balanced look)
columns=21
grid_output=""
red_dot_grid=""
for (( i=1; i<=total_days; i++ )); do
    if [ "$i" -le "$current_day" ]; then grid_output+="● ";
    else grid_output+="○ "; fi
    if [ "$i" -eq "$current_day" ]; then
        red_dot_grid+="● "
    else
        red_dot_grid+="  "
    fi
    if (( i % columns == 0 )); then
        grid_output+="\n"
        red_dot_grid+="\n"
    fi
done
# 4. Output path and Font
OUTPUT="$HOME/.config/termux-config-files/yearwall/yearwall_generated.png"
left_text="$percent% of $year"
right_text="$current_day/$total_days"
MARTIAN_FONT="/data/data/com.termux/files/home/.config/termux-config-files/fonts/MartianMonoNerdFontMono-Regular.ttf"
# Line tuning — only touch these two:
LINE_Y=700      # absolute Y position (lower number = higher up)
LINE_W=10       # thickness in pixels
# 5. ImageMagick Processing
# Note: text drawn at pixel offsets (0/1/2) is an intentional fake-bold trick
# since ImageMagick doesn't support font-weight on arbitrary TTFs.
magick -size 1080x2400 xc:"rgb(46,52,64)" \
    \
    `# -- Dot grid (centered) --` \
    -gravity Center \
    -font "DejaVu-Sans-Mono" -pointsize 35 -interline-spacing 4 \
    -fill "rgb(229,233,240)" -draw "text 0,-80 \"$grid_output\"" \
    -fill "rgb(229,233,240)" -draw "text 1,-80 \"$grid_output\"" \
    -fill "rgb(229,233,240)" -draw "text 2,-80 \"$grid_output\"" \
    -fill "rgb(229,233,240)" -draw "text 0,-81 \"$grid_output\"" \
    -fill "rgb(191,97,106)"  -draw "text 0,-80 \"$red_dot_grid\"" \
    -fill "rgb(191,97,106)"  -draw "text 1,-80 \"$red_dot_grid\"" \
    -fill "rgb(191,97,106)"  -draw "text 2,-80 \"$red_dot_grid\"" \
    -fill "rgb(191,97,106)"  -draw "text 0,-81 \"$red_dot_grid\"" \
    \
    `# -- Separator line: adjust LINE_Y and LINE_W at top of script --` \
    -gravity None \
    -stroke "rgb(136,192,208)" -strokewidth $LINE_W \
    -draw "line 95,$LINE_Y 968,$LINE_Y" \
    -stroke none \
    \
    `# -- Header left --` \
    -gravity West \
    -font "$MARTIAN_FONT" -pointsize 35 \
    -fill "rgb(136,192,208)" -draw "text 95,-535 \"$left_text\"" \
    -fill "rgb(136,192,208)" -draw "text 96,-535 \"$left_text\"" \
    -fill "rgb(136,192,208)" -draw "text 97,-535 \"$left_text\"" \
    \
    `# -- Header right --` \
    -gravity East \
    -font "$MARTIAN_FONT" -pointsize 35 \
    -fill "rgb(235,203,139)" -draw "text 112,-535 \"$right_text\"" \
    -fill "rgb(235,203,139)" -draw "text 113,-535 \"$right_text\"" \
    -fill "rgb(235,203,139)" -draw "text 114,-535 \"$right_text\"" \
    \
    "$OUTPUT"
# 6. Apply Wallpaper
# Note: -l also sets the lock screen wallpaper
termux-wallpaper -f "$OUTPUT" -l
EOF
    chmod +x "$YEARWALL_UPDATE_SCRIPT"
    printfc "$NORD_GREEN" "Script saved."

    # 2. Cron Configuration
    if command -v crontab &>/dev/null; then
        if sv-enable crond > /dev/null 2>&1 && \
           (crontab -l 2>/dev/null | grep -v "yearwall_update.sh"; echo "0 0 * * * $YEARWALL_UPDATE_SCRIPT") | crontab -; then
            printfc "$NORD_GREEN" "Scheduled in crontab."
        else
            printfc "$NORD_RED" "Failed to enable cron service or schedule crontab entry."
        fi
    else
        printfc "$NORD_YELLOW" "crontab missing. Skipping automation schedule."
    fi

    # 3. Boot persistence
    mkdir -p "$BOOT_DIR"
    cat > "$YEARWALL_BOOT_SCRIPT" << BOOTEOF
#!/data/data/com.termux/files/usr/bin/sh
# Auto-generated by yearwall.sh — do not edit manually
sleep 10
if [ ! -f "$YEARWALL_DIR/yearwall_generated.png" ] || [ "\$(date -r "$YEARWALL_DIR/yearwall_generated.png" +%Y%m%d)" != "\$(date +%Y%m%d)" ]; then
    $YEARWALL_UPDATE_SCRIPT &
fi
BOOTEOF
    chmod +x "$YEARWALL_BOOT_SCRIPT"
    printfc "$NORD_GREEN" "Boot persistence enabled."

    # 4. Session catch-up (cron only fires while Termux is running; if the
    # device was off or Termux wasn't open at midnight, the wallpaper goes
    # stale until the next boot. This regenerates it on the next opened
    # session instead of waiting for that.)
    mkdir -p "$PREFIX/etc/profile.d"
    cat > "$YEARWALL_PROFILE_SCRIPT" << PROFILEEOF
#!/data/data/com.termux/files/usr/bin/bash
# Auto-generated by yearwall.sh — do not edit manually
if [ -x "$YEARWALL_UPDATE_SCRIPT" ]; then
    if [ ! -f "$YEARWALL_DIR/yearwall_generated.png" ] || [ "\$(date -r "$YEARWALL_DIR/yearwall_generated.png" +%Y%m%d)" != "\$(date +%Y%m%d)" ]; then
        ("$YEARWALL_UPDATE_SCRIPT" &>/dev/null &)
    fi
fi
PROFILEEOF
    chmod +x "$YEARWALL_PROFILE_SCRIPT"
    printfc "$NORD_GREEN" "Session catch-up enabled."

    # 5. Run now
    echo ""
    if "$YEARWALL_UPDATE_SCRIPT"; then
        printfc "$NORD_GREEN" "Installed successfully."
    else
        printfc "$NORD_RED" "Failed to apply wallpaper."
    fi
    echo ""
}

remove_yearwall() {

    local had_boot_script=0 had_profile_script=0
    [ -f "$YEARWALL_BOOT_SCRIPT" ] && had_boot_script=1
    [ -f "$YEARWALL_PROFILE_SCRIPT" ] && had_profile_script=1

    _remove_yearwall_setup "$YEARWALL_DIR" "$YEARWALL_BOOT_SCRIPT" "$TERMUX_CONFIG_PATH/data/wallpaper/wallpaper.png" "$YEARWALL_PROFILE_SCRIPT"

    printfc "$NORD_GREEN" "Files removed."
    printfc "$NORD_GREEN" "Wallpaper restored to default."

    command -v crontab &>/dev/null && printfc "$NORD_GREEN" "Crontab cleared."

    if [ "$had_boot_script" -eq 1 ]; then
        printfc "$NORD_GREEN" "Boot script removed."
    else
        printfc "$NORD_YELLOW" "Boot script already removed."
    fi

    if [ "$had_profile_script" -eq 1 ]; then
        printfc "$NORD_GREEN" "Session catch-up script removed."
    else
        printfc "$NORD_YELLOW" "Session catch-up script already removed."
    fi

    echo ""
    printfc "$NORD_GREEN" "Remove complete."
    echo ""
}

# --- Router ---
case "$1" in
    setup)  setup_yearwall ;;
    rm)     remove_yearwall ;;
    status) check_status ;;
    *)
        echo "setup   - setup wallpaper"
        echo "status  - check configuration and automation status"
        echo "rm      - remove wallpaper setup"
        echo ""
        exit 1
        ;;
esac
