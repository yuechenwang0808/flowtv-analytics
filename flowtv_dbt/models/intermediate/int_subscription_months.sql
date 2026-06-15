-- One row per subscription per active month.
-- Used by the economics mart for MRR trend, churn, and plan mix.

with subscriptions as (
    select * from {{ ref('stg_subscriptions') }}
),

plans as (
    select * from {{ ref('stg_plans') }}
),

paid_subs as (
    select *
    from subscriptions
    where converted_to_paid = true
),

-- Generate the series of active months for each subscription
subscription_months as (
    select
        s.subscription_id,
        s.user_id,
        s.plan_id,
        s.status,
        s.mrr,
        s.started_at,
        s.ended_at,
        active_month
    from paid_subs s,
    unnest(generate_date_array(
        date_trunc(date(s.started_at), month),
        date_trunc(coalesce(date(s.ended_at), current_date()), month),
        interval 1 month
    )) as active_month
)

select
    sm.subscription_id,
    sm.user_id,
    sm.plan_id,
    p.plan_name,
    sm.status,
    sm.mrr,
    sm.active_month,
    sm.ended_at,
    -- churn flag: did this subscription end in this active month?
    case
        when sm.status = 'churned'
         and date_trunc(date(sm.ended_at), month) = sm.active_month
        then 1 else 0
    end as churned_this_month
from subscription_months sm
left join plans p on sm.plan_id = p.plan_id
