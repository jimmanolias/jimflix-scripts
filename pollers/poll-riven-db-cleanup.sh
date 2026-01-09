#!/bin/bash
set -e
set -o pipefail

# === Configuration ===
SCRIPT_PATH="/srv/jimflix/jimflix-scripts/scripts/cleanup-riven-db.sh"
CONTAINER_NAME="riven-db"
poll_interval=10
LOCKFILE="/tmp/cleanup-riven-db.lock"
WATCH_DIR="/srv/jimflix/plex/media/rd-media"

# === Logging helper ===
log() {
    echo "[INFO] $(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# === Get current symlinks from MediaItem table ===
get_symlinks() {
    docker exec "$CONTAINER_NAME" \
        psql -U postgres -d riven -t -A -F $'\t' -c \
        "SELECT id, symlink_path FROM \"MediaItem\" WHERE symlink_path LIKE '${WATCH_DIR}%';" 2>/dev/null
}

# === Start ===
declare -A previous_state
log "Poller started for cleanup-riven-db.sh" 

while true; do
    declare -A current_state
    changes_detected=false

    # Load current state from database
    while IFS=$'\t' read -r id path; do
        [[ -z "$id" || -z "$path" ]] && continue
        current_state["$id"]="$path"

        # If the path no longer exists in filesystem
        if [[ ! -e "$path" ]]; then
            log "Missing media file detected: id=$id, path=$path"
            changes_detected=true
        fi
    done <<< "$(get_symlinks)"

    # If changes detected, run cleanup script
    if $changes_detected; then
        if [[ -f "$LOCKFILE" ]]; then
            log "Cleanup already running. Skipping trigger."
        else
            log "Changes detected. Running cleanup..."
            bash "$SCRIPT_PATH" &
        fi
    fi

    # Save current state for future comparison (optional)
    previous_state=()
    for id in "${!current_state[@]}"; do
        previous_state["$id"]="${current_state[$id]}"
    done

    sleep "$poll_interval"
done
