#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${LOCAL_PG_EXPORT_DIR:-$ROOT_DIR/exports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_FILE="${1:-${LOCAL_PG_EXPORT_FILE:-$OUTPUT_DIR/xiamimate_local_pg_data_${TIMESTAMP}.sql}}"

LOCAL_PG_HOST_VALUE="${LOCAL_PG_HOST:-127.0.0.1}"
LOCAL_PG_PORT_VALUE="${LOCAL_PG_PORT:-5432}"
LOCAL_PG_DB_VALUE="${LOCAL_PG_DB:-xiamimate}"
LOCAL_PG_USER_VALUE="${LOCAL_PG_USER:-xiamimate}"
LOCAL_PG_PASSWORD_VALUE="${LOCAL_PG_PASSWORD:-xiamimate}"
LOCAL_PG_SCHEMAS_VALUE="${LOCAL_PG_SCHEMAS:-app sync serving}"
LOCAL_PG_DOCKER_CONTAINER_VALUE="${LOCAL_PG_DOCKER_CONTAINER:-xiamimate-postgres}"

resolve_dump_command() {
  if command -v pg_dump >/dev/null 2>&1; then
    DUMP_CMD=(pg_dump)
    DUMP_MODE="host"
    return 0
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "pg_dump not found and docker is unavailable; install PostgreSQL client tools first" >&2
    return 1
  fi

  case "$LOCAL_PG_HOST_VALUE" in
    127.0.0.1|localhost|::1)
      ;;
    *)
      echo "pg_dump not found and LOCAL_PG_HOST=$LOCAL_PG_HOST_VALUE is not local; cannot fall back to docker container export" >&2
      return 1
      ;;
  esac

  if ! docker ps --format '{{.Names}}' | grep -Fxq "$LOCAL_PG_DOCKER_CONTAINER_VALUE"; then
    echo "pg_dump not found and docker fallback container is not running: $LOCAL_PG_DOCKER_CONTAINER_VALUE" >&2
    echo "either start local data infra or install PostgreSQL client tools first" >&2
    return 1
  fi

  DUMP_CMD=(
    docker exec
    -e "PGPASSWORD=$LOCAL_PG_PASSWORD_VALUE"
    "$LOCAL_PG_DOCKER_CONTAINER_VALUE"
    pg_dump
  )
  DUMP_MODE="docker"
}

resolve_dump_command

mkdir -p "$(dirname "$OUTPUT_FILE")"

dump_cmd=(
  "${DUMP_CMD[@]}"
  -h "$LOCAL_PG_HOST_VALUE"
  -p "$LOCAL_PG_PORT_VALUE"
  -U "$LOCAL_PG_USER_VALUE"
  -d "$LOCAL_PG_DB_VALUE"
  --data-only
  --no-owner
  --no-privileges
)

for schema_name in $LOCAL_PG_SCHEMAS_VALUE; do
  dump_cmd+=(--schema="$schema_name")
done

dump_cmd+=(--exclude-table-data=sync.runtime_process_status)
dump_cmd+=(--exclude-table-data=sync.runtime_process_history)

if [[ "$DUMP_MODE" == "host" ]]; then
  export PGPASSWORD="$LOCAL_PG_PASSWORD_VALUE"
  trap 'unset PGPASSWORD' EXIT
fi

echo "Exporting local PostgreSQL data from ${LOCAL_PG_HOST_VALUE}:${LOCAL_PG_PORT_VALUE}/${LOCAL_PG_DB_VALUE}"
echo "Export mode: $DUMP_MODE"
echo "Included schemas: $LOCAL_PG_SCHEMAS_VALUE"
echo "Excluded local-only tables: sync.runtime_process_status sync.runtime_process_history"

"${dump_cmd[@]}" > "$OUTPUT_FILE"

echo "Done: $OUTPUT_FILE"