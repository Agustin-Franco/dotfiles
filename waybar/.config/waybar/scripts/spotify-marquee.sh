#!/usr/bin/env bash
set -euo pipefail

# --- Configuration (override with environment variables) -------------------
WIDTH="${WAYBAR_SPOTIFY_WIDTH:-28}"
SCROLL_STEP="${WAYBAR_SPOTIFY_SCROLL_STEP:-2}"
CACHE_DIR="${XDG_RUNTIME_DIR:-/tmp}/waybar-spotify"
PREF_PLAYERS=("spotify" "spotifyd" "spotify-player")
ICON="${WAYBAR_SPOTIFY_ICON:-}"   # optional prefix e.g. ""

# --- Setup cache -----------------------------------------------------------
mkdir -p "$CACHE_DIR"

# --- Helper functions ------------------------------------------------------
pick_player() {
    local p
    for p in "${PREF_PLAYERS[@]}"; do
        if playerctl -p "$p" status &>/dev/null; then
            printf '%s\n' "$p"
            return 0
        fi
    done
    return 1
}

write_cache() {
    local file="$1" data="$2" tmp
    tmp="$(mktemp "${file}.XXXXXX")"
    printf '%s' "$data" >"$tmp"
    mv "$tmp" "$file"
}

escape_pango() {
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' <<<"${1:-}"
}

json_escape_fallback() {
    # Minimal safe JSON string escaping for fallback mode
    local s="${1:-}"
    s="${s//\\/\\\\}"              # backslash
    s="${s//\"/\\\"}"              # double quote
    s="${s//$'\n'/\\n}"            # newline
    s="${s//$'\r'/\\r}"            # carriage return
    s="${s//$'\t'/\\t}"            # tab
    printf '%s' "$s"
}

output_json() {
    local text="$1" class="$2" tooltip="${3:-}"
    if command -v jq &>/dev/null; then
        jq -nc \
            --arg text "$text" \
            --arg class "$class" \
            --arg tooltip "$tooltip" \
            '{text: $text, class: $class, tooltip: $tooltip}'
    else
        printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' \
            "$(json_escape_fallback "$text")" \
            "$(json_escape_fallback "$class")" \
            "$(json_escape_fallback "$tooltip")"
    fi
}

fmt_time() {
    local raw="${1:-0}"
    raw="${raw%.*}"
    [[ "$raw" =~ ^[0-9]+$ ]] || raw=0
    if (( raw >= 3600 )); then
        printf '%d:%02d:%02d' $(( raw / 3600 )) $(( (raw % 3600) / 60 )) $(( raw % 60 ))
    else
        printf '%d:%02d' $(( raw / 60 )) $(( raw % 60 ))
    fi
}

is_uint() {
    [[ "${1:-}" =~ ^[0-9]+$ ]]
}

# --- Main ------------------------------------------------------------------
if ! PLAYER="$(pick_player)"; then
    output_json "" "stopped" ""
    exit 0
fi

# Use ASCII Unit Separator (0x1F) as true single-byte delimiter
DELIM=$'\x1f'

metadata="$(
    playerctl -p "$PLAYER" metadata --format \
'{{status}}'"$DELIM"'{{title}}'"$DELIM"'{{artist}}'"$DELIM"'{{album}}'"$DELIM"'{{mpris:length}}'"$DELIM"'{{position}}' \
        2>/dev/null || true
)"

if [[ -z "$metadata" ]]; then
    output_json "" "stopped" ""
    exit 0
fi

IFS="$DELIM" read -r status title artist album len_us pos_us <<<"$metadata"

case "${status:-}" in
    Playing) class="playing" ;;
    Paused)  class="paused" ;;
    *)       class="stopped" ;;
esac

len_us="${len_us:-0}"
is_uint "$len_us" || len_us=0
len=$(( len_us / 1000000 ))

pos_file="$CACHE_DIR/${PLAYER}-pos"
if [[ "$status" == "Playing" ]]; then
    pos="$(playerctl -p "$PLAYER" position 2>/dev/null || echo 0)"
    pos="${pos%.*}"
    is_uint "$pos" || pos=0
    write_cache "$pos_file" "$pos"
elif is_uint "${pos_us:-}" && (( pos_us > 0 )); then
    pos=$(( pos_us / 1000000 ))
elif [[ -f "$pos_file" ]]; then
    pos="$(<"$pos_file")"
    is_uint "$pos" || pos=0
else
    pos=0
fi

base="${title:-}"
[[ -n "${artist:-}" ]] && base="${base} - ${artist}"

if [[ -z "$base" ]]; then
    text="-- $(fmt_time "$pos")/$(fmt_time "$len")"
    output_json "$text" "$class" ""
    exit 0
fi

step_file="$CACHE_DIR/${PLAYER}-step"
step=0
if [[ -f "$step_file" ]]; then
    step="$(<"$step_file")"
fi
is_uint "$step" || step=0

if (( ${#base} <= WIDTH )); then
    shown="$base"
    write_cache "$step_file" "0"
else
    scroll="${base} - "
    total=${#scroll}
    (( total > 0 )) || total=1

    start=$(( step % total ))
    doubled="${scroll}${scroll}"
    shown="${doubled:$start:$WIDTH}"

    if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
        step=$(( step + SCROLL_STEP ))
        write_cache "$step_file" "$step"
    fi
fi

shown_escaped="$(escape_pango "$shown")"

icon_part=""
[[ -n "$ICON" ]] && icon_part="${ICON} "

suffix=" <span foreground=\"#8a8f98\">$(fmt_time "$pos")/$(fmt_time "$len")</span>"
text="${icon_part}${shown_escaped}${suffix}"

tooltip="${title:-}"
[[ -n "${artist:-}" ]] && tooltip+=$'\n'"by ${artist}"
[[ -n "${album:-}" ]] && tooltip+=$'\n'"on ${album}"
tooltip+=$'\n\n'"$(fmt_time "$pos") / $(fmt_time "$len")"

# Optional: escape tooltip too (safe default for Waybar markup handling)
tooltip="$(escape_pango "$tooltip")"

output_json "$text" "$class" "$tooltip"
