#!/usr/bin/env bash
set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <app>"
    exit 1
fi

APP="$1"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export APP_DOCKER_DIR="$ROOT/apps/$APP"
export APP_COVERAGE_DIR="$ROOT/apps/$APP/xdebug"
export EXPERIMENT_ID="${APP}-build"

mkdir -p "$APP_COVERAGE_DIR"

echo "===================================="
echo "Building $APP"
echo "===================================="

docker compose \
    -f "$ROOT/apps/$APP/docker-compose.yml" \
    build --no-cache