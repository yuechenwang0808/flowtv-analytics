-- ============================================================
-- 04_create_views.sql
-- Analytical views for FlowTV dashboards.
-- Each view powers one dashboard:
--   vw_acquisition  -> Dashboard 1: Acquisition & Conversion
--   vw_engagement   -> Dashboard 2: Engagement & Retention
--   vw_economics    -> Dashboard 3: Subscriber Economics
--   vw_experiments  -> Dashboard 4: Experimentation
-- ============================================================

-- ============================================================
-- VIEW 1: vw_acquisition
-- Grain: one row per user (signup-level)
-- Purpose: funnel analysis, channel performance, conversion rates
-- ============================================================
CREATE OR REPLACE VIEW vw_acquisition AS
WITH user_funnel AS (
    SELECT
        u.user_id,
        u.signup_date,
        u.signup_timestamp,
        u.acquisition_channel,
        u.country,
        u.primary_device,
        u.age,
        DATE_TRUNC('month', u.signup_date)::DATE AS signup_month,
        DATE_TRUNC('week',  u.signup_date)::DATE AS signup_week,
        -- Did they reach each stage?
        MAX(CASE WHEN e.event_type = 'signup_completed'    THEN 1 ELSE 0 END) AS reached_signup,
        MAX(CASE WHEN e.event_type = 'trial_started'       THEN 1 ELSE 0 END) AS reached_trial,
        MAX(CASE WHEN e.event_type = 'paywall_view'        THEN 1 ELSE 0 END) AS reached_paywall,
        MAX(CASE WHEN e.event_type = 'subscribe_clicked'   THEN 1 ELSE 0 END) AS reached_subscribe_click,
        MAX(CASE WHEN e.event_type = 'subscribed'          THEN 1 ELSE 0 END) AS reached_paid
    FROM users u
    LEFT JOIN events e ON u.user_id = e.user_id
    GROUP BY u.user_id, u.signup_date, u.signup_timestamp,
             u.acquisition_channel, u.country, u.primary_device, u.age
),
user_first_sub AS (
    -- Get first subscription details per user
    SELECT DISTINCT ON (user_id)
        user_id,
        plan_id,
        started_at AS first_sub_started,
        is_trial,
        converted_to_paid,
        mrr AS first_sub_mrr
    FROM subscriptions
    ORDER BY user_id, started_at
)
SELECT
    f.*,
    s.plan_id,
    s.first_sub_started,
    s.converted_to_paid,
    s.first_sub_mrr,
    p.plan_name,
    p.billing_period,
    -- Channel CAC (lookup — could be a separate table but inline for clarity)
    CASE f.acquisition_channel
        WHEN 'organic'     THEN 0
        WHEN 'referral'    THEN 5
        WHEN 'email'       THEN 3
        WHEN 'affiliate'   THEN 12
        WHEN 'display'     THEN 18
        WHEN 'paid_social' THEN 22
        WHEN 'paid_search' THEN 28
        ELSE 0
    END AS channel_cac
FROM user_funnel f
LEFT JOIN user_first_sub s ON f.user_id = s.user_id
LEFT JOIN plans p ON s.plan_id = p.plan_id;


-- ============================================================
-- VIEW 2: vw_engagement
-- Grain: one row per (user, session_date) — daily user activity
-- Purpose: DAU/WAU/MAU, retention, engagement segmentation
-- ============================================================
CREATE OR REPLACE VIEW vw_engagement AS
WITH user_first_session AS (
    SELECT
        user_id,
        MIN(session_date) AS first_session_date,
        DATE_TRUNC('month', MIN(session_date))::DATE AS cohort_month,
        DATE_TRUNC('week',  MIN(session_date))::DATE AS cohort_week
    FROM sessions
    GROUP BY user_id
),
daily_activity AS (
    SELECT
        s.user_id,
        s.session_date,
        COUNT(*)                            AS session_count,
        SUM(s.duration_minutes)             AS total_minutes,
        COUNT(DISTINCT s.device)            AS devices_used,
        STRING_AGG(DISTINCT s.device, ',')  AS devices_list
    FROM sessions s
    GROUP BY s.user_id, s.session_date
)
SELECT
    da.user_id,
    da.session_date,
    DATE_TRUNC('week',  da.session_date)::DATE AS session_week,
    DATE_TRUNC('month', da.session_date)::DATE AS session_month,
    da.session_count,
    da.total_minutes,
    da.devices_used,
    da.devices_list,
    -- User context
    u.acquisition_channel,
    u.country,
    u.primary_device,
    -- Cohort context
    ufs.first_session_date,
    ufs.cohort_month,
    ufs.cohort_week,
    -- Days since first session (the retention "period" column)
    (da.session_date - ufs.first_session_date)             AS days_since_first,
    -- Bucketed retention period (D0/D1/D7/D30/etc.)
    CASE
        WHEN (da.session_date - ufs.first_session_date) = 0 THEN 'D0'
        WHEN (da.session_date - ufs.first_session_date) BETWEEN 1  AND 6   THEN 'D1-6'
        WHEN (da.session_date - ufs.first_session_date) BETWEEN 7  AND 13  THEN 'D7-13'
        WHEN (da.session_date - ufs.first_session_date) BETWEEN 14 AND 29  THEN 'D14-29'
        WHEN (da.session_date - ufs.first_session_date) BETWEEN 30 AND 59  THEN 'D30-59'
        WHEN (da.session_date - ufs.first_session_date) BETWEEN 60 AND 89  THEN 'D60-89'
        WHEN (da.session_date - ufs.first_session_date) >= 90              THEN 'D90+'
    END AS retention_bucket,
    -- Engagement tier classification
    CASE
        WHEN da.total_minutes >= 120 THEN 'power_user'   -- 2+ hrs/day
        WHEN da.total_minutes >= 30  THEN 'regular'      -- 30 min - 2 hr
        ELSE 'casual'                                    -- < 30 min
    END AS engagement_tier
FROM daily_activity da
INNER JOIN users u             ON da.user_id = u.user_id
INNER JOIN user_first_session ufs ON da.user_id = ufs.user_id;


-- ============================================================
-- VIEW 3: vw_economics
-- Grain: one row per (subscription, month) — monthly subscription state
-- Purpose: MRR tracking, churn, LTV, cohort revenue retention
-- ============================================================
CREATE OR REPLACE VIEW vw_economics AS
WITH paid_subs AS (
    -- Only consider subscriptions that converted to paid
    SELECT
        s.subscription_id,
        s.user_id,
        s.plan_id,
        s.started_at,
        s.ended_at,
        s.status,
        s.mrr,
        u.acquisition_channel,
        u.country,
        u.primary_device,
        p.plan_name,
        p.billing_period,
        DATE_TRUNC('month', s.started_at)::DATE AS sub_start_month,
        -- Channel CAC for LTV/CAC math
        CASE u.acquisition_channel
            WHEN 'organic'     THEN 0
            WHEN 'referral'    THEN 5
            WHEN 'email'       THEN 3
            WHEN 'affiliate'   THEN 12
            WHEN 'display'     THEN 18
            WHEN 'paid_social' THEN 22
            WHEN 'paid_search' THEN 28
            ELSE 0
        END AS channel_cac
    FROM subscriptions s
    INNER JOIN users u ON s.user_id = u.user_id
    INNER JOIN plans p ON s.plan_id = p.plan_id
    WHERE s.converted_to_paid = TRUE
),
months AS (
    -- Generate a series of months covering the data range
    SELECT generate_series(
        DATE_TRUNC('month', (SELECT MIN(started_at) FROM paid_subs))::DATE,
        DATE_TRUNC('month', (SELECT MAX(COALESCE(ended_at, NOW())) FROM paid_subs))::DATE,
        INTERVAL '1 month'
    )::DATE AS month_date
)
SELECT
    ps.subscription_id,
    ps.user_id,
    ps.plan_id,
    ps.plan_name,
    ps.billing_period,
    ps.acquisition_channel,
    ps.country,
    ps.primary_device,
    ps.started_at,
    ps.ended_at,
    ps.status,
    ps.mrr,
    ps.channel_cac,
    ps.sub_start_month,
    m.month_date AS active_month,
    -- Months since subscription started (tenure)
    EXTRACT(YEAR  FROM AGE(m.month_date, ps.sub_start_month)) * 12
      + EXTRACT(MONTH FROM AGE(m.month_date, ps.sub_start_month)) AS tenure_months
FROM paid_subs ps
INNER JOIN months m
    ON m.month_date >= ps.sub_start_month
   AND m.month_date <= COALESCE(DATE_TRUNC('month', ps.ended_at)::DATE, CURRENT_DATE);


-- ============================================================
-- VIEW 4: vw_experiments
-- Grain: one row per (experiment, user) — assignment + outcomes
-- Purpose: A/B test analysis, lift calculation, statistical significance
-- ============================================================
CREATE OR REPLACE VIEW vw_experiments AS
WITH user_outcomes AS (
    SELECT
        u.user_id,
        u.signup_timestamp,
        -- Did they convert to paid?
        MAX(CASE WHEN s.converted_to_paid THEN 1 ELSE 0 END) AS converted,
        -- D30 retention: did they have a session 30+ days after signup?
        MAX(CASE
            WHEN sess.session_date >= (u.signup_date + INTERVAL '30 days')::DATE
             AND sess.session_date <  (u.signup_date + INTERVAL '60 days')::DATE
            THEN 1 ELSE 0
        END) AS retained_d30,
        -- D7 retention
        MAX(CASE
            WHEN sess.session_date >= (u.signup_date + INTERVAL '7 days')::DATE
             AND sess.session_date <  (u.signup_date + INTERVAL '14 days')::DATE
            THEN 1 ELSE 0
        END) AS retained_d7,
        -- First subscription MRR (revenue per user)
        MAX(COALESCE(s.mrr, 0)) AS sub_mrr
    FROM users u
    LEFT JOIN subscriptions s ON u.user_id = s.user_id
    LEFT JOIN sessions sess   ON u.user_id = sess.user_id
    GROUP BY u.user_id, u.signup_timestamp, u.signup_date
)
SELECT
    ea.experiment_id,
    e.experiment_name,
    ea.variant,
    e.is_control,
    ea.user_id,
    ea.assigned_at,
    DATE_TRUNC('week',  ea.assigned_at)::DATE AS assigned_week,
    DATE_TRUNC('month', ea.assigned_at)::DATE AS assigned_month,
    uo.converted,
    uo.retained_d7,
    uo.retained_d30,
    uo.sub_mrr,
    -- For LTV approximation in experiments: revenue per assigned user
    COALESCE(uo.sub_mrr, 0) * uo.converted AS revenue_per_assigned
FROM experiment_assignments ea
INNER JOIN experiments e
    ON ea.experiment_id = e.experiment_id
   AND ea.variant       = e.variant
LEFT JOIN user_outcomes uo ON ea.user_id = uo.user_id;
