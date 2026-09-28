# Base de conhecimento — MK829 · Meka DW *(projeto encerrado)*

O que uma pessoa (ou um agente) precisa saber para entender o que foi o Data
Warehouse interno da Mekatronik, o que sobrou dele e o que ainda está em aberto
— sem reabrir o Flowup, o acervo do site e o histórico do repositório.

**Leia isto primeiro:** o MK829 **acabou em setembro/2026**. `readme.md` e
`playbook.html`, na raiz, estão escritos no presente e descrevem um projeto
vivo. **Eles estão desatualizados; esta KB é a versão corrigida.**

A ordem é do porquê ao como: **o que foi e quanto custou → o que rodava → o que
foi modelado → o que ainda serve → onde está cada coisa → o que ficou em aberto.**

| # | arquivo | responde |
|---|---|---|
| 00 | [visao-geral.md](00-visao-geral.md) | O que foi o MK829, quanto consumiu, quem tocou, por que parou e por que ele mexe na contabilidade da casa |
| 01 | [arquitetura-e-ambiente.md](01-arquitetura-e-ambiente.md) | Servidor, VM, PostgreSQL, Airbyte, os dois fluxos de sync e as armadilhas do `docker-compose` e do `abctl` |
| 02 | [modelo-de-dados.md](02-modelo-de-dados.md) | Camadas, padrão de nomenclatura, as 7 fontes previstas (quais chegaram a existir) e a única query real do projeto |
| 03 | [o-que-sobrou.md](03-o-que-sobrou.md) | O que dessas ~800 h ainda é reaproveitável, o que já foi reaproveitado, e o que **não** está nesta pasta |
| 04 | [indice-fontes.md](04-indice-fontes.md) | Inventário dos 10 arquivos, qual original tem o quê, fontes externas usadas e a linha do tempo do git |
| 05 | [pendencias.md](05-pendencias.md) | As divergências entre fontes, a pendência contábil de ~R$ 30 mil e a senha exposta no histórico |

## Como esta KB foi montada

**Lendo os 10 arquivos da pasta, um a um, integralmente.** Nada foi amostrado e
nada foi pulado. `playbook.html` (28,8 KB) foi parseado de HTML para texto e
lido inteiro; os metadados do `.git/` foram lidos como arquivos de texto
(`logs/HEAD`, `refs/*`, `config`, `FETCH_HEAD`, `index` via `strings`) — **nenhum
comando `git` foi executado**. O inventário completo, com o estado de cada
arquivo, está em [04-indice-fontes.md](04-indice-fontes.md).

Como a pasta sozinha não explica um projeto de ~800 horas, a KB cruzou com
fontes de fora, todas nominalmente listadas em
[04 §Fontes fora desta pasta](04-indice-fontes.md):

- **`~/flowup/`** — `feedback-mensal/frentes.json` (janela, encerramento,
  pendência contábil), `feedback-mensal/coleta.py`, `resultados-mes/*.json`
  (horas mês a mês), `flowup-skill/projetos_locais.json`, `kb/`.
- **`~/site-industrial-devops/`** — `DADOS-FLOWUP.md`, `kb/09-pendencias.md`,
  `kb/08-indice-fontes.md`, `06-cases/mekatronik-dw/`.

Onde duas fontes discordam, a KB registra as duas e diz que discordam. Ver
[05-pendencias.md](05-pendencias.md).

## O que esta KB **não** carrega

| fora daqui | por quê | onde está |
|---|---|---|
| A senha do PostgreSQL (`PG_PASSWORD`) | credencial | `.env` (fora do git) e — 🔴 problema conhecido — em texto plano no `docker-compose.yaml` e no histórico do repositório. Ver [05 §4](05-pendencias.md) |
| A Service Account Key JSON do Google | credencial | nunca esteve nesta pasta; vive na configuração do Airbyte, no `.airbyte/` da VM (ignorado pelo git) |
| URLs das planilhas de cronograma, alocação e gestão | apontam para dado interno da empresa | configuração das connections do Airbyte |
| Salários, folha e custo individual do Wollace | dado pessoal / financeiro sensível | Meka Strategy e a DRE do segmento. A KB registra apenas os **agregados de reclassificação** já apurados no `frentes.json`, porque sem eles a pendência contábil fica sem explicação |
| Documento de credenciais de acesso aos serviços do Meka-DW | credencial | Wollace disponibilizaria esse documento a Vanessa Barbalho (compromisso da ata de 22/07/2026; e-mail, thread 1871447900068149394, 22/07/2026). Onde ele está guardado não é registrado. Registrado na ingestão de e-mail de 24/09/2026 |
| Nomes e horas individuais de toda a equipe | fora do escopo deste projeto | Flowup (skill `flowup`) |

Horas por projeto, os três colaboradores que apontaram no MK829 e os valores de
reclassificação **estão** aqui: são dado da Mekatronik sobre um projeto da
própria Mekatronik, e sem eles metade das decisões pendentes fica sem contexto.
