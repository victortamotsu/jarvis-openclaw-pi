#!/bin/bash
#
# scripts/backup.sh — Weekly backup of Firefly database and OpenClaw data
#
# Task T055: Create weekly backup of SQLite DB and /mnt/external/openclaw/ directory
#
# Usage: bash scripts/backup.sh
#
# Creates dated backups in /mnt/external/backups/YYYY-WW/
# Scheduled via cron: 0 3 * * 0 bash /path/to/scripts/backup.sh (weekly on Sunday 03:00)

set -e

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"

# ─────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────

EXTERNAL_ROOT="/mnt/external"
FIREFLY_DATA="$EXTERNAL_ROOT/firefly"
OPENCLAW_DATA="$EXTERNAL_ROOT/openclaw"
BACKUP_ROOT="$EXTERNAL_ROOT/backups"

# Create dated backup directory: YYYY-WW format
YEAR=$(date '+%Y')
WEEK=$(date '+%V')
BACKUP_DIR="$BACKUP_ROOT/$YEAR-W$WEEK"

# Backup file names
BACKUP_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
FIREFLY_DUMP="$BACKUP_DIR/firefly-dump_$BACKUP_TIMESTAMP.sql"
OPENCLAW_TAR="$BACKUP_DIR/openclaw-backup_$BACKUP_TIMESTAMP.tar.gz"
MANIFEST="$BACKUP_DIR/manifest-$BACKUP_TIMESTAMP.txt"

# Retention policy
RETENTION_DAYS=90

# ─────────────────────────────────────────────────────────────────────
# Prerequisites Check
# ─────────────────────────────────────────────────────────────────────

log_section "Backup Initialization"

if [[ ! -d "$FIREFLY_DATA" ]]; then
  log_error "Firefly data directory not found: $FIREFLY_DATA"
  exit 1
fi

if [[ ! -d "$OPENCLAW_DATA" ]]; then
  log_error "OpenClaw data directory not found: $OPENCLAW_DATA"
  exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
log_info "Backup directory: $BACKUP_DIR"

# ─────────────────────────────────────────────────────────────────────
# Firefly Database Backup
# ─────────────────────────────────────────────────────────────────────

log_section "Firefly Database Backup"

# Find Firefly SQLite database
FIREFLY_DB=$(find "$FIREFLY_DATA" -name "*.sqlite" -o -name "*.sqlite3" -o -name "*.db" 2>/dev/null | head -1)

if [[ -z "$FIREFLY_DB" ]]; then
  log_warn "Firefly SQLite database not found, skipping database backup"
else
  log_info "Found Firefly database: $FIREFLY_DB"
  
  # Create SQL dump using sqlite3
  if command -v sqlite3 &> /dev/null; then
    log_info "Creating SQL dump from $FIREFLY_DB..."
    
    if sqlite3 "$FIREFLY_DB" ".dump" > "$FIREFLY_DUMP" 2>&1; then
      local dump_size=$(du -h "$FIREFLY_DUMP" | cut -f1)
      log_success "Database dump created: $FIREFLY_DUMP ($dump_size)"
    else
      log_error "Failed to create database dump"
      exit 1
    fi
  else
    log_warn "sqlite3 command not found, copying database file directly"
    cp "$FIREFLY_DB" "$FIREFLY_DUMP"
    log_success "Database file copied: $FIREFLY_DUMP"
  fi
fi

# ─────────────────────────────────────────────────────────────────────
# OpenClaw Directory Backup
# ─────────────────────────────────────────────────────────────────────

log_section "OpenClaw Data Backup"

log_info "Creating tar.gz backup of $OPENCLAW_DATA..."

if tar --exclude='node_modules' \
        --exclude='.git' \
        --exclude='*.log' \
        --exclude='__pycache__' \
        --exclude='.pytest_cache' \
        -czf "$OPENCLAW_TAR" \
        -C "$(dirname "$OPENCLAW_DATA")" \
        "$(basename "$OPENCLAW_DATA")" 2>&1 | tee -a "$LOG_FILE"; then
  local tar_size=$(du -h "$OPENCLAW_TAR" | cut -f1)
  log_success "OpenClaw backup created: $OPENCLAW_TAR ($tar_size)"
else
  log_error "Failed to create OpenClaw backup"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Create Manifest
# ─────────────────────────────────────────────────────────────────────

log_section "Backup Manifest"

{
  echo "Backup Manifest — $(date '+%Y-%m-%d %H:%M:%S')"
  echo "═══════════════════════════════════════════════════════════════════"
  echo ""
  echo "Backup Week: $YEAR-W$WEEK"
  echo "Backup Directory: $BACKUP_DIR"
  echo ""
  echo "Files:"
  if [[ -f "$FIREFLY_DUMP" ]]; then
    echo "  - $(basename "$FIREFLY_DUMP") ($(du -h "$FIREFLY_DUMP" | cut -f1))"
    echo "    Checksum: $(md5sum "$FIREFLY_DUMP" | cut -d' ' -f1)"
  fi
  echo "  - $(basename "$OPENCLAW_TAR") ($(du -h "$OPENCLAW_TAR" | cut -f1))"
  echo "    Checksum: $(md5sum "$OPENCLAW_TAR" | cut -d' ' -f1)"
  echo ""
  echo "Restoration Instructions:"
  echo "  1. Extract OpenClaw: tar -xzf $OPENCLAW_TAR -C /mnt/external/"
  echo "  2. Restore Firefly: sqlite3 /path/to/firefly.db < $FIREFLY_DUMP"
  echo ""
  echo "Backups older than $RETENTION_DAYS days will be automatically removed."
} > "$MANIFEST"

cat "$MANIFEST" | tee -a "$LOG_FILE"
log_success "Manifest saved: $MANIFEST"

# ─────────────────────────────────────────────────────────────────────
# Cleanup Old Backups (Retention Policy)
# ─────────────────────────────────────────────────────────────────────

log_section "Cleanup Old Backups"

log_info "Removing backups older than $RETENTION_DAYS days from $BACKUP_ROOT..."

CUTOFF_DATE=$(date -d "$RETENTION_DAYS days ago" '+%Y-%m-%d' 2>/dev/null || echo "")

if [[ -n "$CUTOFF_DATE" ]]; then
  find "$BACKUP_ROOT" -type d -name "*-W*" -exec bash -c '
    dir={};
    dir_date=$(ls -d "$dir" 2>/dev/null | head -1 | xargs stat -c %y 2>/dev/null | cut -d" " -f1 || echo "");
    if [[ -n "$dir_date" ]] && [[ "$dir_date" < "'$CUTOFF_DATE'" ]]; then
      echo "  Removing old backup: $dir";
      rm -rf "$dir";
    fi
  ' \; 2>/dev/null || log_warn "Could not parse old backup dates"
  
  log_success "Cleanup complete"
else
  log_info "Date calculation skipped (date command limitations)"
fi

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────

log_section "Backup Complete"

log_success "All backups completed successfully"
log_info "Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
log_info "Backup location: $BACKUP_DIR"
log_info "Log file: $LOG_FILE"

exit 0
