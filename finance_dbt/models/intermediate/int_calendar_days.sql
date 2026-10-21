-- One row per calendar day from 2015-01-01 up to and including today (the "date spine")
with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="to_date('2015-01-01')",
        end_date="dateadd(day, 1, current_date())"
    ) }}
)

select
    cast(date_day as date)              as date_day,
    year(date_day)                      as year,
    month(date_day)                     as month,
    date_trunc('month', date_day)::date as month_start_date,
    dayofweekiso(date_day)              as day_of_week_iso,      -- 1 = Monday ... 7 = Sunday
    dayofweekiso(date_day) in (6, 7)    as is_weekend
from spine