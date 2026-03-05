#!/bin/bash
#
# scripts/health-check.sh — Monitor Docker container health and alert on failures
#
# Task T064: Health check for openclaw, firefly, and scheduler containers
#
# Usage: bash scripts/health-check.sh
#
# Checks via `docker ps --filter` if expected containers are running
# If any container is down, sends alert via Telegram
# Scheduled via cron: */5 * * * * bash /path/to/scripts/health-check.sh

set -e

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"

# ─────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────

# Expected containers
EXPECTED_CONTAINERS=(
  "openclaw-gateway"
  "firefly-iii"
  "mcporter-firefly"
  "scheduler"  # If running; optional
)

# Telegram notification config
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Health check state file (to avoid duplicate alerts)
STATE_FILE="/mnt/external/logs/health-check.state"
mkdir -p "$(dirname "$STATE_FILE")"

# ─────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────

# Check if container is running
container_is_running() {
  local container_name="$1"
  if docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "^$container_name$"; then
    return 0  # Container running
  else
    return 1  # Container not running
  fi
}

# Get container status
get_container_status() {
  local container_name="$1"
  docker ps -a --filter "name=$container_name" --format "{{.Status}}" 2>/dev/null || echo "unknown"
}

# Send Telegram alert
send_telegram_alert() {
  local message="$1"
  
  if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
    log_warn "Telegram not configured, skipping notification"
    return 1
  fi
  
  local escaped_msg=$(echo "$message" | sed 's/"/\\"/g')
  local payload="{\"chat_id\":\"$TELEGRAM_CHAT_ID\",\"text\":\"$escaped_msg\",\"parse_mode\":\"Markdown\"}"
  
  log_debug "Sending Telegram alert: $message"
  
  if curl -s -X POST \
    "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null 2>&1; then
    log_success "Telegram notification sent"
    return 0
  else
    log_error "Failed to send Telegram notification"
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────────────
# Main Health Check Logic
# ─────────────────────────────────────────────────────────────────────

log_section "Docker Health Check"

# Get previous state
PREVIOUS_STATE=""
if [[ -f "$STATE_FILE" ]]; then
  PREVIOUS_STATE=$(cat "$STATE_FILE")
fi

# Check each container
CURRENT_STATE=""
FAILED_CONTAINERS=()
HEALTHY_CONTAINERS=()

for container in "${EXPECTED_CONTAINERS[@]}"; do
  if container_is_running "$container"; then
    log_info "✓ Container running: $container"
    HEALTHY_CONTAINERS+=("$container")
    CURRENT_STATE="${CURRENT_STATE}OK:$container "
  else
    local status=$(get_container_status "$container")
    log_error "✗ Container NOT running: $container (status: $status)"
    FAILED_CONTAINERS+=("$container")
    CURRENT_STATE="${CURRENT_STATE}FAIL:$container "
  fi
done

# Save current state
echo "$CURRENT_STATE" > "$STATE_FILE"

# If there are failed containers, send alert
if [[ ${#FAILED_CONTAINERS[@]} -gt 0 ]]; then
  # Format alert message
  local failed_list=$(printf '%s\n' "${FAILED_CONTAINERS[@]}" | sed 's/^/- /')
  
  local alert_message="🚨 *Health Check Alert* 🚨
  
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')

*Failed Containers:*
$failed_list

*Healthy Containers:*
$(printf '- %s\n' "${HEALTHY_CONTAINERS[@]}")

*Actions:*
1. SSH into Pi: \`ssh pi@jarvis\`
2. Check logs: \`docker logs <container-name>\`
3. Restart container: \`docker restart <container-name>\`
4. Full restart: \`docker-compose restart\`

For more help, see docs/runbook.md → Operational Runbook"
  
  log_error "Detected failed containers: ${FAILED_CONTAINERS[*]}"
  send_telegram_alert "$alert_message"
  
  exit 1
else
  log_success "All expected containers are running"
  exit 0
fi
