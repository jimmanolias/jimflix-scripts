#!/bin/bash
set -euo pipefail

MAX_WAIT=60   
SLEEP=5
ELAPSED=0

log() {
  echo "[WAIT] $(date +'%Y-%m-%d %H:%M:%S') - $1"
}

container_running() {
  docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null | grep -q true
}

mount_ready() {
  mountpoint -q /mnt/zurg && [ "$(ls -A /mnt/zurg 2>/dev/null)" ]
}

log "Waiting for zurg and rclone to be ready..."

while true; do
  if container_running zurg && container_running rclone && mount_ready; then
    log "zurg + rclone are running and /mnt/zurg is mounted"
    exit 0
  fi

  if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
    log "Timeout waiting for zurg/rclone — exiting"
    exit 1
  fi

  sleep "$SLEEP"
  ELAPSED=$((ELAPSED + SLEEP))
done
