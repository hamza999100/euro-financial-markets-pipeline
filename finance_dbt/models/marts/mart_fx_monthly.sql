-- Monthly FX summary per currency: average level and volatility of daily moves
select
    fx.currency_code,
    currency.currency_name,
    date_trunc('month', fx.rate_date)::date   as month_start_date,
    count(*)                                  as trading_days,
    round(avg(fx.eur_fx_rate), 6)             as avg_eur_fx_rate,
    min(fx.eur_fx_rate)                       as min_eur_fx_rate,
    max(fx.eur_fx_rate)                       as max_eur_fx_rate,
    round(stddev(fx.daily_change_pct), 4)     as volatility_daily_change_pct   -- std. deviation of daily % moves
from {{ ref('fact_fx_daily') }} as fx
inner join {{ ref('dim_currency') }} as currency
    on currency.currency_code = fx.currency_code
group by 1, 2, 3