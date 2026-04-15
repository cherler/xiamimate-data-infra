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
