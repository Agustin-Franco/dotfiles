#!/usr/bin/env bash

set -uo pipefail

WALLPAPER_DIR="/home/nebo/Pictures/wallpapers"
INTERVAL_SECONDS=3600
MONITORS=("DP-2" "HDMI-A-1" "DP-1")   # Put your monitor names here (see: hyprctl monitors)

if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    RUNTIME_DIR="$XDG_RUNTIME_DIR"
elif [[ -d "/run/user/$(id -u)" ]]; then
    RUNTIME_DIR="/run/user/$(id -u)"
else
    RUNTIME_DIR="/tmp"
fi
LOCK_FILE="$RUNTIME_DIR/hyprpaper-rotator.lock"
STATE_FILE="$RUNTIME_DIR/hyprpaper-rotator.last"

if [[ "${1:-}" != "--locked" ]]; then
    exec flock -n -o "$LOCK_FILE" "$0" --locked "$@"
fi
shift

ONCE=0
if [[ "${1:-}" == "--once" ]]; then
    ONCE=1
fi

wait_for_hyprpaper() {
    # exec-once ordering isn't guaranteed; hyprpaper might come up slightly later.
    local i
    for i in {1..100}; do
        if hyprctl hyprpaper listactive >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
    done

    printf 'hyprpaper-rotator: hyprpaper IPC not responding (check `ipc = true` and that hyprpaper is running)\n' >&2
    return 1
}

load_images() {
    local files=()
    shopt -s nullglob
    files+=("$WALLPAPER_DIR"/*.png)
    files+=("$WALLPAPER_DIR"/*.jpg)
    files+=("$WALLPAPER_DIR"/*.jpeg)
    files+=("$WALLPAPER_DIR"/*.webp)
    files+=("$WALLPAPER_DIR"/*.PNG)
    files+=("$WALLPAPER_DIR"/*.JPG)
    files+=("$WALLPAPER_DIR"/*.JPEG)
    files+=("$WALLPAPER_DIR"/*.WEBP)
    shopt -u nullglob

    if (( ${#files[@]} < ${#MONITORS[@]} )); then
        return 1
    fi

    printf '%s\n' "${files[@]}"
}

apply_random_wallpapers() {
    mapfile -t all_images < <(load_images) || return 1

    local attempts=0
    local previous=""
    local current=""

    if [[ -f "$STATE_FILE" ]]; then
        previous="$(<"$STATE_FILE")"
    fi

    while :; do
        mapfile -t picks < <(printf '%s\n' "${all_images[@]}" | shuf -n "${#MONITORS[@]}")
        current="$(printf '%s|' "${picks[@]}")"

        if [[ "$current" != "$previous" || $attempts -ge 5 ]]; then
            break
        fi

        ((attempts++))
    done

    local i
    for i in "${!picks[@]}"; do
        # Arguments are: monitor,path,fit_mode (fit_mode optional)
        hyprctl hyprpaper wallpaper "${MONITORS[$i]},${picks[$i]},cover" >/dev/null 2>&1 || true
    done

    printf '%s' "$current" > "$STATE_FILE"
}

while true; do
    wait_for_hyprpaper || { sleep 1; continue; }
    apply_random_wallpapers || true
    (( ONCE == 1 )) && exit 0
    sleep "$INTERVAL_SECONDS"
done
