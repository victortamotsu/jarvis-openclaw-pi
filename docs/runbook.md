# docs/runbook.md — Operation Playbook for Jarvis

**Last Updated**: 2026-03-04  
**Maintainer**: Victor  
**Status**: DRAFT (Phase 1 — Infrastructure setup)

---

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Container Management](#container-management)
3. [Telegram Bot Configuration](#telegram-bot-configuration)
4. [Google OAuth Setup](#google-oauth-setup)
5. [Common Operations](#common-operations)
6. [Troubleshooting](#troubleshooting)
7. [Backup & Recovery](#backup--recovery)
8. [WhatsApp Re-pairing](#whatsapp-re-pairing)

---

## Initial Setup

### 1. Clone Repository

```bash
cd /home/pi  # or your desired location
git clone https://github.com/victortamotsu/jarvis-openclaw-pi.git
cd jarvis-openclaw-pi
```

### 2. Setup git-crypt

**First time** (encryption setup):

```bash
# Initialize git-crypt
git-crypt init

# Generate GPG key (if not already done)
gpg --gen-key
# Follow prompts (your email, name, passphrase)

# Add your GPG key to git-crypt
git-crypt add-gpg-user YOUR_EMAIL@localhost

# Define what will be encrypted (.gitattributes already set)
# Pattern: *.env filter=git-crypt diff=git-crypt
```

**Unlock existing repo**:

```bash
git-crypt unlock
# Will use your GPG key to decrypt .env
```

### 3. Create .env from Template

```bash
cp .env.example .env
nano .env  # Edit with real credentials
```

**Required credentials**:
- `GITHUB_TOKEN` — GitHub personal access token (create at https://github.com/settings/tokens)
- `TELEGRAM_BOT_TOKEN` — From @BotFather on Telegram
- `TELEGRAM_CHAT_ID` — Your personal chat ID with bot (message bot, then `curl https://api.telegram.org/bot$TOKEN/getUpdates` to find)
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN` — OAuth credentials (see Google OAuth Setup)
- `FIREFLY_TOKEN` — From Firefly III admin panel
- `FIREFLY_URL` — Your Firefly III URL (default: `http://firefly-iii:8080`)

### 4. Create External Mount Directories

```bash
# Create directories on external hard drive
mkdir -p /mnt/external/{openclaw,openclaw/memory,openclaw/secrets,logs,logs/openclaw,logs/firefly,logs/scheduler,backups,firefly}

# Set permissions
chmod 755 /mnt/external
chmod 700 /mnt/external/openclaw/secrets
```

### 5. Start Containers

```bash
docker-compose up -d

# Verify all 4 services are running
docker-compose ps
```

Expected output:
```
NAME                  STATUS
firefly-iii           Up (healthy)
openclaw-gateway      Up (healthy)
mcporter-firefly      Up
jarvis-scheduler      Up
```

---

## Container Management

### Check Status

```bash
docker-compose ps
docker-compose logs -f openclaw  # Follow logs for debugging
```

### Restart Individual Service

```bash
docker-compose restart openclaw
# Wait for health check to pass (~60s)
```

### Restart All Services

```bash
docker-compose down
docker-compose up -d
```

### View Logs

```bash
# Last 50 lines
docker-compose logs --tail=50 openclaw

# Real-time
docker-compose logs -f openclaw

# Specific time range (requires journaling setup)
docker-compose logs --since 2h openclaw
```

---

## Telegram Bot Configuration

### 1. Create Bot with BotFather

1. Open Telegram, find `@BotFather`
2. `/newbot`
3. Enter name: "Jarvis"
4. Enter username: "victor_jarvis_bot" (or unique name)
5. Copy **Token** → paste in `.env` as `TELEGRAM_BOT_TOKEN`

### 2. Get Your Chat ID

```bash
# After you message the bot for the first time:
curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates" | jq '.result[0].message.chat.id'

# Copy the number → paste in `.env` as `TELEGRAM_CHAT_ID`
```

### 3. Verify Connection

```bash
docker-compose exec openclaw openclaw agent --message "ping"
# Should respond with "pong" or similar
```

---

## Google OAuth Setup

### 1. Create OAuth Credentials

1. Go to https://console.cloud.google.com
2. Create new project: "Jarvis AI"
3. Enable APIs:
   - Gmail API
   - Google Tasks API
   - Google Drive API
4. Create OAuth 2.0 credential (Desktop application)
5. Download JSON file
6. Extract `client_id`, `client_secret`

### 2. Generate Refresh Token

**First time** (interactive):

```bash
# Run this on a machine with a browser
python3 scripts/get_oauth_token.py \
  --client-id YOUR_CLIENT_ID \
  --client-secret YOUR_CLIENT_SECRET \
  --scopes gmail.readonly tasks drive.file
```

This will:
1. Open browser to Google login
2. Ask for permissions
3. Return refresh token in terminal

### 3. Store Credentials

```bash
# Create secrets directory
mkdir -p /mnt/external/openclaw/secrets
chmod 700 /mnt/external/openclaw/secrets

# Create google-tokens.json
cat > /mnt/external/openclaw/secrets/google-tokens.json <<EOF
{
  "type": "authorized_user",
  "client_id": "$GOOGLE_CLIENT_ID",
  "client_secret": "$GOOGLE_CLIENT_SECRET",
  "refresh_token": "$GOOGLE_REFRESH_TOKEN"
}
EOF

chmod 600 /mnt/external/openclaw/secrets/google-tokens.json
```

### 4. Test Connection

```bash
# Your curl command to test Google Tasks API
curl "https://tasks.googleapis.com/tasks/v1/users/@me/lists" \
  -H "Authorization: Bearer $GOOGLE_REFRESH_TOKEN"
```

---

## Common Operations

### Manual Email Check

```bash
docker-compose exec openclaw \
  openclaw agent --message "Verificar novos emails"
```

### Manual WhatsApp Sync

```bash
docker-compose exec openclaw \
  openclaw agent --message "Verificar mensagens WhatsApp"
```

### Run Import Pipeline

```bash
bash scripts/import-statement.sh
```

### View Cron Jobs

```bash
docker-compose exec scheduler cat /var/spool/cron/crontabs/root
```

### Add Manual Cron Job

Edit `config/crontabs/jarvis` and restart scheduler:

```bash
docker-compose restart scheduler
```

---

## Troubleshooting

### "Container exited with code 127"

**Cause**: Command not found in container  
**Fix**:
```bash
docker-compose logs scheduler
# Check if apk add worked
docker-compose exec scheduler apk list | grep bash
```

### "OAuth token expired"

**Symptom**: Gmail API returns 401 error  
**Fix**:
```bash
# Re-generate refresh token (see Google OAuth Setup)
# Update .env with new token
# Restart openclawcontainer
docker-compose restart openclaw
```

### "Firefly connection refused"

**Symptom**: `pipeline/firefly_importer.py` fails  
**Fix**:
```bash
# Check Firefly is running
docker-compose ps firefly-iii
docker-compose logs firefly-iii

# Check network connectivity
docker-compose exec openclaw ping http://firefly-iii:8080
```

### "WhatsApp: QR code required"

**Symptom**: WhatsApp skill not working  
**Fix**: See [WhatsApp Re-pairing](#whatsapp-re-pairing) section

---

## Backup & Recovery

### Manual Backup

```bash
bash scripts/backup.sh

# Check backup
ls -lah /mnt/external/backups/
```

### Restore from Backup

**For Firefly III (SQLite)**:

```bash
# Stop containers
docker-compose down

# Restore SQLite database
cp /mnt/external/backups/YYYY-MM-DD/firefly.db \
   /mnt/external/firefly/firefly.db

# Restart
docker-compose up -d
```

**For OpenClaw config**:

```bash
tar -xzf /mnt/external/backups/YYYY-MM-DD/openclaw.tar.gz \
    -C /mnt/external/
```

### Recovery Test

Monthly (first Monday):

```bash
# Run mini-test: pause + restart openclaw
docker-compose pause openclaw
sleep 5
docker-compose unpause openclaw

# Check logs
docker-compose logs openclawlast 20 lines
```

---

## WhatsApp Re-pairing

**When needed**: 
- First setup
- WhatsApp logs out on phone
- QR code expired

**Steps**:

1. Open Telegram and message Jarvis: `/whatsapp-pair`

2. Agent will request QR code display:
   ```
   🔐 WHATSAPP PAIRING REQUIRED
   Check your console for QR code.
   Scan with WhatsApp phone: Settings → Linked Devices
   ```

3. On Pi, you'll see QR code in terminal (or at `http://localhost:3000/qr`):
   ```bash
   docker-compose logs -f openclaw | grep -i qr
   ```

4. Scan QR on phone → WhatsApp paired

5. Send confirmation to Jarvis:
   ```
   /whatsapp-paired
   ```

---

## Performance Tuning

### Memory Management

Current limits (docker-compose.yml):
- OpenClaw: 1GB
- Firefly III: 512MB (auto)
- mcporter: 128MB
- Scheduler: 64MB
- **Total**: ~2.1 GB on Pi 4GB

Monitor:
```bash
docker stats
```

If hitting memory ceiling:
- Reduce OpenClaw limit to 800MB
- Or split workloads (schedule less frequent checks)

### Token Efficiency

Optimize prompts in `config/openclaw/agents/jarvis/SOUL.md`:
- Classificação: ~200 tokens
- Extração: ~500 tokens
- Análise complexa: ~1500 tokens

Track weekly consumption (T065):
```bash
grep "tokens_used" /mnt/external/logs/openclaw/*.log | awk -F: '{sum+=$NF} END {print sum}'
```

---

## Operational Playbooks (Phase 7: T057)

### 1. Container Restart Playbook

**When to use**: Container crashes, hung process, memory leak

**Single container restart**:
```bash
# Restart just OpenClaw
docker-compose restart openclaw

# Restart Firefly
docker-compose restart firefly-iii

# Monitor logs while restarting
docker-compose logs -f openclaw
```

**Full service restart** (clears all state):
```bash
# Graceful shutdown + restart
docker-compose down
sleep 10
docker-compose up -d

# Verify all containers healthy
docker ps -a
docker-compose ps
```

**Force restart** (if containers stuck):
```bash
# Kill all containers
docker-compose kill

# Remove containers (not volumes)
docker-compose rm -f

# Bring up fresh
docker-compose up -d
```

### 2. Backup Restoration Playbook

**Prerequisites**:
- Know backup date in format `YYYY-WW` (year-week)
- Backup location: `/mnt/external/backups/YYYY-WW/`

**Restore Firefly III Database**:
```bash
BACKUP_DATE="2026-W09"  # Change to desired week
BACKUP_DIR="/mnt/external/backups/$BACKUP_DATE"

# Check available backups
ls -la /mnt/external/backups/

# Stop openclaw (it may hold Firefly connections)
docker-compose stop openclaw

# Find most recent Firefly dump
FIREFLY_DUMP=$(ls -t "$BACKUP_DIR"/firefly-dump_*.sql | head -1)

# Restore (choose one):

# Option A: Restore from SQL dump
docker-compose exec firefly-iii sqlite3 /data/firefly.db < "$FIREFLY_DUMP"

# Option B: Restore from tar backup (replaces entire Firefly data)
tar -xzf "$BACKUP_DIR"/firefly-backup_*.tar.gz -C /mnt/external/

# Restart services
docker-compose up -d

# Verify Firefly is healthy
curl http://localhost:8080/ | head -20
```

**Restore OpenClaw Configuration**:
```bash
BACKUP_DATE="2026-W09"
BACKUP_DIR="/mnt/external/backups/$BACKUP_DATE"

# Extract backup to temporary location
mkdir -p /tmp/openclaw-restore
tar -xzf "$BACKUP_DIR"/openclaw-backup_*.tar.gz -C /tmp/openclaw-restore

# Review what will be restored
ls -la /tmp/openclaw-restore/openclaw/

# Backup current configuration first
cp -r /mnt/external/openclaw /mnt/external/openclaw.backup.$(date +%s)

# Restore (selective restoration recommended)
# Option: Copy specific files only
cp /tmp/openclaw-restore/openclaw/memory/*.json \
   /mnt/external/openclaw/memory/

# Restart openclaw with restored config
docker-compose restart openclaw

# Verify logs for errors
docker-compose logs openclaw | tail -50
```

### 3. OAuth Token Renewal Playbook

**When needed**: Token expiration, permission revocation, re-authentication

**Google OAuth tokens** (Google Drive, Gmail, Google Tasks):
```bash
# Clear cached tokens (forces re-auth)
rm -f /mnt/external/openclaw/tokens/google_*

# Restart OpenClaw (will trigger OAuth flow)
docker-compose restart openclaw

# Verify new token obtained
ls -la /mnt/external/openclaw/tokens/

# Monitor logs for auth success
docker-compose logs openclaw | grep -i "oauth\|auth\|token"
```

**Firefly Bearer Token Renewal**:
```bash
# If using Firefly self-hosted, regenerate API token:
# 1. SSH into Pi
# 2. Access Firefly UI: http://localhost:8080/
# 3. Admin → Settings → Personal Access Tokens
# 4. Revoke old token, create new one
# 5. Update .env file:
export FIREFLY_TOKEN="new_token_here"

# Restart OpenClaw to use new token
docker-compose restart openclaw

# Test connection
docker-compose exec openclaw curl -H "Authorization: Bearer $FIREFLY_TOKEN" \
  http://firefly-iii:8080/api/v1/about
```

**GitHub Token Renewal**:
```bash
# On Pi, regenerate token via GitHub CLI
gh auth refresh

# Or revoke and create new token:
# 1. Go to github.com/settings/tokens
# 2. Click "Regenerate token" on existing token
# 3. Copy new token
# 4. Update .env:
export GITHUB_TOKEN="ghp_new_token_here"

# Restart OpenClaw
docker-compose restart openclaw

# Test with gh CLI
gh repo list
```

### 4. WhatsApp Re-pairing Playbook (Extended)

**When to use**: WhatsApp logs out, device session expires, need to re-scan

**Full re-pairing process**:
```bash
# 1. Trigger re-pairing from Telegram
# Send command to Jarvis: /whatsapp-reset

# 2. Monitor terminal for QR code
docker-compose logs -f openclaw | grep -i "qr\|scan"

# 3. On your phone:
#    - Open WhatsApp
#    - Settings → Linked Devices
#    - Scan QR code shown in logs

# 4. Verify connection established
docker-compose logs openclaw | grep -i "connected\|authenticated"

# 5. Test message
# Send test message from your WhatsApp to Jarvis number
# Verify it appears in OpenClaw logs

# 6. Re-configure contacts (if needed)
# Edit config/openclaw/agents/jarvis/SOUL.md
# Update WhatsApp contact mappings
```

**Troubleshooting WhatsApp**:
```bash
# Clear WhatsApp session
docker-compose exec openclaw \
  rm -rf /data/openclaw/whatsapp-session

# Restart OpenClaw
docker-compose restart openclaw

# Monitor new pairing
docker-compose logs -f openclaw
```

### 5. Logging & Diagnostics Playbook

**View all logs in real-time**:
```bash
# Follow OpenClaw logs
docker-compose logs -f openclaw

# Follow with timestamp + last 50 lines
docker-compose logs -f --timestamps openclaw | tail -100

# View all service logs (multiplexed)
docker-compose logs -f
```

**Parse structured logs from scripts**:
```bash
# View import script logs
cat /mnt/external/logs/import-statement/$(date +%Y-%m-%d).log

# View travel search logs
cat /mnt/external/logs/travel-search/$(date +%Y-%m-%d).log

# View health check logs
cat /mnt/external/logs/health-check/$(date +%Y-%m-%d).log

# Search for errors across all logs
grep -r "ERROR" /mnt/external/logs/ --include="*.log" |
  sort -r | head -20
```

**Check disk space usage**:
```bash
# Overall disk usage
df -h /mnt/external/

# Largest log files
du -sh /mnt/external/logs/* | sort -hr | head -10

# Backup size
du -sh /mnt/external/backups/

# Suggest cleanup if needed
find /mnt/external/logs -name "*.log" -mtime +90 -delete
```

### 6. Recovery/Uptime Testing Playbook

**T058: Monthly recovery test** (first Monday 2am):
```bash
# 1. Simulate container failure
docker-compose pause openclaw
sleep 5

# 2. Restart (should be automatic via restart: unless-stopped)
docker-compose unpause openclaw

# 3. Verify recovery
docker-compose ps
docker-compose logs openclaw | tail -20

# 4. Check health endpoint
curl -v http://127.0.0.1:3000/health

# 5. Send test message via Telegram
# Command: /status
# Expected: ✅ All services healthy

# 6. Log test result
echo "Recovery test [$(date '+%Y-%m-%d %H:%M')] PASSED" >> /mnt/external/logs/recovery-tests.log
```

**Container restart verification**:
```bash
# Check if restart policy is active
docker inspect openclaw-gateway | grep -i "restart"

# Expected output:
# "RestartPolicy": {"Name": "unless-stopped", ...}

# Force test: stop container, verify auto-restart
docker stop openclaw-gateway
sleep 10
docker ps | grep openclaw-gateway  # Should show as running

# If container doesn't restart automatically, fix docker-compose.yml
# Ensure: restart: unless-stopped
```

---

## Security & Compliance Checklist (Phase 7)

- [ ] Logs are being rotated weekly (check `/mnt/external/logs/*/`)
- [ ] Backups execute weekly (check `/mnt/external/backups/YYYY-WW/`)
- [ ] Health checks run every 5 minutes (check crontab)
- [ ] No PII logged (grep credentials/passwords in logs)
- [ ] git-crypt protecting `.env` file
- [ ] All containers use `restart: unless-stopped`
- [ ] Token expiration dates tracked (renewals scheduled quarterly)

---

**Runbook Status**: COMPLETE (Phase 7)  
**Last Updated**: 2026-03-04  
**Sections**: Initial Setup, Container Management, OAuth, Operations, Backup/Recovery, WhatsApp, Diagnostics, Recovery Testing
