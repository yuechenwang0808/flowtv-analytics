with source as (
    select * from {{ source('flowtv_raw', 'events') }}
)

select
    event_id,
    user_id,
    event_type,
    event_timestamp
from source
