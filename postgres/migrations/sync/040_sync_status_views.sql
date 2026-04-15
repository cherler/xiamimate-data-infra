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
