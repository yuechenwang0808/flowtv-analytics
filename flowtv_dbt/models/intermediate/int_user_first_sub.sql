-- First subscription per user (earliest started_at).
-- Mirrors the user_first_sub CTE (DISTINCT ON) in vw_acquisition,
-- using BigQuery's QUALIFY ROW_NUMBER pattern.

with subscriptions as (
    select * from {{ ref('stg_subscriptions') }}
)

select
    user_id,
    plan_id,
    started_at as first_sub_started,
    is_trial,
    converted_to_paid,
    mrr as first_sub_mrr
from subscriptions
qualify row_number() over (partition by user_id order by started_at) = 1
