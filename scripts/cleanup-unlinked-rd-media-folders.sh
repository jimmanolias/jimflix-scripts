#!/bin/bash

MEDIA_ROOT="/srv/jimflix/plex/media"
TARGET_ROOT="/mnt/zurg/__all__"
MOUNTPOINT="/mnt/zurg"
ABORT=0
DELETED_COUNT=0

LOGFILE="/srv/jimflix/jimflix-scripts/logs/cleanup-unlinked-rd-media-folders.log"
MAX_DAYS=10

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$level] $timestamp - $message"
}

if [ -f "$LOGFILE" ] && [ "$(find "$LOGFILE" -mtime +$MAX_DAYS)" ]; then
    rm "$LOGFILE"
fi

exec > >(tee -a "$LOGFILE") 2>&1

echo ""
log "INFO" "Starting cleanup script (cleanup-unlinked-rd-media-folders.sh)"

if ! /srv/jimflix/jimflix-scripts/scripts/check-rd.sh; then
    log "WARN" "Real-Debrid subscription inactive — cleanup-unlinked-rd-media-folders.sh"
    exit 0
fi

if ! mountpoint -q "$MOUNTPOINT"; then
    log "ERROR" "❌ $MOUNTPOINT is NOT mounted. Aborting cleanup to avoid accidental deletion."
    ABORT=1
else
    log "INFO" "Scanning $TARGET_ROOT for Real-Debrid media folders not linked to Jimflix"

    mapfile -t symlink_targets < <(find "$MEDIA_ROOT" -type l -exec readlink -f {} \;)

    declare -A used_folders=()
    for target in "${symlink_targets[@]}"; do
        if [[ "$target" == "$TARGET_ROOT/"* ]]; then
            relpath=${target#"$TARGET_ROOT/"}
            first_folder=${relpath%%/*}
            used_folders["$first_folder"]=1
        fi
    done

    for dir in "$TARGET_ROOT"/*; do
        [ -e "$dir" ] || continue

        base=$(basename "$dir")
        if [[ -z "${used_folders[$base]}" ]]; then
            log "WARN" "Deleting folder: $dir (not linked to Jimflix)"
            rm -rf "$dir" 2>/dev/null || true
            ((DELETED_COUNT++))
        fi
    done

    if [ "$DELETED_COUNT" -eq 0 ]; then
        log "INFO" "Cleanup complete. No unlinked Real-Debrid media folders found"
    else
        log "INFO" "Cleanup complete. Deleted $DELETED_COUNT unlinked Real-Debrid media folder(s)"
    fi
fi

log "INFO" "Cleanup script finished"
echo ""

exit $ABORT
