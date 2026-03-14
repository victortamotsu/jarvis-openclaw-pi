#!/usr/bin/env bash
# scripts/serp-quota.sh — SerpAPI quota management helper
# Usage:
#   serp-quota.sh --check       Check if quota available (exit 0=ok, exit 1=blocked)
#   serp-quota.sh --increment   Record one API call (post-call, only if not cached)
#   serp-quota.sh --status      Print current usage to stdout
#
# T108 — Phase 10 (2026-03-08)

set -euo pipefail

SERP_USAGE_FILE="${SERP_USAGE_FILE:-/mnt/external/openclaw/memory/serp-usage.json}"
CURRENT_MONTH=$(date +%Y-%m)
NOW=$(date --iso-8601=seconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)

# ─────────────────────────────────────────────────────────────────────
# Load Telegram credentials for alerts (sourced from .env if available)
# ─────────────────────────────────────────────────────────────────────
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

send_telegram() {
    local msg="$1"
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo "[serp-quota] Telegram not configured — skipping alert: $msg" >&2
        return 0
    fi
    curl -fsS -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${msg}" \
        -d "parse_mode=HTML" \
        > /dev/null 2>&1 || true
}

# ─────────────────────────────────────────────────────────────────────
# Validate usage file exists
# ─────────────────────────────────────────────────────────────────────
if [ ! -f "$SERP_USAGE_FILE" ]; then
    echo "[serp-quota] ERROR: $SERP_USAGE_FILE not found. Run setup-pi.sh first." >&2
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Load current values
# ─────────────────────────────────────────────────────────────────────
USAGE_MONTH=$(jq -r '.month // ""' "$SERP_USAGE_FILE")
CALLS_USED=$(jq -r '.calls_used // 0' "$SERP_USAGE_FILE")
CALLS_LIMIT=$(jq -r '.calls_limit // 250' "$SERP_USAGE_FILE")
ALERT_SENT=$(jq -r '.alert_80_sent // false' "$SERP_USAGE_FILE")
BLOCKED=$(jq -r '.blocked // false' "$SERP_USAGE_FILE")

# ─────────────────────────────────────────────────────────────────────
# Monthly reset — new month detected
# ─────────────────────────────────────────────────────────────────────
if [ "$USAGE_MONTH" != "$CURRENT_MONTH" ]; then
    jq \
        --arg m "$CURRENT_MONTH" \
        '.month=$m | .calls_used=0 | .alert_80_sent=false | .blocked=false | .last_call=null' \
        "$SERP_USAGE_FILE" > "${SERP_USAGE_FILE}.tmp" \
        && mv "${SERP_USAGE_FILE}.tmp" "$SERP_USAGE_FILE"
    CALLS_USED=0
    ALERT_SENT="false"
    BLOCKED="false"
    echo "[serp-quota] Monthly reset: $USAGE_MONTH → $CURRENT_MONTH" >&2
fi

# ─────────────────────────────────────────────────────────────────────
# Handle arguments
# ─────────────────────────────────────────────────────────────────────
MODE="${1:---check}"

case "$MODE" in

  --check)
    if [ "$BLOCKED" = "true" ]; then
        echo "[serp-quota] BLOCKED: SerpAPI quota exhausted (${CALLS_USED}/${CALLS_LIMIT}). Resets on 1st of next month." >&2
        exit 1
    fi
    if [ "$CALLS_USED" -ge "$CALLS_LIMIT" ]; then
        # Update blocked flag if not already set
        jq '.blocked=true' "$SERP_USAGE_FILE" > "${SERP_USAGE_FILE}.tmp" \
            && mv "${SERP_USAGE_FILE}.tmp" "$SERP_USAGE_FILE"
        echo "[serp-quota] BLOCKED: quota reached (${CALLS_USED}/${CALLS_LIMIT})." >&2
        exit 1
    fi
    echo "[serp-quota] OK: ${CALLS_USED}/${CALLS_LIMIT} calls used this month." >&2
    exit 0
    ;;

  --increment)
    NEW_COUNT=$((CALLS_USED + 1))

    # Persist increment + last_call timestamp
    jq \
        --argjson c "$NEW_COUNT" \
        --arg t "$NOW" \
        '.calls_used=$c | .last_call=$t' \
        "$SERP_USAGE_FILE" > "${SERP_USAGE_FILE}.tmp" \
        && mv "${SERP_USAGE_FILE}.tmp" "$SERP_USAGE_FILE"

    echo "[serp-quota] Incremented: ${NEW_COUNT}/${CALLS_LIMIT}" >&2

    # 80% alert (200/250) — sent only once per month
    THRESHOLD_80=$(( CALLS_LIMIT * 4 / 5 ))
    if [ "$NEW_COUNT" -ge "$THRESHOLD_80" ] && [ "$ALERT_SENT" = "false" ]; then
        REMAINING=$((CALLS_LIMIT - NEW_COUNT))
        MSG="⚠️ <b>SerpAPI Alerta de Cota</b>%0A${NEW_COUNT}/${CALLS_LIMIT} chamadas usadas este mês (${REMAINING} restantes).%0ABuscas de voo continuam disponíveis — monitore o uso."
        send_telegram "$MSG"
        jq '.alert_80_sent=true' "$SERP_USAGE_FILE" > "${SERP_USAGE_FILE}.tmp" \
            && mv "${SERP_USAGE_FILE}.tmp" "$SERP_USAGE_FILE"
        echo "[serp-quota] 80% alert sent (${NEW_COUNT}/${CALLS_LIMIT})" >&2
    fi

    # 100% block (250/250)
    if [ "$NEW_COUNT" -ge "$CALLS_LIMIT" ]; then
        jq '.blocked=true' "$SERP_USAGE_FILE" > "${SERP_USAGE_FILE}.tmp" \
            && mv "${SERP_USAGE_FILE}.tmp" "$SERP_USAGE_FILE"
        NEXT_MONTH=$(date -d "$(date +%Y-%m-01) +1 month" +%Y-%m 2>/dev/null \
            || python3 -c "import datetime; d=datetime.date.today(); print(f'{d.year}-{d.month%12+1:02d}' if d.month<12 else f'{d.year+1}-01')")
        MSG="🛑 <b>SerpAPI Cota Esgotada</b>%0ABuscas de voo desativadas até 1º de ${NEXT_MONTH}.%0AChamadas restantes este mês: 0/${CALLS_LIMIT}."
        send_telegram "$MSG"
        echo "[serp-quota] BLOCKED: quota exhausted (${NEW_COUNT}/${CALLS_LIMIT})" >&2
        exit 0  # Don't exit 1 here — the call already succeeded; just record the block
    fi

    exit 0
    ;;

  --status)
    REMAINING=$((CALLS_LIMIT - CALLS_USED))
    LAST_CALL=$(jq -r '.last_call // "nunca"' "$SERP_USAGE_FILE")
    echo "SerpAPI Quota — ${CURRENT_MONTH}"
    echo "  Usadas:     ${CALLS_USED}/${CALLS_LIMIT}"
    echo "  Restantes:  ${REMAINING}"
    echo "  Bloqueado:  ${BLOCKED}"
    echo "  Última:     ${LAST_CALL}"
    exit 0
    ;;

  *)
    echo "Usage: $0 [--check|--increment|--status]" >&2
    exit 2
    ;;

esac
