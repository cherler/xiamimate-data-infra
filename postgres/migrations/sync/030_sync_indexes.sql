-- sync.* indexes kept separate so the compatibility bootstrap stays readable.

CREATE INDEX IF NOT EXISTS idx_collection_log_finished ON sync.collection_log(finished_at);
CREATE INDEX IF NOT EXISTS idx_history_date ON sync.keepa_product_history(date);
CREATE INDEX IF NOT EXISTS idx_history_domain_daily_domain_date ON sync.keepa_history_domain_daily(domain, date);
CREATE INDEX IF NOT EXISTS idx_history_root_category_daily_domain_date ON sync.keepa_history_root_category_daily(domain, date);
CREATE INDEX IF NOT EXISTS idx_history_root_category_daily_root_category ON sync.keepa_history_root_category_daily(root_category_id, date);
CREATE INDEX IF NOT EXISTS idx_snapshot_capture_time ON sync.keepa_product_snapshot(data_capture_time);
CREATE INDEX IF NOT EXISTS idx_trends_keyword ON sync.google_trends_daily(keyword);
CREATE INDEX IF NOT EXISTS idx_registry_active ON sync.keepa_asin_registry(is_active);
CREATE INDEX IF NOT EXISTS idx_registry_domain_active_priority ON sync.keepa_asin_registry(domain, is_active, business_priority DESC, priority DESC);
CREATE INDEX IF NOT EXISTS idx_snapshot_domain_asin_price ON sync.keepa_product_snapshot(domain, asin, price);
CREATE INDEX IF NOT EXISTS idx_history_domain_asin_date ON sync.keepa_product_history(domain, asin, date DESC);
CREATE INDEX IF NOT EXISTS idx_keyword_mapping_domain_asin_keyword ON sync.asin_keyword_mapping(domain, asin, keyword);
CREATE INDEX IF NOT EXISTS idx_keyword_mapping_domain_keyword_asin ON sync.asin_keyword_mapping(domain, keyword, asin);
CREATE INDEX IF NOT EXISTS idx_asin_raw_mapping_created_at ON sync.asin_raw_file_mapping(created_at);
CREATE INDEX IF NOT EXISTS idx_category_depth ON sync.keepa_category_registry(depth, product_count);
CREATE INDEX IF NOT EXISTS idx_discovery_expansion_last_run ON sync.discovery_expansion_state(expansion_type, domain, last_run_at);
