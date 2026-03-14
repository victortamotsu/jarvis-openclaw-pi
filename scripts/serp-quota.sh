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
# Load current values (python3 — jq not required)
# ─────────────────────────────────────────────────────────────────────
read -r USAGE_MONTH CALLS_USED CALLS_LIMIT ALERT_SENT BLOCKED <<< "$(python3 - << 'PYEOF'
import json, sys
f = "$SERP_USAGE_FILE"
try:
    with open(f) as fp:
        d = json.load(fp)
except Exception:
    d = {}
print(
    d.get("month", ""),
    int(d.get("calls_used", 0)),
    int(d.get("calls_limit", 250)),
    str(d.get("alert_80_sent", False)).lower(),
    str(d.get("blocked", False)).lower()
)
PYEOF
)"

# ─────────────────────────────────────────────────────────────────────
# Monthly reset — new month detected
# ─────────────────────────────────────────────────────────────────────
if [ "$USAGE_MONTH" != "$CURRENT_MONTH" ]; then
    python3 - << PYEOF
import json
f = "${SERP_USAGE_FILE}"
with open(f) as fp:
    d = json.load(fp)
d.update({"month": "${CURRENT_MONTH}", "calls_used": 0, "alert_80_sent": False, "blocked": False, "last_call": None})
with open(f, "w") as fp:
    json.dump(d, fp, indent=2)
PYEOF
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
        python3 -c "
import json
f='${SERP_USAGE_FILE}'
with open(f) as fp: d=json.load(fp)
d['blocked']=True
with open(f,'w') as fp: json.dump(d,fp,indent=2)
"
        echo "[serp-quota] BLOCKED: quota reached (${CALLS_USED}/${CALLS_LIMIT})." >&2
        exit 1
    fi
    echo "[serp-quota] OK: ${CALLS_USED}/${CALLS_LIMIT} calls used this month." >&2
    exit 0
    ;;

  --increment)
    NEW_COUNT=$((CALLS_USED + 1))

    # Persist increment + last_call timestamp
    python3 - << PYEOF
import json
from datetime import datetime
f = "${SERP_USAGE_FILE}"
with open(f) as fp:
    d = json.load(fp)
d["calls_used"] = ${NEW_COUNT}
d["last_call"] = "${NOW}"
with open(f, "w") as fp:
    json.dump(d, fp, indent=2)
PYEOF

    echo "[serp-quota] Incremented: ${NEW_COUNT}/${CALLS_LIMIT}" >&2

    # 80% alert (200/250) — sent only once per month
    THRESHOLD_80=$(( CALLS_LIMIT * 4 / 5 ))
    if [ "$NEW_COUNT" -ge "$THRESHOLD_80" ] && [ "$ALERT_SENT" = "false" ]; then
        REMAINING=$((CALLS_LIMIT - NEW_COUNT))
        MSG="⚠️ <b>SerpAPI Alerta de Cota</b>%0A${NEW_COUNT}/${CALLS_LIMIT} chamadas usadas este mês (${REMAINING} restantes).%0ABuscas de voo continuam disponíveis — monitore o uso."
        send_telegram "$MSG"
        python3 -c "
import json
f='${SERP_USAGE_FILE}'
with open(f) as fp: d=json.load(fp)
d['alert_80_sent']=True
with open(f,'w') as fp: json.dump(d,fp,indent=2)
"
        echo "[serp-quota] 80% alert sent (${NEW_COUNT}/${CALLS_LIMIT})" >&2
    fi

    # 100% block (250/250)
    if [ "$NEW_COUNT" -ge "$CALLS_LIMIT" ]; then
        python3 -c "
import json
f='${SERP_USAGE_FILE}'
with open(f) as fp: d=json.load(fp)
d['blocked']=True
with open(f,'w') as fp: json.dump(d,fp,indent=2)
"
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
    LAST_CALL=$(python3 -c "import json; d=json.load(open('${SERP_USAGE_FILE}')); print(d.get('last_call') or 'nunca')")
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
