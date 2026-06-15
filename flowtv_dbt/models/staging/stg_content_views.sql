with source as (
    select * from {{ source('flowtv_raw', 'content_views') }}
)

select
    view_id,
    user_id,
    session_id,
    content_id,
    view_date,
    watch_percentage,
    completed
from source
