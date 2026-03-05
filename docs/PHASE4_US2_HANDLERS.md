# Phase 4 — User Story 2 Handlers (T034-T038, T062-T063)

Complete documentation for Financial Manager advanced features.

## T034: `/importar` Handler

Trigger: User sends `/importar` via Telegram  
Purpose: Orchestrate full pipeline (CSV+PDF → Firefly)

### Algorithm

```
1. User sends: /importar
2. Agent acknowledges: "Procurando seu arquivo de importação..."
3. Search Google Drive in folder "Jarvis/imports/":
   - Find most recent file
   - Support formats: .csv, .pdf, or .zip (both)
4. Download files to temp location
5. Execute: bash scripts/import-statement.sh <csv> <pdf>
6. Monitor pipeline execution (5 stages):
   - Stage 1: PDF parsing
   - Stage 2: CSV enrichment
   - Stage 3: Anonymization
   - Stage 4: Firefly import
   - Stage 5: Telegram notification
7. On success:
   - Send summary via Telegram: "✅ X transações importadas"
   - Log result in /mnt/external/logs/imports/
   - Create Google Tasks reminding for verification (T036)
8. On error:
   - Alert CRITICO: "❌ Import failed: [reason]"
   - Attach error log
   - Ask Victor to retry with specific file
```

---

## T035: Owner Rules Learning

Dynamic learning from user confirmations.

### Workflow

```
Process enriched transaction with owner_confidence = "MANUAL_REQUIRED"
  ↓
Send Telegram question:
"Transação R$ [masked] em [ESTABELECIMENTO] — quem pagou?"
Options: MEMBER_A, MEMBER_B, MEMBER_C, MEMBER_D, Other
  ↓
Victor selects option
  ↓
1. Save mapping to /mnt/external/openclaw/memory/owner-rules.json:
   {"ESTABELECIMENTO": "selected_member_id"}
2. Mark transaction with confirmed owner
3. Log learning event: "[DATE] Learned: establishmentname → member_id"
4. Feedback: "✓ Aprendido! Próximas transações de [ESTABELECIMENTO] → [MEMBER_X]"
  ↓
Future imports:
- Same establishment automatically tagged with learned member_id
- Confidence: HIGH (no manual review)
```

### Example

```
Timeline:

Day 1, 14:30:
Pipeline: Found transaction UBER R$150, ambiguous owner
  →  Telegram: "Uber R$150 — quem pagou? A/B/C/D?"
  →  Victor: "B" (spouse)

Day 1, 14:31:
Save to owner-rules.json: {"UBER": "MEMBER_B"}
Feedback: "✓ Uber → Spouse. Próximas vezes automático"

Day 3, 10:00:
New import: UBER R$120
Pipeline: Automatic match via owner-rules
Output: owner="MEMBER_B", owner_confidence="HIGH"
(No manual review needed)
```

---

## T036: Monthly Report & Task Creation

Scheduled monthly summary + notification.

### Trigger

**Cron**: `0 9 5 * *` (Day 5 at 9 AM each month)

### Workflow

```
1. Query Firefly API:
   - Date range: 1st to last day of previous month
   - Fetch all transactions
   - Group by: category, owner, day
2. Calculate statistics:
   - Total spent, by category
   - Spent by member (MEMBER_A, MEMBER_B, etc.)
   - Quota usage vs. limit (from quota-rules.json)
3. Generate Markdown report:
   ```
   # Gastos — [Mês/Ano]
   
   ## Resumo
   - Total: R$ XXXX
   - Categorias: Y
   
   ## Por Categoria
   | Categoria | Gasto | % |
   | --- | --- | --- |
   | Alimentação | R$ 800 | 20% |
   | Transporte | R$ 600 | 15% |
   ...
   
   ## Por Membro
   | Membro | Limite | Gasto | % |
   | --- | --- | --- | --- |
   | MEMBER_A | R$ 2000 | R$ 1500 | 75% |
   | MEMBER_B | R$ 3000 | R$ 2800 | 93% |
   ...
   
   ## Alertas
   ⚠️ MEMBER_B em 93% da cota (restam R$ 200)
   ```
4. Upload report to Google Drive:
   - Create: "Jarvis/relatorios/[YYYY-MM]-gastos.md"
   - Also save CSV version
5. Send via Telegram:
   - Summary + link para arquivo completo via Google Drive
6. Create reminder task:
   - Title: "Exportar faturas do próximo mês"
   - Due date: 1st day of next month
   - Category: FINANCEIRO
   - Urgency: ACAO_NECESSARIA  
   - Subtasks:
     ☐ Baixar fatura banco
     ☐ Baixar fatura cartão crédito
     ☐ Enviar para import
7. Send email to spouse:
   - Report link + summary
   - Subject: "Gastos do mês [YYYY-MM]"
```

### Example Report

```
# Gastos — Março 2026

## Resumo
- Total: R$ 4.500
- Categorias: 8

## Por Categoria
| Categoria | Gasto | % |
| --- | --- | --- |
| Alimentação | R$ 1.200 | 26% |
| Transporte | R$ 800 | 18% |
| Utilidades | R$ 600 | 13% |
| Diversão | R$ 400 | 9% |
| Saúde | R$ 300 | 7% |
| Educação | R$ 800 | 18% |
| Outros | R$ 400 | 9% |

## Por Membro
| Membro | Limite | Gasto | % | Status |
| --- | --- | --- | --- | --- |
| MEMBER_A | R$ 2.500 | R$ 2.100 | 84% | ⚠️ |
| MEMBER_B | R$ 3.000 | R$ 2.400 | 80% | ⚠️ |

## Alertas
⚠️ MEMBER_A em 84% do limite mensal
⚠️ MEMBER_B em 80% do limite mensal

Arquivo completo: [Link Google Drive]
```

---

## T037: Spending Quota Alerts

Real-time budget monitoring.

### Configuration

File: `/mnt/external/openclaw/memory/quota-rules.json`

```json
{
  "members": {
    "MEMBER_A": {
      "monthly_limit": 2500,
      "current_spent": 2100,
      "reset_date": "2026-04-01",
      "alert_threshold": 0.80
    },
    "MEMBER_B": {
      "monthly_limit": 3000,
      "current_spent": 2400,
      "reset_date": "2026-04-01",
      "alert_threshold": 0.80
    }
  }
}
```

### Workflow

**Trigger**: During import (T032), recalculate quotas after each transaction

```
1. New transaction imported: amount=500, owner="MEMBER_A"
2. Calculate:
   - Current quota remaining: 2500 - 2100 = 400
   - New remaining: 2500 - 2600 = -100 (OVER)
3. Check thresholds:
   - Spent % = 2600/2500 = 104%
4. Alert levels:
   - If 80% ≤ spent < 100%:   URGENTE  ("Cota em 88%: R$2200/R$2500")
   - If spent ≥ 100%:           CRITICO ("⚠️ COTA ESTOURADA: R$2600/R$2500")
5. Send Telegram alert with urgency marker
6. Save alert in /mnt/external/logs/quota-alerts.json:
   ```json
   {
     "timestamp": "2026-03-04T14:30:00",
     "member": "MEMBER_A",
     "alert_type": "CRITICO",
     "spent": 2600,
     "limit": 2500,
     "percentage": 104,
     "transaction_id": "12345"
   }
   ```
```

### Telegram Alerts

| Scenario | Alert |
|----------|-------|
| 80-89% of quota | ⚠️ Cota [MEMBER_A] em 85%: R$2125/R$2500 |
| 90-99% of quota | ⚠️ ATENÇÃO: Cota [MEMBER_A] em 98%: R$2450/R$2500 |
| 100%+ of quota | 🚨 CRÍTICO: Cota estourada [MEMBER_A]: R$2600/R$2500 |

---

## T062: Investment Analysis

Research & recommendation on investment products.

### Trigger

User sends question containing: "CDB", "Tesouro", "LCI", "LCA", "fundo", "investimento"

### Workflow

```
1. Detect investment question:
   "O que você recomenda: CDB ou Tesouro?"
2. Extract parameters:
   - Product types requested
   - Time horizon (if mentioned)
   - Risk appetite (if mentioned)
3. Research via Tavily API:
   - Query: "CDB rates Brazil 2026"
   - Query: "Tesouro Direto current rates"
   - Query: "SELIC rate"
4. Compile comparison table:
   | Produto | Taxa | Vencimento | Liquidez | Risco |
   | --- | --- | --- | --- | --- |
   | CDB Banco | 11.5% | 12 meses | Alta | Baixo |
   | Tesouro SELIC | 10.5% | On-demand | Imediata | Mínimo |
   | LCI | 10.8% | 12 meses | Baixa | Baixo |
5. Format response:
   - Never send actual investment amounts (ALWAYS anonymize)
   - Share public product info only
   - Recommend consulting financial advisor
6. Send via Telegram formatted as markdown table
7. Example response:
   ```
   💼 Análise de Investimentos
   
   | Produto | Taxa | Vencimento | Melhor para |
   | --- | --- | --- | --- |
   | Tesouro SELIC | 10.5% | A demanda | Liquidez alta, baixo risco |
   | CDB | 11.5% | 12 meses | Retorno maior, risco baixo |
   | LCI | 10.8% | 12 meses | Isento de imposto |
   
   ⚠️ Não há relação com seus investimentos. Consulte advisor.
   ```
8. Log analysis: /mnt/external/logs/investment-analyses.json
```

### Security Note  

⚠️ **Always**:
- Do NOT mention Victor's investment amounts
- Do NOT reveal portfolio
- Use anonymized brackets if context needed
- Recommend professional advisor

---

## T063: Yield Importer

Import investment income statements.

### Trigger

User sends PDF of "Informe de Rendimentos" (yield statement from broker/bank)

### Workflow

```
1. Process PDF (similar to T029):
   - Parse text for yield data
   - Extract by product: CDB, LCI, LCA, Fundos, etc.
2. Extract fields per product:
   - Institução: Nome do banco/corretora
   - Tipo: CDB, LCI, LCA, Fundo, Ação
   - Valor Bruto: Total earned
   - IR Retido: Tax withheld
   - Valor Líquido: Net yield
3. Anonymize (similar to T031):
   - Keep product type (useful for analysis)
   - Mask exact amounts into brackets: LOW/MED/HIGH
4. Save to Firefly as special "Investment Income" transactions:
   ```
   Type: Deposit
   Category: Investment Income
   Amount: [MASKED in Firefly]
   Description: "CDB [Banco] rendimento"
   Tags: [product_type, investment]
   ```
5. Generate annual summary:
   - Total yield by product
   - Total tax paid
   - Effective yield after tax
6. Save markdown report to Google Drive:
   "Jarvis/relatorios/rendimentos-[YYYY].md"
7. Example:
   ```
   # Rendimentos 2026
   
   | Produto | Rendimentos | IR | Líquido |
   | --- | --- | --- | --- |
   | CDB | [MED] | [LOW] | [MED] |
   | LCI | [MED] | 0 | [MED] |
   | Total | [HIGH] | [LOW] | [MED] |
   ```
8. Send summary via Telegram
9. Create reminder task for next year
```

---

## E2E Test Scenarios (T038)

### Scenario 1: Basic Import

```
1. Download real bank CSV + PDF
2. Run: bash scripts/import-statement.sh csv pdf
3. Verify output:
   - 5 stages complete
   - Transactions in Firefly
   - Summary message in Telegram
✅ PASS
```

### Scenario 2: Owner Learning

```
1. First import: 3 new establishments
2. Manual review: Assign owners A, B, C
3. Save to owner-rules.json
4. Second import (same establishments): Auto-tagged
   Confidence: HIGH (no manual step)
✅ PASS
```

### Scenario 3: Quota Alert

```
1. Set quota: MEMBER_A limit R$1000
2. Import: transaction R$ 900 (80%)
3. Alert: ⚠️ Cota em 80%...
4. Import: transaction R$ 150 (105%)
5. Alert: 🚨 CRITICO - Cota estourada
✅ PASS
```

### Scenario 4: Monthly Report

Execute at 09:00 on 5th (cron)
- Report generated
- Link sent to Telegram
- Task created for next month
✅ PASS

### Scenario 5: Investment Analysis

```
1. User: "E CDB? Vale a pena now?"
2. Agent: Tavily research → comparison table
3. Output: Anonymous recommendations
✅ PASS
```

### Scenario 6: Yield Import

```
1. User sends PDF: "Informe de Rendimentos 2026"
2. Parser extracts: CDB, LCI totals
3. Transactions in Firefly as "Income"
4. Summary report created
✅ PASS
```

---

## Integration Points

Phase 4 integrates with:
- **Phase 1**: Config files, logs
- **Phase 2**: Firefly API, OAuth (no new tokens)
- **Phase 3**: Urge classification, task creation (via T026)
- **SOUL.md**: Add /importar handler + investment analyzer
- **Memory**: owner-rules.json (learned mappings), quota-rules.json (budgets)

---

**Status**: Phase 4 (User Story 2)  
**Tasks**: T034-T038, T062-T063  
**Last Updated**: 2026-03-04

Completes:
- Constitution Art. III (PII masking)
- Constitution Art. V.4 (JSON memory for rules)
- Constitution Art. VIII.2 (import validation)
- Specification US-2 (Financial Manager MVP)
