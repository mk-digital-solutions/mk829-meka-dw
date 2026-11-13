# 06 · Consumo: Power BI e Planilha de Gestão

## Power BI

- Lê os schemas `mart_*` do Postgres em `192.168.0.157:5432` (ou `100.87.152.38:5432` via Tailscale).
- Atualização agendada: **07, 10, 13, 16 e 19h BRT**. O `pipeline_transformacao` roda toda hora no :30
  para o mart estar fresco antes de cada refresh ([03](03-airflow-e-orquestracao.md)).
- Modelos citados nas fontes: "Banco - Cronogramas" (relação com `CostCenters`) e o que lê
  `PA - Composição Projetos`. O inventário dos relatórios não foi encontrado nas fontes desta pasta.

### Erros de refresh conhecidos

| mensagem | causa | diagnóstico | correção |
|---|---|---|---|
| `Column 'CostCenters.Id' ... contains a duplicate value '6925'` | o mesmo MK em **duas planilhas de cronograma** | query abaixo | tirar o MK de uma planilha (ou desativar a conexão e dropar as `raw_cronogramas.mkXXX_*` dela) |
| `Type mismatch. Unable to convert '' from VT_BSTR to VT_DATE` | uma coluna de data virou `varchar` no DW por um valor fora do padrão | query abaixo | formatar/corrigir a célula **na planilha do Google**, esperar sync + pipeline |
| Timeout ao conectar (máquina nova) | rota do Tailscale | `tracert -d 192.168.0.157` | [01 §Tailscale](01-infraestrutura-e-rede.md#tailscale-a-rota-1921680024-quebrada) |

**MK duplicado** (o erro cita só o primeiro Id; 6925 era o MK726):

```sql
select upper(trim("MK")), count(*)
from mart_cronogramas.fct_banco
where coalesce(trim("MK"),'') <> ''
group by 1 having count(*) > 1;
```

Caso de 29/10/2026: MK720–726 nas planilhas mk720 (nova, do Albert) e mk726 (antiga); MK412/414/415/416
em mk412 e mk413; MK524 em mk413 e mk524. Resolvido às 14:12: conexão MK726 desativada, tabelas
`mk726_00___*` e `mk412_00___*` dropadas, MK524 retirado da planilha MK413. O banco do FlowUp não tinha
duplicata. Fonte: memória `cronogramas-mk-duplicado-powerbi`.

**Coluna de data rebaixada**: valores que travam = os não vazios que não batem
`^\d{1,2}/\d{1,2}/\d{2,4}$` nem `^\d{5}$`. Serial de 5 dígitos já é convertido desde 19/10/2026
([04](04-dbt-modelos-e-nomenclatura.md)). Exemplo de consulta:

```bash
docker exec postgres_db sh -c 'psql -U "$POSTGRES_USER" -d postgres -tAc "SELECT \"<coluna>\", count(*) FROM raw_planilhas.\"<TABELA>\" WHERE trim(\"<coluna>\") ~ '\''^\d{5}$'\'' GROUP BY 1;"'
```

Casos de 19/10/2026: pedido PO18162749 (MK927–MK930) com `46310` em `Data de Emissao do Pedido`
(resolvido pela blindagem); `11/09/20245` em `Data de Início` (MK408–MK411), corrigido na planilha pelo
Wollace. As três colunas de data de `COMPOSICAO_PROJETOS` (Emissão, Fechamento Comercial, Início) ficaram
`date`. Fonte: memória `sheets-serial-date-quebra-powerbi`.

**No DBeaver:** script com BEGIN/COMMIT precisa de Alt+X (Ctrl+Enter roda só a linha do cursor).

## Planilha de Gestão (Google Sheets)

Planilha `1sUAXt551TbR2snogO8wLlWDX779fLwNcrDWke2X8uKs`, alimentada pela DAG **`sheets_planilha_gestao`**
(última etapa da cadeia de cronogramas do pipeline, portanto de hora em hora).

| aba | fonte |
|---|---|
| `BANCO_CRONOGRAMAS_BI` | `mart_cronogramas.fct_banco` |
| `BANCO_ATIVIDADES_BI` | `mart_cronogramas.fct_atividades` |
| `BANCO_ENTREGAS_BI` | `mart_cronogramas.fct_entregas` |
| `Banco_Alocacao` | `mart_planilhas.fct_banco_bi` (MAPA_MANUAL `NOME: colaborador_planilha`) |
| `BANCO_COLABORADORES_BI` | `mart_planilhas.BANCO_COLABORADORES` (MAPA_MANUAL `NOME: NOME_B1`, `Nº: No_A1`) |

Como funciona: lê o cabeçalho da linha 1 da aba, casa com as colunas do mart por nome normalizado (+
`MAPA_MANUAL` no topo do arquivo), grava RAW com `values.batchUpdate`, limpa a sobra e apaga linhas vazias
da grade. `ABAS` mapeia aba → (schema, tabela). Credencial: conexão Airflow `google_sheets_gestao`
(service account `sheets-teste@sheetsproject-490617`). Primeiro run: 777/5526/2901 linhas em ~15 s;
Banco_Alocacao 1908, colaboradores 97 (22/10/2026).

**Ajuste de coluna é no `MAPA_MANUAL`**, e o cabeçalho da planilha manda: coluna nova na planilha, com nome
casável, passa a ser preenchida.

**Por que não o Airbyte:** a conexão `63b7eba3` (destination-google-sheets 0.3.5) ordenava colunas
alfabeticamente e fazia `clear()` + `append(INSERT_ROWS)`, inchando a grade até o limite de células (falhou
de 07 a 10/10/2026). Ela deve ficar desligada.

O desenho da DAG segue o `handover (1).md` (Hugo): service account, escrita em blocos ≤ ~2 MB por
requisição, cota de 60 escritas/min por usuário, limite de 10 M células, completar com vazio quando a aba
encolhe. A divergência de cronograma (o handover fala em 5 min; a DAG roda de hora em hora) está em [10](10-pendencias.md).

Fonte: memória `airbyte-sheets-planilha-gestao`; `handover (1).md`.
