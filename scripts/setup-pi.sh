#!/bin/bash
#
# setup-pi.sh — Prepare Raspberry Pi 4 for deployment
#
# Prerequisites:
#   - Raspberry Pi OS (latest)
#   - User: pi (with sudo access)
#   - Docker + docker-compose installed
#   - External USB drive mounted
#
# Usage: bash scripts/setup-pi.sh
#
# Exits with: 0 (success), 1 (docker missing), 2 (mount missing), 3 (permission denied)

set -e  # Exit on error

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTERNAL_PATH="/mnt/external"
OPENCLAW_PATH="$EXTERNAL_PATH/openclaw"
SECRETS_PATH="$OPENCLAW_PATH/secrets"
LOG_PATH="$EXTERNAL_PATH/logs"

echo "═══════════════════════════════════════════════════════════════════"
echo "  Jarvis OpenClaw PI — Setup Script"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────────────────────────
# 1. Check Docker installation
# ─────────────────────────────────────────────────────────────────────

echo "✓ Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "✗ Docker not found. Install with: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

DOCKER_VERSION=$(docker --version | awk '{print $3}' | cut -d',' -f1)
echo "  ℹ Docker version: $DOCKER_VERSION"

if ! command -v docker-compose &> /dev/null; then
    echo "✗ docker-compose not found. Install with: pip3 install docker-compose"
    exit 1
fi

COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | cut -d',' -f1)
echo "  ℹ docker-compose version: $COMPOSE_VERSION"

# ─────────────────────────────────────────────────────────────────────
# 2. Check external mount exists
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "✓ Checking external mount ($EXTERNAL_PATH)..."
if [ ! -d "$EXTERNAL_PATH" ]; then
    echo "✗ Mount point $EXTERNAL_PATH not found."
    echo "  Follow Pi setup docs to mount USB drive at $EXTERNAL_PATH"
    exit 2
fi

DISK_USAGE=$(df -h "$EXTERNAL_PATH" | awk 'NR==2 {print $2}')
echo "  ℹ Available space: $DISK_USAGE"

# Check write permissions
if [ ! -w "$EXTERNAL_PATH" ]; then
    echo "✗ No write permission on $EXTERNAL_PATH"
    echo "  Run: sudo chown pi:pi $EXTERNAL_PATH && sudo chmod 755 $EXTERNAL_PATH"
    exit 3
fi

# ─────────────────────────────────────────────────────────────────────
# 3. Create directory structure
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "✓ Creating directory structure..."

mkdir -p "$OPENCLAW_PATH"/{memory,data,tmp} || true
mkdir -p "$SECRETS_PATH" || true
mkdir -p "{LOG_PATH"/{openclaw,firefly,scheduler,nginx} || true
mkdir -p "$EXTERNAL_PATH"/{backups,projects,firefly} || true

echo "  ✓ $OPENCLAW_PATH"
echo "  ✓ $SECRETS_PATH"
echo "  ✓ $LOG_PATH"

# ─────────────────────────────────────────────────────────────────────
# 4. Set permissions (security: secrets 700, logs 755)
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "✓ Setting permissions..."

chmod 700 "$SECRETS_PATH"
chmod 755 "$OPENCLAW_PATH"
chmod 755 "$LOG_PATH"
chmod 755 "$EXTERNAL_PATH"/{backups,projects}

echo "  ✓ Secrets: 700 (owner only)"
echo "  ✓ OpenClaw: 755 (owner+read)"
echo "  ✓ Logs: 755 (owner+read)"

# ─────────────────────────────────────────────────────────────────────
# 5. Install git-crypt (for .env encryption)
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "✓ Checking git-crypt installation..."

if ! command -v git-crypt &> /dev/null; then
    echo "  ℹ Installing git-crypt..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y git-crypt > /dev/null 2>&1
        echo "  ✓ git-crypt installed via apt"
    else
        echo "  ✗ APT not found. Install manually: brew install git-crypt"
    fi
else
    GITCRYPT_VERSION=$(git-crypt --version 2>&1 | awk '{print $NF}')
    echo "  ✓ git-crypt already installed: $GITCRYPT_VERSION"
fi

# ─────────────────────────────────────────────────────────────────────
# 6. Check and unlock .env via git-crypt
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "✓ Checking .env encryption status..."

if [ -f "$REPO_ROOT/.env" ]; then
    if git-crypt status "$REPO_ROOT/.env" > /dev/null 2>&1; then
        if [ ! -f "$REPO_ROOT/.env" ] || [ ! -r "$REPO_ROOT/.env" ]; then
            echo "  ℹ .env is encrypted. Unlocking..."
            cd "$REPO_ROOT"
            git-crypt unlock 2>&1 | head -5 || echo "  ℹ (GPG key required for unlock)"
        else
            echo "  ✓ .env is readable"
        fi
    fi
else
    echo "  ℹ .env not found. Copy from .env.example:"
    echo "     cp $REPO_ROOT/.env.example $REPO_ROOT/.env"
    echo "     # Edit with real credentials"
fi

# ─────────────────────────────────────────────────────────────────────
# 7. Validate Docker Compose configuration
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "✓ Validating Docker Compose configuration..."

cd "$REPO_ROOT"
if docker-compose config > /dev/null 2>&1; then
    echo "  ✓ docker-compose.yml is valid"
else
    echo "  ✗ docker-compose.yml has errors:"
    docker-compose config 2>&1 | head -10
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# 8. Create initial memory JSON files (if missing)
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "✓ Initializing memory storage..."

# owner-rules.json — establecimientos → member_id mapping
if [ ! -f "$OPENCLAW_PATH/memory/owner-rules.json" ]; then
    cat > "$OPENCLAW_PATH/memory/owner-rules.json" <<'EOF'
{
  "supermarket": "victor",
  "restaurant": "victor",
  "gas_station": "victor",
  "bookstore": "victor",
  "pharmacy": "victor",
  "travel_agency": "family",
  "school_fees": "family"
}
EOF
    echo "  ✓ owner-rules.json initialized"
fi

# travel-params.json — active travel searches
if [ ! -f "$OPENCLAW_PATH/memory/travel-params.json" ]; then
    cat > "$OPENCLAW_PATH/memory/travel-params.json" <<'EOF'
{
  "searches": []
}
EOF
    echo "  ✓ travel-params.json initialized"
fi

# quota-rules.json — spending limits per member
if [ ! -f "$OPENCLAW_PATH/memory/quota-rules.json" ]; then
    cat > "$OPENCLAW_PATH/memory/quota-rules.json" <<'EOF'
{
  "members": {
    "victor": {
      "monthly_limit": 3000,
      "current_spent": 0,
      "reset_date": "2026-04-01"
    },
    "family": {
      "monthly_limit": 5000,
      "current_spent": 0,
      "reset_date": "2026-04-01"
    }
  }
}
EOF
    echo "  ✓ quota-rules.json initialized"
fi

# serp-usage.json — SerpAPI monthly quota tracking (T107 — Phase 10)
if [ ! -f "$OPENCLAW_PATH/memory/serp-usage.json" ]; then
    cp "$REPO_ROOT/templates/memory/serp-usage.json" "$OPENCLAW_PATH/memory/serp-usage.json"
    echo "  ✓ serp-usage.json initialized (SerpAPI quota tracker, 0/250)"
fi

chmod 600 "$OPENCLAW_PATH/memory"/*.json

# ─────────────────────────────────────────────────────────────────────
# 9. Setup cron container
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "✓ Preparing cron configuration..."

if [ -f "$REPO_ROOT/config/crontabs/jarvis" ]; then
    echo "  ✓ config/crontabs/jarvis found"
else
    echo "  ℹ config/crontabs/jarvis not yet created (will be created in Phase 1)"
fi

# ─────────────────────────────────────────────────────────────────────
# 10. Pre-pull Docker images (optional, speeds up first deployment)
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "✓ Pre-pulling Docker images (optional)..."
echo "  ℹ This may take 2-5 minutes on first run..."

docker-compose pull --ignore-pull-failures > /dev/null 2>&1 || echo "  ℹ (Some images may not exist yet)"

# ─────────────────────────────────────────────────────────────────────
# 11. Summary & next steps
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  ✓ Setup Complete!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo ""
echo "1. Edit credentials:"
echo "   nano .env"
echo ""
echo "2. Start containers:"
echo "   docker-compose up -d"
echo ""
echo "3. Verify health:"
echo "   docker-compose ps"
echo "   docker-compose logs -f openclaw"
echo ""
echo "4. Test Telegram bot:"
echo "   docker-compose exec openclaw openclaw agent --message 'ping'"
echo ""
echo "📖 Full documentation: docs/runbook.md"
echo ""
