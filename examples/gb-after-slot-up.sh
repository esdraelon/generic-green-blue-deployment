#!/usr/bin/env bash
# Example GB_HOOK_AFTER_SLOT_UP: tag the new web slot image for a worker compose file.
set -euo pipefail

slot="${1:?slot required}"

WORKER_IMAGE="${WORKER_IMAGE:-my-app-worker:latest}"
BLUE_CONTAINER="${BLUE_CONTAINER:-my-app-blue}"
GREEN_CONTAINER="${GREEN_CONTAINER:-my-app-green}"

case "$slot" in
    blue) container="$BLUE_CONTAINER" ;;
    green) container="$GREEN_CONTAINER" ;;
    *) exit 1 ;;
esac

if docker inspect "$container" >/dev/null 2>&1; then
    image_id="$(docker inspect -f '{{.Image}}' "$container")"
    docker tag "$image_id" "$WORKER_IMAGE"
fi
