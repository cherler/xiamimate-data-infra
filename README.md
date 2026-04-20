# XiaMimate Data Infra

这个仓库是 XiaMimate 拆分后的基础设施仓库，用于承接 PostgreSQL、Grafana、Metabase 等基础设施资产。

当前状态：

- 由原始单仓库 `xiamimate` 在 2026-04-15 启动 Phase 1 迁移时创建。
- 当前已经接管本地 PostgreSQL、Grafana、Metabase 的正式启动入口。
- 当前 PostgreSQL 数据目录已迁到共享运行时根目录 `/path/to/xiamimate-runtime/postgres/pgdata`；旧仓仅保留兼容 symlink。

当前已迁入内容：

- `postgres/docker-compose.yml`
- `postgres/.env.example`
- `postgres/init_postgres.sql`
- `postgres/init_sync_tables.sql`
- `postgres/migrations/bootstrap/`
- `postgres/migrations/sync/`
- `postgres/migrations/serving/`
- `postgres/scripts/rebuild_init_sync_tables.sh`
- `postgres/scripts/manage_local_data_infra.sh`
- `postgres/grafana/`

当前刻意未迁入内容：

- `init_app_tables.sql`

原因：

- `init_sync_tables.sql` 仍保留为兼容 bootstrap 入口，但它现在由 `postgres/migrations/*` 重建，避免继续把 `sync.*` / `serving.*` 的逻辑直接混写在一个文件里。
- `sync.*`、`serving.*`、`app.*` 的细粒度 schema 所有权仍在拆分中。
- `pgdata/` 属于运行态数据，已经外置到仓库外的共享运行时目录，不进入 Git。

当前正式运行方式：

1. 在 `postgres/.env` 中声明：
	- `COMPOSE_PROJECT_NAME=postgres`
	- `XIAMIMATE_RUNTIME_ROOT=/path/to/xiamimate-runtime`
	- `XIAMIMATE_POSTGRES_DATA_DIR=<当前 PostgreSQL 数据目录>`
	- `XIAMIMATE_METABASE_VOLUME_NAME=postgres_metabase_data`
	- `XIAMIMATE_GRAFANA_VOLUME_NAME=postgres_grafana_data`
2. 通过 `bash postgres/scripts/manage_local_data_infra.sh up` 启动 PostgreSQL / Metabase / Grafana。
3. `postgres/docker-compose.yml` 已为 PostgreSQL / Metabase / Grafana 配置 `restart: unless-stopped`，Docker daemon 恢复后会自动拉起这三个容器；如果希望 macOS 开机后也自动恢复，需要同时让 Docker Desktop 随登录自动启动。

下一步：

1. 把 `sync.*` migration 最终迁给 `xiamimate-collector`。
2. 把 `serving.*` migration 最终迁给 `xiamimate-theme-api`。
3. 后续为 `chat_backend` 独立出 `app.*` migration 目录。
4. 在观察期结束后，可选择逐步移除旧仓保留的兼容 symlink，仅保留 shared runtime 作为唯一运行态入口。
