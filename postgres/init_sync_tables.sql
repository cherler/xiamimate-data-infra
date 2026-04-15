-- ============================================================

-- compatibility bootstrap: rebuild from postgres/migrations/*
-- do not hand-edit this file; edit fragments then rerun rebuild
-- ============================================================

-- >>> BEGIN migrations/bootstrap/001_create_shared_schemas.sql
-- Shared schema bootstrap for collector/theme-api local initialization.

CREATE SCHEMA IF NOT EXISTS sync;
CREATE SCHEMA IF NOT EXISTS serving;

-- <<< END migrations/bootstrap/001_create_shared_schemas.sql

-- >>> BEGIN migrations/sync/010_sync_core_tables.sql
-- sync.* core tables owned by collector, still mirrored here for shared bootstrap compatibility.

-- ASIN 注册表
CREATE TABLE IF NOT EXISTS sync.keepa_asin_registry (
    asin              VARCHAR NOT NULL,
    domain            INTEGER NOT NULL DEFAULT 1,
    marketplace       VARCHAR,
    product_title     VARCHAR,
    brand             VARCHAR,
    category          VARCHAR,
    category_id       BIGINT,
    category_path     VARCHAR,
    root_category_id  BIGINT,
    discovery_source  VARCHAR,
    search_term       VARCHAR,
    priority          INTEGER DEFAULT 0,
    business_score_total INTEGER,
    business_tier     VARCHAR,
    business_priority INTEGER,
    score_updated_at  TIMESTAMPTZ,
    first_seen_at     TIMESTAMPTZ,
    last_fetched_at   TIMESTAMPTZ,
    last_snapshot_at  TIMESTAMPTZ,
    fetch_count       INTEGER DEFAULT 0,
    is_active         BOOLEAN DEFAULT TRUE,
    inactive_reason   VARCHAR,
    inactive_at       TIMESTAMPTZ,
    notes             VARCHAR,
    PRIMARY KEY (asin, domain)
);

ALTER TABLE sync.keepa_asin_registry
ADD COLUMN IF NOT EXISTS business_score_total INTEGER;

ALTER TABLE sync.keepa_asin_registry
ADD COLUMN IF NOT EXISTS business_tier VARCHAR;

ALTER TABLE sync.keepa_asin_registry
ADD COLUMN IF NOT EXISTS business_priority INTEGER;

ALTER TABLE sync.keepa_asin_registry
ADD COLUMN IF NOT EXISTS score_updated_at TIMESTAMPTZ;

-- 商品历史 (日粒度)
CREATE TABLE IF NOT EXISTS sync.keepa_product_history (
    asin              VARCHAR NOT NULL,
    domain            INTEGER NOT NULL DEFAULT 1,
    date              DATE NOT NULL,
    amazon_price      DOUBLE PRECISION,
    new_price         DOUBLE PRECISION,
    used_price        DOUBLE PRECISION,
    buy_box_price     DOUBLE PRECISION,
    list_price        DOUBLE PRECISION,
    bsr               BIGINT,
    rating            DOUBLE PRECISION,
    review_count      BIGINT,
    monthly_sold      BIGINT,
    new_offer_count   INTEGER,
    used_offer_count  INTEGER,
    ingested_at       TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (asin, domain, date)
);

-- 商品历史日聚合 (全历史，按站点)
CREATE TABLE IF NOT EXISTS sync.keepa_history_domain_daily (
    date                 DATE NOT NULL,
    domain               INTEGER NOT NULL,
    rows_count           BIGINT NOT NULL,
    asin_count           BIGINT NOT NULL,
    avg_effective_price  DOUBLE PRECISION,
    min_effective_price  DOUBLE PRECISION,
    max_effective_price  DOUBLE PRECISION,
    avg_bsr              DOUBLE PRECISION,
    best_bsr             BIGINT,
    avg_rating           DOUBLE PRECISION,
    avg_review_count     DOUBLE PRECISION,
    sum_monthly_sold     DOUBLE PRECISION,
    avg_monthly_sold     DOUBLE PRECISION,
    aggregated_at        TIMESTAMPTZ,
    PRIMARY KEY (date, domain)
);

-- 商品历史日聚合 (全历史，按站点 × 根类目)
CREATE TABLE IF NOT EXISTS sync.keepa_history_root_category_daily (
    date                 DATE NOT NULL,
    domain               INTEGER NOT NULL,
    root_category_id     BIGINT NOT NULL,
    root_category_name   VARCHAR,
    rows_count           BIGINT NOT NULL,
    asin_count           BIGINT NOT NULL,
    avg_effective_price  DOUBLE PRECISION,
    min_effective_price  DOUBLE PRECISION,
    max_effective_price  DOUBLE PRECISION,
    avg_bsr              DOUBLE PRECISION,
    best_bsr             BIGINT,
    avg_rating           DOUBLE PRECISION,
    avg_review_count     DOUBLE PRECISION,
    sum_monthly_sold     DOUBLE PRECISION,
    avg_monthly_sold     DOUBLE PRECISION,
    aggregated_at        TIMESTAMPTZ,
    PRIMARY KEY (date, domain, root_category_id)
);

-- 商品快照 (每个 ASIN 保留最新一次)
CREATE TABLE IF NOT EXISTS sync.keepa_product_snapshot (
    asin                  VARCHAR NOT NULL,
    domain                INTEGER NOT NULL DEFAULT 1,
    marketplace           VARCHAR,
    product_title         VARCHAR,
    brand                 VARCHAR,
    category              VARCHAR,
    price                 DOUBLE PRECISION,
    list_price            DOUBLE PRECISION,
    bsr                   BIGINT,
    rating                DOUBLE PRECISION,
    review_count          BIGINT,
    estimated_sales       BIGINT,
    estimated_sales_period VARCHAR,
    seller_count          INTEGER,
    total_offer_count     INTEGER,
    offer_count_fba       INTEGER,
    offer_count_fbm       INTEGER,
    retrieved_offer_count INTEGER,
    offers_successful     BOOLEAN,
    stock_status          VARCHAR,
    data_capture_time     TIMESTAMPTZ,
    source_url            VARCHAR,
    keepa_last_update     BIGINT,
    ingested_at           TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (asin, domain)
);

-- Google Trends 日度指数
CREATE TABLE IF NOT EXISTS sync.google_trends_daily (
    keyword           VARCHAR NOT NULL,
    geo               VARCHAR NOT NULL DEFAULT 'US',
    date              DATE NOT NULL,
    trend_index       DOUBLE PRECISION,
    search_volume     DOUBLE PRECISION,
    is_partial        BOOLEAN DEFAULT FALSE,
    ingested_at       TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (keyword, geo, date)
);

-- 采集日志
CREATE TABLE IF NOT EXISTS sync.collection_log (
    job_id            SERIAL,
    run_date          DATE NOT NULL DEFAULT CURRENT_DATE,
    source            VARCHAR NOT NULL,
    domain            INTEGER,
    asins_requested   INTEGER DEFAULT 0,
    asins_succeeded   INTEGER DEFAULT 0,
    rows_ingested     INTEGER DEFAULT 0,
    tokens_before     INTEGER,
    tokens_after      INTEGER,
    tokens_consumed   INTEGER,
    duration_seconds  DOUBLE PRECISION,
    raw_file_path     VARCHAR,
    error_message     VARCHAR,
    started_at        TIMESTAMPTZ,
    finished_at       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE sync.collection_log
ADD COLUMN IF NOT EXISTS raw_file_path VARCHAR;

-- ASIN ↔ 关键词映射
CREATE TABLE IF NOT EXISTS sync.asin_keyword_mapping (
    asin              VARCHAR NOT NULL,
    domain            INTEGER NOT NULL DEFAULT 1,
    keyword           VARCHAR NOT NULL,
    geo               VARCHAR DEFAULT 'US',
    source            VARCHAR DEFAULT 'title_extract',
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (asin, domain, keyword)
);

-- ASIN ↔ 原始文件映射
CREATE TABLE IF NOT EXISTS sync.asin_raw_file_mapping (
    asin              VARCHAR NOT NULL,
    domain            INTEGER NOT NULL DEFAULT 1,
    source            VARCHAR NOT NULL,
    raw_file_path     VARCHAR NOT NULL,
    file_format       VARCHAR DEFAULT 'json',
    is_compressed     BOOLEAN DEFAULT FALSE,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (asin, domain, raw_file_path)
);

ALTER TABLE sync.asin_raw_file_mapping
ADD COLUMN IF NOT EXISTS file_format VARCHAR DEFAULT 'json';

ALTER TABLE sync.asin_raw_file_mapping
ADD COLUMN IF NOT EXISTS is_compressed BOOLEAN DEFAULT FALSE;

-- 下一阶段自动扩张状态
CREATE TABLE IF NOT EXISTS sync.discovery_expansion_state (
    expansion_type       VARCHAR NOT NULL,
    domain               INTEGER NOT NULL DEFAULT 1,
    target_key           VARCHAR NOT NULL,
    target_label         VARCHAR,
    last_priority_score  DOUBLE PRECISION,
    last_candidate_count INTEGER DEFAULT 0,
    last_new_asin_count  INTEGER DEFAULT 0,
    total_new_asin_count INTEGER DEFAULT 0,
    run_count            INTEGER DEFAULT 0,
    first_run_at         TIMESTAMPTZ,
    last_run_at          TIMESTAMPTZ,
    notes                VARCHAR,
    PRIMARY KEY (expansion_type, domain, target_key)
);

-- 类目注册表
CREATE TABLE IF NOT EXISTS sync.keepa_category_registry (
    category_id       BIGINT NOT NULL,
    domain            INTEGER NOT NULL DEFAULT 1,
    category_en       VARCHAR,
    category_cn       VARCHAR,
    parent_id         BIGINT,
    level             VARCHAR,
    product_count     BIGINT DEFAULT 0,
    depth             INTEGER DEFAULT 1,
    is_active         BOOLEAN DEFAULT TRUE,
    bestseller_fetched_at  TIMESTAMPTZ,
    bestseller_asin_count  INTEGER DEFAULT 0,
    children_fetched_at    TIMESTAMPTZ,
    sort_order        INTEGER DEFAULT 0,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (category_id, domain)
);

-- <<< END migrations/sync/010_sync_core_tables.sql

-- >>> BEGIN migrations/serving/010_serving_theme_feature_tables.sql
-- serving.* feature tables consumed by theme-api, rebuilt by collector.

CREATE TABLE IF NOT EXISTS serving.theme_base_daily (
    domain                INTEGER NOT NULL,
    asin                  VARCHAR NOT NULL,
    date                  DATE NOT NULL,
    product_title         VARCHAR,
    brand                 VARCHAR,
    category              VARCHAR,
    effective_price       DOUBLE PRECISION,
    rating                DOUBLE PRECISION,
    review_count          BIGINT,
    new_offer_count       INTEGER,
    used_offer_count      INTEGER,
    bsr                   BIGINT,
    estimated_daily_sales DOUBLE PRECISION,
    synced_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (domain, asin, date)
);

CREATE TABLE IF NOT EXISTS serving.theme_trends_daily (
    domain                       INTEGER NOT NULL,
    asin                         VARCHAR NOT NULL,
    date                         DATE NOT NULL,
    trend_index_mean             DOUBLE PRECISION,
    trend_index_wow              DOUBLE PRECISION,
    trend_index_dod              DOUBLE PRECISION,
    trend_index_roll_std_7       DOUBLE PRECISION,
    trend_index_roll_max_7       DOUBLE PRECISION,
    trend_keyword_coverage_ratio DOUBLE PRECISION,
    synced_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (domain, asin, date)
);

CREATE TABLE IF NOT EXISTS serving.theme_cross_daily (
    domain                INTEGER NOT NULL,
    asin                  VARCHAR NOT NULL,
    date                  DATE NOT NULL,
    product_title         VARCHAR,
    effective_price       DOUBLE PRECISION,
    bsr                   BIGINT,
    rating                DOUBLE PRECISION,
    review_count          BIGINT,
    new_offer_count       INTEGER,
    used_offer_count      INTEGER,
    estimated_daily_sales DOUBLE PRECISION,
    trend_index_mean      DOUBLE PRECISION,
    price_discount_pct    DOUBLE PRECISION,
    synced_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (domain, asin, date)
);

-- <<< END migrations/serving/010_serving_theme_feature_tables.sql

-- >>> BEGIN migrations/sync/020_sync_runtime_monitor.sql
-- sync.* runtime monitoring tables and view for Grafana/local service health.

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

-- <<< END migrations/sync/020_sync_runtime_monitor.sql

-- >>> BEGIN migrations/serving/020_serving_theme_api_auth_tables.sql
-- serving.* auth/audit tables owned by theme-api.

CREATE TABLE IF NOT EXISTS serving.api_keys (
    key_id          VARCHAR PRIMARY KEY,
    name            VARCHAR NOT NULL,
    tier            VARCHAR NOT NULL DEFAULT 'standard',
    key_prefix      VARCHAR NOT NULL,
    key_hash        VARCHAR NOT NULL UNIQUE,
    key_raw         VARCHAR,
    status          VARCHAR NOT NULL DEFAULT 'active',
    daily_quota     INTEGER,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at      TIMESTAMPTZ,
    last_used_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS serving.api_usage (
    id              BIGSERIAL PRIMARY KEY,
    key_id          VARCHAR NOT NULL REFERENCES serving.api_keys(key_id),
    endpoint        VARCHAR NOT NULL,
    usage_date      DATE NOT NULL,
    status_code     INTEGER NOT NULL,
    response_time_ms INTEGER,
    request_count   INTEGER NOT NULL DEFAULT 1,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- <<< END migrations/serving/020_serving_theme_api_auth_tables.sql

-- >>> BEGIN migrations/sync/030_sync_indexes.sql
-- sync.* indexes kept separate so the compatibility bootstrap stays readable.

CREATE INDEX IF NOT EXISTS idx_collection_log_finished ON sync.collection_log(finished_at);
CREATE INDEX IF NOT EXISTS idx_history_date ON sync.keepa_product_history(date);
CREATE INDEX IF NOT EXISTS idx_history_domain_daily_domain_date ON sync.keepa_history_domain_daily(domain, date);
CREATE INDEX IF NOT EXISTS idx_history_root_category_daily_domain_date ON sync.keepa_history_root_category_daily(domain, date);
CREATE INDEX IF NOT EXISTS idx_history_root_category_daily_root_category ON sync.keepa_history_root_category_daily(root_category_id, date);
CREATE INDEX IF NOT EXISTS idx_snapshot_capture_time ON sync.keepa_product_snapshot(data_capture_time);
CREATE INDEX IF NOT EXISTS idx_trends_keyword ON sync.google_trends_daily(keyword);
CREATE INDEX IF NOT EXISTS idx_registry_active ON sync.keepa_asin_registry(is_active);
CREATE INDEX IF NOT EXISTS idx_asin_raw_mapping_created_at ON sync.asin_raw_file_mapping(created_at);
CREATE INDEX IF NOT EXISTS idx_category_depth ON sync.keepa_category_registry(depth, product_count);
CREATE INDEX IF NOT EXISTS idx_discovery_expansion_last_run ON sync.discovery_expansion_state(expansion_type, domain, last_run_at);
CREATE INDEX IF NOT EXISTS idx_runtime_process_status_group ON sync.runtime_process_status(process_group, status);
CREATE INDEX IF NOT EXISTS idx_runtime_process_status_checked_at ON sync.runtime_process_status(checked_at);
CREATE INDEX IF NOT EXISTS idx_runtime_process_history_checked_at ON sync.runtime_process_history(checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_runtime_process_history_process_key_checked_at ON sync.runtime_process_history(process_key, checked_at DESC);

-- <<< END migrations/sync/030_sync_indexes.sql

-- >>> BEGIN migrations/serving/030_serving_indexes.sql
-- serving.* indexes aligned with theme-api query paths and auth audit lookups.

CREATE INDEX IF NOT EXISTS idx_theme_base_daily_domain_date ON serving.theme_base_daily(domain, date DESC);
CREATE INDEX IF NOT EXISTS idx_theme_trends_daily_domain_date ON serving.theme_trends_daily(domain, date DESC);
CREATE INDEX IF NOT EXISTS idx_theme_cross_daily_domain_date ON serving.theme_cross_daily(domain, date DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_key_date ON serving.api_usage(key_id, usage_date);
CREATE INDEX IF NOT EXISTS idx_api_usage_created_at ON serving.api_usage(created_at);
CREATE INDEX IF NOT EXISTS idx_api_usage_endpoint ON serving.api_usage(endpoint, usage_date);
CREATE INDEX IF NOT EXISTS idx_api_keys_status ON serving.api_keys(status);

-- <<< END migrations/serving/030_serving_indexes.sql

-- >>> BEGIN migrations/sync/040_sync_status_views.sql
-- sync.* status views used by Grafana/Metabase and by collector diagnostics.

CREATE OR REPLACE VIEW sync.keepa_refresh_status AS
WITH base AS (
    SELECT
        r.asin,
        r.domain,
        CASE r.domain
            WHEN 1 THEN 'US'
            WHEN 2 THEN 'GB'
            WHEN 3 THEN 'DE'
            WHEN 4 THEN 'FR'
            WHEN 5 THEN 'JP'
            WHEN 6 THEN 'CA'
            WHEN 8 THEN 'IT'
            WHEN 9 THEN 'ES'
            WHEN 10 THEN 'IN'
            WHEN 11 THEN 'MX'
            WHEN 12 THEN 'BR'
            WHEN 13 THEN 'AU'
            ELSE r.domain::text
        END AS domain_label,
        r.product_title,
        r.category,
        r.root_category_id,
        r.priority,
        r.business_score_total,
        r.business_tier,
        COALESCE(NULLIF(r.business_tier, ''), 'UNSCORED') AS tier_label,
        r.business_priority,
        COALESCE(r.business_priority, r.priority, 0) AS effective_priority,
        r.score_updated_at,
        r.first_seen_at,
        r.last_fetched_at,
        r.fetch_count,
        CASE r.business_tier
            WHEN 'P0' THEN 3
            WHEN 'P1' THEN 10
            WHEN 'P2' THEN 21
            ELSE 14
        END AS target_min_days,
        CASE r.business_tier
            WHEN 'P0' THEN 7
            WHEN 'P1' THEN 14
            WHEN 'P2' THEN 30
            ELSE 14
        END AS target_max_days,
        CASE r.business_tier
            WHEN 'P0' THEN '3-7 天'
            WHEN 'P1' THEN '10-14 天'
            WHEN 'P2' THEN '21-30 天'
            ELSE '14 天 (兜底)'
        END AS target_window_label,
        CASE
            WHEN r.business_tier = 'P0' THEN ROUND(
                168 - ((LEAST(GREATEST(COALESCE(r.business_priority, 90), 90), 100) - 90) * 96.0 / 10)
            )::BIGINT
            WHEN r.business_tier = 'P1' THEN ROUND(
                336 - ((LEAST(GREATEST(COALESCE(r.business_priority, 60), 60), 80) - 60) * 96.0 / 20)
            )::BIGINT
            WHEN r.business_tier = 'P2' THEN ROUND(
                720 - ((LEAST(GREATEST(COALESCE(r.business_priority, 20), 20), 40) - 20) * 216.0 / 20)
            )::BIGINT
            ELSE 336
        END AS target_stale_hours
    FROM sync.keepa_asin_registry r
    WHERE r.is_active = TRUE
)
SELECT
    base.*,
    CASE
        WHEN base.last_fetched_at IS NULL THEN NULL
        ELSE ROUND((EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - base.last_fetched_at)) / 3600.0)::numeric, 1)
    END AS age_hours,
    CASE
        WHEN base.last_fetched_at IS NULL THEN NULL
        ELSE ROUND((EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - base.last_fetched_at)) / 86400.0)::numeric, 2)
    END AS age_days,
    (base.last_fetched_at IS NULL) AS is_never_fetched,
    (
        base.last_fetched_at IS NOT NULL
        AND EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - base.last_fetched_at)) / 3600.0 >= base.target_stale_hours
    ) AS is_overdue,
    (
        base.last_fetched_at IS NULL
        OR EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - base.last_fetched_at)) / 3600.0 >= base.target_stale_hours
    ) AS is_pending,
    CASE
        WHEN base.last_fetched_at IS NULL THEN NULL
        ELSE GREATEST(
            ROUND((EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - base.last_fetched_at)) / 3600.0 - base.target_stale_hours)::numeric, 1),
            0
        )
    END AS overdue_hours
FROM base;

CREATE OR REPLACE VIEW sync.keepa_snapshot_status AS
SELECT
    s.asin,
    s.domain,
    CASE s.domain
        WHEN 1 THEN 'US'
        WHEN 2 THEN 'GB'
        WHEN 3 THEN 'DE'
        WHEN 4 THEN 'FR'
        WHEN 5 THEN 'JP'
        WHEN 6 THEN 'CA'
        WHEN 8 THEN 'IT'
        WHEN 9 THEN 'ES'
        WHEN 10 THEN 'IN'
        WHEN 11 THEN 'MX'
        WHEN 12 THEN 'BR'
        WHEN 13 THEN 'AU'
        ELSE s.domain::text
    END AS domain_label,
    s.marketplace,
    s.product_title,
    s.brand,
    s.category,
    s.price,
    s.list_price,
    s.bsr,
    s.rating,
    s.review_count,
    s.estimated_sales,
    s.estimated_sales_period,
    s.seller_count,
    s.total_offer_count,
    s.offer_count_fba,
    s.offer_count_fbm,
    s.retrieved_offer_count,
    s.offers_successful,
    s.stock_status,
    s.data_capture_time,
    s.keepa_last_update,
    s.ingested_at,
    (s.total_offer_count IS NOT NULL) AS has_offer_data,
    (s.offer_count_fba IS NOT NULL OR s.offer_count_fbm IS NOT NULL) AS has_offer_breakdown,
    CASE
        WHEN s.data_capture_time IS NULL THEN NULL
        ELSE ROUND((EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - s.data_capture_time)) / 3600.0)::numeric, 1)
    END AS snapshot_age_hours,
    CASE
        WHEN COALESCE(s.total_offer_count, 0) = 0 THEN NULL
        ELSE ROUND((100.0 * COALESCE(s.offer_count_fba, 0) / GREATEST(s.total_offer_count, 1))::numeric, 1)
    END AS fba_share_pct,
    CASE
        WHEN COALESCE(s.total_offer_count, 0) = 0 THEN NULL
        ELSE ROUND((100.0 * COALESCE(s.offer_count_fbm, 0) / GREATEST(s.total_offer_count, 1))::numeric, 1)
    END AS fbm_share_pct
FROM sync.keepa_product_snapshot s;

-- <<< END migrations/sync/040_sync_status_views.sql

-- >>> BEGIN migrations/sync/050_sync_expansion_candidate_views.sql
-- sync.* candidate/expansion views used by shortlist and keyword expansion workflows.

CREATE OR REPLACE VIEW sync.keyword_expansion_candidates AS
WITH mapped AS (
    SELECT
        m.domain,
        m.geo,
        m.keyword,
        COUNT(DISTINCT m.asin) AS mapped_asin_count,
        COUNT(DISTINCT CASE WHEN COALESCE(r.business_priority, r.priority, 0) >= 90 THEN m.asin END) AS mapped_p0_asin_count,
        COUNT(DISTINCT NULLIF(split_part(r.category_path, ' > ', 2), '')) AS l2_category_count,
        COUNT(DISTINCT NULLIF(split_part(r.category_path, ' > ', 3), '')) AS l3_category_count,
        MAX(COALESCE(r.business_priority, r.priority, 0)) AS max_business_priority
    FROM sync.asin_keyword_mapping m
    JOIN sync.keepa_asin_registry r
      ON r.asin = m.asin AND r.domain = m.domain
    WHERE r.is_active = TRUE
    GROUP BY 1, 2, 3
), trend AS (
    SELECT
        keyword,
        geo,
        AVG(trend_index) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '30 days') AS trend_30d_avg,
        AVG(trend_index) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '7 days') AS last_7d_avg,
        AVG(trend_index) FILTER (
            WHERE date >= CURRENT_DATE - INTERVAL '14 days'
              AND date < CURRENT_DATE - INTERVAL '7 days'
        ) AS prev_7d_avg
    FROM sync.google_trends_daily t
    WHERE date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY 1, 2
), trend_hot AS (
    SELECT
        t.keyword,
        t.geo,
        COUNT(*) FILTER (
            WHERE t.date >= CURRENT_DATE - INTERVAL '7 days'
              AND t.trend_index > tr.trend_30d_avg
        ) AS hot_days_over_30d_avg
    FROM sync.google_trends_daily t
    JOIN trend tr ON tr.keyword = t.keyword AND tr.geo = t.geo
    WHERE t.date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY 1, 2
), base AS (
    SELECT
        m.domain,
        CASE m.domain
            WHEN 1 THEN 'US'
            WHEN 2 THEN 'GB'
            WHEN 3 THEN 'DE'
            WHEN 4 THEN 'FR'
            WHEN 5 THEN 'JP'
            WHEN 6 THEN 'CA'
            WHEN 8 THEN 'IT'
            WHEN 9 THEN 'ES'
            WHEN 10 THEN 'IN'
            WHEN 11 THEN 'MX'
            WHEN 12 THEN 'BR'
            WHEN 13 THEN 'AU'
            ELSE m.domain::text
        END AS domain_label,
        m.geo,
        m.keyword,
        m.mapped_asin_count,
        m.mapped_p0_asin_count,
        m.l2_category_count,
        m.l3_category_count,
        m.max_business_priority,
        tr.trend_30d_avg,
        tr.last_7d_avg,
        tr.prev_7d_avg,
        th.hot_days_over_30d_avg,
        s.last_run_at,
        CASE WHEN tr.prev_7d_avg IS NOT NULL AND tr.prev_7d_avg > 0 THEN tr.last_7d_avg / tr.prev_7d_avg ELSE NULL END AS trend_growth_7d
    FROM mapped m
    LEFT JOIN trend tr
      ON tr.keyword = m.keyword AND tr.geo = m.geo
    LEFT JOIN trend_hot th
      ON th.keyword = m.keyword AND th.geo = m.geo
    LEFT JOIN sync.discovery_expansion_state s
      ON s.expansion_type = 'keyword'
     AND s.domain = m.domain
     AND s.target_key = m.keyword
    WHERE m.mapped_asin_count BETWEEN 3 AND 50
)
SELECT
    *,
    CASE WHEN trend_30d_avg >= 20 THEN 2 WHEN trend_30d_avg >= 10 THEN 1 ELSE 0 END AS trend_level_score,
    CASE WHEN trend_growth_7d >= 1.15 THEN 2 WHEN trend_growth_7d >= 1.05 THEN 1 ELSE 0 END AS trend_growth_score,
    CASE WHEN mapped_asin_count BETWEEN 3 AND 20 THEN 2 WHEN mapped_asin_count BETWEEN 21 AND 50 THEN 1 ELSE 0 END AS coverage_gap_score,
    CASE WHEN mapped_p0_asin_count >= 1 THEN 2 WHEN max_business_priority >= 70 THEN 1 ELSE 0 END AS quality_anchor_score,
    CASE WHEN (l2_category_count >= 1 OR l3_category_count >= 1) THEN 1 ELSE 0 END AS category_match_score,
    (
        CASE WHEN trend_30d_avg >= 20 THEN 2 WHEN trend_30d_avg >= 10 THEN 1 ELSE 0 END
        + CASE WHEN trend_growth_7d >= 1.15 THEN 2 WHEN trend_growth_7d >= 1.05 THEN 1 ELSE 0 END
        + CASE WHEN mapped_asin_count BETWEEN 3 AND 20 THEN 2 WHEN mapped_asin_count BETWEEN 21 AND 50 THEN 1 ELSE 0 END
        + CASE WHEN mapped_p0_asin_count >= 1 THEN 2 WHEN max_business_priority >= 70 THEN 1 ELSE 0 END
        + CASE WHEN (l2_category_count >= 1 OR l3_category_count >= 1) THEN 1 ELSE 0 END
    ) AS expand_priority,
    CASE WHEN last_run_at IS NULL THEN NULL ELSE ROUND((EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - last_run_at)) / 3600.0)::numeric, 1) END AS hours_since_last_run,
    CASE
        WHEN trend_30d_avg < 10 THEN FALSE
        WHEN hot_days_over_30d_avg < 3 THEN FALSE
        WHEN trend_growth_7d IS NULL OR trend_growth_7d < 1.05 THEN FALSE
        WHEN char_length(trim(keyword)) < 4 THEN FALSE
        WHEN last_run_at IS NOT NULL AND CURRENT_TIMESTAMP - last_run_at < INTERVAL '72 hours' THEN FALSE
        ELSE TRUE
    END AS is_candidate
FROM base;

CREATE OR REPLACE VIEW sync.subcategory_expansion_candidates AS
WITH latest_history AS (
    SELECT *
    FROM (
        SELECT
            asin,
            domain,
            COALESCE(buy_box_price, amazon_price, new_price, list_price) AS latest_effective_price,
            monthly_sold AS latest_monthly_sold,
            new_offer_count AS latest_new_offer_count,
            ROW_NUMBER() OVER (PARTITION BY asin, domain ORDER BY date DESC) AS rn
        FROM sync.keepa_product_history
        WHERE date >= CURRENT_DATE - INTERVAL '30 days'
    ) ranked
    WHERE rn = 1
), history_30d AS (
    SELECT
        asin,
        domain,
        AVG(new_offer_count) AS avg_new_offer_count_30d,
        COUNT(*) AS history_days_30d
    FROM sync.keepa_product_history
    WHERE date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY 1, 2
), trend_by_keyword AS (
    SELECT
        m.asin,
        m.domain,
        AVG(t.trend_index) FILTER (WHERE t.date >= CURRENT_DATE - INTERVAL '30 days') AS avg_trend_30d,
        AVG(t.trend_index) FILTER (WHERE t.date >= CURRENT_DATE - INTERVAL '7 days') AS last_7d_avg,
        AVG(t.trend_index) FILTER (
            WHERE t.date >= CURRENT_DATE - INTERVAL '14 days'
              AND t.date < CURRENT_DATE - INTERVAL '7 days'
        ) AS prev_7d_avg
    FROM sync.asin_keyword_mapping m
    LEFT JOIN sync.google_trends_daily t
      ON t.keyword = m.keyword
     AND t.geo = m.geo
     AND t.date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY 1, 2
), snapshot_now AS (
    SELECT
        asin,
        domain,
        COALESCE(total_offer_count, seller_count, retrieved_offer_count) AS current_offer_count
    FROM sync.keepa_product_snapshot
), categorized AS (
    SELECT
        r.asin,
        r.domain,
        kr2.category_id AS l2_category_id,
        COALESCE(kr2.category_cn, kr2.category_en) AS l2_category_name,
        kr3.category_id AS l3_category_id,
        COALESCE(kr3.category_cn, kr3.category_en) AS l3_category_name,
        COALESCE(kr3.category_id, kr2.category_id) AS target_category_id,
        COALESCE(
            COALESCE(kr3.category_cn, kr3.category_en),
            COALESCE(kr2.category_cn, kr2.category_en)
        ) AS target_category_name,
        CASE
            WHEN kr3.category_id IS NOT NULL THEN 3
            WHEN kr2.category_id IS NOT NULL THEN 2
            ELSE NULL
        END AS target_category_depth
    FROM sync.keepa_asin_registry r
    LEFT JOIN sync.keepa_category_registry kr2
      ON kr2.domain = r.domain
     AND kr2.parent_id = r.root_category_id
     AND kr2.depth = 2
     AND kr2.category_en = NULLIF(split_part(r.category_path, ' > ', 2), '')
    LEFT JOIN sync.keepa_category_registry kr3
      ON kr3.domain = r.domain
     AND kr3.parent_id = kr2.category_id
     AND kr3.depth = 3
     AND kr3.category_en = NULLIF(split_part(r.category_path, ' > ', 3), '')
    WHERE r.is_active = TRUE
      AND r.root_category_id IS NOT NULL
      AND r.category_path IS NOT NULL
      AND r.category_path <> ''
), base AS (
    SELECT
        c.domain,
        CASE c.domain
            WHEN 1 THEN 'US'
            WHEN 2 THEN 'GB'
            WHEN 3 THEN 'DE'
            WHEN 4 THEN 'FR'
            WHEN 5 THEN 'JP'
            WHEN 6 THEN 'CA'
            WHEN 8 THEN 'IT'
            WHEN 9 THEN 'ES'
            WHEN 10 THEN 'IN'
            WHEN 11 THEN 'MX'
            WHEN 12 THEN 'BR'
            WHEN 13 THEN 'AU'
            ELSE c.domain::text
        END AS domain_label,
        c.target_category_id AS category_id,
        c.target_category_name AS category_name,
        c.target_category_depth AS category_depth,
        MAX(COALESCE(kt.product_count, 0)) AS category_product_count,
        COUNT(*) AS sample_asin_count,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY lh.latest_effective_price) AS median_effective_price_30d,
        AVG(lh.latest_monthly_sold) AS avg_monthly_sold_30d,
        AVG(COALESCE(sn.current_offer_count, h30.avg_new_offer_count_30d, lh.latest_new_offer_count)) AS avg_offer_count_30d,
        AVG(tb.avg_trend_30d) AS trend_index_30d,
        MAX(CASE WHEN tb.prev_7d_avg IS NOT NULL AND tb.prev_7d_avg > 0 THEN tb.last_7d_avg / tb.prev_7d_avg ELSE NULL END) AS trend_growth_7d,
        AVG(h30.history_days_30d) AS avg_history_days_30d,
        MAX(s.last_run_at) AS last_run_at
    FROM categorized c
    LEFT JOIN latest_history lh
            ON lh.asin = c.asin AND lh.domain = c.domain
    LEFT JOIN history_30d h30
            ON h30.asin = c.asin AND h30.domain = c.domain
    LEFT JOIN trend_by_keyword tb
            ON tb.asin = c.asin AND tb.domain = c.domain
    LEFT JOIN snapshot_now sn
            ON sn.asin = c.asin AND sn.domain = c.domain
    LEFT JOIN sync.keepa_category_registry kt
            ON kt.category_id = c.target_category_id AND kt.domain = c.domain
    LEFT JOIN sync.discovery_expansion_state s
      ON s.expansion_type = 'category'
     AND s.domain = c.domain
     AND s.target_key = CAST(c.target_category_id AS VARCHAR)
    WHERE c.target_category_id IS NOT NULL
    GROUP BY c.domain, domain_label, c.target_category_id, c.target_category_name, c.target_category_depth
), scored AS (
    SELECT
        *,
        CASE
            WHEN domain = 1 AND median_effective_price_30d BETWEEN 15 AND 60 THEN 2
            WHEN domain = 2 AND median_effective_price_30d BETWEEN 12 AND 50 THEN 2
            WHEN domain = 3 AND median_effective_price_30d BETWEEN 15 AND 60 THEN 2
            WHEN domain = 4 AND median_effective_price_30d BETWEEN 15 AND 60 THEN 2
            WHEN domain = 5 AND median_effective_price_30d BETWEEN 2000 AND 8000 THEN 2
            WHEN domain = 6 AND median_effective_price_30d BETWEEN 20 AND 80 THEN 2
            WHEN domain = 8 AND median_effective_price_30d BETWEEN 15 AND 60 THEN 2
            WHEN domain = 9 AND median_effective_price_30d BETWEEN 15 AND 60 THEN 2
            WHEN domain = 10 AND median_effective_price_30d BETWEEN 1200 AND 5000 THEN 2
            WHEN domain = 11 AND median_effective_price_30d BETWEEN 300 AND 1200 THEN 2
            WHEN domain = 12 AND median_effective_price_30d BETWEEN 80 AND 300 THEN 2
            WHEN domain = 13 AND median_effective_price_30d BETWEEN 25 AND 90 THEN 2
            ELSE 0
        END AS price_score,
        CASE WHEN avg_monthly_sold_30d >= 200 THEN 2 WHEN avg_monthly_sold_30d >= 50 THEN 1 ELSE 0 END AS demand_score,
        CASE WHEN trend_index_30d >= 20 AND trend_growth_7d >= 1.15 THEN 2 WHEN trend_index_30d >= 10 THEN 1 ELSE 0 END AS trend_score,
        CASE WHEN avg_offer_count_30d <= 8 THEN 2 WHEN avg_offer_count_30d <= 12 THEN 1 ELSE 0 END AS competition_score,
        CASE WHEN category_product_count >= GREATEST(sample_asin_count * 80, 5000) THEN 2 WHEN category_product_count >= GREATEST(sample_asin_count * 30, 1000) THEN 1 ELSE 0 END AS coverage_gap_score,
        CASE WHEN last_run_at IS NULL THEN NULL ELSE ROUND((EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - last_run_at)) / 3600.0)::numeric, 1) END AS hours_since_last_run
    FROM base
)
SELECT
    *,
    (demand_score + trend_score + competition_score + price_score + coverage_gap_score) AS shortlist_score,
    CASE
        WHEN category_depth NOT IN (2, 3) THEN FALSE
        WHEN sample_asin_count < 10 THEN FALSE
        WHEN last_run_at IS NOT NULL AND CURRENT_TIMESTAMP - last_run_at < INTERVAL '720 hours' THEN FALSE
        WHEN (demand_score + trend_score + competition_score + price_score + coverage_gap_score) < 3 THEN FALSE
        ELSE TRUE
    END AS is_candidate
FROM scored;

-- <<< END migrations/sync/050_sync_expansion_candidate_views.sql

