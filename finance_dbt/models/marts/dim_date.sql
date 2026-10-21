-- Date dimension for Power BI: one row per day, with readable labels
select
    date_day,
    year,
    quarter(date_day)                   as quarter,
    month,
    monthname(date_day)                 as month_name,     -- 'Jan', 'Feb', ...
    to_char(date_day, 'YYYY-MM')        as year_month,
    month_start_date,
    day_of_week_iso,
    dayname(date_day)                   as day_name,       -- 'Mon', 'Tue', ...
    is_weekend
from {{ ref('int_calendar_days') }}