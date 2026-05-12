#!/bin/bash

# Omarchy-inspired screenshot capture for Hyprland (Wayland).
# Uses grim + slurp, copies to clipboard, saves to disk, and notifies.

set -euo pipefail

[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs

# Use XDG Pictures dir (or ~/Pictures) and always save into Screenshots.
BASE_PICTURES_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}"
OUTPUT_DIR="$BASE_PICTURES_DIR/Screenshots"

if [[ ! -d $OUTPUT_DIR ]]; then
  mkdir -p "$OUTPUT_DIR"
  notify-send "Created screenshot directory: $OUTPUT_DIR" -u normal -t 2000 || true
fi

# If a slurp selection is already active, kill it (same behavior as Omarchy).
pkill slurp 2>/dev/null && exit 0

have() { command -v "$1" >/dev/null 2>&1; }

SCREENSHOT_EDITOR="${OMARCHY_SCREENSHOT_EDITOR:-satty}"

# Parse --editor flag from any position
ARGS=()
for arg in "$@"; do
  if [[ $arg == --editor=* ]]; then
    SCREENSHOT_EDITOR="${arg#--editor=}"
  else
    ARGS+=("$arg")
  fi
done
set -- "${ARGS[@]}"

open_editor() {
  local filepath="$1"

  if [[ $SCREENSHOT_EDITOR == "satty" ]] && have satty; then
    satty --filename "$filepath" \
      --output-filename "$filepath" \
      --actions-on-enter save-to-clipboard \
      --save-after-copy \
      --copy-command 'wl-copy'
  elif [[ -n ${SCREENSHOT_EDITOR:-} ]] && have "$SCREENSHOT_EDITOR"; then
    "$SCREENSHOT_EDITOR" "$filepath"
  else
    return 1
  fi
}

MODE="${1:-smart}"
PROCESSING="${2:-slurp}"

# Accounting for portrait/transformed displays (copied from Omarchy).
JQ_MONITOR_GEO='
  def format_geo:
    .x as $x | .y as $y |
    (.width / .scale | floor) as $w |
    (.height / .scale | floor) as $h |
    .transform as $t |
    if $t == 1 or $t == 3 then
      "\($x),\($y) \($h)x\($w)"
    else
      "\($x),\($y) \($w)x\($h)"
    end;
'

get_rectangles() {
  local active_workspace
  active_workspace=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .activeWorkspace.id')
  hyprctl monitors -j | jq -r --arg ws "$active_workspace" "${JQ_MONITOR_GEO} .[] | select(.activeWorkspace.id == (\$ws | tonumber)) | format_geo"
  hyprctl clients -j | jq -r --arg ws "$active_workspace" '.[] | select(.workspace.id == ($ws | tonumber)) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
}

# Keep hyprpicker alive until after grim captures so the screenshot sees the
# frozen overlay rather than live content shifting during teardown.
PID=""
cleanup_freeze() {
  [[ -n ${PID:-} ]] && kill "$PID" 2>/dev/null || true
}
trap cleanup_freeze EXIT

start_freeze() {
  if have hyprpicker; then
    hyprpicker -r -z >/dev/null 2>&1 &
    PID=$!
    sleep .1
  fi
}

SELECTION=""
case "$MODE" in
  region)
    start_freeze
    SELECTION=$(slurp 2>/dev/null || true)
    ;;
  windows)
    start_freeze
    SELECTION=$(get_rectangles | slurp -r 2>/dev/null || true)
    ;;
  fullscreen)
    SELECTION=$(hyprctl monitors -j | jq -r "${JQ_MONITOR_GEO} .[] | select(.focused == true) | format_geo" || true)
    ;;
  smart | *)
    RECTS=$(get_rectangles || true)
    start_freeze
    SELECTION=$(echo "$RECTS" | slurp 2>/dev/null || true)

    # If the selection area is L * W < 20, assume you clicked inside a window/output.
    if [[ $SELECTION =~ ^([0-9]+),([0-9]+)[[:space:]]([0-9]+)x([0-9]+)$ ]]; then
      if ((${BASH_REMATCH[3]} * ${BASH_REMATCH[4]} < 20)); then
        click_x="${BASH_REMATCH[1]}"
        click_y="${BASH_REMATCH[2]}"

        while IFS= read -r rect; do
          if [[ $rect =~ ^([0-9]+),([0-9]+)[[:space:]]([0-9]+)x([0-9]+) ]]; then
            rect_x="${BASH_REMATCH[1]}"
            rect_y="${BASH_REMATCH[2]}"
            rect_width="${BASH_REMATCH[3]}"
            rect_height="${BASH_REMATCH[4]}"

            if ((click_x >= rect_x && click_x < rect_x + rect_width && click_y >= rect_y && click_y < rect_y + rect_height)); then
              SELECTION="${rect_x},${rect_y} ${rect_width}x${rect_height}"
              break
            fi
          fi
        done <<<"$RECTS"
      fi
    fi
    ;;
esac

[[ -z ${SELECTION:-} ]] && exit 0

FILENAME="screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
FILEPATH="$OUTPUT_DIR/$FILENAME"

if [[ $PROCESSING == "slurp" ]]; then
  if ! grim -g "$SELECTION" "$FILEPATH"; then
    notify-send "Screenshot failed" "grim could not capture selection" -u critical -t 4000 || true
    exit 1
  fi

  if ! wl-copy <"$FILEPATH"; then
    notify-send "Screenshot saved" "Saved to $FILEPATH (clipboard copy failed)" -u normal -t 4000 -i "$FILEPATH" || true
    exit 0
  fi

  (
    # If the notification daemon supports actions, offer an Edit action like Omarchy.
    ACTION=$(notify-send "Screenshot saved to clipboard and file" "Saved to $FILEPATH" -t 10000 -i "$FILEPATH" -A "default=edit" 2>/dev/null || true)
    [[ $ACTION == "default" ]] && open_editor "$FILEPATH" || true
  ) &
else
  if ! grim -g "$SELECTION" - | wl-copy; then
    notify-send "Screenshot failed" "Could not capture/copy selection" -u critical -t 4000 || true
    exit 1
  fi
  notify-send "Screenshot copied" "Selection copied to clipboard" -u normal -t 2000 || true
fi
