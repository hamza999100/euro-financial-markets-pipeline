-- Daily ECB euro reference exchange rates: 1 EUR = x units of foreign currency
with source as (
    select * from {{ source('raw', 'raw_ecb_observations') }}
    where series_key like 'EXR.%'
),

renamed as (
    select
        series_key,
        split_part(series_key, '.', 3)       as currency_code,   -- EXR.D.USD.EUR.SP00.A -> USD
        try_to_date(period, 'YYYY-MM-DD')    as rate_date,
        try_to_decimal(obs_value, 18, 6)     as eur_fx_rate,
        obs_status,
        loaded_at
    from source
)

select * from renamed
-- keep the newest load if a series/date ever arrives twice
qualify row_number() over (partition by series_key, rate_date order by loaded_at desc) = 1