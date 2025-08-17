#!/bin/bash

# Completely Silent Screenshot Script - No Flash Version
# Eliminates visual feedback including flash effects

# Configuration
SCREENSHOT_DIR="$HOME/Screenshots"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILENAME="screenshot_${TIMESTAMP}.png"
FULL_PATH="${SCREENSHOT_DIR}/${FILENAME}"

# Create screenshots directory if it doesn't exist
mkdir -p "$SCREENSHOT_DIR"

# Function to disable desktop effects temporarily
disable_effects() {
    # Disable GNOME screenshot sound and flash
    if command -v gsettings &> /dev/null; then
        # Store original values
        ORIGINAL_SOUND=$(gsettings get org.gnome.desktop.sound event-sounds 2>/dev/null)
        ORIGINAL_CAMERA=$(gsettings get org.gnome.desktop.sound input-feedback-sounds 2>/dev/null)
        
        # Disable sounds
        gsettings set org.gnome.desktop.sound event-sounds false 2>/dev/null
        gsettings set org.gnome.desktop.sound input-feedback-sounds false 2>/dev/null
    fi
    
    # Disable KDE screenshot effects
    if command -v kwriteconfig5 &> /dev/null; then
        kwriteconfig5 --file kglobalshortcutsrc --group "org.kde.spectacle.desktop" --key "_k_friendly_name" "Spectacle" 2>/dev/null
    fi
}

# Function to restore desktop effects
restore_effects() {
    if command -v gsettings &> /dev/null && [ -n "$ORIGINAL_SOUND" ]; then
        gsettings set org.gnome.desktop.sound event-sounds "$ORIGINAL_SOUND" 2>/dev/null
        gsettings set org.gnome.desktop.sound input-feedback-sounds "$ORIGINAL_CAMERA" 2>/dev/null
    fi
}

# Detect display server
detect_display_server() {
    if [ -n "$WAYLAND_DISPLAY" ]; then
        echo "wayland"
    elif [ -n "$DISPLAY" ]; then
        echo "x11"
    else
        echo "unknown"
    fi
}

# Function to take completely silent screenshot on X11
take_screenshot_x11_silent() {
    # Method 1: Using import with specific no-flash settings
    if command -v import &> /dev/null; then
        DISPLAY=${DISPLAY:-:0} import -window root -quality 100 -silent -depth 8 "$FULL_PATH" 2>/dev/null
        [ $? -eq 0 ] && [ -s "$FULL_PATH" ] && return 0
    fi
    
    # Method 2: Using xwd with convert (most silent method)
    if command -v xwd &> /dev/null && command -v convert &> /dev/null; then
        DISPLAY=${DISPLAY:-:0} xwd -root -out /tmp/screenshot_$$.xwd 2>/dev/null && \
        convert /tmp/screenshot_$$.xwd "$FULL_PATH" 2>/dev/null && \
        rm -f /tmp/screenshot_$$.xwd 2>/dev/null
        [ $? -eq 0 ] && [ -s "$FULL_PATH" ] && return 0
    fi
    
    # Method 3: Using maim with no cursor and silent options
    if command -v maim &> /dev/null; then
        DISPLAY=${DISPLAY:-:0} maim --hidecursor --quality 10 "$FULL_PATH" 2>/dev/null
        [ $? -eq 0 ] && [ -s "$FULL_PATH" ] && return 0
    fi
    
    # Method 4: Using scrot with minimal quality for speed (reduces flash time)
    if command -v scrot &> /dev/null; then
        DISPLAY=${DISPLAY:-:0} scrot -z -q 10 "$FULL_PATH" 2>/dev/null
        [ $? -eq 0 ] && [ -s "$FULL_PATH" ] && return 0
    fi
    
    # Method 5: Using ffmpeg to capture single frame (completely silent)
    if command -v ffmpeg &> /dev/null; then
        DISPLAY=${DISPLAY:-:0} ffmpeg -f x11grab -video_size $(xdpyinfo | grep dimensions | awk '{print $2}' 2>/dev/null || echo "1920x1080") -i :0.0 -frames:v 1 -loglevel quiet -y "$FULL_PATH" 2>/dev/null
        [ $? -eq 0 ] && [ -s "$FULL_PATH" ] && return 0
    fi
    
    return 1
}

# Function to take completely silent screenshot on Wayland
take_screenshot_wayland_silent() {
    # Method 1: Using grim (naturally silent on Wayland)
    if command -v grim &> /dev/null; then
        grim "$FULL_PATH" 2>/dev/null
        [ $? -eq 0 ] && [ -s "$FULL_PATH" ] && return 0
    fi
    
    # Method 2: Using gnome-screenshot with no flash
    if command -v gnome-screenshot &> /dev/null; then
        # Temporarily disable effects
        disable_effects
        gnome-screenshot --file="$FULL_PATH" --include-border 2>/dev/null
        restore_effects
        [ $? -eq 0 ] && [ -s "$FULL_PATH" ] && return 0
    fi
    
    # Method 3: Using flameshot in background mode
    if command -v flameshot &> /dev/null; then
        flameshot full -p "$SCREENSHOT_DIR" -d 0 2>/dev/null &
        sleep 0.5  # Small delay to let it capture
        latest_file=$(ls -t "$SCREENSHOT_DIR"/*.png 2>/dev/null | head -n1)
        if [ -f "$latest_file" ] && [ "$latest_file" != "$FULL_PATH" ]; then
            mv "$latest_file" "$FULL_PATH" 2>/dev/null
            return 0
        fi
    fi
    
    # Method 4: Using spectacle with no effects
    if command -v spectacle &> /dev/null; then
        spectacle -b -n -o "$FULL_PATH" 2>/dev/null
        [ $? -eq 0 ] && [ -s "$FULL_PATH" ] && return 0
    fi
    
    # Method 5: Using wlr-randr with grim for wlroots compositors
    if command -v wlr-randr &> /dev/null && command -v grim &> /dev/null; then
        grim -o $(wlr-randr | grep -m1 "^[A-Z]" | cut -d' ' -f1) "$FULL_PATH" 2>/dev/null
        [ $? -eq 0 ] && [ -s "$FULL_PATH" ] && return 0
    fi
    
    return 1
}

# Function to use framebuffer directly (most silent method)
take_screenshot_framebuffer() {
    if [ -r /dev/fb0 ]; then
        # Get framebuffer info
        if command -v fbset &> /dev/null; then
            resolution=$(fbset | grep geometry | awk '{print $2 "x" $3}')
            if [ -n "$resolution" ] && command -v ffmpeg &> /dev/null; then
                ffmpeg -f fbdev -i /dev/fb0 -frames:v 1 -s "$resolution" -loglevel quiet -y "$FULL_PATH" 2>/dev/null
                [ $? -eq 0 ] && [ -s "$FULL_PATH" ] && return 0
            fi
        fi
    fi
    return 1
}

# Main screenshot function
take_silent_screenshot() {
    local display_server=$(detect_display_server)
    
    # First try framebuffer method (most silent)
    if take_screenshot_framebuffer; then
        return 0
    fi
    
    # Then try display-server specific methods
    case $display_server in
        "wayland")
            if take_screenshot_wayland_silent; then
                return 0
            else
                # Try X11 methods as fallback with Xwayland
                take_screenshot_x11_silent
                return $?
            fi
            ;;
        "x11")
            if take_screenshot_x11_silent; then
                return 0
            else
                # Try Wayland methods as fallback
                take_screenshot_wayland_silent
                return $?
            fi
            ;;
        *)
            # Try all methods
            if take_screenshot_x11_silent; then
                return 0
            elif take_screenshot_wayland_silent; then
                return 0
            else
                return 1
            fi
            ;;
    esac
}

# Function to create a background daemon
create_daemon() {
    local interval=$1
    local count=$2
    
    # Create daemon script
    cat > /tmp/screenshot_daemon.sh << 'EOF'
#!/bin/bash
SCREENSHOT_DIR="$1"
INTERVAL="$2"
COUNT="$3"
PARENT_SCRIPT="$4"

for ((i=1; i<=COUNT; i++)); do
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    FILENAME="screenshot_daemon_${i}_${TIMESTAMP}.png"
    FULL_PATH="${SCREENSHOT_DIR}/${FILENAME}"
    
    # Call parent script silently
    "$PARENT_SCRIPT" > /dev/null 2>&1
    
    if [ $i -lt $COUNT ]; then
        sleep "$INTERVAL"
    fi
done
EOF
    
    chmod +x /tmp/screenshot_daemon.sh
    nohup /tmp/screenshot_daemon.sh "$SCREENSHOT_DIR" "$interval" "$count" "$0" > /dev/null 2>&1 &
    
    echo "Background daemon started (PID: $!)"
    echo "Taking $count screenshots every $interval seconds silently in background"
    echo "Screenshots will be saved to: $SCREENSHOT_DIR"
}

# Debug function
debug_system() {
    echo "=== System Debug Information ==="
    echo "Display server: $(detect_display_server)"
    echo "DISPLAY: ${DISPLAY:-'not set'}"
    echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-'not set'}"
    echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-'not set'}"
    echo "Desktop: ${XDG_CURRENT_DESKTOP:-'not detected'}"
    echo ""
    echo "Available tools:"
    for tool in import xwd convert maim scrot ffmpeg grim gnome-screenshot flameshot spectacle fbset; do
        if command -v "$tool" &> /dev/null; then
            echo "  ✓ $tool"
        else
            echo "  ✗ $tool"
        fi
    done
    echo ""
    echo "Framebuffer access:"
    if [ -r /dev/fb0 ]; then
        echo "  ✓ Can read /dev/fb0"
    else
        echo "  ✗ Cannot read /dev/fb0 (normal for most systems)"
    fi
    echo "================================"
}

# Parse command line arguments
case "$1" in
    -h|--help)
        echo "Usage: $0 [OPTIONS]"
        echo "Take completely silent screenshots (no flash, no sound)"
        echo ""
        echo "Options:"
        echo "  -h, --help              Show this help message"
        echo "  -c, --continuous N M    Take N screenshots every M seconds"
        echo "  -b, --background N M    Take N screenshots every M seconds in background"
        echo "  -d, --directory DIR     Set custom screenshot directory"
        echo "  -n, --name NAME         Set custom filename prefix"
        echo "  --debug                 Show system debug information"
        echo "  --test                  Test screenshot capability"
        echo ""
        echo "Examples:"
        echo "  $0                      Take a single silent screenshot"
        echo "  $0 -c 5 10             Take 5 screenshots every 10 seconds"
        echo "  $0 -b 20 30            Take 20 screenshots every 30 seconds in background"
        echo "  $0 --debug             Show debug information"
        ;;
    --debug)
        debug_system
        ;;
    --test)
        echo "Testing silent screenshot capability..."
        if take_silent_screenshot; then
            if [ -f "$FULL_PATH" ] && [ -s "$FULL_PATH" ]; then
                echo "✓ Test successful! Silent screenshot saved: $FULL_PATH"
                echo "File size: $(du -h "$FULL_PATH" | cut -f1)"
            else
                echo "✗ Test failed: File created but empty"
            fi
        else
            echo "✗ Test failed: Could not create screenshot"
        fi
        ;;
    -c|--continuous)
        if [ $# -lt 3 ]; then
            echo "Error: Continuous mode requires count and interval" >&2
            exit 1
        fi
        count=$2
        interval=$3
        echo "Taking $count screenshots every $interval seconds (silent mode)..."
        for ((i=1; i<=count; i++)); do
            TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
            FILENAME="screenshot_${i}_${TIMESTAMP}.png"
            FULL_PATH="${SCREENSHOT_DIR}/${FILENAME}"
            
            if take_silent_screenshot; then
                echo "Silent screenshot $i/$count completed"
            else
                echo "Failed screenshot $i/$count" >&2
            fi
            
            [ $i -lt $count ] && sleep "$interval"
        done
        ;;
    -b|--background)
        if [ $# -lt 3 ]; then
            echo "Error: Background mode requires count and interval" >&2
            exit 1
        fi
        create_daemon "$3" "$2"
        ;;
    -d|--directory)
        if [ -z "$2" ]; then
            echo "Error: Directory option requires a path" >&2
            exit 1
        fi
        SCREENSHOT_DIR="$2"
        mkdir -p "$SCREENSHOT_DIR"
        FULL_PATH="${SCREENSHOT_DIR}/${FILENAME}"
        if take_silent_screenshot; then
            echo "Silent screenshot saved: $FULL_PATH"
        fi
        ;;
    -n|--name)
        if [ -z "$2" ]; then
            echo "Error: Name option requires a prefix" >&2
            exit 1
        fi
        FILENAME="${2}_${TIMESTAMP}.png"
        FULL_PATH="${SCREENSHOT_DIR}/${FILENAME}"
        if take_silent_screenshot; then
            echo "Silent screenshot saved: $FULL_PATH"
        fi
        ;;
    "")
        # Default: take single silent screenshot
        if take_silent_screenshot; then
            if [ -f "$FULL_PATH" ] && [ -s "$FULL_PATH" ]; then
                echo "Silent screenshot saved: $FULL_PATH"
            else
                echo "Warning: Screenshot may be empty" >&2
                exit 1
            fi
        else
            echo "Failed to take silent screenshot" >&2
            echo "Run '$0 --debug' for diagnostic information" >&2
            exit 1
        fi
        ;;
    *)
        echo "Unknown option: $1" >&2
        echo "Use $0 --help for usage information" >&2
        exit 1
        ;;
esac
