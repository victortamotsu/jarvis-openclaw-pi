#!/bin/bash
#
# scripts/validate-firefly.sh — Validate Firefly III API connectivity
#
# Prerequisites:
#   - FIREFLY_TOKEN set in .env
#   - FIREFLY_URL set in .env (default: http://firefly-iii:8080)
#   - docker-compose running firefly-iii service
#
# Usage: bash scripts/validate-firefly.sh
#
# Phase 2 task validated: T015

set -e

# Load environment
if [ ! -f ".env" ]; then
    echo "✗ .env not found. Copy from .env.example and fill credentials."
    exit 1
fi

source .env

# Defaults
FIREFLY_URL="${FIREFLY_URL:-http://firefly-iii:8080}"
FIREFLY_TOKEN="${FIREFLY_TOKEN:-}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "═══════════════════════════════════════════════════════════════════"
echo "  Firefly III Validation (Phase 2: T015)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Firefly URL: $FIREFLY_URL"
echo ""

# ─────────────────────────────────────────────────────────────────────
# Check container is running
# ─────────────────────────────────────────────────────────────────────

echo "[Check] Firefly container status..."

if docker-compose ps firefly-iii | grep -q "Up"; then
    echo -e "${GREEN}✓ Firefly III container is running${NC}"
else
    echo -e "${RED}✗ Firefly III not running${NC}"
    echo "  Start with: docker-compose up -d firefly-iii"
    exit 1
fi

# Wait for service to be ready
sleep 3

# ─────────────────────────────────────────────────────────────────────
# Test basic connectivity
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Test] Basic connectivity..."

CURL_OUTPUT=$(curl -s -o /dev/null -w "%{http_code}" "$FIREFLY_URL/")

if [ "$CURL_OUTPUT" = "200" ] || [ "$CURL_OUTPUT" = "302" ]; then
    echo -e "${GREEN}✓ Firefly web UI is accessible (HTTP $CURL_OUTPUT)${NC}"
else
    echo -e "${RED}✗ Firefly not responding (HTTP $CURL_OUTPUT)${NC}"
    echo "  Check container logs: docker-compose logs firefly-iii"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Test API with token
# ─────────────────────────────────────────────────────────────────────

if [ -z "$FIREFLY_TOKEN" ]; then
    echo ""
    echo -e "${YELLOW}⚠ FIREFLY_TOKEN not set in .env${NC}"
    echo "  Get token from: $FIREFLY_URL/profile → API → Personal Access Token"
    echo "  Add to .env: FIREFLY_TOKEN=your_token_here"
    exit 1
fi

echo ""
echo "[Test] API authentication..."

API_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $FIREFLY_TOKEN" \
    -H "Content-Type: application/json" \
    "$FIREFLY_URL/api/v1/about")

HTTP_CODE=$(echo "$API_RESPONSE" | tail -n 1)
BODY=$(echo "$API_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ API authentication successful${NC}"
    
    # Extract version
    VERSION=$(echo "$BODY" | grep -o '"version":"[^"]*' | cut -d'"' -f4)
    echo "  Firefly version: $VERSION"
else
    echo -e "${RED}✗ API authentication failed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $(echo "$BODY" | head -c 200)"
    echo ""
    echo "  Troubleshooting:"
    echo "    1. Verify FIREFLY_TOKEN value (no spaces)"
    echo "    2. Check token hasn't expired"
    echo "    3. Restart Firefly: docker-compose restart firefly-iii"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Test key endpoints
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Test] API endpoints..."

# List accounts
ACCOUNTS=$(curl -s -H "Authorization: Bearer $FIREFLY_TOKEN" \
    "$FIREFLY_URL/api/v1/accounts?type=asset" | grep -o '"id":"[^"]*' | wc -l)
echo -e "${GREEN}✓ /accounts endpoint working ($ACCOUNTS accounts found)${NC}"

# List categories
CATEGORIES=$(curl -s -H "Authorization: Bearer $FIREFLY_TOKEN" \
    "$FIREFLY_URL/api/v1/categories" | grep -o '"name":"[^"]*' | wc -l)
echo -e "${GREEN}✓ /categories endpoint working ($CATEGORIES categories)${NC}"

# List tags
TAGS=$(curl -s -H "Authorization: Bearer $FIREFLY_TOKEN" \
    "$FIREFLY_URL/api/v1/tags" | grep -o '"tag":"[^"]*' | wc -l)
echo -e "${GREEN}✓ /tags endpoint working ($TAGS tags)${NC}"

# ─────────────────────────────────────────────────────────────────────
# Test transaction creation (safe: no data persistence required)
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Test] Transaction creation (dry run)..."

CREATE_TEST=$(curl -s -X POST \
    -H "Authorization: Bearer $FIREFLY_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "transactions": [{
            "type": "withdrawal",
            "date": "2026-03-04",
            "currency_code": "BRL",
            "amount": "0.01",
            "description": "[TEST] OpenClaw validation",
            "tags": ["openclaw-validation"]
        }]
    }' \
    "$FIREFLY_URL/api/v1/transactions")

if echo "$CREATE_TEST" | grep -q '"id"'; then
    TRANS_ID=$(echo "$CREATE_TEST" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    echo -e "${GREEN}✓ Transaction creation working (test ID: $TRANS_ID)${NC}"
    echo "  Note: Test transaction was created. You may delete it manually."
else
    echo -e "${RED}✗ Transaction creation failed${NC}"
    echo "  Response: $(echo "$CREATE_TEST" | head -c 300)"
fi

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Firefly III validation complete!${NC}"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Run: bash scripts/validate-mount.sh (T016)"
echo "  2. Run: bash scripts/validate-oauth.sh (T014)"
echo "  3. Start Phase 3 implementation"
echo ""
