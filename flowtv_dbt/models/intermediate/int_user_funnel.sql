-- One row per user with funnel-stage flags, derived from events.
-- Mirrors the user_funnel CTE in the original vw_acquisition.

with users as (
    select * from {{ ref('stg_users') }}
),

events as (
    select * from {{ ref('stg_events') }}
)

select
    u.user_id,
    u.signup_date,
    u.signup_timestamp,
    u.acquisition_channel,
    u.country,
    u.primary_device,
    u.age,
    date_trunc(u.signup_date, month) as signup_month,
    date_trunc(u.signup_date, week)  as signup_week,
    max(case when e.event_type = 'signup_completed'  then 1 else 0 end) as reached_signup,
    max(case when e.event_type = 'trial_started'     then 1 else 0 end) as reached_trial,
    max(case when e.event_type = 'paywall_view'      then 1 else 0 end) as reached_paywall,
    max(case when e.event_type = 'subscribe_clicked' then 1 else 0 end) as reached_subscribe_click,
    max(case when e.event_type = 'subscribed'        then 1 else 0 end) as reached_paid
from users u
left join events e on u.user_id = e.user_id
group by
    u.user_id, u.signup_date, u.signup_timestamp,
    u.acquisition_channel, u.country, u.primary_device, u.age
