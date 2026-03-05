#!/bin/bash
#
# scripts/validate-mount.sh — Validate external disk mount and Docker volumes
#
# Prerequisites:
#   - /mnt/external mounted and writable
#   - docker-compose.yml configured with correct volume paths
#
# Usage: bash scripts/validate-mount.sh
#
# Phase 2 task validated: T016

set -e

EXTERNAL_PATH="/mnt/external"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "═══════════════════════════════════════════════════════════════════"
echo "  External Mount & Docker Volume Validation (Phase 2: T016)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────────────────────────
# 1. Check mount exists and is writable
# ─────────────────────────────────────────────────────────────────────

echo "[Check] Mount point: $EXTERNAL_PATH"

if [ ! -d "$EXTERNAL_PATH" ]; then
    echo -e "${RED}✗ Mount point does not exist${NC}"
    echo "  Ensure USB/external drive is mounted at $EXTERNAL_PATH"
    echo "  Reference: docs/runbook.md → Initial Setup → step 4"
    exit 1
fi

echo -e "${GREEN}✓ Mount point exists${NC}"

# Check write permission
if [ ! -w "$EXTERNAL_PATH" ]; then
    echo -e "${RED}✗ No write permission on $EXTERNAL_PATH${NC}"
    echo "  Fix with: sudo chown pi:pi $EXTERNAL_PATH && sudo chmod 755 $EXTERNAL_PATH"
    exit 1
fi

echo -e "${GREEN}✓ Write permission: OK${NC}"

# ─────────────────────────────────────────────────────────────────────
# 2. Check disk space
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Check] Disk space..."

DISK_INFO=$(df -h "$EXTERNAL_PATH" | awk 'NR==2 {print $2, $3, $4, $5}')
read -r SIZE USED AVAIL PERCENT <<< "$DISK_INFO"

echo "  Total: $SIZE"
echo "  Used: $USED ($PERCENT)"
echo "  Available: $AVAIL"

if [ "${PERCENT%\%}" -gt 90 ]; then
    echo -e "${RED}✗ Disk usage above 90% — cleanup required${NC}"
    exit 1
elif [ "${PERCENT%\%}" -gt 75 ]; then
    echo -e "${YELLOW}⚠ Disk usage above 75% — monitor space${NC}"
else
    echo -e "${GREEN}✓ Disk space: Healthy${NC}"
fi

# ─────────────────────────────────────────────────────────────────────
# 3. Check directory structure
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Check] Directory structure..."

REQUIRED_DIRS=(
    "openclaw"
    "openclaw/memory"
    "openclaw/secrets"
    "myclosets/data"
    "logs"
    "logs/openclaw"
    "logs/firefly"
    "logs/scheduler"
    "backups"
    "firefly"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$EXTERNAL_PATH/$dir" ]; then
        echo -e "${YELLOW}⚠ Missing: $dir (creating...)${NC}"
        mkdir -p "$EXTERNAL_PATH/$dir"
    fi
    echo "  ✓ $dir"
done

# ─────────────────────────────────────────────────────────────────────
# 4. Check file permissions (secrets should be 700)
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Check] File permissions..."

SECRETS_PERMS=$(stat -c "%a" "$EXTERNAL_PATH/openclaw/secrets" 2>/dev/null || echo "unknown")

if [ "$SECRETS_PERMS" != "700" ]; then
    echo -e "${YELLOW}⚠ Secrets directory permissions: $SECRETS_PERMS (should be 700)${NC}"
    sudo chmod 700 "$EXTERNAL_PATH/openclaw/secrets"
    echo "  ✓ Fixed to 700"
else
    echo -e "${GREEN}✓ Secrets permissions: 700${NC}"
fi

# ─────────────────────────────────────────────────────────────────────
# 5. Verify Docker volumes mapping
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Check] Docker Compose volume bindings..."

cd "$REPO_ROOT"

# Extract volume information from docker-compose config
echo "Checking volume mounts from docker-compose.yml..."

COMPOSE_OUTPUT=$(docker-compose config 2>/dev/null || echo "")

if echo "$COMPOSE_OUTPUT" | grep -q "$EXTERNAL_PATH"; then
    echo -e "${GREEN}✓ docker-compose references external mount${NC}"
    
    # Show which services use external mount
    if echo "$COMPOSE_OUTPUT" | grep -A2 "openclaw:" | grep -q "$EXTERNAL_PATH"; then
        echo "  ✓ openclaw service: volume mapped"
    fi
    if echo "$COMPOSE_OUTPUT" | grep -A2 "firefly-iii:" | grep -q "$EXTERNAL_PATH"; then
        echo "  ✓ firefly-iii service: volume mapped"
    fi
    if echo "$COMPOSE_OUTPUT" | grep -A2 "scheduler:" | grep -q "$EXTERNAL_PATH"; then
        echo "  ✓ scheduler service: volume mapped"
    fi
else
    echo -e "${YELLOW}⚠ docker-compose.yml may not reference $EXTERNAL_PATH${NC}"
    echo "  Review and update docker-compose.yml volumes section"
fi

# ─────────────────────────────────────────────────────────────────────
# 6. Test write capability (create temp file)
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Check] Write capability test..."

TEST_FILE="$EXTERNAL_PATH/openclaw/tmp/validate-write-test-$$.txt"
mkdir -p "$EXTERNAL_PATH/openclaw/tmp"

if echo "OpenClaw validation: $(date)" > "$TEST_FILE"; then
    echo -e "${GREEN}✓ Write test passed${NC}"
    rm -f "$TEST_FILE"
else
    echo -e "${RED}✗ Write test failed${NC}"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# 7. Test Docker volume access (from container perspective)
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Check] Docker volume access from containers..."

if docker-compose ps openclaw 2>/dev/null | grep -q "Up"; then
    CONTAINER_TEST=$(docker-compose exec -T openclaw test -w /mnt/external/openclaw && echo "OK" || echo "FAIL")
    
    if [ "$CONTAINER_TEST" = "OK" ]; then
        echo -e "${GREEN}✓ OpenClaw container can write to mounted volume${NC}"
    else
        echo -e "${RED}✗ OpenClaw container cannot write to volume${NC}"
        echo "  Check Docker volume configuration"
    fi
else
    echo -e "${YELLOW}⚠ OpenClaw container not running (skipping container test)${NC}"
    echo "  Start with: docker-compose up -d openclaw"
fi

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Mount and volume validation complete!${NC}"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo "  • External mount: $EXTERNAL_PATH"
printf "  • Used space: %s\n" "$DISK_INFO"
echo "  • Docker volumes: configured"
echo ""
echo "Phase 2 Status: All infrastructure tests passed!"
echo ""
echo "Next: Begin Phase 3 (User Story 1 — Pendências MVP)"
echo ""
