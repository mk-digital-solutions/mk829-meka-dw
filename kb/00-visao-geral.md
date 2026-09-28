# 00 · Visão geral — o que foi o MK829

## Em um parágrafo

O **MK829 — Meka DW** foi o projeto de **Data Warehouse interno da Mekatronik**:
reestruturar os dados de gestão da própria casa (cronogramas, alocação de
equipe, apontamento de horas, chamados, CRM) num PostgreSQL organizado em
camadas, alimentado por **Airbyte**, para consumo em BI. Não era projeto de
cliente e **nunca gerou receita** — era investimento da empresa, com janela
definida até setembro/2026.

**Está encerrado.** Escreva sobre ele no passado. Esta pasta é o resíduo local
do projeto, não um ambiente vivo.

## Números — o tamanho real do investimento

| | |
|---|---|
| Horas no ano fiscal | **~753 a 817 h**, conforme a fonte (ver [05-pendencias §1](05-pendencias.md)) — a 3ª maior alocação da carteira, atrás de MK852 e MK830 |
| Pessoas | **3 apontaram**, mas na prática **1 executor**: Wollace Cavalcante Dantas (~95% das horas). Hugo Fonsêca entrou como arquiteto em blocos de 0,5–8 h/mês; José Roberto Gentile, 2,5 h em mai/jun |
| Receita | **R$ 0,00** — `receita_mes: 0.0`, `teto_restante: 0.0` (`flowup/feedback-mensal/frentes.json`) |
| Janela | mar/2026 → **set/2026**, encerrado **no prazo** |
| Destino da equipe | Wollace realocado em **01/09/2026** para a frente **M. Dias Branco SAP APM (MK903)**, sem um dia de ociosidade |

### Horas por mês (Flowup, apuração por mês-calendário)

Extraído de `~/flowup/resultados-mes/resultado-devops-mes-2026-*.json`,
campo `equipe[].projetos_mk.MK829`:

| mês | total | quem |
|---|---:|---|
| 03/2026 | 41,75 | Wollace 34,0 · Hugo 7,75 |
| 04/2026 | 154,83 | Wollace 149,33 · Hugo 5,5 |
| 05/2026 | 141,50 | Wollace 138,5 · J. Roberto 2,5 · Hugo 0,5 |
| 06/2026 | 148,50 | Wollace 146,0 · J. Roberto 2,5 |
| 07/2026 | 152,50 | Wollace 150,5 · Hugo 2,0 |
| 08/2026 | 167,83 | Wollace 166,33 · Hugo 1,5 |
| 09/2026 | 10,00 | Wollace 10,0 — **rampa de saída** |
| **soma** | **816,91** | |

A curva conta a história sozinha: **um desenvolvedor em dedicação praticamente
integral de abril a agosto, e desligamento abrupto em setembro.**

## Por que este projeto importa para a contabilidade

O MK829 é o **único** centro de custo em `MK_INTERNOS` no Flowup
(`flowup/feedback-mensal/coleta.py:51` → `MK_INTERNOS = {"MK829"}`). Isso tem
duas consequências práticas que aparecem em toda análise de resultado:

1. **É excluído da "disponibilidade para projetos faturável" (D.proj
   faturável).** Hora em MK829 é hora em MK, mas não é hora vendável
   (`flowup/kb/03-indicadores-e-ciclos.md`, `flowup/feedback-mensal/README.md`).
2. **O custo do Wollace até agosto/2026 era investimento, não custo do
   segmento.** Reclassificá-lo tira custo direto **e** reduz a base de folha,
   que é a base do rateio — os dois efeitos somam. Ver
   [05-pendencias §2](05-pendencias.md), a pendência aberta mais cara desta pasta.

## Por que parou

**Não foi cancelamento por fracasso — foi fim de janela.** A base registrada no
Flowup é explícita:

> "investimento interno da empresa com janela definida ATE SETEMBRO/2026;
> encerrado no prazo. Wollace realocado em 01/09 na frente M. Dias Branco SAP APM"
> — `flowup/feedback-mensal/frentes.json`, bloco `MK829`

**Nenhuma fonte desta pasta ou das fontes cruzadas diz que o DW entrou em
produção, que houve dashboard entregue, ou que alguém consumiu os dados.** O que
existe documentado é a infraestrutura, o padrão e o desenho — não o resultado.
Ver [03-o-que-sobrou.md](03-o-que-sobrou.md) e a advertência do
[05-pendencias §3](05-pendencias.md) sobre o descasamento entre horas e artefato.

## O escopo, como estava desenhado

Fluxo alvo (readme.md, playbook.html):

```
Google Sheets ─┐
Flowup (MySQL) ─┤
Agilizatronik  ─┼─► Airbyte ─► PostgreSQL raw_airbyte ─► stg_ ─► int_ ─► mart_ ─► Power BI
MMGP           ─┤
VOE            ─┘
```

Do que foi desenhado, **só o primeiro trecho chegou a existir de fato** nesta
pasta: Google Sheets → Airbyte → PostgreSQL. Flowup, Agilizatronik, MMGP e VOE
aparecem como *"próximos passos"* em ambos os documentos — nunca como algo
configurado. Ver [02-modelo-de-dados.md §Fontes](02-modelo-de-dados.md).

### O que as atas de julho/2026 acrescentam ao escopo (ingestão de e-mail, 24/09/2026)

Na apresentação do portal, em **22/07/2026** (e-mail, thread
1871447900068149394, 22/07/2026, ata gerada automaticamente):

- **DRE e planilhas de gestão entraram na linha principal.** Livia Furtado e
  Vanessa Barbalho incluiriam a elaboração da DRE (Demonstração do Resultado do
  Exercício) na linha de trabalho principal do projeto e estruturariam as
  diversas planilhas do setor de gestão numa base única. A ata não diz de onde
  viriam os dados da DRE, e nenhuma fonte registra que isso tenha sido feito
  antes do encerramento em setembro.
- **Plataforma Pulse postergada.** A implementação da plataforma Pulse (a ata
  não diz o que ela é nem de quem) foi adiada para priorizar a consolidação dos
  dados; a adoção futura ficou condicionada a validação de segurança e
  conformidade técnica.

As atas também mostram uma trilha de entregas e uma arquitetura (Airflow, dbt,
OpenMetadata, portal) que esta KB, montada só com a pasta local, não enxergava.
Isso diverge do que está escrito acima e no [05 §8](05-pendencias.md); as duas
versões estão no [05 §10 e §11](05-pendencias.md).
