
    
    

select
    id as unique_field,
    count(*) as n_records

from "postgres"."public"."teste_conexao"
where id is not null
group by id
having count(*) > 1


