-- Monthly HICP inflation, annual rate of change in percent (Germany + euro area)
with source as (
    select * from {{ source('raw', 'raw_ecb_observations') }}
    where series_key like 'HICP.%'
),

renamed as (
    select
        series_key,
        split_part(series_key, '.', 3)       as country_code,     -- HICP.M.DE.N... -> DE / U2
        try_to_date(period || '-01', 'YYYY-MM-DD') as month_start_date, -- '2026-09' -> 2026-09-01
        try_to_decimal(obs_value, 10, 2)     as inflation_yoy_pct,
        obs_status,
        loaded_at
    from source
)

select * from renamed
qualify row_number() over (partition by series_key, month_start_date order by loaded_at desc) = 1