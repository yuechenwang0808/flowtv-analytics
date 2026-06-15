with source as (
    select * from {{ source('flowtv_raw', 'experiment_assignments') }}
)

select
    experiment_id,
    user_id,
    variant,
    assigned_at
from source
