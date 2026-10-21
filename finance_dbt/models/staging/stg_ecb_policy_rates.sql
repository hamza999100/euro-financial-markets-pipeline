-- ECB key interest rates. Rows only exist on the dates a rate CHANGED (forward-filled later).
with source as (
    select * from {{ source('raw', 'raw_ecb_observations') }}
    where series_key like 'FM.%'
),

renamed as (
    select
        series_key,
        split_part(series_key, '.', 7)       as rate_type,        -- FM.B.U2.EUR.4F.KR.DFR.LEV -> DFR
        try_to_date(period, 'YYYY-MM-DD')    as effective_date,
        try_to_decimal(obs_value, 10, 4)     as rate_pct,
        obs_status,
        loaded_at
    from source
)

select * from renamed
qualify row_number() over (partition by series_key, effective_date order by loaded_at desc) = 1