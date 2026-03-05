#!/bin/bash
#
# scripts/check-channels.sh — Process emails and WhatsApp for pending tasks
#
# Task T024: Orchestrates skill 1 (Pendências) flow:
#   1. Check Gmail for new emails
#   2. Check WhatsApp for new messages  
#   3. Classify urgency (INFORMATIVO/ACAO_NECESSARIA/URGENTE/CRITICO)
#   4. Deduplicate against existing tasks (list_tasks 30-day window)
#   5. Create/update tasks in Google Tasks
#   6. Send alerts via Telegram with appropriate classification
#
# Usage: bash scripts/check-channels.sh
# Cron: */15 * * * * (every 15 minutes) — defined in config/crontabs/jarvis

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGS_DIR="/mnt/external/logs/openclaw"
LOG_FILE="$LOGS_DIR/check-channels-$(date '+%Y%m%d').log"

# Ensure log dir exists
mkdir -p "$LOGS_DIR"

# ─────────────────────────────────────────────────────────────────────
# Logging helper
# ─────────────────────────────────────────────────────────────────────

log() {
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

log_error() {
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# ─────────────────────────────────────────────────────────────────────
# Check Prerequisites
# ─────────────────────────────────────────────────────────────────────

log "═══ Starting channel check (every 15 min) ═══"

if ! command -v docker-compose &> /dev/null; then
  log_error "docker-compose not found"
  exit 1
fi

if ! docker-compose -f "$REPO_ROOT/docker-compose.yml" ps openclaw | grep -q "Up"; then
  log_error "OpenClaw container not running"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Main orchestration: Call OpenClaw agent with full S1 workflow
# ─────────────────────────────────────────────────────────────────────

log "Invoking OpenClaw agent for channel processing..."

# Construct prompt that triggers full Skill 1 workflow:
# 1. Check channels (Gmail + WhatsApp)
# 2. Classify each item by urgency
# 3. Deduplicate against existing tasks
# 4. Create/update Google Tasks
# 5. Send alerts via Telegram

PROMPT="Verificar novos emails e mensagens WhatsApp. Para cada item:

1. Classif urgência: INFORMATIVO (digest diário 22h) | ACAO_NECESSARIA (alerta direto) | URGENTE (alerta imediato) | CRITICO (repetir 15min).

2. Buscar task existente (30 dias): title con tem words-chave + contato.
   - SE encontrar: update_task com histórico novo.
   - SE novo: create_task com urgência + sub-tasks se múltiplas ações.

3. Enviar alert Telegram com:
   - ACAO_NECESSARIA: 🔔 Título | @contato
   - URGENTE: ⚠️ Título | @contato  
   - CRITICO: 🚨 CRÍTICO | Título | @contato (repetir 15min até confirmação)

Processar conforme SOUL.md Skill 1, exemplos de classificação dos atributos."

# Execute via docker-compose exec (non-interactive mode)
RESPONSE=$(docker-compose -f "$REPO_ROOT/docker-compose.yml" exec -T openclaw \
  openclaw agent --message "$PROMPT" --max-tokens 500 2>&1 || echo "TIMEOUT")

# Log response
log "Agent response: $RESPONSE" | head -c 500
echo "... (truncated)" >> "$LOG_FILE"

# ─────────────────────────────────────────────────────────────────────
# Validate Success
# ─────────────────────────────────────────────────────────────────────

if echo "$RESPONSE" | grep -iE "sucesso|completed|criado|atualizado|alert"; then
  log "✓ Channel check completed successfully"
  exit 0
elif echo "$RESPONSE" | grep -q "TIMEOUT"; then
  log_error "Agent response timeout (>30s)"
  exit 1
else
  log_error "Unexpected response: $RESPONSE" | head -c 200
  exit 1
fi
