CREATE SCHEMA IF NOT EXISTS ops;

CREATE TABLE IF NOT EXISTS ops.collection_job (
    job_id BIGSERIAL PRIMARY KEY,
    source_name TEXT NOT NULL,
    source_type TEXT NOT NULL,
    command_name TEXT NOT NULL,
    status TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ,
    target_count INTEGER,
    success_count INTEGER,
    failure_count INTEGER,
    job_params JSONB,
    error_message TEXT
);

CREATE TABLE IF NOT EXISTS ops.asset_manifest (
    asset_id BIGSERIAL PRIMARY KEY,
    source_name TEXT NOT NULL,
    asset_type TEXT NOT NULL,
    entity_type TEXT,
    entity_id TEXT,
    file_path TEXT NOT NULL,
    file_hash TEXT,
    mime_type TEXT,
    file_size_bytes BIGINT,
    language_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB
);

CREATE TABLE IF NOT EXISTS ops.supplier_followup (
    followup_id BIGSERIAL PRIMARY KEY,
    candidate_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    supplier_platform TEXT NOT NULL,
    supplier_name TEXT NOT NULL,
    current_status TEXT NOT NULL,
    next_action TEXT,
    owner_name TEXT,
    quoted_price NUMERIC(18, 4),
    price_currency TEXT,
    min_moq INTEGER,
    sample_requested BOOLEAN,
    sample_received BOOLEAN,
    last_contacted_at TIMESTAMPTZ,
    next_followup_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_collection_job_source_name ON ops.collection_job(source_name);
CREATE INDEX IF NOT EXISTS idx_asset_manifest_entity ON ops.asset_manifest(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_supplier_followup_candidate_id ON ops.supplier_followup(candidate_id);