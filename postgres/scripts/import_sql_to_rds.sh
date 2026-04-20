#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
INPUT_FILE="${1:-${RDS_IMPORT_FILE:-}}"
RDS_IMPORT_SCHEMAS_VALUE="${RDS_IMPORT_SCHEMAS:-app sync serving}"
RDS_IMPORT_RESET_VALUE="${RDS_IMPORT_RESET:-0}"

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

psql_base=(
  psql
  -v ON_ERROR_STOP=1
  -h "$PG_HOST_VALUE"
  -p "$PG_PORT_VALUE"
  -U "$PG_USER_VALUE"
  -d "$PG_DB_VALUE"
)

build_schema_array_sql() {
  local schema_sql=""
  local schema_name

  for schema_name in $RDS_IMPORT_SCHEMAS_VALUE; do
    if [[ -n "$schema_sql" ]]; then
      schema_sql+=", "
    fi
    schema_sql+="'${schema_name}'"
  done

  printf '%s' "$schema_sql"
}

ensure_target_is_empty() {
  local schema_array_sql
  schema_array_sql="$(build_schema_array_sql)"

  "${psql_base[@]}" <<SQL
DO \
\$\$
DECLARE
  table_item RECORD;
  table_has_rows BOOLEAN;
BEGIN
  FOR table_item IN
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname = ANY (ARRAY[$schema_array_sql])
    ORDER BY schemaname, tablename
  LOOP
    EXECUTE format(
      'SELECT EXISTS (SELECT 1 FROM %I.%I LIMIT 1)',
      table_item.schemaname,
      table_item.tablename
    ) INTO table_has_rows;

    IF table_has_rows THEN
      RAISE EXCEPTION 'target database is not empty; first non-empty table: %.%', table_item.schemaname, table_item.tablename
        USING HINT = 'rerun with RDS_IMPORT_RESET=1 to truncate target schemas before import';
    END IF;
  END LOOP;
END
\$\$;
SQL
}

reset_target_tables() {
  local schema_array_sql
  schema_array_sql="$(build_schema_array_sql)"

  "${psql_base[@]}" <<SQL
DO \
\$\$
DECLARE
  table_list TEXT;
BEGIN
  SELECT string_agg(format('%I.%I', schemaname, tablename), ', ' ORDER BY schemaname, tablename)
    INTO table_list
  FROM pg_tables
  WHERE schemaname = ANY (ARRAY[$schema_array_sql]);

  IF table_list IS NULL THEN
    RAISE EXCEPTION 'no tables found in target schemas: %', '$RDS_IMPORT_SCHEMAS_VALUE';
  END IF;

  EXECUTE 'TRUNCATE TABLE ' || table_list || ' RESTART IDENTITY CASCADE';
END
\$\$;
SQL
}

echo "Importing SQL into ${PG_HOST_VALUE}:${PG_PORT_VALUE}/${PG_DB_VALUE}"
echo "Source file: $INPUT_FILE"
echo "Target schemas: $RDS_IMPORT_SCHEMAS_VALUE"

if [[ "$RDS_IMPORT_RESET_VALUE" == "1" ]]; then
  echo "Reset mode: enabled (truncate target schemas before import)"
  reset_target_tables
else
  echo "Reset mode: disabled (target schemas must be empty)"
  ensure_target_is_empty
fi

if [[ "$INPUT_FILE" == *.gz ]]; then
  gzip -dc "$INPUT_FILE" | "${psql_base[@]}"
else
  "${psql_base[@]}" -f "$INPUT_FILE"
fi

echo "Done: imported $INPUT_FILE"