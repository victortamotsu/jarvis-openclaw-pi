#!/bin/bash
#
# scripts/validate-local-env.sh — Validate MINIMAL local prerequisites before docker-compose up
#
# Only checks what MUST exist on the host Pi; everything else runs inside containers:
#
#   LOCAL (host only):                  CONTAINER (scheduler image):
#   ─────────────────                   ────────────────────────────
#   docker + docker compose             sqlite3   (backup.sh)
#   git                                 jq        (scripts)
#   git-crypt  (decrypt .env)           logrotate (log rotation)
#   .env with all tokens set            github-cli (create-project.sh)
#   /mnt/external mounted + writable    python3 + requests (pipeline)
#
# Usage:
#   bash scripts/validate-local-env.sh
#
# Run BEFORE: docker-compose up -d

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

# ─────────────────────────────────────────────────────────────────────
# Colors
# ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────

check_pass() { echo -e "  ${GREEN}✓${NC} $1"; ((PASS++)); }
check_fail() { echo -e "  ${RED}✗${NC} $1"; echo -e "    ${YELLOW}→${NC} $2"; ((FAIL++)); }
check_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; echo -e "    ${YELLOW}→${NC} $2"; ((WARN++)); }
section()    { echo ""; echo -e "${CYAN}── $1${NC}"; }

# ─────────────────────────────────────────────────────────────────────
# Header
# ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Jarvis Pre-Deploy: Minimal Local Environment Check   ${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Note:${NC} sqlite3, jq, logrotate, gh CLI, python3 are"
echo     "        provided by containers — NOT required locally."

# ─────────────────────────────────────────────────────────────────────
# 1. Container Runtime
# ─────────────────────────────────────────────────────────────────────

section "Container Runtime"

if command -v docker &>/dev/null; then
  check_pass "docker installed ($(docker --version | cut -d' ' -f3 | tr -d ','))"
else
  check_fail "docker not found" "apt install docker.io && sudo systemctl enable --now docker"
fi

if docker info &>/dev/null; then
  check_pass "docker daemon running"
else
  check_fail "docker daemon not running" "sudo systemctl start docker"
fi

# Accept both 'docker compose' (plugin) and 'docker-compose' (standalone)
if docker compose version &>/dev/null 2>&1; then
  check_pass "docker compose available ($(docker compose version --short))"
elif docker-compose version &>/dev/null 2>&1; then
  check_pass "docker-compose available ($(docker-compose --version | cut -d' ' -f3 | tr -d ','))"
else
  check_fail "docker compose not available" "apt install docker-compose-plugin"
fi

# ─────────────────────────────────────────────────────────────────────
# 2. Source Control & Encryption
# ─────────────────────────────────────────────────────────────────────

section "Source Control & Encryption  (host-side, needed before docker-compose up)"

if command -v git &>/dev/null; then
  check_pass "git installed ($(git --version | cut -d' ' -f3))"
else
  check_fail "git not found" "apt install git"
fi

if command -v git-crypt &>/dev/null; then
  check_pass "git-crypt installed"
else
  check_fail "git-crypt not found" "apt install git-crypt"
fi

# Check if .env is decrypted (binary file = still encrypted)
if [[ -f "$ENV_FILE" ]]; then
  if file "$ENV_FILE" 2>/dev/null | grep -q "text"; then
    check_pass ".env is decrypted (plaintext)"
  else
    check_fail ".env appears encrypted or binary" \
      "Run: git-crypt unlock  (requires your GPG key or symmetric key)"
  fi
else
  check_fail ".env file missing" \
    "cp .env.example .env  then fill in all token values"
fi

# ─────────────────────────────────────────────────────────────────────
# 3. External Storage
# ─────────────────────────────────────────────────────────────────────

EXTERNAL="${EXTERNAL_MOUNT:-/mnt/external}"

section "External Storage ($EXTERNAL)"

if [[ -d "$EXTERNAL" ]]; then
  check_pass "mount point exists: $EXTERNAL"
else
  check_fail "mount point not found: $EXTERNAL" \
    "mkdir -p $EXTERNAL && mount /dev/sdX1 $EXTERNAL  (replace sdX1 with your device)"
fi

if [[ -d "$EXTERNAL" ]] && [[ -w "$EXTERNAL" ]]; then
  check_pass "mount is writable"
else
  [[ -d "$EXTERNAL" ]] && check_fail "mount is not writable" \
    "Check ownership: sudo chown -R pi:pi $EXTERNAL"
fi

if [[ -d "$EXTERNAL" ]]; then
  FREE_KB=$(df "$EXTERNAL" 2>/dev/null | awk 'NR==2{print $4}')
  FREE_GB=$(( ${FREE_KB:-0} / 1024 / 1024 ))
  if [[ "${FREE_KB:-0}" -gt 10485760 ]]; then  # > 10GB
    check_pass "sufficient disk space: ${FREE_GB}GB free"
  elif [[ "${FREE_KB:-0}" -gt 5242880 ]]; then  # > 5GB, warn
    check_warn "low disk space: ${FREE_GB}GB free (recommend ≥ 10GB)" \
      "Consider cleaning old backups in $EXTERNAL/backups/"
  else
    check_fail "insufficient disk space: ${FREE_GB}GB free (minimum 5GB)" \
      "Free up space on $EXTERNAL before deploying"
  fi
fi

# ─────────────────────────────────────────────────────────────────────
# 4. .env Variables
# ─────────────────────────────────────────────────────────────────────

section ".env Production Variables"

if [[ ! -f "$ENV_FILE" ]]; then
  check_fail ".env not found — skipping variable checks" \
    "cp .env.example .env  then fill all values"
else
  REQUIRED_VARS=(
    TELEGRAM_BOT_TOKEN
    TELEGRAM_CHAT_ID
    GITHUB_TOKEN
    FIREFLY_TOKEN
    GOOGLE_CLIENT_ID
    GOOGLE_CLIENT_SECRET
    GOOGLE_REFRESH_TOKEN
    APP_KEY
  )

  for var in "${REQUIRED_VARS[@]}"; do
    # Extract value; strip quotes
    value=$(grep -E "^${var}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"'"'" | xargs)
    if [[ -z "$value" ]]; then
      check_fail "${var} not set" "Edit .env and set a real value for ${var}"
    elif echo "$value" | grep -qiE "^(change_me|your_|todo|xxxx|placeholder|example|changeme|<)"; then
      check_fail "${var} is a placeholder value" \
        "Replace '${value}' with a real token in .env"
    else
      # Show masked value: first 4 chars + ****
      masked="${value:0:4}****"
      check_pass "${var}=${masked}"
    fi
  done
fi

# ─────────────────────────────────────────────────────────────────────
# 5. Summary
# ─────────────────────────────────────────────────────────────────────

TOTAL=$((PASS + FAIL + WARN))
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"

if [[ $FAIL -gt 0 ]]; then
  echo -e "  ${RED}${BOLD}❌ $FAIL/$TOTAL checks failed${NC}"
  [[ $WARN -gt 0 ]] && echo -e "  ${YELLOW}⚠  $WARN warnings${NC}"
  echo ""
  echo "  Fix the issues above, then re-run:"
  echo "    bash scripts/validate-local-env.sh"
  echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
  exit 1
else
  echo -e "  ${GREEN}${BOLD}✅ All $PASS checks passed${NC} ($WARN warnings)"
  echo ""
  echo "  Containers will provide: sqlite3, jq, logrotate, gh CLI, python3"
  echo ""
  echo "  Ready:  docker-compose up -d"
  echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
  exit 0
fi
