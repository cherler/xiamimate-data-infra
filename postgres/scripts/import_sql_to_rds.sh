#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
INPUT_FILE="${1:-${RDS_IMPORT_FILE:-}}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

PG_HOST_VALUE="${PG_HOST:-}"
PG_PORT_VALUE="${PG_PORT:-5432}"
PG_DB_VALUE="${PG_DB:-}"
PG_USER_VALUE="${PG_USER:-}"

if [[ -z "${PGPASSWORD:-}" && -n "${PG_PASSWORD:-}" ]]; then
  PGPASSWORD="$PG_PASSWORD"
fi

if [[ -z "$INPUT_FILE" ]]; then
  echo "Usage: bash postgres/scripts/import_sql_to_rds.sh /absolute/path/to/data.sql[.gz]" >&2
  exit 1
fi

if [[ -z "$PG_HOST_VALUE" || -z "$PG_DB_VALUE" || -z "$PG_USER_VALUE" ]]; then
  echo "PG_HOST, PG_DB, PG_USER are required (set them in postgres/.env or the shell)" >&2
  exit 1
fi

if [[ "$PG_HOST_VALUE" == "localhost" || "$PG_HOST_VALUE" == "127.0.0.1" || "$PG_HOST_VALUE" == "postgres" ]]; then
  echo "refusing to import into local PostgreSQL; this script is for ECS/RDS targets only" >&2
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "input SQL file not found: $INPUT_FILE" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql not found; install PostgreSQL client tools first" >&2
  exit 1
fi

echo "Importing SQL into ${PG_HOST_VALUE}:${PG_PORT_VALUE}/${PG_DB_VALUE}"
echo "Source file: $INPUT_FILE"

if [[ "$INPUT_FILE" == *.gz ]]; then
  gzip -dc "$INPUT_FILE" | psql \
    -v ON_ERROR_STOP=1 \
    -h "$PG_HOST_VALUE" \
    -p "$PG_PORT_VALUE" \
    -U "$PG_USER_VALUE" \
    -d "$PG_DB_VALUE"
else
  psql \
    -v ON_ERROR_STOP=1 \
    -h "$PG_HOST_VALUE" \
    -p "$PG_PORT_VALUE" \
    -U "$PG_USER_VALUE" \
    -d "$PG_DB_VALUE" \
    -f "$INPUT_FILE"
fi

echo "Done: imported $INPUT_FILE"