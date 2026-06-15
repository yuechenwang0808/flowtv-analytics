with source as (
    select * from {{ source('flowtv_raw', 'subscriptions') }}
)

select
    subscription_id,
    user_id,
    plan_id,
    status,
    started_at,
    ended_at,
    is_trial,
    converted_to_paid,
    mrr
from source
