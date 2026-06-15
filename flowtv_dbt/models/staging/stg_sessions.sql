with source as (
    select * from {{ source('flowtv_raw', 'sessions') }}
)

select
    session_id,
    user_id,
    session_date,
    session_start,
    duration_minutes,
    device
from source
