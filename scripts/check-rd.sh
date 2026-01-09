#!/bin/bash
set -euo pipefail

ENV_FILE="/srv/jimflix/jimflix-scripts/.env"

if [ ! -f "$ENV_FILE" ]; then
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [ -z "${RD_TOKEN:-}" ]; then
  exit 1
fi

RESPONSE=$(curl -s \
  -H "Authorization: Bearer $RD_TOKEN" \
  https://api.real-debrid.com/rest/1.0/user || true)

if [ -z "$RESPONSE" ]; then
  exit 1
fi

CLEAN_RESPONSE=$(echo "$RESPONSE" | tr -d '\n\r ')

if echo "$CLEAN_RESPONSE" | grep -q '"type":"premium"'; then
  exit 0
else
  exit 1
fi
