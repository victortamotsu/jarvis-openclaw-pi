# Phase 4 — Financial Manager E2E Validation (T038)

**Status**: Validation Framework Ready  
**Effective Date**: 2026-03-04  
**Test Scope**: All Phase 4 handlers (T034-T037, T062-T063)

---

## Scenario 1: Basic CSV/PDF Import → Firefly

**Objective**: Verify end-to-end pipeline from local files to Firefly III

**Prerequisites**:
- ✅ docker-compose running (firefly-iii, openclaw, mcporter)
- ✅ scripts/import-statement.sh executable
- ✅ .env configured with FIREFLY_TOKEN
- ✅ Sample files: test-statement.csv + test-statement.pdf

**Steps**:

1. Prepare test files:
   ```bash
   # Create minimal test CSV
   cat > /tmp/test-statement.csv << EOF
   data,estabelecimento,valor,categoria
   2026-02-15,CARREFOUR,150.50,alimentacao
   2026-02-16,UBER,45.00,transporte
   2026-02-17,AMAZON,200.00,outros
   EOF
   
   # Create minimal test PDF (or use real export)
   # Place in ~/Jarvis/imports/ for /importar handler
   ```

2. Execute import manually:
   ```bash
   bash scripts/import-statement.sh /tmp/test-statement.csv /tmp/test-statement.pdf
   ```

3. Verify each stage:
   - **Stage 1** (PDF parsing): Check logs for transaction extraction
   - **Stage 2** (CSV enrichment): Verify merge completed
   - **Stage 3** (Anonymization): Confirm MEMBER_X masking applied
   - **Stage 4** (Firefly import): Query API for new transactions
   - **Stage 5** (Telegram): Receive summary message

4. Validate in Firefly:
   ```bash
   curl -s http://localhost:8080/api/v1/transactions \
     -H "Authorization: Bearer $FIREFLY_TOKEN" \
     | grep -c "2026-02"
   # Expected: 3+ results from test CSV
   ```

**Expected Outcome**: ✅ PASS
- 3 transactions in Firefly with correct amounts+categories
- Telegram message received: "✅ 3 transações importadas"
- Log file created: `/mnt/external/logs/imports/2026-02-*.log`
- quota-rules.json updated with new spending

**Failure Handling**:
- If PDF parsing fails: Check if pdf-reader-mcp installed
- If Firefly insert fails: Verify FIREFLY_TOKEN valid + API accessible
- If Telegram fails: Check TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID

---

## Scenario 2: Owner Rules Learning

**Objective**: Verify dynamic learning and persistence in owner-rules.json

**Prerequisites**:
- ✅ Scenario 1 passed
- ✅ owner-rules.json exists: `/mnt/external/openclaw/memory/owner-rules.json`
- ✅ Telegram bot configured

**Steps**:

1. Trigger ambiguous transaction:
   ```bash
   # Manually trigger import with ambiguous establishment
   echo "2026-02-20,RESTAURANTE XYZ,120.00,alimentacao" >> /tmp/test-statement.csv
   bash scripts/import-statement.sh /tmp/test-statement.csv /tmp/test-statement.pdf
   ```

2. Monitor Telegram:
   - Should receive: "🤔 Restaurante XYZ R$120 — quem pagou? A/B/C/D?"
   - Victor selects: "A" (self)

3. Verify learning:
   ```bash
   cat /mnt/external/openclaw/memory/owner-rules.json
   # Expected: {"RESTAURANTE": "MEMBER_A"}
   ```

4. Re-import with same establishment:
   ```bash
   echo "2026-02-25,RESTAURANTE XYZ,85.00,alimentacao" >> /tmp/test-statement.csv
   bash scripts/import-statement.sh /tmp/test-statement.csv /tmp/test-statement.pdf
   ```

5. Verify no question asked:
   - Telegram should show: "✓ Restaurante XYZ → Victor (automático)"
   - Transaction auto-tagged MEMBER_A

**Expected Outcome**: ✅ PASS
- First import: Owner question in Telegram
- owner-rules.json updated with {"RESTAURANTE": "MEMBER_A"}
- Second import: Automatic (no question)
- Both transactions have owner_id = MEMBER_A

---

## Scenario 3: Quota Alerts (80% and 100%+)

**Objective**: Verify quota monitoring and alerting at thresholds

**Prerequisites**:
- ✅ Scenario 1 passed
- ✅ quota-rules.json configured with limits
- ✅ MEMBER_A limit: R$500 (for testing)

**Steps**:

1. Initialize test quota:
   ```bash
   cat > /mnt/external/openclaw/memory/quota-rules.json << 'EOF'
   {
     "members": {
       "MEMBER_A": {
         "monthly_limit": 500,
         "current_spent": 0,
         "reset_date": "2026-04-01",
         "alert_threshold": 0.80
       }
     }
   }
   EOF
   ```

2. Import transaction R$400 (80%):
   ```bash
   echo "2026-02-28,CARREFOUR,400.00,alimentacao" >> /tmp/test-statement.csv
   bash scripts/import-statement.sh /tmp/test-statement.csv /tmp/test-statement.pdf
   ```

3. Verify 80% alert:
   - Telegram: "⚠️ Cota [MEMBER_A] em 80%: R$400/R$500"
   - Urgency: URGENTE
   - Log: `/mnt/external/logs/quota-alerts.json` entry recorded

4. Import second transaction R$150 (100%+):
   ```bash
   echo "2026-03-01,UBER,150.00,transporte" >> /tmp/test-statement.csv
   bash scripts/import-statement.sh /tmp/test-statement.csv /tmp/test-statement.pdf
   ```

5. Verify overflow alert:
   - Telegram: "🚨 CRÍTICO: Cota estourada [MEMBER_A]: R$550/R$500"
   - Urgency: CRITICO
   - Current quota: updated to R$550

**Expected Outcome**: ✅ PASS
- Two separate alerts received with correct severity
- quota-rules.json current_spent updated correctly
- Log file contains both alert entries

---

## Scenario 4: Monthly Report Generation

**Objective**: Verify T036 monthly report workflow

**Prerequisites**:
- ✅ Scenario 1-3 passed (transactions in Firefly)
- ✅ Cron not necessary for manual testing
- ✅ TELEGRAM_BOT_TOKEN configured

**Steps**:

1. Execute monthly report manually:
   ```bash
   bash scripts/monthly-report.sh "2026-02"
   ```

2. Monitor execution:
   - Should take 10-30 seconds
   - Check logs: `/mnt/external/logs/monthly-reports/`

3. Verify Telegram notification:
   - Should receive summary with:
     - Total spent for February
     - Breakdown by category
     - Member spending summary

4. Check generated files:
   ```bash
   ls -la /tmp/report-2026-02.md
   cat /tmp/report-2026-02.md
   # Should contain transaction JSON + summary
   ```

5. Verify task creation (manual check):
   ```bash
   # In production, would create task "Exportar faturas mês 2026-03"
   # Check Google Tasks via openclaw agent:
   docker-compose exec -T openclaw \
     openclaw agent --message "list_tasks()"
   ```

**Expected Outcome**: ✅ PASS
- Report generated: `/mnt/external/logs/monthly-reports/2026-02-summary.json`
- Telegram notification sent with summary
- Report includes all transactions from period
- Task reminder would be created for next month

---

## Scenario 5: Investment Analysis Handler

**Objective**: Verify T062 investment product research and comparison

**Prerequisites**:
- ✅ openclaw container running
- ✅ Tavily skill configured
- ✅ Telegram bot active

**Steps**:

1. Trigger via Telegram:
   ```
   Victor sends: "E CDB agora? Vale a pena com SELIC em 10%?"
   ```

2. Agent processes:
   - Detects keyword "CDB"
   - Queries Tavily for current rates
   - Formats comparison table

3. Monitor Telegram response:
   - Should receive table with:
     - Product names (CDB, Tesouro, LCI)
     - Current rates
     - Risk levels
     - Best-for classification

4. Verify no sensitive data:
   - Response only contains public market data
   - No mention of Victor's investments
   - No exact amounts from portfolio

**Expected Outcome**: ✅ PASS
- Investment analysis returned within 5 seconds
- Table format correct with 3+ products
- No sensitive portfolio data exposed
- Log entry in `/mnt/external/logs/investment-analyses.json`

**Example Response**:
```
💼 Análise de Investimentos

| Produto | Taxa | Liquidez | Melhor Para |
| Tesouro SELIC | 10.0% | Imediata | Segurança |
| CDB | 11.5% | Alta | Retorno maior |
| LCI | 10.8% | Média | Fiscal |

⚠️ Não há relação com seus investimentos.
```

---

## Scenario 6: Yield Importer

**Objective**: Verify T063 investment income import and consolidation

**Prerequisites**:
- ✅ Scenario 1 passed (Firefly working)
- ✅ Sample PDF: informe de rendimentos 2026
- ✅ Telegram bot active

**Steps**:

1. Prepare yield PDF:
   - Use real bank "Informe de Rendimentos" PDF
   - Or create test PDF with text:
     ```
     Institição: Banco Brasil
     Produto: CDB
     Rendimento Bruto: R$ 1500
     IR Retido: R$ 225
     Rendimento Líquido: R$ 1275
     ```

2. Send to Jarvis via Telegram:
   ```
   Victor sends PDF file to Telegram chat
   ```

3. Agent processes:
   - Extracts text from PDF
   - Parses product types + amounts
   - Applies anonymization
   - Creates Firefly transactions

4. Verify Firefly entries:
   ```bash
   curl -s http://localhost:8080/api/v1/transactions \
     -H "Authorization: Bearer $FIREFLY_TOKEN" \
     | grep -i "investment"
   # Expected: 1+ transactions with category "Investment Income"
   ```

5. Monitor Telegram:
   - Should receive: "💰 Rendimentos Importados"
   - Summary with total yield (masked)
   - Link to Drive report (if configured)

6. Check consolidated report:
   ```bash
   # Report would be saved to: Jarvis/relatorios/rendimentos-2026.md
   # Accessible via Google Drive in production
   ```

**Expected Outcome**: ✅ PASS
- Yield transactions imported to Firefly
- Amounts masked in Telegram (brackets only)
- Consolidated report generated
- Task reminder created: "Declarar rendimentos IRPF"

---

## Scenario 7: Full End-to-End Flow (All Handlers)

**Objective**: Verify integrated Phase 4 workflow

**Prerequisites**:
- ✅ All prerequisites from Scenarios 1-6

**Steps**:

1. **Day 1 — Import**:
   ```bash
   # User sends /importar via Telegram
   # Pipeline executes: PDF → CSV → enrich → anonymize → Firefly
   # Quota alerts trigger if necessary
   # Owner learning occurs for ambiguous entries
   ```

2. **Mid-month — Investment Query**:
   ```bash
   # Victor asks about CDB rates
   # Agent responds with analysis
   ```

3. **Day 28 — Investment Yield Import**:
   ```bash
   # Victor sends yield PDF
   # Transactions created + report generated
   ```

4. **Day 5 Next Month — Monthly Report**:
   ```bash
   # Cron triggers at 09:00
   # Report for previous month generated
   # Email sent to spouse
   # New task created for imports
   ```

5. **Month Start + 5min — Quota Reset**:
   ```bash
   # Cron resets spending counters
   # Telegram confirmation sent
   ```

**Expected Outcome**: ✅ PASS
- All handlers executed in sequence
- No conflicts or data loss
- All transactions accounted for
- Alerts triggered appropriately
- Reports generated correctly

---

## Success Criteria (T038 Validation)

| Criterion | Scenario | Status |
|-----------|----------|--------|
| CSV/PDF import completes | S1 | ✅ 3+ transactions in Firefly |
| Owner learning persists | S2 | ✅ owner-rules.json updated |
| Quota 80% alert triggers | S3 | ✅ URGENTE alert sent |
| Quota 100% alert triggers | S3 | ✅ CRITICO alert sent |
| Monthly report generates | S4 | ✅ Report file created |
| Investment analysis responds | S5 | ✅ Comparison table sent |
| Yield import completes | S6 | ✅ Income transactions created |
| Full flow executes | S7 | ✅ All handlers coordinate |

---

## Failure Recovery

If any scenario fails:

1. **Check logs**: `/mnt/external/logs/[module]/`
2. **Verify credentials**: `.env` file has required tokens
3. **Test API access**:
   ```bash
   # Firefly
   curl -s http://firefly-iii:8080/api/v1/about \
     -H "Authorization: Bearer $FIREFLY_TOKEN"
   
   # Telegram
   curl -s https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe
   ```
4. **Review Docker logs**:
   ```bash
   docker-compose logs openclaw | tail -50
   ```
5. **Check disk space**: `/mnt/external/` must have >500MB free

---

## Sign-Off

**Phase 4 E2E Validation**: Ready for execution  
**All handlers documented**: ✅  
**All scripts deployed**: ✅  
**All cron jobs configured**: ✅  

**Next Step**: Execute scenarios 1-7 with real data from Firefly III

---

**Created**: 2026-03-04  
**Reference**: PHASE4_US2_HANDLERS.md, SOUL.md (Skill 2 sections)
