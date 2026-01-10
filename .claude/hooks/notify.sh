#!/bin/bash

# Skip notification if terminal is already focused
ACTIVE_WINDOW=$(xdotool getactivewindow getwindowname 2>/dev/null || echo "")
if [[ "$ACTIVE_WINDOW" =~ [Cc]laude ]] || [[ "$ACTIVE_WINDOW" =~ [Tt]erminator ]] || [[ "$ACTIVE_WINDOW" =~ [Tt]erminal ]] || [[ "$ACTIVE_WINDOW" =~ [Kk]itty ]] || [[ "$ACTIVE_WINDOW" =~ [Aa]lacritty ]] || [[ "$ACTIVE_WINDOW" =~ [Ww]ezterm ]] || [[ "$ACTIVE_WINDOW" =~ ✳ ]]; then
  exit 0
fi

# Read JSON input from stdin
INPUT=$(cat)

# Parse notification type and message using jq
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')
MESSAGE=$(echo "$INPUT" | jq -r '.message // empty')

# Set title based on notification type
case "$NOTIFICATION_TYPE" in
  "permission_prompt")
    TITLE="Claude Code - Permission Required"
    ;;
  "idle_prompt")
    TITLE="Claude Code - Waiting"
    ;;
  *)
    exit 0
    ;;
esac

# Use message if available, otherwise fallback
BODY="${MESSAGE:-Claude needs your attention}"

# Send desktop notification (urgency=critical makes it persist until dismissed)
notify-send -i dialog-information "$TITLE" "$BODY"

# Play notification sound
paplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null || \
paplay /usr/share/sounds/gnome/default/alerts/drip.ogg 2>/dev/null || \
true

exit 0
