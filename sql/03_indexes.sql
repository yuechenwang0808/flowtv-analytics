-- ============================================================
-- 03_indexes.sql
-- Indexes for FlowTV. Run AFTER 02_load_data.sh.
-- Indexing post-load is much faster than during.
-- ============================================================

-- Users
CREATE INDEX idx_users_channel       ON users(acquisition_channel);
CREATE INDEX idx_users_signup_date   ON users(signup_date);
CREATE INDEX idx_users_country       ON users(country);

-- Subscriptions
CREATE INDEX idx_subs_user           ON subscriptions(user_id);
CREATE INDEX idx_subs_plan           ON subscriptions(plan_id);
CREATE INDEX idx_subs_status         ON subscriptions(status);
CREATE INDEX idx_subs_started        ON subscriptions(started_at);
CREATE INDEX idx_subs_ended          ON subscriptions(ended_at);

-- Sessions
CREATE INDEX idx_sessions_user       ON sessions(user_id);
CREATE INDEX idx_sessions_date       ON sessions(session_date);

-- Content views
CREATE INDEX idx_views_user          ON content_views(user_id);
CREATE INDEX idx_views_session       ON content_views(session_id);
CREATE INDEX idx_views_content       ON content_views(content_id);
CREATE INDEX idx_views_date          ON content_views(view_date);

-- Events
CREATE INDEX idx_events_user         ON events(user_id);
CREATE INDEX idx_events_type         ON events(event_type);
CREATE INDEX idx_events_timestamp    ON events(event_timestamp);

-- Experiment assignments
CREATE INDEX idx_exp_assign_user     ON experiment_assignments(user_id);
CREATE INDEX idx_exp_assign_exp      ON experiment_assignments(experiment_id);

-- Update statistics for query planner
ANALYZE;
