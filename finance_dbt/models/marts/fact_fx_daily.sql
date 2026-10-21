-- Daily EUR exchange rates with day-over-day change. INCREMENTAL: daily runs only process recent days.
{{ config(
    materialized='incremental',
    unique_key=['currency_code', 'rate_date'],
    incremental_strategy='merge'
) }}

with fx as (
    select currency_code, rate_date, eur_fx_rate
    from {{ ref('stg_ecb_fx') }}
    {% if is_incremental() %}
    -- incremental run: read only a 10-day window, so lag() below still sees the previous business day
    where rate_date >= (select dateadd(day, -10, max(rate_date)) from {{ this }})
    {% endif %}
),

with_change as (
    select
        currency_code,
        rate_date,
        eur_fx_rate,
        lag(eur_fx_rate) over (partition by currency_code order by rate_date) as prev_eur_fx_rate,
        round((eur_fx_rate / prev_eur_fx_rate - 1) * 100, 4)                  as daily_change_pct
    from fx
)

select * from with_change
{% if is_incremental() %}
-- ...but only write back the last 3 days (new days are inserted, recent days updated via MERGE)
where rate_date > (select dateadd(day, -3, max(rate_date)) from {{ this }})
{% endif %}