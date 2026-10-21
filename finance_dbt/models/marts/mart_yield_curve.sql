-- German yield curve: 10y - 2y Bund spread per day. Negative spread = inverted curve.
with yields as (
    select
        yield_date,
        max(case when maturity_years = 2  then yield_pct end) as yield_2y_pct,
        max(case when maturity_years = 10 then yield_pct end) as yield_10y_pct
    from {{ ref('stg_bbk_yields') }}
    group by yield_date
)

select
    yields.yield_date,
    yields.yield_2y_pct,
    yields.yield_10y_pct,
    yields.yield_10y_pct - yields.yield_2y_pct        as spread_10y_2y_pp,   -- percentage points
    (yields.yield_10y_pct - yields.yield_2y_pct) < 0  as is_inverted,
    policy.deposit_rate_pct                            as ecb_deposit_rate_pct
from yields
left join {{ ref('int_policy_rate_daily') }} as policy
    on policy.date_day = yields.yield_date
where yields.yield_2y_pct is not null
  and yields.yield_10y_pct is not null