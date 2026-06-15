-- User-grain acquisition mart. Matches vw_acquisition column-for-column.
-- Powers Dashboard 1: funnel, channel performance, signups over time, geo.

with funnel as (
    select * from {{ ref('int_user_funnel') }}
),

first_sub as (
    select * from {{ ref('int_user_first_sub') }}
),

plans as (
    select * from {{ ref('stg_plans') }}
),

channel_cac as (
    select * from {{ ref('channel_cac') }}
)

select
    f.user_id,
    f.signup_date,
    f.signup_timestamp,
    f.acquisition_channel,
    f.country,
    f.primary_device,
    f.age,
    f.signup_month,
    f.signup_week,
    f.reached_signup,
    f.reached_trial,
    f.reached_paywall,
    f.reached_subscribe_click,
    f.reached_paid,
    s.plan_id,
    s.first_sub_started,
    s.converted_to_paid,
    s.first_sub_mrr,
    p.plan_name,
    p.billing_period,
    coalesce(c.channel_cac, 0) as channel_cac
from funnel f
left join first_sub s on f.user_id = s.user_id
left join plans p on s.plan_id = p.plan_id
left join channel_cac c on f.acquisition_channel = c.acquisition_channel
