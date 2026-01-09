#!/bin/bash
set -e
set -o pipefail

# === Configuration ===
SCRIPT_PATH="/srv/jimflix/jimflix-scripts/scripts/cleanup-orphaned-rd-symlink-folders.sh"
MEDIA_ROOT="/srv/jimflix/plex/media"
MOUNTPOINT="/mnt/zurg"
LOCKFILE="/tmp/poll-cleanup-orphaned-rd-symlink-folders.lock"
poll_interval=20

# === Logging helper ===
log() {
    echo "[INFO] $(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# === Detect orphaned folders (return list of paths) ===
get_orphaned_folders() {
    find "$MEDIA_ROOT" -type d -print0 | while IFS= read -r -d '' dir; do
        total_symlinks=$(find "$dir" -maxdepth 1 -type l | wc -l)
        broken_symlinks=$(find "$dir" -maxdepth 1 -type l ! -exec test -e {} \; -print | wc -l)

        if [[ "$total_symlinks" -gt 0 && "$total_symlinks" -eq "$broken_symlinks" ]]; then
            echo "$dir"
        fi
    done
}

# === Start ===
declare -A previous_state
log "Poller started for cleanup-orphaned-rd-symlink-folders.sh"

while true; do
    # Check if mountpoint is available
    if ! mountpoint -q "$MOUNTPOINT"; then
        log "Mountpoint $MOUNTPOINT is not available. Skipping check."
        sleep "$poll_interval"
        continue
    fi

    declare -A current_state
    changes_detected=false

    # Load current orphaned folders
    while IFS= read -r dir; do
        current_state["$dir"]=1
    done < <(get_orphaned_folders)

    # Compare: Detect if there are new orphaned folders compared to previous state
    for dir in "${!current_state[@]}"; do
        if [[ -z "${previous_state[$dir]}" ]]; then
            log "Οrphaned symlink folder detected: $dir"
            changes_detected=true
            break
        fi
    done

    # Trigger cleanup if changes detected
    if $changes_detected; then
        if [[ -f "$LOCKFILE" ]]; then
            log "Cleanup already running. Skipping trigger."
        else
            log "Changes detected. Running cleanup..."
            touch "$LOCKFILE"
            bash "$SCRIPT_PATH" &
            (
                # Wait for the cleanup script to finish, then remove lockfile
                while kill -0 $! 2>/dev/null; do sleep 1; done
                rm -f "$LOCKFILE"
            ) &
        fi
    fi

    # Update previous state
    previous_state=()
    for dir in "${!current_state[@]}"; do
        previous_state["$dir"]=1
    done

    sleep "$poll_interval"
done
