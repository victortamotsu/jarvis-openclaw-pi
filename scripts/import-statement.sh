#!/bin/bash
#
# scripts/import-statement.sh — Orchestrate full import pipeline
#
# Task T033: Coordinates CSV + PDF → enriched → anonymous → Firefly import
#
# Usage: bash scripts/import-statement.sh <csv_path> <pdf_path>
# Example: bash scripts/import-statement.sh ~/Downloads/statement.csv ~/Downloads/fatura.pdf
#
# Pipeline:
# 1. csv + pdf → pdf_parser extracts transactions
# 2. csv + pdf_json → csv_enricher merges + applies owner rules
# 3. enriched_csv → anonymizer masks PII
# 4. anonymous_csv → firefly_importer imports to Firefly
# 5. Send confirmation via Telegram

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIPELINE_DIR="$REPO_ROOT/pipeline"
LOGS_DIR="/mnt/external/logs/openclaw"
LOG_FILE="$LOGS_DIR/import-$(date '+%Y%m%d_%H%M%S').log"

# Ensure log dir
mkdir -p "$LOGS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

# ─────────────────────────────────────────────────────────────────────
# Input Validation
# ─────────────────────────────────────────────────────────────────────

if [ $# -lt 2 ]; then
  echo "Usage: bash scripts/import-statement.sh <csv_path> <pdf_path>"
  echo ""
  echo "Example: bash scripts/import-statement.sh ~/statement.csv ~/fatura.pdf"
  exit 1
fi

CSV_PATH="$1"
PDF_PATH="$2"

log "═══ Import Pipeline Started ═══"
log "CSV: $CSV_PATH"
log "PDF: $PDF_PATH"

if [ ! -f "$CSV_PATH" ]; then
  log_error "CSV not found: $CSV_PATH"
  exit 1
fi

if [ ! -f "$PDF_PATH" ]; then
  log_error "PDF not found: $PDF_PATH"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Load Environment
# ─────────────────────────────────────────────────────────────────────

if [ ! -f "$REPO_ROOT/.env" ]; then
  log_error ".env not found"
  exit 1
fi

source "$REPO_ROOT/.env"

# Verify Python available
if ! command -v python3 &> /dev/null; then
  log_error "python3 not found"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Stage 1: PDF Parsing
# ─────────────────────────────────────────────────────────────────────

log "Stage 1: PDF Parsing..."

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

PDF_JSON="$WORK_DIR/pdf_output.json"

if python3 "$PIPELINE_DIR/pdf_parser.py" "$PDF_PATH" > "$PDF_JSON" 2>> "$LOG_FILE"; then
  TXN_COUNT=$(grep -o '"transaction_count":[0-9]*' "$PDF_JSON" | cut -d':' -f2)
  log_success "PDF parsed: $TXN_COUNT transactions"
else
  log_error "PDF parsing failed"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Stage 2: CSV Enrichment (merge + owner rules)
# ─────────────────────────────────────────────────────────────────────

log "Stage 2: CSV Enrichment..."

ENRICHED_CSV="$WORK_DIR/enriched.csv"

if python3 "$PIPELINE_DIR/csv_enricher.py" "$CSV_PATH" "$PDF_JSON" > /dev/null 2>> "$LOG_FILE"; then
  # Output goes to _enriched.csv variant
  ENRICHED_CSV="${CSV_PATH%.*}_enriched.csv"
  if [ -f "$ENRICHED_CSV" ]; then
    ENRICHED_COUNT=$(tail -n +2 "$ENRICHED_CSV" | wc - l)
    log_success "CSV enriched: $ENRICHED_COUNT rows"
  else
    log_error "Enriched CSV not created"
    exit 1
  fi
else
  log_error "CSV enrichment failed"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Stage 3: Anonymization
# ─────────────────────────────────────────────────────────────────────

log "Stage 3: Anonymization..."

if python3 "$PIPELINE_DIR/anonymizer.py" "$ENRICHED_CSV" > /dev/null 2>> "$LOG_FILE"; then
  ANON_CSV="${ENRICHED_CSV%.*}_anonymous.csv"
  if [ -f "$ANON_CSV" ]; then
    log_success "Data anonymized"
  else
    log_error "Anonymous CSV not created"
    exit 1
  fi
else
  log_error "Anonymization failed"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Stage 4: Firefly Import
# ─────────────────────────────────────────────────────────────────────

log "Stage 4: Firefly Import..."

IMPORT_RESULT="$WORK_DIR/import_result.json"

if FIREFLY_TOKEN="$FIREFLY_TOKEN" FIREFLY_URL="$FIREFLY_URL" \
   python3 "$PIPELINE_DIR/firefly_importer.py" "$ANON_CSV" > "$IMPORT_RESULT" 2>> "$LOG_FILE"; then
  
  IMPORTED=$(grep -o '"imported":[0-9]*' "$IMPORT_RESULT" | cut -d':' -f2)
  ERRORS=$(grep -o '"errors":[0-9]*' "$IMPORT_RESULT" | cut -d':' -f2)
  
  log_success "Import complete: $IMPORTED transactions, $ERRORS errors"
else
  log_error "Firefly import failed"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Stage 5: Notification
# ─────────────────────────────────────────────────────────────────────

log "Stage 5: Telegram Notification..."

SUMMARY_MSG="📊 Import Summary:
• PDF transactions: $TXN_COUNT
• Enriched rows: $ENRICHED_COUNT
• Imported to Firefly: $IMPORTED
• Errors: $ERRORS
✅ Pipeline complete"

# Send via Telegram (if TELEGRAM_BOT_TOKEN is set)
if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${SUMMARY_MSG}" > /dev/null
  
  log_success "Notification sent to Telegram"
else
  log_error "Telegram credentials not configured"
fi

# ─────────────────────────────────────────────────────────────────────
# Cleanup & Summary
# ─────────────────────────────────────────────────────────────────────

log ""
log "═══ Pipeline Complete ═══"
log "Log saved: $LOG_FILE"
log ""
echo -e "${GREEN}$SUMMARY_MSG${NC}"
