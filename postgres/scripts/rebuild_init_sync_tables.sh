#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_FILE="$ROOT_DIR/init_sync_tables.sql"
FRAGMENTS=(
  "$ROOT_DIR/migrations/bootstrap/001_create_shared_schemas.sql"
  "$ROOT_DIR/migrations/sync/010_sync_core_tables.sql"
  "$ROOT_DIR/migrations/serving/010_serving_theme_feature_tables.sql"
  "$ROOT_DIR/migrations/serving/020_serving_theme_api_auth_tables.sql"
  "$ROOT_DIR/migrations/sync/030_sync_indexes.sql"
  "$ROOT_DIR/migrations/serving/030_serving_indexes.sql"
  "$ROOT_DIR/migrations/sync/040_sync_status_views.sql"
  "$ROOT_DIR/migrations/sync/050_sync_expansion_candidate_views.sql"
  "$ROOT_DIR/migrations/sync/060_sync_candidate_expansion_jobs.sql"
)

for fragment in "${FRAGMENTS[@]}"; do
  if [[ ! -f "$fragment" ]]; then
    echo "missing fragment: $fragment" >&2
    exit 1
  fi
done

{
  printf '%s\n\n' '-- ============================================================'
  printf '%s\n' '-- compatibility bootstrap: rebuild from postgres/migrations/*'
  printf '%s\n' '-- do not hand-edit this file; edit fragments then rerun rebuild'
  printf '%s\n' '-- ============================================================'
  printf '\n'

  for fragment in "${FRAGMENTS[@]}"; do
    relative_fragment="${fragment#"$ROOT_DIR/"}"
    printf '%s\n' "-- >>> BEGIN ${relative_fragment}"
    cat "$fragment"
    printf '\n%s\n\n' "-- <<< END ${relative_fragment}"
  done
} > "$OUTPUT_FILE"

echo "rebuilt $OUTPUT_FILE"
