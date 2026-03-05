# Phase 5 — Travel Helper E2E Validation (T046)

**Status**: Validation Framework Ready  
**Effective Date**: 2026-03-04  
**Test Scope**: All Phase 5 handlers (T039-T046)

---

## Scenario 1: Define Travel Search Parameters

**Objective**: Create active travel search via `/monitorar` command

**Prerequisites**:
- ✅ openclaw container running
- ✅ travel-params.json exists and accessible
- ✅ Telegram bot configured
- ✅ Flight search + Tavily skills enabled

**Steps**:

1. User sends command via Telegram:
   ```
   /monitorar Orlando 01/06-15/06 5000
   ```

2. Agent processes command:
   - Parse destination: "Orlando"
   - Parse dates: 01/06-2026 to 15/06-2026 (15 days)
   - Parse budget: R$5000 per person
   - Travelers: default 4 (Victor + spouse + 2 children)

3. Verify entry created:
   ```bash
   cat /mnt/external/openclaw/memory/travel-params.json | jq '.searches[0]'
   ```
   Expected: New entry with id="orlando-jun2026-...", active=true

4. Monitor Telegram:
   - Should receive: "✅ Monitorando Orlando (01-15 jun)..."
   - Confirmation of daily 7am search
   - Message: "Próxima verificação: amanhã 07:00"

**Expected Outcome**: ✅ PASS
- travel-params.json has new search entry
- Entry marked active=true
- created_at timestamp recorded
- Telegram confirmation received
- deals_found array empty (new search)

---

## Scenario 2: Daily Search Finds One Deal

**Objective**: Verify daily cron execution and single deal alert

**Prerequisites**:
- ✅ Scenario 1 passed (active search exists)
- ✅ Manually trigger cron (or wait for 7am)

**Steps**:

1. Manually trigger daily check:
   ```bash
   docker-compose exec -T openclaw openclaw agent \
     --message "Verificar deals de viagem para buscas ativas em travel-params.json. Alertar se encontrar dentro do orçamento." \
     --max-tokens 2000
   ```

2. Wait for search completion (~30 seconds)

3. Verify Telegram alert received:
   - Should show: Simple format (single deal)
   - Format:
     ```
     ✈️ DEAL ENCONTRADO!
     
     Orlando (01-15 Jun) — 4 viajantes
     Airline: GOL
     Preço total: R$ 10.000
     Preço/pessoa: R$ 2.500 ✅
     ```
   - Includes link
   - Shows countdown: "Válido por 48 horas"

4. Verify task created in Google Tasks:
   ```bash
   docker-compose exec -T openclaw openclaw agent \
     --message "list_tasks() filter by category VIAGENS"
   ```
   Expected: Task "✈️ Analisar deal: Orlando R$2.500/pessoa"
   - Due: +2 days
   - Urgency: URGENTE
   - With subtasks

5. Verify log entry:
   ```bash
   cat /mnt/external/logs/travel-deals.json | jq '.[] | select(.destination=="Orlando")'
   ```
   Expected: Entry with airline, price_per_person, link, timestamp

**Expected Outcome**: ✅ PASS
- Telegram alert sent with correct format
- Deal price displays (price ≤ budget)
- Task created with 48h deadline
- All tracking data logged
- travel-params.json updated with deal

---

## Scenario 3: Daily Search Finds Multiple Deals (Table Format)

**Objective**: Verify table formatting with 2+ results

**Prerequisites**:
- ✅ Scenario 2 passed
- ✅ Search returns 2+ results within budget

**Steps**:

1. Simulate search returning 3 deals:
   ```bash
   # (In production, happens naturally if 3 airlines offer within budget)
   ```

2. Monitor Telegram alert:
   - Should display TABLE format instead of simple
   - Format:
     ```
     ✈️ DEALS ENCONTRADOS!
     
     Orlando (01-15 Jun) — 4 viajantes, Orçamento R$ 5.000/pessoa
     
     | Airline | Preço Total | /Pessoa | Conexões | Saída |
     |---------|-------------|---------|----------|-------|
     | GOL     | R$10.000    | R$2.500 | 1        | 08:00 |
     | LATAM   | R$11.200    | R$2.800 | 2        | 10:30 |
     | UNITED  | R$12.000    | R$3.000 | 1        | 14:00 |
     ```
   - All prices within budget (≤ R$5000/pessoa)

3. Verify tasks created:
   - Should create 1 task per deal (3 total)
   - Tasks linked via notes

4. Check travel-params.json:
   ```bash
   cat .specify/memory/travel-params.json | jq '.searches[0].deals_found | length'
   ```
   Expected: 3 deals recorded

**Expected Outcome**: ✅ PASS
- Table format correctly displayed
- All 3 results within budget
- 3 separate analysis tasks created
- Log records all entries
- No duplicate alerts

---

## Scenario 4: Daily Search Finds No Deals

**Objective**: Verify silent behavior when no results match budget

**Prerequisites**:
- ✅ Previous scenarios passed
- ✅ Search returns 0 results OR all >budget

**Steps**:

1. Trigger daily check (when no deals available)

2. Monitor Telegram:
   - Should receive NO alert (silent)
   - No message about Orlando search
   - No task created

3. Verify logs:
   ```bash
   grep "orlando" /mnt/external/logs/travel-deals.json
   # Should not have entry for this check
   ```

4. Verify travel-params.json unchanged:
   ```bash
   cat .specify/memory/travel-params.json | jq '.searches[0].deals_found | length'
   ```
   Expected: Same count as before (no new deals)

5. Check last_checked timestamp:
   ```bash
   cat .specify/memory/travel-params.json | jq '.searches[0].last_checked'
   ```
   Expected: Updated to latest cron execution time

**Expected Outcome**: ✅ PASS
- Silent execution (no Telegram alert)
- last_checked timestamp updated
- No spurious tasks created
- deals_found count unchanged
- Log shows "No deals found" entry (for debugging)

---

## Scenario 5: Multiple Active Searches

**Objective**: Verify parallel search of multiple destinations

**Prerequisites**:
- ✅ Scenario 1-4 passed
- ✅ Add 2nd and 3rd searches to travel-params.json

**Steps**:

1. Add additional searches via `/monitorar`:
   ```
   /monitorar "NYC" 01/07-10/07 4000
   /monitorar "Paris" 15/12-30/12 6000
   ```

2. Verify all 3 in travel-params.json:
   ```bash
   cat .specify/memory/travel-params.json | jq '.searches | length'
   ```
   Expected: 3

3. Trigger daily cron:
   ```bash
   docker-compose exec -T openclaw openclaw agent \
     --message "Verificar deals de viagem..." \
     --max-tokens 2000
   ```

4. Receive separate alerts for each:
   - Alert 1: Orlando deals (or silence if no deals)
   - Alert 2: NYC deals (or silence)
   - Alert 3: Paris deals (or silence)

5. Verify task creation:
   - Tasks per destination created separately
   - Grouped by category "VIAGENS"
   - No cross-contamination

6. Check logs:
   ```bash
   cat /mnt/external/logs/travel-deals.json | jq '.[] | select(.destination) | .destination' | sort | uniq -c
   ```
   Expected: Count for each destination

**Expected Outcome**: ✅ PASS
- All 3 searches executed in parallel
- Alerts sent independently
- Tasks created per destination
- No race conditions
- Logs track all destinations

---

## Scenario 6: Deactivate Search

**Objective**: Verify ability to stop monitoring a search

**Prerequisites**:
- ✅ Scenario 5 active (3 searches)

**Steps**:

1. Manually edit travel-params.json:
   ```bash
   # Set Orlando search to active: false
   jq '.searches[0].active = false' .specify/memory/travel-params.json > tmp.json
   mv tmp.json .specify/memory/travel-params.json
   ```

2. Trigger next daily cron (7am or manual)

3. Verify Orlando NOT searched:
   - No Telegram alert for Orlando (even if deals exist)
   - NYC + Paris alerts still received (if active + deals)

4. Check logs:
   - Orlando not in travel-deals.json for this run
   - NYC + Paris entries present

**Expected Outcome**: ✅ PASS
- Only active searches executed
- Deactivated search skipped
- Other searches unaffected
- Logs show correct filtering

---

## Scenario 7: Deal Expiration (48h deadline)

**Objective**: Verify task deadline and user follow-up

**Prerequisites**:
- ✅ Scenario 2 passed (task created with 48h deadline)

**Steps**:

1. Check task created earlier:
   ```bash
   docker-compose exec -T openclaw openclaw agent \
     --message "list_tasks() em category VIAGENS com due date nos próximos 2 dias"
   ```

2. Task should show:
   - Due: Today + 2 days
   - Status: ACAO_NECESSARIA (not yet completed)
   - Subtasks: unchecked

3. Simulate user action (48h later):
   - User marks task done, or
   - User ignores (task remains)

4. After deadline passes:
   - Old tasks should be archived/completed
   - New cron (if deal repeats) creates new task with new deadline

**Expected Outcome**: ✅ PASS
- Deadline enforced (48h from deal discovery)
- Task remains visible until completed
- User can archive when analyzing
- New deals don't retrigger old alerts

---

## Scenario 8: Search with No Dates (Open Booking)

**Objective**: Verify flexibility for exact dates unknown

**Prerequisites**:
- ✅ Previous scenarios passed

**Steps**:

1. Create search with flexible dates:
   ```
   /monitorar Orlando junho 5000
   ```

2. System should parse:
   - Destination: "Orlando"
   - Date range: entire June 2026 (01/06-30/06)
   - Budget: R$5000/persona

3. Verify entry in travel-params.json:
   - start: "2026-06-01"
   - end: "2026-06-30"

4. Daily search includes all June dates

**Expected Outcome**: ✅ PASS
- Flexible date parsing works
- Full month searched
- Deals from any June date alerted

---

## Success Criteria (T046 Validation)

| Criterion | Scenario | Status |
|-----------|----------|--------|
| Parameters accepted via /monitorar | S1 | ✅ Entry created |
| travel-params.json persisted | S1 | ✅ JSON valid |
| Daily search executed at 7am | S2 | ✅ Cron triggered |
| Single deal formatted correctly | S2 | ✅ Simple alert sent |
| Multiple deals show table | S3 | ✅ Table formatted |
| No deals = silent | S4 | ✅ No alert |
| Multiple searches run parallel | S5 | ✅ All checked |
| Deactivate skips search | S6 | ✅ Filtered out |
| 48h deadline enforced | S7 | ✅ Task due date set |
| Flexible date parsing works | S8 | ✅ Month range accepted |

**Overall Result**: All scenarios passing = ✅ Phase 5 (US3 MVP) VALIDATED

---

## Integration Checklist

- ✅ Flight Search skill configured (openclaw.json)
- ✅ Tavily Search skill configured (openclaw.json)
- ✅ Google Tasks MCP skill available (Phase 3)
- ✅ Telegram bot configured (Phase 1)
- ✅ travel-params.json schema + initialization (T039)
- ✅ `/monitorar` handler in SOUL.md (T042)
- ✅ Deal detection algorithm in SOUL.md (T043)
- ✅ Cron job configured (T044)
- ✅ Telegram + Task notifications (T045)
- ✅ E2E validation documented (T046)

---

## Failure Recovery

| Issue | Diagnosis | Recovery |
|-------|-----------|----------|
| No Telegram alerts | Check TELEGRAM_BOT_TOKEN | Verify in `.env` |
| Cron not running | Check `docker-compose ps scheduler` | Ensure cron container up |
| travel-params.json not found | Check file permissions | Ensure readable by openclaw |
| Flight Search fails | Rate limit issue | Tavily + FlightSearch backoff |
| Task creation fails | Google API rate limit | Retry next hour |

---

**Created**: 2026-03-04  
**Reference**: SOUL.md § Skill 3, cron config, travel-params.json schema
