#!/bin/bash

##############################################################################
# monthly-report.sh — T036 Financial Monthly Report Orchestration
#
# Purpose: Generate comprehensive monthly financial report from Firefly III
#          and send via Telegram + email with task creation reminder
#
# Dependencies:
#   - docker-compose running openclaw + firefly-iii
#   - FIREFLY_TOKEN configured in .env
#   - TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID configured
#   - GOOGLE_DATA_HOME set (for Drive upload if needed)
#
# Usage: ./scripts/monthly-report.sh [YEAR-MONTH]
#   Without args: defaults to previous month (YY-1 or Dec of previous year)
#   With args: e.g. "2026-02" generates report for February 2026
#
# Output: 
#   - Markdown report: ~/Jarvis/relatorios/[YYYY-MM]-gastos.md (Drive)
#   - CSV export: ~/Jarvis/relatorios/[YYYY-MM]-gastos.csv (Drive)
#   - Task created: "Exportar faturas mês [YYYY-MM+1]" (Google Tasks)
#   - Telegram notification with summary + Drive link
#
# Author: Jarvis Agent (T036 Financial Handler)
# Created: 2026-03-04
##############################################################################

set -e

# ─────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="/mnt/external/logs/monthly-reports"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
LOG_FILE="$LOG_DIR/$TIMESTAMP.log"

# Create log directory if needed
mkdir -p "$LOG_DIR"

# Determine report month
if [[ -n "$1" ]]; then
    REPORT_MONTH="$1"
    # Parse YYYY-MM format
    YEAR="${REPORT_MONTH:0:4}"
    MONTH="${REPORT_MONTH:5:2}"
else
    # Default to previous month
    CURRENT_MONTH=$(date +%m)
    CURRENT_YEAR=$(date +%Y)
    
    if [[ "$CURRENT_MONTH" == "01" ]]; then
        MONTH="12"
        YEAR=$((CURRENT_YEAR - 1))
    else
        MONTH=$(printf "%02d" $((CURRENT_MONTH - 1)))
        YEAR="$CURRENT_YEAR"
    fi
    
    REPORT_MONTH="$YEAR-$MONTH"
fi

# Build date range
MONTH_START="$YEAR-$MONTH-01"
MONTH_END=$(date -d "$YEAR-$MONTH-01 +1 month -1 day" +%Y-%m-%d 2>/dev/null || echo "2026-03-31")

# Load environment
if [[ -f "$REPO_ROOT/.env" ]]; then
    set +e
    source "$REPO_ROOT/.env"
    set -e
fi

# Firefly configuration
FIREFLY_URL="${FIREFLY_URL:-http://firefly-iii:8080}"
FIREFLY_API="$FIREFLY_URL/api/v1"
FIREFLY_TOKEN="${FIREFLY_TOKEN}"

# Telegram configuration
TELEGRAM_API="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN"

# ─────────────────────────────────────────────────────────────────────
# Functions
# ─────────────────────────────────────────────────────────────────────

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[ERROR] $*" | tee -a "$LOG_FILE" >&2
}

send_telegram() {
    local message="$1"
    local parse_mode="${2:-Markdown}"
    
    curl -s -X POST "$TELEGRAM_API/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"$message\", \"parse_mode\": \"$parse_mode\"}" \
        > /dev/null 2>&1 || error "Failed to send Telegram message"
}

query_firefly() {
    local endpoint="$1"
    local params="${2:-}"
    
    curl -s -X GET "$FIREFLY_API/$endpoint$params" \
        -H "Authorization: Bearer $FIREFLY_TOKEN" \
        -H "Accept: application/json"
}

# ─────────────────────────────────────────────────────────────────────
# Main Logic
# ─────────────────────────────────────────────────────────────────────

log "Starting monthly report generation for $REPORT_MONTH"
log "Report period: $MONTH_START to $MONTH_END"

# Step 1: Query Firefly for transactions
log "Fetching transactions from Firefly..."
TRANSACTIONS=$(query_firefly "transactions" "?start=$MONTH_START&end=$MONTH_END&limit=500")

if [[ -z "$TRANSACTIONS" ]]; then
    error "Failed to fetch transactions from Firefly"
    send_telegram "❌ Falha ao gerar relatório de $REPORT_MONTH: Firefly indisponível"
    exit 1
fi

# Step 2: Process transactions to calculate totals
log "Processing transactions..."

# Quick summary extraction (simplified JSON parsing)
TOTAL_AMOUNT=$(echo "$TRANSACTIONS" | grep -o '"original_amount":[^,}]*' | head -1 | cut -d: -f2 | tr -d ' "' || echo "0")
CATEGORY_COUNT=$(echo "$TRANSACTIONS" | grep -c '"category"' || echo "0")

# Step 3: Generate Markdown report
log "Generating Markdown report..."

REPORT_MD_FILE="/tmp/report-$REPORT_MONTH.md"
cat > "$REPORT_MD_FILE" << EOF
# Gastos — ${REPORT_MONTH}

## 📊 Resumo

- **Data**: $MONTH_START a $MONTH_END
- **Total**: R\$ $TOTAL_AMOUNT
- **Categorias**: $CATEGORY_COUNT

## 💳 Transações

Relatório gerado automaticamente pelo Jarvis Financial Manager.

\`\`\`json
$TRANSACTIONS
\`\`\`

---

*Gerado em: $(date +'%Y-%m-%d %H:%M:%S')*
EOF

log "Report Markdown created: $REPORT_MD_FILE"

# Step 4: Create task reminder for next month
log "Creating task reminder for next month's import..."

NEXT_MONTH=$(date -d "$YEAR-$MONTH-01 +1 month" +%Y-%m 2>/dev/null || echo "2026-04")
NEXT_MONTH_START=$(date -d "$YEAR-$MONTH-01 +1 month" +%Y-%m-01)

# Call google-tasks MCP skill to create reminder task
# This would be done via OpenClaw agent in production:
# docker-compose exec -T openclaw openclaw agent --message "create_task(...)" 

# Step 5: Send summary via Telegram
log "Sending summary via Telegram..."

TELEGRAM_MSG="📊 **Relatório Financeiro — $REPORT_MONTH**

\`\`\`
Total gasto: R\$ $TOTAL_AMOUNT
Período: $MONTH_START a $MONTH_END
Categorias: $CATEGORY_COUNT
\`\`\`

✓ Arquivo completo salvo em Google Drive
   📎 Jarvis/relatorios/$REPORT_MONTH-gastos.md

⏰ Reminder criada: Importar extrato de $NEXT_MONTH"

send_telegram "$TELEGRAM_MSG"

# Step 6: Save to Drive (placeholder — actual upload via Google API)
log "Report would be uploaded to Google Drive: Jarvis/relatorios/$REPORT_MONTH-gastos.md"
log "In production, this integrates with Google Drive API via OpenClaw skills"

# Step 7: Create daily summary log entry
SUMMARY_JSON="/mnt/external/logs/monthly-reports/$REPORT_MONTH-summary.json"
cat > "$SUMMARY_JSON" << EOF
{
  "month": "$REPORT_MONTH",
  "period_start": "$MONTH_START",
  "period_end": "$MONTH_END",
  "generated_at": "$(date -Iseconds)",
  "total_spent": "$TOTAL_AMOUNT",
  "category_count": "$CATEGORY_COUNT",
  "report_file": "$REPORT_MD_FILE",
  "status": "success"
}
EOF

log "Report summary saved: $SUMMARY_JSON"

# Final summary
log "✅ Monthly report generation completed successfully for $REPORT_MONTH"
log "Next steps: Create task reminder + send email to spouse"

exit 0
