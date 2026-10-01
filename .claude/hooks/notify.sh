#!/bin/bash

# Skip notification if the focused window owns this process (Ghostty, Cursor terminal, ...).
# Uses the Window Calls GNOME extension, since Wayland hides the focused window from clients.
# If the lookup fails, fall through and notify: an extra notification beats a missed prompt.
FOCUSED_PID=$(gdbus call --session --dest org.gnome.Shell \
  --object-path /org/gnome/Shell/Extensions/Windows \
  --method org.gnome.Shell.Extensions.Windows.List 2>/dev/null |
  sed -E "s/^\('(.*)',\)$/\1/" | jq -r '.[] | select(.focus) | .pid' 2>/dev/null)
if [[ -z "$FOCUSED_PID" ]]; then
  echo "notify.sh: could not read focused window (is window-calls@domandoman.xyz enabled?)" >&2
else
  pid=$$
  while [[ "$pid" -gt 1 ]]; do
    [[ "$pid" == "$FOCUSED_PID" ]] && exit 0
    pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
  done
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
