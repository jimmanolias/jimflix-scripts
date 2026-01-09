#!/bin/bash

MEDIA_ROOT="/srv/jimflix/plex/media"
TARGET_ROOT="/mnt/zurg/__all__"
MOUNTPOINT="/mnt/zurg"
LOGFILE="/srv/jimflix/jimflix-scripts/logs/cleanup-orphaned-rd-symlink-folders.log"
MAX_DAYS=10
ABORT=0
DELETED_COUNT=0

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
log "INFO" "Starting cleanup script (cleanup-orphaned-rd-symlink-folders.sh)"

if ! /srv/jimflix/jimflix-scripts/scripts/check-rd.sh; then
    log "WARN" "Real-Debrid subscription inactive — skipping cleanup-orphaned-rd-symlink-folders.sh"
    exit 0
fi

if ! mountpoint -q "$MOUNTPOINT"; then
    log "ERROR" "❌ $MOUNTPOINT is NOT mounted. Aborting cleanup to avoid accidental deletion."
    ABORT=1
else
    log "INFO" "Scanning $MEDIA_ROOT for folders containing only broken symlinks pointing to deleted or missing Real-Debrid media"

    while IFS= read -r -d '' dir; do
        total_symlinks=$(find "$dir" -maxdepth 1 -type l | wc -l)
        broken_symlinks=$(find "$dir" -maxdepth 1 -type l ! -exec test -e {} \; -print | wc -l)

        if [[ "$total_symlinks" -gt 0 && "$total_symlinks" -eq "$broken_symlinks" ]]; then
            log "WARN" "Deleting folder: $dir (all symlinks are broken)"
            rm -rf "$dir"
            ((DELETED_COUNT++))
        fi
    done < <(find "$MEDIA_ROOT" -type d -print0)

    if [ "$DELETED_COUNT" -gt 0 ]; then
        log "INFO" "Cleanup complete. Deleted $DELETED_COUNT orphaned symlink folder(s)"
    else
        log "INFO" "Cleanup complete. No orphaned symlink folders found"
    fi
fi

log "INFO" "Cleanup script finished"
echo ""

exit $ABORT
