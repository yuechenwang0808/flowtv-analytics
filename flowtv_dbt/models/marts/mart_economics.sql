-- Subscription-month grain economics mart. Matches vw_economics.
-- Powers Dashboard 3: MRR trend, LTV/CAC, churn trend, plan mix.

with subscriptions as (
    select * from {{ ref('stg_subscriptions') }}
),

users as (
    select * from {{ ref('stg_users') }}
),

plans as (
    select * from {{ ref('stg_plans') }}
),

channel_cac as (
    select * from {{ ref('channel_cac') }}
),

paid_subs as (
    select
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
        date_trunc(date(s.started_at), month) as sub_start_month,
        coalesce(c.channel_cac, 0) as channel_cac
    from subscriptions s
    inner join users u on s.user_id = u.user_id
    inner join plans p on s.plan_id = p.plan_id
    left join channel_cac c on u.acquisition_channel = c.acquisition_channel
    where s.converted_to_paid = true
),

month_bounds as (
    select
        date_trunc(min(date(started_at)), month) as min_month,
        least(
            date_trunc(max(coalesce(date(ended_at), current_date())), month),
            date '2025-06-01'
        ) as max_month
    from paid_subs
),

months as (
    select active_month
    from month_bounds,
    unnest(generate_date_array(min_month, max_month, interval 1 month)) as active_month
)

select
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
    m.active_month,
    date_diff(m.active_month, ps.sub_start_month, month) as tenure_months
from paid_subs ps
inner join months m
    on m.active_month >= ps.sub_start_month
   and m.active_month <= coalesce(date_trunc(date(ps.ended_at), month), current_date())
   and m.active_month <= date '2025-06-30'    -- ADD THIS LINE: cap at data end