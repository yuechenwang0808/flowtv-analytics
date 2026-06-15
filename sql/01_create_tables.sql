-- ============================================================
-- 01_create_tables.sql
-- FlowTV — schema for synthetic streaming analytics dataset
-- Run after creating the 'flowtv' database.
-- ============================================================

-- Drop tables in reverse-dependency order if rerunning
DROP TABLE IF EXISTS content_views CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS experiment_assignments CASCADE;
DROP TABLE IF EXISTS experiments CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS content_catalog CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS plans CASCADE;

-- ============================================================
-- 1. PLANS (lookup table — 4 rows)
-- ============================================================
CREATE TABLE plans (
    plan_id          INTEGER PRIMARY KEY,
    plan_name        VARCHAR(20) NOT NULL,
    price_monthly    NUMERIC(8,2) NOT NULL,
    billing_period   VARCHAR(10) NOT NULL,  -- 'monthly' or 'annual'
    max_streams      INTEGER NOT NULL,
    resolution       VARCHAR(10) NOT NULL
);

-- ============================================================
-- 2. CONTENT CATALOG (500 titles)
-- ============================================================
CREATE TABLE content_catalog (
    content_id       VARCHAR(10) PRIMARY KEY,
    title            VARCHAR(200),
    content_type     VARCHAR(20),   -- 'series' or 'movie'
    genre            VARCHAR(30),
    release_year     INTEGER,
    duration_minutes INTEGER,
    is_original      BOOLEAN
);

-- ============================================================
-- 3. USERS (~100K rows)
-- ============================================================
CREATE TABLE users (
    user_id              VARCHAR(15) PRIMARY KEY,
    signup_date          DATE NOT NULL,
    signup_timestamp     TIMESTAMP NOT NULL,
    acquisition_channel  VARCHAR(30) NOT NULL,
    country              VARCHAR(5) NOT NULL,
    primary_device       VARCHAR(20) NOT NULL,
    age                  INTEGER,
    email                VARCHAR(200)
);

-- ============================================================
-- 4. EXPERIMENTS (5 experiments, ~10 variants)
-- ============================================================
CREATE TABLE experiments (
    experiment_id    VARCHAR(30) NOT NULL,
    experiment_name  VARCHAR(100),
    variant          VARCHAR(50) NOT NULL,
    start_date       DATE,
    end_date         DATE,
    is_control       BOOLEAN,
    PRIMARY KEY (experiment_id, variant)
);

-- ============================================================
-- 5. EXPERIMENT ASSIGNMENTS (~200K rows)
-- ============================================================
CREATE TABLE experiment_assignments (
    experiment_id    VARCHAR(30) NOT NULL,
    user_id          VARCHAR(15) NOT NULL,
    variant          VARCHAR(50) NOT NULL,
    assigned_at      TIMESTAMP NOT NULL,
    PRIMARY KEY (experiment_id, user_id)
);

-- ============================================================
-- 6. SUBSCRIPTIONS (~50K rows)
-- ============================================================
CREATE TABLE subscriptions (
    subscription_id    VARCHAR(15) PRIMARY KEY,
    user_id            VARCHAR(15) NOT NULL,
    plan_id            INTEGER NOT NULL,
    status             VARCHAR(20) NOT NULL,  -- 'active', 'churned', 'trial_expired'
    started_at         TIMESTAMP NOT NULL,
    ended_at           TIMESTAMP,
    is_trial           BOOLEAN,
    converted_to_paid  BOOLEAN,
    mrr                NUMERIC(8,2)
);

-- ============================================================
-- 7. EVENTS (~1.5M rows — funnel tracking)
-- ============================================================
CREATE TABLE events (
    event_id         VARCHAR(15) PRIMARY KEY,
    user_id          VARCHAR(15) NOT NULL,
    event_type       VARCHAR(40) NOT NULL,
    event_timestamp  TIMESTAMP NOT NULL
);

-- ============================================================
-- 8. SESSIONS (~25M rows — daily engagement)
-- ============================================================
CREATE TABLE sessions (
    session_id        VARCHAR(20) PRIMARY KEY,
    user_id           VARCHAR(15) NOT NULL,
    session_date      DATE NOT NULL,
    session_start     TIMESTAMP NOT NULL,
    duration_minutes  INTEGER NOT NULL,
    device            VARCHAR(20)
);

-- ============================================================
-- 9. CONTENT VIEWS (~50M rows — what got watched)
-- ============================================================
CREATE TABLE content_views (
    view_id            VARCHAR(20) PRIMARY KEY,
    user_id            VARCHAR(15) NOT NULL,
    session_id         VARCHAR(20) NOT NULL,
    content_id         VARCHAR(10) NOT NULL,
    view_date          DATE NOT NULL,
    watch_percentage   NUMERIC(4,2),
    completed          BOOLEAN
);

-- ============================================================
-- INDEXES — built after data load for speed
-- (see 03_indexes.sql)
-- ============================================================
