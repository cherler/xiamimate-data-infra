-- Agent-facing Keepa candidate expansion jobs and token accounting.

CREATE TABLE IF NOT EXISTS sync.keepa_candidate_expansion_jobs (
    job_id                 VARCHAR PRIMARY KEY,
    domain                 INTEGER NOT NULL DEFAULT 1,
    marketplace            VARCHAR,
    source                 VARCHAR NOT NULL DEFAULT 'agent_interactive',
    priority               VARCHAR NOT NULL DEFAULT 'interactive_normal',
    product_query          VARCHAR,
    recall_mode            VARCHAR DEFAULT 'hybrid',
    category_id            BIGINT,
    category_path          VARCHAR,
    include_descendants    BOOLEAN DEFAULT TRUE,
    target_asin_count      INTEGER DEFAULT 20,
    min_pool_size          INTEGER DEFAULT 8,
    status                 VARCHAR NOT NULL DEFAULT 'queued',
    status_reason          VARCHAR,
    requested_by_session_id VARCHAR,
    requested_by_user_id   VARCHAR,
    idempotency_key        VARCHAR,
    tokens_estimated       INTEGER DEFAULT 0,
    tokens_reserved        INTEGER DEFAULT 0,
    tokens_consumed        INTEGER DEFAULT 0,
    token_wait_until       TIMESTAMPTZ,
    result_candidate_asins TEXT[],
    result_new_asin_count  INTEGER DEFAULT 0,
    error_message          VARCHAR,
    meta_json              JSONB DEFAULT '{}'::JSONB,
    created_at             TIMESTAMPTZ DEFAULT NOW(),
    updated_at             TIMESTAMPTZ DEFAULT NOW(),
    started_at             TIMESTAMPTZ,
    finished_at            TIMESTAMPTZ
);

ALTER TABLE sync.keepa_candidate_expansion_jobs
ADD COLUMN IF NOT EXISTS marketplace VARCHAR;

ALTER TABLE sync.keepa_candidate_expansion_jobs
ADD COLUMN IF NOT EXISTS recall_mode VARCHAR DEFAULT 'hybrid';

ALTER TABLE sync.keepa_candidate_expansion_jobs
ADD COLUMN IF NOT EXISTS min_pool_size INTEGER DEFAULT 8;

ALTER TABLE sync.keepa_candidate_expansion_jobs
ADD COLUMN IF NOT EXISTS requested_by_user_id VARCHAR;

ALTER TABLE sync.keepa_candidate_expansion_jobs
ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR;

ALTER TABLE sync.keepa_candidate_expansion_jobs
ADD COLUMN IF NOT EXISTS token_wait_until TIMESTAMPTZ;

ALTER TABLE sync.keepa_candidate_expansion_jobs
ADD COLUMN IF NOT EXISTS meta_json JSONB DEFAULT '{}'::JSONB;

CREATE TABLE IF NOT EXISTS sync.keepa_token_ledger (
    ledger_id          BIGSERIAL PRIMARY KEY,
    job_id             VARCHAR,
    domain             INTEGER,
    source             VARCHAR NOT NULL,
    queue_name         VARCHAR NOT NULL,
    action             VARCHAR NOT NULL,
    tokens_before      INTEGER,
    tokens_delta       INTEGER NOT NULL DEFAULT 0,
    tokens_after       INTEGER,
    keepa_refill_in_ms INTEGER,
    status             VARCHAR DEFAULT 'recorded',
    message            VARCHAR,
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    meta_json          JSONB DEFAULT '{}'::JSONB
);

CREATE TABLE IF NOT EXISTS sync.keepa_token_budget_policy (
    policy_name        VARCHAR PRIMARY KEY,
    enabled            BOOLEAN DEFAULT TRUE,
    interactive_ratio  DOUBLE PRECISION DEFAULT 0.40,
    auto_discovery_ratio DOUBLE PRECISION DEFAULT 0.20,
    auto_history_ratio DOUBLE PRECISION DEFAULT 0.35,
    safe_reserve_ratio DOUBLE PRECISION DEFAULT 0.05,
    interactive_min_tokens INTEGER DEFAULT 90,
    bestseller_min_tokens  INTEGER DEFAULT 50,
    search_min_tokens      INTEGER DEFAULT 12,
    history_min_tokens     INTEGER DEFAULT 2,
    safe_reserve_tokens    INTEGER DEFAULT 20,
    pause_history_when_interactive_pending BOOLEAN DEFAULT TRUE,
    max_history_tokens_per_run INTEGER DEFAULT 200,
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    notes               VARCHAR
);

INSERT INTO sync.keepa_token_budget_policy (
    policy_name,
    notes
)
VALUES (
    'default',
    'Default Keepa token budget for interactive candidate expansion and auto-collect scheduling.'
)
ON CONFLICT (policy_name) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_candidate_expansion_jobs_status_priority
ON sync.keepa_candidate_expansion_jobs(status, priority, created_at);

CREATE INDEX IF NOT EXISTS idx_candidate_expansion_jobs_domain_category
ON sync.keepa_candidate_expansion_jobs(domain, category_id, status);

CREATE UNIQUE INDEX IF NOT EXISTS idx_candidate_expansion_jobs_idempotency
ON sync.keepa_candidate_expansion_jobs(idempotency_key)
WHERE idempotency_key IS NOT NULL AND idempotency_key <> '';

CREATE INDEX IF NOT EXISTS idx_keepa_token_ledger_job
ON sync.keepa_token_ledger(job_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_keepa_token_ledger_queue_time
ON sync.keepa_token_ledger(queue_name, created_at DESC);
