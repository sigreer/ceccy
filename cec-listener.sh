#!/bin/bash

echo "[CEC-LISTENER] Script started."

if ! command -v kdialog &> /dev/null; then
  echo "Error: kdialog is not installed. Please install kdialog to use this script." >&2
  exit 1
fi

echo "[CEC-LISTENER] kdialog found. Starting main loop."

# Configurable cec-client options
CEC_CLIENT_CMD="sudo cec-client -d 8 -t p -p 1"

# Global variable to track shutdown confirmation window
declare -i SHUTDOWN_PENDING=0
SHUTDOWN_POPUP_PID=0
PENDING_ACTION=""
PENDING_TIMER_PID=0

# New variables for yellow double-press logic
YELLOW_PRESS_PENDING=0
YELLOW_TIMER_PID=0
YELLOW_TOGGLE_OUTPUT=""

show_confirmation_dialog() {
  local action_key="$1"
  local message="$2"
  local confirm_callback="$3"
  local cancel_callback="$4"

  # Cancel any existing pending action
  if [ -n "$PENDING_ACTION" ]; then
    cancel_pending_action
  fi

  kdialog --passivepopup "$message" 10 &
  SHUTDOWN_POPUP_PID=$!
  PENDING_ACTION="$action_key"
  PENDING_CONFIRM_CALLBACK="$confirm_callback"
  PENDING_CANCEL_CALLBACK="$cancel_callback"

  # Start a background timer to auto-cancel after 10 seconds
  (
    sleep 10
    if [ "$PENDING_ACTION" = "$action_key" ]; then
      kill $SHUTDOWN_POPUP_PID 2>/dev/null
      $cancel_callback
      PENDING_ACTION=""
    fi
  ) &
  PENDING_TIMER_PID=$!
}

cancel_pending_action() {
  if [ -n "$PENDING_ACTION" ]; then
    echo "[CEC-LISTENER] Cancelling pending $PENDING_ACTION."
    kill $SHUTDOWN_POPUP_PID 2>/dev/null
    kill $PENDING_TIMER_PID 2>/dev/null
    $PENDING_CANCEL_CALLBACK
    PENDING_ACTION=""
  fi
}

confirm_pending_action() {
  if [ -n "$PENDING_ACTION" ]; then
    echo "[CEC-LISTENER] Confirming pending $PENDING_ACTION."
    kill $SHUTDOWN_POPUP_PID 2>/dev/null
    kill $PENDING_TIMER_PID 2>/dev/null
    $PENDING_CONFIRM_CALLBACK
    PENDING_ACTION=""
  fi
}

handle_cec_command() {
  echo "[CEC-LISTENER] handle_cec_command called with: $1"
  # If a confirmation is pending, check for confirmation or cancellation
  if [ -n "$PENDING_ACTION" ]; then
    case "$1" in
      "$PENDING_ACTION"|"44:00")
        confirm_pending_action
        return
        ;;
      *)
        cancel_pending_action
        ;;
    esac
    return
  fi
  # Handle yellow double-press logic
  if [ $YELLOW_PRESS_PENDING -eq 1 ]; then
    case "$1" in
      "44:74")
        yellow_double_press_action
        return
        ;;
      *)
        cancel_yellow_pending
        ;;
    esac
    return
  fi
  case "$1" in
    "44:49")  # Next button (shutdown)
      show_confirmation_dialog "44:49" \
        "Shutdown requested. Press NEXT or ENTER on the remote within 10 seconds to confirm." \
        shutdown_confirmed shutdown_cancelled
      ;;
    "44:71")  # Blue button (test)
      show_confirmation_dialog "44:71" \
        "Test prompt: Press BLUE or ENTER on the remote within 10 seconds to confirm." \
        test_confirmed test_cancelled
      ;;
    "44:74")  # Yellow button
      yellow_single_press_action
      ;;
    "44:00")  # Enter button
      echo "[CEC-LISTENER] Enter key pressed (no action unless confirming a pending action)"
      ;;
    "44:01")  # Up
      echo "[CEC-LISTENER] Up key pressed"
      ;;
    "44:02")  # Down
      echo "[CEC-LISTENER] Down key pressed"
      ;;
    "44:03")  # Left
      echo "[CEC-LISTENER] Left key pressed"
      ;;
    "44:04")  # Right
      echo "[CEC-LISTENER] Right key pressed"
      ;;
    "44:72")  # Red
      echo "[CEC-LISTENER] Red key pressed"
      ;;
    "44:73")  # Green
      echo "[CEC-LISTENER] Green key pressed"
      ;;
    # Add more cases as needed
    *)
      echo "[CEC-LISTENER] Unhandled keycode: $1"
      ;;
  esac
}

shutdown_confirmed() {
  echo "[CEC-LISTENER] Shutdown confirmed by CEC key."
  kdialog --passivepopup "Shutting down..." 3
  sudo /sbin/shutdown now
}

shutdown_cancelled() {
  echo "[CEC-LISTENER] Shutdown cancelled (no CEC key press)."
  kdialog --passivepopup "Shutdown cancelled." 3
}

test_confirmed() {
  echo "[CEC-LISTENER] Test confirmed by CEC key."
  kdialog --passivepopup "Test confirmed..." 3
}

test_cancelled() {
  echo "[CEC-LISTENER] Test cancelled (no CEC key press)."
  kdialog --passivepopup "Test cancelled." 3
}

yellow_single_press_action() {
  echo "[CEC-LISTENER] Yellow button single press: running panelswitch."
  panelswitch &
  YELLOW_PRESS_PENDING=1
  # Start a 3-second timer to listen for a second yellow press
  (
    sleep 3
    if [ $YELLOW_PRESS_PENDING -eq 1 ]; then
      YELLOW_PRESS_PENDING=0
      echo "[CEC-LISTENER] No second yellow press detected."
    fi
  ) &
  YELLOW_TIMER_PID=$!
}

yellow_double_press_action() {
  echo "[CEC-LISTENER] Yellow button double press: toggling DP-3 display."
  YELLOW_PRESS_PENDING=0
  kill $YELLOW_TIMER_PID 2>/dev/null
  DISPLAY_NAME="DP-3"
  # Check if DP-3 is enabled or disabled
  ENABLED=$(kscreen-doctor -o | awk -v out="$DISPLAY_NAME" '
    $0 ~ "Output:" && $3 == out {inblock=1; next}
    $0 ~ "Output:" {inblock=0}
    inblock && /enabled/ {print "enabled"; exit}
    inblock && /disabled/ {print "disabled"; exit}
  ')
  if [ "$ENABLED" = "enabled" ]; then
    echo "[CEC-LISTENER] Disabling $DISPLAY_NAME via kscreen-doctor."
    kscreen-doctor output.$DISPLAY_NAME.disable
  else
    echo "[CEC-LISTENER] Enabling $DISPLAY_NAME via kscreen-doctor and restoring geometry, scale, and priority."
    kscreen-doctor output.$DISPLAY_NAME.enable
    kscreen-doctor output.$DISPLAY_NAME.geometry 0,864 3840x1200
    kscreen-doctor output.$DISPLAY_NAME.scale 1
    kscreen-doctor output.$DISPLAY_NAME.priority 1
    # Also restore HDMI-A-1
    kscreen-doctor output.HDMI-A-1.priority 2
    kscreen-doctor output.HDMI-A-1.geometry 2931,0 1536x864
    kscreen-doctor output.HDMI-A-1.scale 1.25
  fi
}

cancel_yellow_pending() {
  if [ $YELLOW_PRESS_PENDING -eq 1 ]; then
    YELLOW_PRESS_PENDING=0
    kill $YELLOW_TIMER_PID 2>/dev/null
    echo "[CEC-LISTENER] Yellow pending cancelled by other key."
  fi
}

# Main listener loop
# Use a named pipe to allow real-time dialog control
CEC_PIPE=$(mktemp -u)
mkfifo "$CEC_PIPE"
trap 'rm -f "$CEC_PIPE"' EXIT

# Start cec-client in the background, writing to the pipe
$CEC_CLIENT_CMD > "$CEC_PIPE" &
CEC_CLIENT_PID=$!

while read -r line < "$CEC_PIPE"; do
  echo "[CEC-LISTENER] cec-client output: $line"
  if [[ "$line" =~ 44:([0-9a-f]{2}) ]]; then
    keycode="44:${BASH_REMATCH[1]}"
    echo "[CEC-LISTENER] Detected keycode: $keycode"
    handle_cec_command "$keycode"
  fi
done

wait $CEC_CLIENT_PID

status=$?
if [ $status -ne 0 ]; then
  echo "[CEC-LISTENER] cec-client or main loop exited with status $status" >&2
else
  echo "[CEC-LISTENER] Main loop ended unexpectedly."
fi
