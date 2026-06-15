-- Experiment-user grain mart. Matches vw_experiments column-for-column.
-- Powers Dashboard 4: conversion lift, retention lift, results grid.

with assignments as (
    select * from {{ ref('stg_experiment_assignments') }}
),

experiments as (
    select * from {{ ref('stg_experiments') }}
),

outcomes as (
    select * from {{ ref('int_user_outcomes') }}
)

select
    ea.experiment_id,
    e.experiment_name,
    ea.variant,
    e.is_control,
    ea.user_id,
    ea.assigned_at,
    date_trunc(date(ea.assigned_at), week)  as assigned_week,
    date_trunc(date(ea.assigned_at), month) as assigned_month,
    o.converted,
    o.retained_d7,
    o.retained_d30,
    o.sub_mrr,
    coalesce(o.sub_mrr, 0) * o.converted as revenue_per_assigned
from assignments ea
inner join experiments e
    on ea.experiment_id = e.experiment_id
   and ea.variant = e.variant
left join outcomes o on ea.user_id = o.user_id
