with source as (
    select * from {{ source('flowtv_raw', 'plans') }}
)

select
    plan_id,
    plan_name,
    price_monthly,
    billing_period,
    max_streams,
    resolution
from source
