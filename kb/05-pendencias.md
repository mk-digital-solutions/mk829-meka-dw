# 05 · Pendências, divergências e o que precisa de decisão

Projeto encerrado ainda tem cauda. Estas são as pontas soltas — divergências
entre fontes ficam registradas com **as duas versões**, não resolvidas no chute.

---

## 1. 🟡 Quantas horas o MK829 consumiu? Três números diferentes

| valor | fonte | o que exatamente mede |
|---|---|---|
| **753 h** | apuração da sessão de set/2026 (Flowup, ano fiscal) | horas no ano fiscal — janela e recorte não registrados aqui |
| **784,7 h** | `flowup/feedback-mensal/frentes.json` → `wollace_meka_dw.base` | **só as horas do Wollace**, jan–ago/2026 (13,3% das 5.916,4 h do segmento) |
| **812 h / 2 pessoas** | `site-industrial-devops/.../DADOS-FLOWUP.md`, consulta de 03/09/2026 | portfólio por projeto |
| **816,91 h / 3 pessoas** | soma mês a mês de `flowup/resultados-mes/*.json`, mar–set/2026 | todo mundo, mês-calendário, incluindo os 10 h de set |

**São recortes diferentes, não necessariamente contradição** — 784,7 é só o
Wollace até agosto; 816,91 é todo mundo até setembro. Mas **753 não se explica
por nenhum dos recortes acima**, e 812 × 816,91 diverge em 5 h (a consulta do
site é de 03/09, antes de fechar setembro).

**Decisão do Hugo:** fixar qual número é o oficial antes de citá-lo em qualquer
peça externa. Todos são defensáveis; usar dois em documentos diferentes não é.

---

## 2. 🔴 A pendência contábil — a mais cara, e está aberta

Registrada em `flowup/feedback-mensal/frentes.json` →
`despesas.wollace_ate_agosto`:

- **O quê:** até o fim de agosto/2026 o custo do Wollace era **investimento da
  empresa (Meka DW)**, não custo do segmento DevOps.
- **Efeito duplo:** reclassificar tira **custo direto** do segmento **e** reduz a
  **base de folha**, que é a base do rateio. Os dois efeitos somam.
- **Magnitude estimada:** **R$ 30.000** — `status: "mecanismo confirmado,
  magnitude a apurar"`.
- **Identificável no sistema hoje: apenas R$ 8.262,55** — pessoal variável
  R$ 7.343,00 + pessoal fixo R$ 468,00 + informática R$ 451,55.
- **Efeito no rateio se a folha dele sair: R$ 7.607,00.**
- 🔴 **O bloqueio:** *"R$ 143.996 da folha do segmento (56% do total) está
  lançada SEM colaborador atribuído. O salário do Wollace está dentro desse
  bolo, então o sistema não consegue isolar o custo dele hoje."* **Atribuir esse
  bolo é o pré-requisito da análise.**

Um segundo bloco do mesmo arquivo (`wollace_meka_dw`) dá o cálculo por rateio de
horas, com **duas leituras**: **conservadora R$ 30.507,76** (só as horas no
MK829) e **cheia R$ 39.877,42** (todas as horas dele). Status: *"A CONFIRMAR se
o financeiro já retirou."*

**Ação:** confirmar com o financeiro. Enquanto os R$ 143.996 não tiverem
colaborador atribuído, o número exato não sai do sistema.

---

## 3. 🔴 ~800 horas, 58 KB de artefato — o descasamento

Este é o achado central desta KB, e ele precisa ser dito sem rodeio:

**Um desenvolvedor em dedicação praticamente integral de abril a agosto/2026
deixou, nesta pasta, 10 arquivos e 58 KB — dos quais 51 KB são documentação e
apenas 5,6 KB são código (uma única query SQL, não commitada).**

Não há nesta pasta: um único modelo `stg_`/`int_`/`mart_`/`dim_`/`fct_`, um
projeto dbt, um dump ou DDL do banco, um export de configuração do Airbyte, um
`.pbix` ou qualquer artefato de BI, um script de carga, um teste.

**Três hipóteses, nesta ordem de probabilidade:**

1. **O trabalho está no GitHub e nunca foi trazido para cá.** É a hipótese mais
   forte: `origin/main` está à frente desde 29/05, com último fetch em 23/07, e
   existe a branch remota **`chlorum-novos-modelos-dbt`** — cujo nome é
   literalmente "novos modelos dbt". **Verificar isto é a primeira coisa a
   fazer.** Repo: `github.com/mk-digital-solutions/mk829-meka-dw`.
2. **O trabalho está no ambiente, não no repositório** — configuração do Airbyte
   (que vive no `.airbyte/`, ignorado pelo git), objetos criados direto no
   Postgres da VM 192.168.0.168, planilhas do Google. Nesse caso, **desligar a VM
   apaga o projeto.**
3. **As horas foram majoritariamente de operação, aprendizado e configuração**,
   não de produção de artefato versionável.

**As três exigem a mesma ação:** olhar o remoto e olhar a VM **antes** de dar o
MK829 por documentado. Ver [03-o-que-sobrou.md](03-o-que-sobrou.md).

---

## 4. 🔴 Senha do PostgreSQL exposta no histórico do repositório

O `docker-compose.yaml` tem um conflito de merge não resolvido, e o lado `HEAD`
carrega o `POSTGRES_PASSWORD` **em texto plano**. O commit de 09/04/2026
("Added .env interaction with docker compose") trocou o literal por
`${PG_PASSWORD}`, mas **o literal continua no histórico do git** — e o
repositório está no GitHub.

**A senha não foi copiada para esta KB de propósito.** Ela está no arquivo e no
histórico.

**Ação:** se o banco `mkdw_db` ainda existir em qualquer lugar, **rotacionar a
senha**. Reescrever histórico não é necessário se a senha for trocada — e é o
caminho mais seguro. Decidir também se o repositório e o GitHub Pages devem
continuar publicados.

---

## 5. 🟡 Dois IPs para o mesmo banco

| IP | fonte |
|---|---|
| **192.168.0.168** | `readme.md` e `playbook.html` — "IP da VM" |
| **192.168.0.156** | cabeçalho de `queries/dataset_apontamentos_diario.sql` — *"Fonte: banco postgres @ 192.168.0.156"* |

O SQL é **duas semanas mais recente** que o readme (30/04 × 16/04). Duas
leituras possíveis, e nenhuma fonte decide entre elas: **(a)** a VM mudou de IP e
o readme ficou desatualizado; **(b)** são duas máquinas — a do DW e uma réplica
do Flowup. `192.168.0.156` não aparece em nenhum outro arquivo de nenhum projeto
do `~/`.

---

## 6. 🟡 O `docker-compose.yaml` está quebrado desde 15/04/2026

Marcadores de conflito no arquivo ⇒ **não é YAML válido** ⇒ `docker compose up`
falha. Ficou assim quase cinco meses sem ninguém corrigir — o que sugere que
**ninguém subiu o ambiente a partir deste clone depois de abril**.

Não corrigi o arquivo: a regra desta KB é não editar arquivo do projeto. Mas é
correção de um minuto, se o ambiente voltar a ser usado.

---

## 7. 🟡 `queries/` nunca foi versionado

`queries/dataset_apontamentos_diario.sql` não está no índice do git. Existe só
neste disco. **Se esta pasta for apagada, ele some.** É o artefato de código mais
avançado do projeto — vale um commit, ou pelo menos uma cópia em lugar seguro.

---

## 8. 🟡 O readme e o playbook estão escritos no presente

Ambos dizem "o projeto **está sendo executado**" e listam "**Próximos Passos**"
que nunca aconteceram (APIs, conector MySQL do Flowup, modelagem, dbt, Power BI).
Lidos hoje, **descrevem um projeto vivo que não existe mais** — e o `readme.md` e
o `playbook.html` foram copiados nesse estado para o acervo do site
(`site-industrial-devops/06-cases/mekatronik-dw/`), de onde podem sair para um
deck comercial.

**Decisão:** ou marcar os originais como encerrados, ou garantir que quem usar o
case saiba disso. Este `CLAUDE.md`/`kb` é a rede de segurança enquanto isso não
for feito.

---

## 9. 🟢 Sem pendência: o Meka Strategy nunca foi fonte prevista

Registro explícito para evitar retrabalho: **nenhuma fonte desta pasta menciona
o Meka Strategy** como origem de dados do DW. O financeiro entraria pelo Flowup
(`flowup_despesas`). Se alguém propuser "o DW já puxava do Meka Strategy", está
enganado.

---

## 10. 🔴 dbt, Power BI e entregas: a KB diz "nunca aconteceram", as atas dizem outra coisa

*Aberta na ingestão de e-mail de 24/09/2026.*

| versão | o que diz | fonte |
|---|---|---|
| **KB** | O readme e o playbook listam dbt, modelagem e Power BI como "Próximos Passos" que **nunca aconteceram** (§8 acima); "só o `raw_airbyte` tem evidência de ter existido" ([02](02-modelo-de-dados.md)); nenhuma fonte diz que houve dashboard entregue ou consumo; "o que existe documentado é a infraestrutura, o padrão e o desenho" ([00](00-visao-geral.md)) | `readme.md`, `playbook.html`, `padrao_nomenclaturas.md` e o inventário da pasta local ([04](04-indice-fontes.md)) |
| **E-mail** | 15/04: validação da **Entrega 01**, com Power BI Gateway instalado no servidor para acessar o PostgreSQL. 28/05: validação da **Entrega 3**, "implementação de Airflow e dbt permite automação e organização de fluxos", OpenMetadata centraliza a documentação, e **decisão** de migrar as transformações pesadas do Power Query para modelos dbt no PostgreSQL; o grupo desenvolveria o modelo de transformações do **dashboard de faturamento** para a entrega seguinte. 22/07 e 23/07: portal lançado ([03](03-o-que-sobrou.md)) | e-mail, thread 1862559850459943952, 15/04/2026; thread 1866459286671535771, 28/05/2026; threads 1871447900068149394 e 1871536062366461551, 22 e 23/07/2026 |

Há ainda convites de agenda para Entrega 1 a 4 e para "Produto de dados 02" e
"Pré-Validação Produto de dados 02 e 03", sem conteúdo além da data (e-mail,
lote de 2026-04 a 2026-08). E um convite do Wollace Dantas ao Hugo e à Vanessa
Barbalho para **"Validação - Produto de dados 06 - MK829"**, quinta, **08/10/2026,
14h às 15h** (e-mail, thread 1878333610353397433, 06/10/2026): há validação de
entrega marcada depois do "encerrado em set/26" do índice global.

**Não resolvido aqui.** As atas são geradas automaticamente e registram decisão e
intenção, não artefato: nenhuma diz que o dashboard de faturamento foi entregue.
*Inferência (das datas):* o fetch que trouxe a branch `chlorum-novos-modelos-dbt`
é de 29/05/2026, um dia depois da ata que decide migrar para dbt, o que reforça a
hipótese 1 do §3. **Ação:** a mesma do §3, olhar o GitHub (e o portal, se ainda
estiver de pé) antes de dizer o que o MK829 entregou.

---

## 11. 🟡 Quando o Meka DW começou, e com quem

*Aberta na ingestão de e-mail de 24/09/2026.*

| versão | o que diz | fonte |
|---|---|---|
| **KB** | Janela **mar/2026 → set/2026**; um executor, Wollace (~95% das horas), com Hugo como arquiteto; primeiro commit em 09/04/2026 | `flowup/feedback-mensal/frentes.json`, `flowup/resultados-mes/*.json`, metadado do `.git/` ([00](00-visao-geral.md), [04](04-indice-fontes.md)) |
| **E-mail** | Em **03/02/2026**, na "Reunião Datawarehouse", Hugo apontou as limitações do CronSQL em controle e monitoramento de execuções e apresentou Airflow, OpenMetadata e dbt (grafado "DB3" no resumo automático); **José Almeida apresentou a infraestrutura já construída** da plataforma de Data Warehousing, e os itens de ação eram de capacitação de Lucas Tejo Sena em dbt e Airflow | e-mail, thread 1856126130398270797, 03/02/2026 (resumo automático do read.ai) |

**Ressalva sobre a atribuição:** a ata de 03/02 não cita "MK829" nem "Meka-DW";
foi ligada a este projeto pelo roteamento da ingestão. O que a sustenta é José
Almeida reaparecer como convidado da reunião sobre a licença do Windows Server do
Meka-DW, em 18/09/2026 (e-mail, thread 1876667899637299617). Duas leituras, e
nenhuma fonte decide: **(a)** o DW teve uma fase anterior a março, não apontada
no MK829 do Flowup; **(b)** a reunião de 03/02 era sobre outra plataforma de DW.
**Ação:** Hugo confirma de memória; se (a), o [00](00-visao-geral.md) ganha a
fase anterior e o §1 ganha mais um recorte de horas.
