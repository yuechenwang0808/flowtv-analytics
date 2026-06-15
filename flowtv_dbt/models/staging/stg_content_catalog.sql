with source as (
    select * from {{ source('flowtv_raw', 'content_catalog') }}
)

select
    content_id,
    title,
    content_type,
    genre,
    release_year,
    duration_minutes,
    is_original
from source
