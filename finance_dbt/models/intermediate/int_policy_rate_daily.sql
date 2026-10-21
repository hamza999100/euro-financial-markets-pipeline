-- ECB deposit facility rate valid on each calendar day (forward-filled from the change dates)
with calendar as (
    select date_day from {{ ref('int_calendar_days') }}
),

rate_changes as (
    select effective_date, rate_pct
    from {{ ref('stg_ecb_policy_rates') }}
    where rate_type = 'DFR'
)

select
    calendar.date_day,
    rate_changes.rate_pct        as deposit_rate_pct,
    rate_changes.effective_date  as rate_valid_since
from calendar
-- ASOF JOIN: for every day, take the most recent rate change on or before that day
asof join rate_changes
    match_condition (calendar.date_day >= rate_changes.effective_date)