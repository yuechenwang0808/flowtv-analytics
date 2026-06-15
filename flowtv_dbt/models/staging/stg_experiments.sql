with source as (
    select * from {{ source('flowtv_raw', 'experiments') }}
)

select
    experiment_id,
    experiment_name,
    variant,
    start_date,
    end_date,
    is_control
from source
