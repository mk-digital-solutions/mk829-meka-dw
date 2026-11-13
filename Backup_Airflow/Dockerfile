# Usa a mesma versão que está no seu docker-compose
FROM apache/airflow:3.1.5

USER root
RUN apt-get update && apt-get install -y git && apt-get clean

USER airflow

# Instala o Cosmos e o adaptador do banco (exemplo com Postgres)
RUN pip install --no-cache-dir \
    astronomer-cosmos \
    dbt-postgres 
   