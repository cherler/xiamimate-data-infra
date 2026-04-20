#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
BOOTSTRAP_SQL="$ROOT_DIR/init_sync_tables.sql"

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

if [[ -z "$PG_HOST_VALUE" || -z "$PG_DB_VALUE" || -z "$PG_USER_VALUE" ]]; then
  echo "PG_HOST, PG_DB, PG_USER are required (set them in postgres/.env or the shell)" >&2
  exit 1
fi

if [[ "$PG_HOST_VALUE" == "localhost" || "$PG_HOST_VALUE" == "127.0.0.1" || "$PG_HOST_VALUE" == "postgres" ]]; then
  echo "refusing to bootstrap local PostgreSQL; this script is for ECS/RDS targets only" >&2
  exit 1
fi

if [[ ! -f "$BOOTSTRAP_SQL" ]]; then
  echo "shared bootstrap SQL not found: $BOOTSTRAP_SQL" >&2
  exit 1
fi

echo "Bootstrapping shared sync/serving schema into ${PG_HOST_VALUE}:${PG_PORT_VALUE}/${PG_DB_VALUE}"
psql \
  -h "$PG_HOST_VALUE" \
  -p "$PG_PORT_VALUE" \
  -U "$PG_USER_VALUE" \
  -d "$PG_DB_VALUE" \
  -f "$BOOTSTRAP_SQL"

echo "Done: shared bootstrap applied from $BOOTSTRAP_SQL"
