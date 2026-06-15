-- User-day grain engagement mart. Matches vw_engagement column-for-column.
-- Powers Dashboard 2: cohort retention heatmap, active users, device mix.
-- cohort_month = month of user's FIRST SESSION (matches original view).

with sessions as (
    select * from {{ ref('stg_sessions') }}
),

users as (
    select * from {{ ref('stg_users') }}
),

user_first_session as (
    select
        user_id,
        min(session_date) as first_session_date,
        date_trunc(min(session_date), month) as cohort_month,
        date_trunc(min(session_date), week)  as cohort_week
    from sessions
    group by user_id
),

daily_activity as (
    select
        user_id,
        session_date,
        count(*) as session_count,
        sum(duration_minutes) as total_minutes,
        count(distinct device) as devices_used,
        string_agg(distinct device, ',') as devices_list
    from sessions
    group by user_id, session_date
)

select
    da.user_id,
    da.session_date,
    date_trunc(da.session_date, week)  as session_week,
    date_trunc(da.session_date, month) as session_month,
    da.session_count,
    da.total_minutes,
    da.devices_used,
    da.devices_list,
    u.acquisition_channel,
    u.country,
    u.primary_device,
    ufs.first_session_date,
    ufs.cohort_month,
    ufs.cohort_week,
    date_diff(da.session_date, ufs.first_session_date, day) as days_since_first,
    case
        when date_diff(da.session_date, ufs.first_session_date, day) = 0 then 'D0'
        when date_diff(da.session_date, ufs.first_session_date, day) between 1  and 6   then 'D1-6'
        when date_diff(da.session_date, ufs.first_session_date, day) between 7  and 13  then 'D7-13'
        when date_diff(da.session_date, ufs.first_session_date, day) between 14 and 29  then 'D14-29'
        when date_diff(da.session_date, ufs.first_session_date, day) between 30 and 59  then 'D30-59'
        when date_diff(da.session_date, ufs.first_session_date, day) between 60 and 89  then 'D60-89'
        when date_diff(da.session_date, ufs.first_session_date, day) >= 90              then 'D90+'
    end as retention_bucket,
    case
        when da.total_minutes >= 120 then 'power_user'
        when da.total_minutes >= 30  then 'regular'
        else 'casual'
    end as engagement_tier
from daily_activity da
inner join users u on da.user_id = u.user_id
inner join user_first_session ufs on da.user_id = ufs.user_id
