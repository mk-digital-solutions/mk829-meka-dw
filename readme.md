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
- **IP da VM:** 192.168.0.168  

---

## ⚙️ Componentes do Projeto

### 📦 `docker-compose.yaml`
Responsável por provisionar o ambiente de banco de dados:

- Criação de container Docker
- Banco de dados utilizado: **PostgreSQL**

---

### ☸️ `abctl`
Utilizado para instalação e gerenciamento do Airbyte:

- Instalação via **Kubernetes (K3S)**
- Responsável pela ingestão de dados
- Integração com:
  - Google Sheets
  - PostgreSQL

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

<<<<<<< HEAD
## 🚀 Próximos Passos
=======
## � Playbook Interativo

Para um guia passo a passo interativo sobre a configuração e uso do projeto, acesse o [Playbook MK829 - Meka-DW](https://[username].github.io/mk829-meka-dw/) (substitua [username] pelo seu nome de usuário no GitHub).

---

## �🚀 Próximos Passos
>>>>>>> 848108c1b9aa329c43a924f0a52dc487ae35c060

- Importação de APIs para extração dos dados das diversas plataformas utilizadas
- Uso de conector MySQL como Source no Airbyte
- Modelagem do Data Warehouse
- Implementação de transformações
- Integração com ferramentas de visualização (Power BI)
