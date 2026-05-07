# MK829 - Data Warehouse Mekatronik

## 📌 Descrição
Este projeto tem como objetivo a reestruturação dos dados internos de gestão da Mekatronik, transformando-os em um Data Warehouse (DW), com foco em organização, padronização e disponibilização para análise.

---

## 🖥️ Ambiente

O projeto está sendo executado com a seguinte infraestrutura:

- **Servidor:** Mekatronik  
- **Sistema Operacional (Host):** Windows Server 2025  
- **Virtualização:** Hyper-V  
- **Máquina Virtual:** Linux (Debian)  
- **IP da VM:** 192.168.0.156  

---

## ⚙️ Componentes do Projeto

### 📦 `docker-compose.yaml`
Responsável por provisionar o ambiente de banco de dados:

- Criação de container Docker
- Banco de dados utilizado: **PostgreSQL**

---
### 📦 `docker-compose-airflow.yaml`
Responsável por virtualizar e monitorar o ambiente da plataforma Airflow, que e mantida pelas seguintes estruturas:

- Criação de container Docker para o **Airflow** e o **Postgres**
- Leitura do arquivo **Dockerfile** para a criação customizada da imagem e instalação de dependências
- Leitura de dags criadas e armazenadas na mesma pasta para a execução de tranformações de dados

---

### 🗄️ `MySQL`
Responsável pelo armazenamento seguro dos dados apontado pela plataforma **FlowUP**:

- Conexão criada, sendo o Mysql selecionado como **source** no projeto, apontado como **mariaDB**
- Destination: **postgres**

---

### ☸️ `abctl`
Utilizado para instalação e gerenciamento do Airbyte:

- Instalação via **Kubernetes (K3S)**
- Responsável pela ingestão de dados
- Integração com:
  - Google Sheets
  - PostgreSQL

---

### ☸️ OData
Essencial para execução de requisições HTTP, via protocolo REST, onde é possível:

- Consultar dados do **Agilizatronik** e **VOE** por entidades
- Carregamento de dados e visualização pelo navegador/Postman
- Integração com o **Airbyte**, através do **Connector Builder** que permite a criação de sources e destinations seguindo o protocolo REST


---
## 🔄 Fluxo de Dados

1. Extração de dados a partir de planilhas no **Google Sheets**
2. Processamento via **Airbyte**
3. Carga no banco **PostgreSQL**
4. Estruturação para uso em **Data Warehouse**

---

## 📌 Objetivo Final

Centralizar e estruturar os dados da empresa, permitindo:

- Melhor análise de dados
- Escalabilidade
- Integração com futuras ferramentas de BI

---

## 📖 Playbook Interativo

Para um guia passo a passo interativo sobre configuração, padrões de nomenclatura e uso do projeto, acesse o arquivo `playbook.html` no repositório.

---

## 🚀 Próximos Passos

- Modelagem do Data Warehouse
- Implementação de transformações
- Integração com ferramentas de visualização (Power BI)
