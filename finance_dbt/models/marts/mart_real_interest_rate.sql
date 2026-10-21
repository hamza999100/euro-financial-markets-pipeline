-- Real interest rate per month = ECB deposit rate (valid at month-end) - HICP inflation
with inflation as (
    select
        month_start_date,
        max(case when country_code = 'DE' then inflation_yoy_pct end) as inflation_de_pct,
        max(case when country_code = 'U2' then inflation_yoy_pct end) as inflation_ea_pct
    from {{ ref('stg_ecb_inflation') }}
    group by month_start_date
),

rate_at_month_end as (
    select
        date_trunc('month', date_day)::date as month_start_date,
        deposit_rate_pct
    from {{ ref('int_policy_rate_daily') }}
    -- last available day of each month (for the current month: today)
    qualify row_number() over (partition by date_trunc('month', date_day) order by date_day desc) = 1
)

select
    inflation.month_start_date,
    rate_at_month_end.deposit_rate_pct,
    inflation.inflation_de_pct,
    inflation.inflation_ea_pct,
    rate_at_month_end.deposit_rate_pct - inflation.inflation_de_pct as real_rate_de_pct,
    rate_at_month_end.deposit_rate_pct - inflation.inflation_ea_pct as real_rate_ea_pct
from inflation
inner join rate_at_month_end
    on rate_at_month_end.month_start_date = inflation.month_start_date