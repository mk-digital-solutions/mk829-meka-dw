select count(*) * 60 as segundos_on
from {{ ref('int_iba_pivot_minute') }}
where corrente > 2.8