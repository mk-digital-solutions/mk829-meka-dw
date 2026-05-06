select avg(case when corrente >= 7 then 16 else null end) as media_filtrada
from {{ ref('int_iba_pivot_minute') }}