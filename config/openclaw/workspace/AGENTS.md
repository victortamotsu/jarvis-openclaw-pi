# AGENTS.md — Available Skills Reference

**Agent**: jarvis  
**Skills Loaded**: 6  
**Last Updated**: 2026-03-04

---

## 1. **Skill — Google Tasks API**

**Type**: MCP stdio custom  
**Implementation**: `skills/google-tasks/index.js` (Node.js)  
**Tools Exposed**:
- `create_task(list_name, title, notes, due_date, subtasks)`
- `list_tasks(list_name, max_results=10, status_filter=None)`
- `update_task(task_id, updates{notes, due_date, status})`
- `complete_task(task_id)`

**OAuth**: Bearer `$GOOGLE_REFRESH_TOKEN` (auto-refresh before each call)  
**Used by**: Skill 1 (pendências), Skill 2 (relatórios), Skill 3 (viagens), Skill 4 (projetos)

---

## 2. **Skill — Gmail Read (Native OpenClaw)**

**Type**: ClawHub  
**Implementation**: OpenClaw native skill (`openclaw-gmail`)  
**Tools**:
- `read_inbox(folder="INBOX", max_results=20)`
- `get_message(message_id, full_body=True)`
- `search_emails(query, max_results=10)`

**Fallback**: Gmail API REST (OAuth 2.0) if skill unavailable  
**Used by**: Skill 1 (email processing)

---

## 3. **Skill — WhatsApp Passive (Native OpenClaw)**

**Type**: ClawHub (`openclaw-whatsapp` via Baileys)  
**Implementation**: Runs within OpenClaw runtime  
**Tools**:
- `read_messages(count=50, only_new=True)`
- `get_chat_history(contact, count=100)`
- `get_contact_info(phone_number)`

**Important**: Agent NEVER sends messages via WhatsApp (read-only)  
**Pairing**: Requires QR code scan on Pi on first run  
**Used by**: Skill 1 (message capture), Skill 3 (travel group monitoring)

---

## 4. **Skill — Web Search (Tavily)**

**Type**: ClawHub  
**Implementation**: `tavily-search`  
**Tools**:
- `search(query, topic="general", max_results=5)`
- `deep_search(query, topic="research")`

**API Key**: Free tier (5k calls/month) or none required for basic tier  
**Used by**: Skill 1 (context for replies), Skill 2 (investment analysis), Skill 3 (travel deals), Skill 4 (project research)

---

## 5. **Skill — Flight Search (No API Key)**

**Type**: ClawHub  
**Implementation**: `flight-search`  
**Tools**:
- `search_flights(origin, destination, date, passengers=4, max_results=10)`
- `search_hotels(destination, check_in, check_out, guests=4)`

**Limitations**: Basic results, no live pricing (reference only)  
**Used by**: Skill 3 (travel deals)

---

## 6. **Skill — Firefly III (MCP mcporter)**

**Type**: MCP stdio wrapper  
**Implementation**: `skills/firefly-mcp/mcporter.json` → `steipete/mcporter` container  
**Tools** (via Firefly REST API):
- `get_transactions(date_from, date_to, limit=100)`
- `create_transaction(account, type, amount, date, description, category)`
- `get_categories()`
- `get_accounts()`
- `get_expense_report(date_from, date_to)`

**Fallback**: Direct REST API calls (`pipeline/firefly_importer.py`) for bulk operations  
**Auth**: Bearer `$FIREFLY_TOKEN`  
**Used by**: Skill 2 (financial queries + MCP interface)

---

## 7. **Skill — GitHub (Native OpenClaw)**

**Type**: ClawHub  
**Implementation**: `gh` CLI wrapper  
**Tools**:
- `gh_repo_create(name, description, visibility="public")`
- `gh_repo_clone(repo_url, destination)`
- `gh_run_command(command, context_dir)`

**Auth**: `$GITHUB_TOKEN` (personal access token)  
**Used by**: Skill 4 (repo creation)

---

## 8. **PDF Parsing (pdf-reader-mcp)**

**Type**: External binary (npm-based)  
**Implementation**: `@sylphx/pdf-reader-mcp` v2.3.0  
**Tools**:
- `parse_pdf(file_path)`  → returns text + tables + metadata
- `extract_tables(file_path)` → structured CSV

**Capabilities**: ARM-compatible, PDF.js engine, fast parallel processing  
**Used by**: Skill 2 (invoice parsing in `pipeline/pdf_parser.py`)

---

## 9. **Helper Scripts (Bash)**

### `scripts/check-channels.sh`
Dispara agente para verificar emails + WhatsApp. Chamado pelo cron `*/15 * * * *`.

### `scripts/monthly-report.sh`
Gera relatório mensal de gastos. Chamado pelo cron `0 9 5 * *` (dia 5 às 9h).

### `scripts/import-statement.sh`
Orquestra pipeline de importação CSV+PDF → Firefly. Chamado manualmente por `/importar`.

### `scripts/health-check.sh`
Monitora status dos containers. Chamado pelo cron `*/5 * * * *` (a cada 5 min).

---

## Skill Orchestration Flow

```
User command (Telegram)
  ↓
SOUL.md routing logic
  ↓ (selects skill by context)
  ├─→ Google Tasks (read/write pendências)
  ├─→ Gmail (read emails)
  ├─→ WhatsApp (read messages)
  ├─→ Web Search (context enrichment)
  ├─→ Firefly (queries + CLI)
  ├─→ GitHub (repo ops)
  └─→ PDF Parser (invoice processing)
  ↓
Tool result
  ↓
Format + send via Telegram
```

---

**Last Updated**: 2026-03-04  
**Next Update**: After Phase 2 (after validating all skill connections)
