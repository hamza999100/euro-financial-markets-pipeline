-- ECB reference rates are only published on business days.
-- Any Saturday/Sunday row means a parsing or loading bug -> test fails.
select *
from {{ ref('stg_ecb_fx') }}
where dayofweekiso(rate_date) in (6, 7)