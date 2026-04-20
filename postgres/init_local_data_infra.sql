-- ============================================================

-- local-only bootstrap: rebuild from postgres/migrations/local/*
-- do not hand-edit this file; edit fragments then rerun rebuild
-- ============================================================

-- >>> BEGIN migrations/local/010_local_runtime_monitor.sql
-- local-only runtime monitoring tables and indexes for docker-compose based data infra.

CREATE TABLE IF NOT EXISTS sync.runtime_process_status (
    process_key               VARCHAR PRIMARY KEY,
    process_label             VARCHAR NOT NULL,
    process_group             VARCHAR NOT NULL DEFAULT 'local-services',
    status                    VARCHAR NOT NULL,
    pid                       INTEGER,
    pid_source                VARCHAR,
    command_line              VARCHAR,
    log_path                  VARCHAR,
    log_updated_at            TIMESTAMPTZ,
    health_url                VARCHAR,
    health_status             VARCHAR,
    health_http_status        INTEGER,
    expected_interval_seconds INTEGER,
    stale_after_seconds       INTEGER,
    checked_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    process_started_at        TIMESTAMPTZ,
    uptime_seconds            BIGINT,
    notes                     VARCHAR
);

CREATE TABLE IF NOT EXISTS sync.runtime_process_history (
    checked_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    process_key               VARCHAR NOT NULL,
    process_label             VARCHAR NOT NULL,
    process_group             VARCHAR NOT NULL DEFAULT 'local-services',
    status                    VARCHAR NOT NULL,
    pid                       INTEGER,
    pid_source                VARCHAR,
    command_line              VARCHAR,
    log_path                  VARCHAR,
    log_updated_at            TIMESTAMPTZ,
    health_url                VARCHAR,
    health_status             VARCHAR,
    health_http_status        INTEGER,
    expected_interval_seconds INTEGER,
    stale_after_seconds       INTEGER,
    process_started_at        TIMESTAMPTZ,
    uptime_seconds            BIGINT,
    notes                     VARCHAR
);

CREATE OR REPLACE VIEW sync.runtime_process_overview AS
SELECT
    process_key,
    process_label,
    process_group,
    status,
    CASE status
        WHEN 'running' THEN 1
        WHEN 'degraded' THEN 0
        WHEN 'stopped' THEN -1
        ELSE -2
    END AS status_code,
    pid,
    pid_source,
    command_line,
    log_path,
    log_updated_at,
    EXTRACT(EPOCH FROM (NOW() - checked_at))::BIGINT AS snapshot_age_seconds,
    CASE
        WHEN log_updated_at IS NULL THEN NULL
        ELSE EXTRACT(EPOCH FROM (NOW() - log_updated_at))::BIGINT
    END AS log_age_seconds,
    health_url,
    health_status,
    health_http_status,
    expected_interval_seconds,
    stale_after_seconds,
    checked_at,
    process_started_at,
    uptime_seconds,
    notes
FROM sync.runtime_process_status;

CREATE INDEX IF NOT EXISTS idx_runtime_process_status_group ON sync.runtime_process_status(process_group, status);
CREATE INDEX IF NOT EXISTS idx_runtime_process_status_checked_at ON sync.runtime_process_status(checked_at);
CREATE INDEX IF NOT EXISTS idx_runtime_process_history_checked_at ON sync.runtime_process_history(checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_runtime_process_history_process_key_checked_at ON sync.runtime_process_history(process_key, checked_at DESC);

-- <<< END migrations/local/010_local_runtime_monitor.sql

