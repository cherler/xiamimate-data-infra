#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
ENV_FILE="$ROOT_DIR/.env"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-postgres}"

run_compose() {
    if [[ -f "$ENV_FILE" ]]; then
        (cd "$ROOT_DIR" && docker compose --env-file "$ENV_FILE" --project-name "$PROJECT_NAME" -f "$COMPOSE_FILE" "$@")
    else
        (cd "$ROOT_DIR" && docker compose --project-name "$PROJECT_NAME" -f "$COMPOSE_FILE" "$@")
    fi
}

case "${1:-}" in
    up)
        run_compose up -d
        ;;
    down)
        run_compose down
        ;;
    restart)
        run_compose down
        run_compose up -d
        ;;
    ps)
        run_compose ps
        ;;
    logs)
        shift || true
        run_compose logs --tail 200 "$@"
        ;;
    config)
        run_compose config
        ;;
    *)
        echo "Usage: bash postgres/scripts/manage_local_data_infra.sh {up|down|restart|ps|logs [service...]|config}"
        exit 1
        ;;
esac