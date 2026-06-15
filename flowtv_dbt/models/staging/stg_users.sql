with source as (
    select * from {{ source('flowtv_raw', 'users') }}
)

select
    user_id,
    signup_timestamp,
    signup_date,
    acquisition_channel,
    country,
    primary_device,
    age,
    email
from source
