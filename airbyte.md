# Documentação: Extração de Dados com Airbyte

> **Público-alvo:** Pessoas envolvidas ao MK829 - Meka-DW  
> **Última atualização:** Abril de 2026  
> **Ferramenta:** Airbyte (Open-source)

---

## Sumário

1. [Visão Geral](#visão-geral)
2. [Fluxo 1 — Google Sheets → PostgreSQL](#fluxo-1--google-sheets--postgresql)
   - [Configuração da Source (Google Sheets)](#configuração-da-source-google-sheets)
   - [Configuração da Destination (PostgreSQL)](#configuração-da-destination-postgresql)
   - [Configuração do Sync](#configuração-do-sync--fluxo-1)
3. [Fluxo 2 — PostgreSQL → Planilha de Gestão](#fluxo-2--postgresql--planilha-de-gestão)
   - [Configuração da Source (PostgreSQL)](#configuração-da-source-postgresql)
   - [Configuração da Destination (Google Sheets)](#configuração-da-destination-google-sheets)
   - [Configuração do Sync](#configuração-do-sync--fluxo-2)
4. [Boas Práticas](#boas-práticas)
5. [Troubleshooting Rápido](#troubleshooting-rápido)

---

## Visão Geral

Este documento descreve os dois fluxos de extração e carga de dados configurados no Airbyte:

```
[Google Sheets] ──────────────▶ [Airbyte] ──────────────▶ [PostgreSQL]
  Cronogramas                Full Refresh - Overwrite        Banco de dados

[PostgreSQL]   ──────────────▶ [Airbyte] ──────────────▶ [Google Sheets]
  Banco de dados              A cada 12 horas             Planilha de Gestão
```

---

## Fluxo 1 — Google Sheets → PostgreSQL

Este fluxo extrai dados de cronogramas mantidos em planilhas do Google Sheets e os carrega no banco de dados PostgreSQL.

### Configuração da Source (Google Sheets)

1. No menu lateral, acesse **Sources** → clique em **+ New Source**.
2. Selecione o conector **Google Sheets**.
3. Preencha as configurações:

   | Campo                | Valor / Descrição                                             |
   |----------------------|---------------------------------------------------------------|
   | **Name**             | `google_sheets_MKXXX`                                        |
   | **Authentication**   | Service Account Key (arquivo .JSON gerado após criação)      |
   | **Spreadsheet Link** | URL completa da planilha de cronogramas                      |
   | **Row Batch Size**   | `200` (padrão — ajustar conforme volume de dados)            |

4. Certifique-se de que a conta de serviço tem permissão de **leitura ou edição** na planilha, compartilhando com o e-mail.
5. Clique em **Test and Save** para validar a conexão.


---

### Configuração da Destination (PostgreSQL)

1. Acesse **Destinations** → clique em **+ New Destination**.
2. Selecione o conector **PostgreSQL**.
3. Preencha as configurações:

   | Campo        | Valor / Descrição                                          |
   |--------------|------------------------------------------------------------|
   | **Name**     | `postgres_mkdw`                                            |
   | **Host**     | Meka-dw                                                    |
   | **Port**     | `5432`                                                     |
   | **Database** | postgres                                                   |
   | **Schema**   | Schema de destino (ex: `raw_airbyte`)                      |
   | **Username** | Usuário com permissão de escrita no schema                 |
   | **Password** | Senha do usuário (determinado no container do postgres)    |
   | **SSL Mode** | `require` (recomendado para produção)                      |

4. Clique em **Test and Save** para validar.


---

### Configuração do Sync — Fluxo 1

1. Acesse **Connections** → **+ New Connection**.
2. Selecione a source `google_sheets_MKXXX` e a destination `postgres_mkdw`.
3. Configure conforme abaixo:

   | Configuração    | Valor                                                                          |
   |-----------------|--------------------------------------------------------------------------------|
   | **Sync Mode**   | Full Refresh — Overwrite                                                       |
   | **Agendamento** | Conforme necessidade da equipe (foi determinado como padrão "a cada 12 horas") |

4. Clique em **Set up connection**.

**Sobre o modo Full Refresh — Overwrite:**  
A cada execução, todos os dados existentes na tabela de destino são apagados e recarregados integralmente a partir da planilha. Isso garante que o PostgreSQL sempre reflita o estado atual dos cronogramas, sem acúmulo de registros antigos já apagados ou alterados.

> **⚠️ Atenção:** Como os dados são sobrescritos a cada sync, será mantida a versão atualizada de cada planilha conectada ao postgres.

---

## Fluxo 2 — PostgreSQL → Planilha de Gestão

Este fluxo exporta dados do PostgreSQL para uma planilha de gestão no Google Sheets, atualizando-a automaticamente a cada 12 horas (padrão alterável).

### Configuração da Source (PostgreSQL)

1. Acesse **Sources** → clique em **+ New Source**.
2. Selecione o conector **PostgreSQL**.
3. Preencha as configurações:

   | Campo                  | Valor / Descrição                                           |
   |------------------------|-------------------------------------------------------------|
   | **Name**               | `postgres_mkdw`                                            |
   | **Host**               | Meka-dw                                                    |
   | **Port**               | `5432`                                                     |
   | **Database**           | postgres                                                   |
   | **Schema**             | Schema contendo as tabelas a serem exportadas              |
   | **Username**           | Usuário com permissão de **leitura ou edição** no schema  |
   | **Password**           | Senha do usuário (inserido no conteiner do postgres)       |
   | **SSL Mode**           | `require` (recomendado)                                    |

4. Clique em **Test and Save**.

> **⚠️ Atenção:** Utilize sempre um usuário com permissão **somente leitura** na source para evitar qualquer risco de alteração nos dados de origem.

---

### Configuração da Destination (Google Sheets)

1. Acesse **Destinations** → clique em **+ New Destination**.
2. Selecione o conector **Google Sheets**.
3. Preencha as configurações:

   | Campo                | Valor / Descrição                                        |
   |----------------------|----------------------------------------------------------|
   | **Name**             | `PLANILHA_GESTÃO`                                       |
   | **Authentication**   | Service Account Key (JSON)                              |
   | **Spreadsheet Link** | URL completa da planilha de gestão de destino           |

4. Certifique-se de que a conta de serviço tem permissão de **Editor** na planilha de gestão.
5. Clique em **Test and Save**.

> **💡 Dica:** Cada stream (tabela) do PostgreSQL será carregado em uma aba separada dentro da planilha. Nomeie as abas de forma consistente com os nomes das tabelas de origem.

---

### Configuração do Sync — Fluxo 2

1. Acesse **Connections** → **+ New Connection**.
2. Selecione a source `postgres_mkdw` e a destination `PLANILHA_GESTÃO`.
3. Configure conforme abaixo:

   | Configuração    | Valor                    |
   |-----------------|--------------------------|
   | **Sync Mode**   | Full Refresh — Overwrite |
   | **Agendamento** | A cada 12 horas          |

4. Clique em **Set up connection**.

**Sobre o agendamento de 12 horas:**  
O Airbyte executará o sync automaticamente duas vezes ao dia, mantendo a planilha de gestão sempre atualizada com os dados mais recentes do PostgreSQL. As execuções podem ser acompanhadas em **Connections → Sync History**.

> **💡 Dica:** Se precisar de uma atualização fora do ciclo automático, acesse a connection e clique em **Sync Now** para disparar uma execução manual imediata.

---

## Boas Práticas

- **Nomeie conexões de forma descritiva:** Use o padrão `[source]_para_[destination]` (ex: `google_sheets_cronogramas_para_postgres`).
- **Monitore as execuções regularmente:** Acesse **Connections → Sync History** para verificar status, volumes e tempo de execução.
- **Gerencie credenciais com segurança:** Nunca salve senhas ou chaves JSON em texto plano; use variáveis de ambiente ou um gerenciador de segredos.
- **Evite editar a planilha de gestão manualmente:** Como ela é sobrescrita a cada sync, alterações manuais serão perdidas na próxima execução.
- **Escalone os horários:** Distribua os horários dos syncs para não sobrecarregar o banco de dados simultaneamente.

---

## Troubleshooting Rápido

| Sintoma                                         | Possível Causa                                       | Ação Recomendada                                               |
|-------------------------------------------------|------------------------------------------------------|----------------------------------------------------------------|
| Teste de conexão falha no Google Sheets         | Planilha não compartilhada com a Service Account     | Compartilhe a planilha com permissão de Leitor/Editor          |
| Dados da planilha não aparecem no PostgreSQL    | Aba da planilha com nome diferente do esperado       | Verifique os streams selecionados na configuração do sync      |
| Planilha de gestão não é atualizada             | Sync falhando silenciosamente                        | Verifique o Sync History e os logs de erro da connection       |
| Dados duplicados na planilha de gestão          | Modo de sync configurado incorretamente              | Confirme se o modo está como Full Refresh — Overwrite          |
| Sync do Fluxo 2 demora muito para concluir      | Volume elevado ou tabelas sem filtro de colunas      | Reduza os streams ou remova colunas desnecessárias             |
| Erro de autenticação na Source PostgreSQL       | Usuário sem permissão ou senha expirada              | Atualize as credenciais na configuração da source              |

---

*Documentação gerada para uso interno. Em caso de dúvidas, consulte a [documentação oficial do Airbyte](https://docs.airbyte.com) ou o time de Engenharia de Dados.*
