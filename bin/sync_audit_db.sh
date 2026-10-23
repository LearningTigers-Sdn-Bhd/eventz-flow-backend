#!/usr/bin/env bash
# frozen_string_literal: true
# ==============================================================================
# EventzFlow Local Audit Mirror Sync Script
# Dumps production EventzFlow PostgreSQL using read-only credentials (claude_auditor)
# and restores into a local mirror database (eventzflow_audit).
# ==============================================================================
set -euo pipefail

# Configuration
PROD_HOST="${PROD_DB_HOST:-46.202.166.235}"
PROD_PORT="${PROD_DB_PORT:-5434}"
PROD_USER="${PROD_DB_USER:-claude_auditor}"
PROD_DB="${PROD_DB_NAME:-eventz_flow_api_production}"
PROD_PASS="${PROD_DB_PASS:-LTigers82*}"

LOCAL_DB="${LOCAL_AUDIT_DB:-eventzflow_audit}"
DUMP_DIR="/tmp"
DUMP_FILE="${DUMP_DIR}/eventzflow_mirror_$(date +%Y%m%d_%H%M%S).dump"

# Locate PostgreSQL 18 tools (required to match server version 18.4)
PG_BIN="/opt/homebrew/opt/postgresql@18/bin"
if [ ! -d "$PG_BIN" ]; then
  if command -v pg_dump >/dev/null 2>&1; then
    PG_BIN="$(dirname "$(command -v pg_dump)")"
  else
    echo "Error: PostgreSQL client tools not found. Please install postgresql@18 via Homebrew."
    exit 1
  fi
fi

echo "=================================================="
echo " Starting EventzFlow Mirror Sync"
echo " Remote: ${PROD_USER}@${PROD_HOST}:${PROD_PORT}/${PROD_DB}"
echo " Local DB: ${LOCAL_DB}"
echo " Dump File: ${DUMP_FILE}"
echo "=================================================="

# 1. Dump from production (read-only)
echo "==> [1/4] Dumping production data..."
PGPASSWORD="${PROD_PASS}" "${PG_BIN}/pg_dump" \
  -h "${PROD_HOST}" \
  -p "${PROD_PORT}" \
  -U "${PROD_USER}" \
  -d "${PROD_DB}" \
  -Fc \
  -v \
  -f "${DUMP_FILE}"

echo "==> Dump finished: $(ls -lh "${DUMP_FILE}" | awk '{print $5}')"

# 2. Recreate local audit database
echo "==> [2/4] Resetting local mirror database (${LOCAL_DB})..."
dropdb --if-exists "${LOCAL_DB}"
createdb "${LOCAL_DB}"

# 3. Restore dump cleanly
echo "==> [3/4] Restoring into ${LOCAL_DB}..."
"${PG_BIN}/pg_restore" \
  --no-owner \
  --no-privileges \
  -d "${LOCAL_DB}" \
  "${DUMP_FILE}" || true

# 4. Analyze table statistics
echo "==> [4/4] Optimizing query planner statistics (ANALYZE)..."
psql -d "${LOCAL_DB}" -c "ANALYZE;"

# Cleanup temporary dump file
rm -f "${DUMP_FILE}"

echo "=================================================="
echo " Sync successfully completed!"
echo " Mirror available at: postgresql://localhost:5432/${LOCAL_DB}"
echo " Connect with: psql -d ${LOCAL_DB}"
echo "=================================================="
