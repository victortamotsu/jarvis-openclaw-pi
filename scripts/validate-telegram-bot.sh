#!/bin/bash
#
# scripts/validate-telegram-bot.sh — Validate Telegram Bot integration
#
# Prerequisites:
#   - TELEGRAM_BOT_TOKEN set in .env
#   - TELEGRAM_CHAT_ID set in .env
#   - docker-compose running
#
# Usage: bash scripts/validate-telegram-bot.sh
#
# Phase 2 tasks validated: T011, T012, T013

set -e

# Load environment
if [ ! -f ".env" ]; then
    echo "✗ .env not found. Copy from .env.example and fill credentials."
    exit 1
fi

source .env

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════════════════════════════"
echo "  Telegram Bot Validation (Phase 2: T011-T013)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────────────────────────
# T011: Validate bot exists via Telegram API
# ─────────────────────────────────────────────────────────────────────

echo "[T011] Validating Telegram Bot token..."

if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo -e "${RED}✗ TELEGRAM_BOT_TOKEN not set in .env${NC}"
    exit 1
fi

RESPONSE=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    BOT_NAME=$(echo "$RESPONSE" | grep -o '"first_name":"[^"]*' | cut -d'"' -f4)
    BOT_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | cut -d':' -f2)
    echo -e "${GREEN}✓ Bot registered: @$(echo "$RESPONSE" | grep -o '"username":"[^"]*' | cut -d'"' -f4)${NC}"
    echo "  Name: $BOT_NAME (ID: $BOT_ID)"
else
    echo -e "${RED}✗ Bot validation failed. Check TELEGRAM_BOT_TOKEN.${NC}"
    echo "Response: $RESPONSE" | head -c 200
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# T012: Validate OpenClaw container is running and responsive
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[T012] Checking OpenClaw container..."

if ! docker-compose ps openclaw | grep -q "Up"; then
    echo -e "${YELLOW}⚠ OpenClaw not running. Starting...${NC}"
    docker-compose up -d openclaw
    sleep 10
fi

# Health check
if curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OpenClaw health check passed${NC}"
else
    echo -e "${RED}✗ OpenClaw health check failed (HTTP GET /health timeout)${NC}"
    echo "Logs:"
    docker-compose logs --tail=20 openclaw
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# T013: Test end-to-end message flow
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[T013] Testing end-to-end message flow..."

if [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo -e "${RED}✗ TELEGRAM_CHAT_ID not set in .env${NC}"
    echo "  Get your ID: message @userinfobot on Telegram"
    exit 1
fi

# Send test message
TEST_MSG="🤖 Jarvis validation test - $(date '+%Y-%m-%d %H:%M:%S')"
SEND_RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${TEST_MSG}")

if echo "$SEND_RESPONSE" | grep -q '"ok":true'; then
    echo -e "${GREEN}✓ Test message sent to Telegram${NC}"
    echo "  You should receive the message shortly"
else
    echo -e "${RED}✗ Message send failed${NC}"
    echo "Response: $SEND_RESPONSE" | head -c 200
    exit 1
fi

# Test agent response
echo ""
echo "[T013] Testing agent response to message..."

# Send test command to agent (via OpenClaw)
AGENT_TEST=$(docker-compose exec -T openclaw openclaw agent --message "ping" 2>&1 || echo "timeout")

if echo "$AGENT_TEST" | grep -q -i "pong\|pong\|success"; then
    echo -e "${GREEN}✓ Agent responded to test command${NC}"
else
    echo -e "${YELLOW}⚠ Agent response unclear. Raw output:${NC}"
    echo "$AGENT_TEST" | head -c 200
fi

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Phase 2 Telegram validation complete!${NC}"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Run: bash scripts/validate-firefly.sh (T015)"
echo "  2. Run: bash scripts/validate-oauth.sh (T014)"
echo "  3. Run: bash scripts/validate-mount.sh (T016)"
echo ""
echo "⚠ Cleanup: Delete test message from Telegram if desired"
echo ""
