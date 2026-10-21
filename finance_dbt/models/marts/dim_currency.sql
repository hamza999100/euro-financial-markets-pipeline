-- Currency dimension, from the currencies seed (static reference data)
select
    currency_code,
    currency_name,
    region
from {{ ref('currencies') }}