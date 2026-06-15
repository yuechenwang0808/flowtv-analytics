-- One row per user with conversion and retention outcomes.
-- Retention is measured by whether the user had any session in the
-- day-window after signup (D7 window: days 7-13, D30 window: days 30-59).

with users as (
    select * from {{ ref('stg_users') }}
),

subscriptions as (
    select * from {{ ref('stg_subscriptions') }}
),

sessions as (
    select * from {{ ref('stg_sessions') }}
),

user_conversion as (
    select
        user_id,
        max(case when converted_to_paid then 1 else 0 end) as converted,
        max(coalesce(mrr, 0)) as sub_mrr
    from subscriptions
    group by user_id
),

user_retention as (
    select
        u.user_id,
        max(case
            when s.session_date >= date_add(u.signup_date, interval 7 day)
             and s.session_date <  date_add(u.signup_date, interval 14 day)
            then 1 else 0
        end) as retained_d7,
        max(case
            when s.session_date >= date_add(u.signup_date, interval 30 day)
             and s.session_date <  date_add(u.signup_date, interval 60 day)
            then 1 else 0
        end) as retained_d30
    from users u
    left join sessions s on u.user_id = s.user_id
    group by u.user_id
)

select
    u.user_id,
    u.signup_date,
    u.signup_timestamp,
    u.acquisition_channel,
    u.country,
    u.primary_device,
    coalesce(c.converted, 0) as converted,
    coalesce(c.sub_mrr, 0) as sub_mrr,
    coalesce(r.retained_d7, 0) as retained_d7,
    coalesce(r.retained_d30, 0) as retained_d30
from users u
left join user_conversion c on u.user_id = c.user_id
left join user_retention r on u.user_id = r.user_id
