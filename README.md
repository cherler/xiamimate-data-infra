# XiaMimate Data Infra

这个仓库是 XiaMimate 拆分后的基础设施仓库，用于承接 PostgreSQL schema/migration 资产，以及本地 PostgreSQL、Grafana、Metabase 运行入口。

当前状态：

- 由原始单仓库 `xiamimate` 在 2026-04-15 启动 Phase 1 迁移时创建。
- 当前已经接管本地 PostgreSQL、Grafana、Metabase 的正式启动入口。
- 当前 PostgreSQL 数据目录已迁到共享运行时根目录 `/path/to/xiamimate-runtime/postgres/pgdata`；旧仓仅保留兼容 symlink。

当前结构已经拆成两层：

1. `shared schema`：可同步到 ECS / RDS 执行
2. `local-only runtime`：只给本地 docker-compose 使用

当前已迁入内容：

- `postgres/docker-compose.yml`
- `postgres/.env.example`
- `postgres/init_postgres.sql`
- `postgres/init_sync_tables.sql`
- `postgres/init_local_data_infra.sql`
- `postgres/migrations/bootstrap/`
- `postgres/migrations/local/`
- `postgres/migrations/sync/`
- `postgres/migrations/serving/`
- `postgres/scripts/rebuild_init_sync_tables.sh`
- `postgres/scripts/rebuild_init_local_data_infra.sh`
- `postgres/scripts/bootstrap_rds_sync_schema.sh`
- `postgres/scripts/export_local_pg_data.sh`
- `postgres/scripts/import_sql_to_rds.sh`
- `postgres/scripts/manage_local_data_infra.sh`
- `postgres/grafana/`

当前刻意未迁入内容：

- `init_app_tables.sql`

职责说明：

- `init_sync_tables.sql` 是 shared bootstrap，只包含 `sync.*` 核心表、`serving.*` 兼容表、共享索引与共享视图，可直接用于 ECS / RDS。
- `init_local_data_infra.sql` 是 local-only bootstrap，只包含本地 Grafana / Metabase / 进程巡检依赖的 runtime monitor 表与索引。
- `postgres/docker-compose.yml` 当前仍是 local-only 运行入口；它会同时加载 shared bootstrap 与 local-only bootstrap。
- `sync.*`、`serving.*`、`app.*` 的细粒度 schema 所有权仍在拆分中。
- `pgdata/` 属于运行态数据，已经外置到仓库外的共享运行时目录，不进入 Git。

本地正式运行方式：

1. 在 `postgres/.env` 中声明：
   - `COMPOSE_PROJECT_NAME=postgres`
   - `XIAMIMATE_RUNTIME_ROOT=/path/to/xiamimate-runtime`
   - `XIAMIMATE_POSTGRES_DATA_DIR=<当前 PostgreSQL 数据目录>`
   - `XIAMIMATE_METABASE_VOLUME_NAME=postgres_metabase_data`
   - `XIAMIMATE_GRAFANA_VOLUME_NAME=postgres_grafana_data`
2. 通过 `bash postgres/scripts/manage_local_data_infra.sh up` 启动 PostgreSQL / Metabase / Grafana。
3. `postgres/docker-compose.yml` 已为 PostgreSQL / Metabase / Grafana 配置 `restart: unless-stopped`，Docker daemon 恢复后会自动拉起这三个容器；如果希望 macOS 开机后也自动恢复，需要同时让 Docker Desktop 随登录自动启动。

ECS / RDS 使用方式：

1. 可以把仓库同步到 ECS，但不要直接启动 `postgres/docker-compose.yml`。
2. ECS 只应使用 shared bootstrap：
   - `bash postgres/scripts/bootstrap_rds_sync_schema.sh`
   - 或直接执行 `psql -f postgres/init_sync_tables.sql`
3. 如果本地 PostgreSQL 已经有历史业务数据，需要先从本地导出，再在 ECS 上导入 RDS：
   - 本地导出：`bash postgres/scripts/export_local_pg_data.sh /tmp/xiamimate_local_pg_data.sql`
   - 传到 ECS：`scp /tmp/xiamimate_local_pg_data.sql <ecs>:/tmp/`
   - ECS 导入（目标库为空）：`bash postgres/scripts/import_sql_to_rds.sh /tmp/xiamimate_local_pg_data.sql`
   - ECS 导入（覆盖已有业务数据）：`RDS_IMPORT_RESET=1 bash postgres/scripts/import_sql_to_rds.sh /tmp/xiamimate_local_pg_data.sql`
4. `export_local_pg_data.sh` 默认只导出 `app`、`sync`、`serving` 三个业务 schema 的数据，并排除本地巡检表 `sync.runtime_process_status`、`sync.runtime_process_history`。
5. `import_sql_to_rds.sh` 默认会先检查 `app`、`sync`、`serving` 是否为空；如果检测到非空表，会提前失败并提示使用 `RDS_IMPORT_RESET=1`，避免导入到一半才因为主键冲突中断。
6. `init_local_data_infra.sql`、`manage_local_data_infra.sh`、Grafana provisioning 属于 local-only，不应在 ECS 上直接启用。

下一步：

1. 把 `sync.*` migration 最终迁给 `xiamimate-collector`。
2. 把 `serving.*` migration 最终迁给 `xiamimate-theme-api`。
3. 后续为 `chat_backend` 独立出 `app.*` migration 目录。
4. 在观察期结束后，可选择逐步移除旧仓保留的兼容 symlink，仅保留 shared runtime 作为唯一运行态入口。
