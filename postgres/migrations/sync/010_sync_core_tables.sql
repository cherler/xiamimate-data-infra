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
