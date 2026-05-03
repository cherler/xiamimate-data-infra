-- Agent-facing opportunity discovery jobs and full evidence payload storage.

CREATE TABLE IF NOT EXISTS sync.keepa_opportunity_discovery_jobs (
    job_id                  VARCHAR PRIMARY KEY,
    domain                  INTEGER NOT NULL DEFAULT 1,
    marketplace             VARCHAR,
    platform                VARCHAR NOT NULL DEFAULT 'Amazon',
    query                   VARCHAR,
    category_id             BIGINT,
    category_path           VARCHAR,
    include_descendants     BOOLEAN DEFAULT TRUE,
    limit_count             INTEGER DEFAULT 10,
    window_days             INTEGER DEFAULT 30,
    min_data_confidence     VARCHAR DEFAULT 'low',
    include_expandable      BOOLEAN DEFAULT TRUE,
    status                  VARCHAR NOT NULL DEFAULT 'completed',
    opportunity_count       INTEGER DEFAULT 0,
    request_payload_json    JSONB DEFAULT '{}'::JSONB,
    result_payload_json     JSONB DEFAULT '{}'::JSONB,
    summary_payload_json    JSONB DEFAULT '{}'::JSONB,
    error_message           VARCHAR,
    meta_json               JSONB DEFAULT '{}'::JSONB,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW(),
    finished_at             TIMESTAMPTZ
);

ALTER TABLE sync.keepa_opportunity_discovery_jobs
ADD COLUMN IF NOT EXISTS marketplace VARCHAR;

ALTER TABLE sync.keepa_opportunity_discovery_jobs
ADD COLUMN IF NOT EXISTS platform VARCHAR NOT NULL DEFAULT 'Amazon';

ALTER TABLE sync.keepa_opportunity_discovery_jobs
ADD COLUMN IF NOT EXISTS query VARCHAR;

ALTER TABLE sync.keepa_opportunity_discovery_jobs
ADD COLUMN IF NOT EXISTS limit_count INTEGER DEFAULT 10;

ALTER TABLE sync.keepa_opportunity_discovery_jobs
ADD COLUMN IF NOT EXISTS request_payload_json JSONB DEFAULT '{}'::JSONB;

ALTER TABLE sync.keepa_opportunity_discovery_jobs
ADD COLUMN IF NOT EXISTS result_payload_json JSONB DEFAULT '{}'::JSONB;

ALTER TABLE sync.keepa_opportunity_discovery_jobs
ADD COLUMN IF NOT EXISTS summary_payload_json JSONB DEFAULT '{}'::JSONB;

CREATE INDEX IF NOT EXISTS idx_opportunity_discovery_jobs_domain_created
ON sync.keepa_opportunity_discovery_jobs(domain, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_opportunity_discovery_jobs_category_created
ON sync.keepa_opportunity_discovery_jobs(domain, category_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_opportunity_discovery_jobs_status_created
ON sync.keepa_opportunity_discovery_jobs(status, created_at DESC);
