# PostgreSQL migrations

这组 SQL 片段是 `postgres/init_sync_tables.sql` 的当前拆分结果。

设计原则：

1. `init_sync_tables.sql` 仍保留为兼容性 bootstrap 入口，供 Docker initdb、collector 本地校验和 phase 3 shadow 验证直接执行。
2. 真正的逻辑拆分在 `migrations/` 下维护，按 `bootstrap/`、`sync/`、`serving/` 分组。
3. 当前阶段 `xiamimate-data-infra` 仍然物理持有这些片段，但逻辑所有权已经按 schema 切分：
   - `sync/*`：collector 责任
   - `serving/*`：theme-api 责任
4. 如果调整了碎片文件，需要重新执行 `bash postgres/scripts/rebuild_init_sync_tables.sh` 来刷新兼容 bootstrap。

当前执行顺序：

1. `bootstrap/001_create_shared_schemas.sql`
2. `sync/010_sync_core_tables.sql`
3. `serving/010_serving_theme_feature_tables.sql`
4. `sync/020_sync_runtime_monitor.sql`
5. `serving/020_serving_theme_api_auth_tables.sql`
6. `sync/030_sync_indexes.sql`
7. `serving/030_serving_indexes.sql`
8. `sync/040_sync_status_views.sql`
9. `sync/050_sync_expansion_candidate_views.sql`
10. `sync/060_sync_candidate_expansion_jobs.sql`
