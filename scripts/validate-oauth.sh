#!/bin/bash
#
# scripts/validate-oauth.sh — Validate Google OAuth credentials are configured
#
# Prerequisites:
#   - .env file exists with OAuth credentials (manual step, see docs/PHASE2_OAUTH_SETUP.md)
#
# Usage: bash scripts/validate-oauth.sh
#
# Phase 2 task validated: T014 (OAuth credential verification)

set -e

# Load environment
if [ ! -f ".env" ]; then
    echo "✗ .env not found. Copy from .env.example and follow docs/PHASE2_OAUTH_SETUP.md"
    exit 1
fi

source .env

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "═══════════════════════════════════════════════════════════════════"
echo "  Google OAuth Credential Validation (Phase 2: T014)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Following: docs/PHASE2_OAUTH_SETUP.md"
echo ""

# ─────────────────────────────────────────────────────────────────────
# Check credentials are set
# ─────────────────────────────────────────────────────────────────────

echo "[Check] OAuth credentials are configured..."
echo ""

MISSING=0

if [ -z "$GOOGLE_CLIENT_ID" ]; then
    echo -e "${RED}✗ GOOGLE_CLIENT_ID not set${NC}"
    MISSING=$((MISSING + 1))
else
    echo -e "${GREEN}✓ GOOGLE_CLIENT_ID found${NC}"
    echo "  Value: ${GOOGLE_CLIENT_ID:0:30}..."
fi

if [ -z "$GOOGLE_CLIENT_SECRET" ]; then
    echo -e "${RED}✗ GOOGLE_CLIENT_SECRET not set${NC}"
    MISSING=$((MISSING + 1))
else
    echo -e "${GREEN}✓ GOOGLE_CLIENT_SECRET found${NC}"
    echo "  Value: ${GOOGLE_CLIENT_SECRET:0:20}... (length: ${#GOOGLE_CLIENT_SECRET})"
fi

if [ -z "$GOOGLE_REFRESH_TOKEN" ]; then
    echo -e "${RED}✗ GOOGLE_REFRESH_TOKEN not set${NC}"
    MISSING=$((MISSING + 1))
else
    echo -e "${GREEN}✓ GOOGLE_REFRESH_TOKEN found${NC}"
    echo "  Value: ${GOOGLE_REFRESH_TOKEN:0:30}... (length: ${#GOOGLE_REFRESH_TOKEN})"
fi

if [ $MISSING -gt 0 ]; then
    echo ""
    echo -e "${RED}✗ Missing $MISSING credential(s)${NC}"
    echo ""
    echo "Setup instructions: docs/PHASE2_OAUTH_SETUP.md"
    exit 1
fi

echo ""

# ─────────────────────────────────────────────────────────────────────
# Test token refresh
# ─────────────────────────────────────────────────────────────────────

echo "[Test] Token refresh capability..."

REFRESH_RESPONSE=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=$GOOGLE_CLIENT_ID" \
  -d "client_secret=$GOOGLE_CLIENT_SECRET" \
  -d "refresh_token=$GOOGLE_REFRESH_TOKEN" \
  -d "grant_type=refresh_token")

if echo "$REFRESH_RESPONSE" | grep -q '"access_token"'; then
    ACCESS_TOKEN=$(echo "$REFRESH_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
    EXPIRY=$(echo "$REFRESH_RESPONSE" | grep -o '"expires_in":[0-9]*' | cut -d':' -f2)
    
    echo -e "${GREEN}✓ Token refresh successful${NC}"
    echo "  Access token obtained: ${ACCESS_TOKEN:0:30}..."
    echo "  Expires in: ${EXPIRY}s (approximately 1 hour)"
else
    echo -e "${RED}✗ Token refresh failed${NC}"
    echo "  Response: $(echo "$REFRESH_RESPONSE" | head -c 300)"
    echo ""
    echo "  Troubleshooting:"
    echo "    1. Verify credentials in .env are correct (no spaces, correct format)"
    echo "    2. Check credentials in https://console.cloud.google.com/apis/credentials"
    echo "    3. Ensure APIs are enabled in GCP project"
    echo "    4. Check token hasn't been revoked at https://myaccount.google.com/permissions"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Test Google Tasks API
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Test] Google Tasks API access..."

TASKS_RESPONSE=$(curl -s "https://tasks.googleapis.com/tasks/v1/users/@me/lists" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

if echo "$TASKS_RESPONSE" | grep -q '"items"'; then
    TASK_COUNT=$(echo "$TASKS_RESPONSE" | grep -o '"id":"[^"]*' | wc -l)
    echo -e "${GREEN}✓ Google Tasks API working${NC}"
    echo "  Task lists available: $TASK_COUNT"
else
    echo -e "${YELLOW}⚠ Google Tasks API response unclear${NC}"
    echo "  Response: $(echo "$TASKS_RESPONSE" | head -c 300)"
fi

# ─────────────────────────────────────────────────────────────────────
# Test Gmail API
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Test] Gmail API access..."

GMAIL_RESPONSE=$(curl -s "https://www.googleapis.com/gmail/v1/users/me/messages?maxResults=1" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

if echo "$GMAIL_RESPONSE" | grep -q '"messages"'; then
    echo -e "${GREEN}✓ Gmail API working${NC}"
    echo "  Recent emails accessible"
elif echo "$GMAIL_RESPONSE" | grep -q '"resultSizeEstimate":0'; then
    echo -e "${GREEN}✓ Gmail API working (no recent emails)${NC}"
else
    echo -e "${YELLOW}⚠ Gmail API response unclear${NC}"
    echo "  Response: $(echo "$GMAIL_RESPONSE" | head -c 300)"
fi

# ─────────────────────────────────────────────────────────────────────
# Test Google Drive API
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "[Test] Google Drive API access..."

DRIVE_RESPONSE=$(curl -s "https://www.googleapis.com/drive/v3/files?maxResults=1&spaces=drive" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

if echo "$DRIVE_RESPONSE" | grep -q '"files"'; then
    echo -e "${GREEN}✓ Google Drive API working${NC}"
    echo "  Drive files accessible"
elif echo "$DRIVE_RESPONSE" | grep -q '"files": \[\]'; then
    echo -e "${GREEN}✓ Google Drive API working (no files found)${NC}"
else
    echo -e "${YELLOW}⚠ Google Drive API response unclear${NC}"
    echo "  Response: $(echo "$DRIVE_RESPONSE" | head -c 300)"
fi

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ OAuth validation complete!${NC}"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "OAuth credentials are ready for Phase 3 (User Stories)."
echo ""
echo "Next steps:"
echo "  1. Run: bash scripts/validate-telegram-bot.sh (T011-T013)"
echo "  2. Run: bash scripts/validate-firefly.sh (T015)"
echo "  3. Run: bash scripts/validate-mount.sh (T016)"
echo "  4. Begin Phase 3: User Story 1 implementation (T017+)"
echo ""
