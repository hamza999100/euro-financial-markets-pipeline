-- Daily yields of the current 2-year and 10-year German federal securities (Bundesbank)
with source as (
    select * from {{ source('raw', 'raw_bbk_observations') }}
),

renamed as (
    select
        series_key,
        case
            when series_key like '%WT0202%' then 2
            when series_key like '%WT1010%' then 10
        end                                  as maturity_years,
        try_to_date(period, 'YYYY-MM-DD')    as yield_date,
        try_to_decimal(obs_value, 10, 4)     as yield_pct,
        obs_status,
        loaded_at
    from source
)

select * from renamed
qualify row_number() over (partition by series_key, yield_date order by loaded_at desc) = 1