#!/bin/bash
set -o pipefail

LOCKFILE="/tmp/cleanup-riven-db.lock"
LOGFILE="/srv/jimflix/jimflix-scripts/logs/cleanup-riven-db.log"
CONTAINER_NAME="riven-db"
MOUNTPOINT="/mnt/zurg"

log() {
    local level="INFO"
    local message="$1"

    if [[ "$1" == "ERROR" || "$1" == "WARN" || "$1" == "INFO" ]]; then
        level="$1"
        message="$2"
    fi

    if [[ -z "$message" ]]; then
        echo "" | tee -a "$LOGFILE"
    else
        echo "[$level] $(date +"%Y-%m-%d %H:%M:%S") - $message" | tee -a "$LOGFILE"
    fi
}

log ""
log "INFO" "Starting cleanup script (cleanup-riven-db.sh)"

if ! /srv/jimflix/jimflix-scripts/scripts/check-rd.sh; then
    log "WARN" "Real-Debrid subscription inactive — skipping cleanup-riven.sh"
    exit 0
fi

if ! mountpoint -q "$MOUNTPOINT"; then
    log "ERROR" "❌ $MOUNTPOINT is NOT mounted. Aborting cleanup to avoid accidental deletion."
    log "INFO" "Cleanup script finished"
    log ""
    exit 1
fi

if [ -e "$LOCKFILE" ]; then
    log "INFO" "Cleanup script is already running. Exiting."
    log ""
    exit 0
fi

trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT
touch "$LOCKFILE"

exec_psql() {
    local sql="$1"
    local silent="${2:-false}"   # default false αν δεν δοθεί
    if [[ "$silent" == "true" ]]; then
        docker exec "$CONTAINER_NAME" psql -U postgres -d riven -t -A -F $'\t' -c "$sql" > /dev/null 2>&1
    else
        docker exec "$CONTAINER_NAME" psql -U postgres -d riven -t -A -F $'\t' -c "$sql"
    fi
}

##########################
# 1. Cleanup Movies missing media files
##########################
log "INFO" "Scanning Riven-DB for Movies missing media files"
deleted_movies=0
movie_records=$(exec_psql "SELECT m.id, mi.symlink_path FROM \"Movie\" m JOIN \"MediaItem\" mi ON m.id = mi.id;")
while IFS=$'\t' read -r movie_id symlink_path; do
    if [[ -n "$movie_id" && ! -e "$symlink_path" ]]; then
        exec_psql "DELETE FROM \"Movie\" WHERE id='$movie_id';" true || true
        exec_psql "DELETE FROM \"MediaItem\" WHERE id='$movie_id';" true || true
        ((deleted_movies++))
    fi
done <<< "$movie_records"
if [[ "$deleted_movies" -eq 0 ]]; then
    log "INFO" "Movies cleanup completed. No orphaned movies found"
else
    log "INFO" "Movies cleanup completed. Deleted $deleted_movies orphaned movie(s)"
fi

##########################
# 2. Cleanup Episodes missing media files
##########################
log "INFO" "Scanning Riven-DB for Episodes missing media files"
deleted_episodes=0
episode_records=$(exec_psql "SELECT e.id, mi.symlink_path FROM \"Episode\" e JOIN \"MediaItem\" mi ON e.id = mi.id;")
while IFS=$'\t' read -r episode_id symlink_path; do
    if [[ -n "$episode_id" && ! -e "$symlink_path" ]]; then
        exec_psql "DELETE FROM \"Episode\" WHERE id='$episode_id';" true || true
        exec_psql "DELETE FROM \"MediaItem\" WHERE id='$episode_id';" true || true
        ((deleted_episodes++))
    fi
done <<< "$episode_records"
if [[ "$deleted_episodes" -eq 0 ]]; then
    log "INFO" "Episodes cleanup completed. No orphaned episodes found"
else
    log "INFO" "Episodes cleanup completed. Deleted $deleted_episodes orphaned episode(s)"
fi

##########################
# 3. Cleanup Seasons without episodes
##########################
log "INFO" "Scanning Riven-DB for Seasons without any Episodes"
deleted_seasons=0
season_ids=$(exec_psql "SELECT id FROM \"Season\";")
for season_id in $season_ids; do
    if [[ -n "$season_id" ]]; then
        episode_count=$(exec_psql "SELECT COUNT(*) FROM \"Episode\" WHERE \"parent_id\" = '$season_id';")
        if [[ "$episode_count" -eq 0 ]]; then
            exec_psql "DELETE FROM \"Season\" WHERE id='$season_id';" true || true
            ((deleted_seasons++))
        fi
    fi
done
if [[ "$deleted_seasons" -eq 0 ]]; then
    log "INFO" "Seasons cleanup completed. No orphaned seasons found"
else
    log "INFO" "Seasons cleanup completed. Deleted $deleted_seasons orphaned season(s)"
fi

##########################
# 4. Cleanup Shows without seasons
##########################
log "INFO" "Scanning Riven-DB for Shows without any Seasons"
deleted_shows=0
show_ids=$(exec_psql "SELECT id FROM \"Show\";")
for show_id in $show_ids; do
    if [[ -n "$show_id" ]]; then
        season_count=$(exec_psql "SELECT COUNT(*) FROM \"Season\" WHERE \"parent_id\" = '$show_id';")
        if [[ "$season_count" -eq 0 ]]; then
            exec_psql "DELETE FROM \"Show\" WHERE id='$show_id';" true || true
            ((deleted_shows++))
        fi
    fi
done
if [[ "$deleted_shows" -eq 0 ]]; then
    log "INFO" "Shows cleanup completed. No orphaned shows found"
else
    log "INFO" "Shows cleanup completed. Deleted $deleted_shows orphaned show(s)"
fi

log "INFO" "Cleanup script finished"
log ""

rm -f "$LOCKFILE"
trap - INT TERM EXIT
