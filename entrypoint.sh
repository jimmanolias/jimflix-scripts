#!/bin/bash
set -euo pipefail

bash /srv/jimflix/jimflix-scripts/scripts/wait-for-zurg-rclone.sh

log() {
  echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log_entrypoint() {
  echo "[ENTRYPOINT] $(date +'%Y-%m-%d %H:%M:%S') - $1"
}

echo ""
log_entrypoint "Initial cleanup sequence triggered on container startup"

bash /srv/jimflix/jimflix-scripts/scripts/cleanup-orphaned-rd-symlink-folders.sh
bash /srv/jimflix/jimflix-scripts/scripts/cleanup-riven-db.sh
bash /srv/jimflix/jimflix-scripts/scripts/cleanup-riven-1080p-db.sh
bash /srv/jimflix/jimflix-scripts/scripts/cleanup-unlinked-rd-media-folders.sh

echo ""
log_entrypoint "Launching background pollers for real-time cleanup monitoring"

bash /srv/jimflix/jimflix-scripts/pollers/poll-cleanup-orphaned-rd-symlink-folders.sh &
bash /srv/jimflix/jimflix-scripts/pollers/poll-riven-db-cleanup.sh &
bash /srv/jimflix/jimflix-scripts/pollers/poll-riven-1080p-db-cleanup.sh &

sleep 1
echo ""

while true; do
  log_entrypoint "Next run of cleanup-unlinked-rd-media-folders.sh scheduled in 6 hours"
  echo ""
  sleep 21600
  log_entrypoint "Running scheduled cleanup-unlinked-rd-media-folders.sh"
  echo ""
  bash /srv/jimflix/jimflix-scripts/scripts/cleanup-unlinked-rd-media-folders.sh
done
