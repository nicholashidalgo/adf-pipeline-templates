<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/nh-logo-dark.svg" />
    <source media="(prefers-color-scheme: light)" srcset="assets/nh-logo-light.svg" />
    <img alt="NH" src="assets/nh-logo-dark.svg" width="80" />
  </picture>
</p>

<h1 align="center">ADF Pipeline Templates</h1>

<p align="center"><b>Production-ready Azure Data Factory pipeline framework with incremental loading, orchestration, and data quality validation</b></p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge" alt="License"></a>&nbsp;
  <img src="https://img.shields.io/badge/Pipelines-3-3b82f6?style=for-the-badge" alt="Pipelines">&nbsp;
  <img src="https://img.shields.io/badge/Templates-10-8b5cf6?style=for-the-badge" alt="Templates">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Azure_Data_Factory-0078D4?style=flat&logo=microsoftazure&logoColor=white" alt="ADF" />
  <img src="https://img.shields.io/badge/Snowflake-29B5E8?style=flat&logo=snowflake&logoColor=white" alt="Snowflake" />
  <img src="https://img.shields.io/badge/Azure_SQL-CC2927?style=flat&logo=microsoftsqlserver&logoColor=white" alt="Azure SQL" />
  <img src="https://img.shields.io/badge/ADLS_Gen2-0078D4?style=flat&logo=microsoftazure&logoColor=white" alt="ADLS" />
  <img src="https://img.shields.io/badge/Key_Vault-0078D4?style=flat&logo=microsoftazure&logoColor=white" alt="Key Vault" />
</p>

---

### What this does

<table>
<tr>
<td>

Reusable Azure Data Factory pipeline templates for production ETL/ELT operations. Implements a **watermark-based incremental load** pattern, a **metadata-driven orchestrator** with parallel execution and error handling, and a **data quality validation** framework with configurable rules.

Built for managed services environments where **SLA compliance**, **operational monitoring**, and **incident-ready logging** are required. All credentials stored in Azure Key Vault. All pipeline runs logged to a control database.

**3** pipeline templates &middot; **4** linked service configs &middot; **5** control tables &middot; **7** DQ rule examples

</td>
</tr>
</table>

---

### Pipeline architecture

| Pipeline | Purpose | Pattern |
|---|---|---|
| <img src="https://img.shields.io/badge/pl__incremental__load-0078D4?style=flat-square" /> | Source to Snowflake staging | Watermark-based CDC with ADLS staging |
| <img src="https://img.shields.io/badge/pl__orchestrator__daily-8b5cf6?style=flat-square" /> | Daily batch orchestration | Metadata-driven ForEach with parallel execution (batch=4) |
| <img src="https://img.shields.io/badge/pl__data__quality__checks-22c55e?style=flat-square" /> | Post-load validation | Rule-based DQ with row count, null, freshness, duplicate, range checks |

---

### Project structure

```
pipelines/
  pl_incremental_load.json        # Watermark-based incremental copy
  pl_orchestrator_daily.json      # Metadata-driven batch orchestrator
  pl_data_quality_checks.json     # Post-load DQ validation
linkedServices/
  linked_services.json            # Azure SQL, Snowflake, ADLS, Key Vault
triggers/
  tr_daily_0600_utc.json          # Daily schedule trigger
scripts/
  control_tables.sql              # Control schema DDL + stored procedures
  seed_dq_rules.sql               # Sample DQ rules
```

---

### Key design decisions

**Watermark pattern over full loads** reduces data volume, pipeline duration, and Snowflake compute cost. The control.watermark_table tracks high-water marks per source table.

**Metadata-driven orchestration** means adding a new source table requires one INSERT into control.pipeline_config, not a new pipeline. The ForEach runs up to 4 pipelines in parallel.

**Data quality as a pipeline stage** runs after every load. Rules are stored in control.dq_rules and results logged to control.dq_results. Failed checks are queryable for SLA reporting and incident triage.

**Key Vault for all credentials** means no connection strings in pipeline JSON. Linked services reference secrets by name.

**Failure alerting** via webhook (Slack/Teams) fires on orchestrator failure with pipeline name, run ID, and timestamp.

---

### Control tables

| Table | Purpose |
|---|---|
| `control.watermark_table` | Tracks last loaded watermark per source table |
| `control.pipeline_config` | Metadata-driven list of pipelines to execute |
| `control.pipeline_run_log` | Audit log of every pipeline execution |
| `control.dq_rules` | Configurable data quality check definitions |
| `control.dq_results` | Historical DQ check results for SLA reporting |

---

### Setup

1. Deploy control tables: run `scripts/control_tables.sql` against your Azure SQL control database
2. Seed DQ rules: run `scripts/seed_dq_rules.sql`
3. Import pipeline JSON files into ADF Studio
4. Configure linked services with your Key Vault secret names
5. Enable the daily trigger

---

<p align="center">
  <a href="https://linkedin.com/in/nicholashidalgo"><img src="https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn"></a>&nbsp;
  <a href="https://nicholashidalgo.com"><img src="https://img.shields.io/badge/Website-000000?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Website"></a>&nbsp;
  <a href="mailto:analytics@nicholashidalgo.com"><img src="https://img.shields.io/badge/Email-D14836?style=for-the-badge&logo=gmail&logoColor=white" alt="Email"></a>
</p>
