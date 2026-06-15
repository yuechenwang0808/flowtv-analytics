#!/bin/bash
# ============================================================
# 02_load_data.sh
# Loads all FlowTV CSVs into the 'flowtv' Postgres database.
# Run from anywhere — paths are absolute via $DATA_DIR.
# ============================================================

set -e  # exit on first error

# Resolve the project root (parent of this script's directory)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
DATA_DIR="$PROJECT_ROOT/data"

echo "📁 Data directory: $DATA_DIR"
echo ""

# Tables in load order (respects FK-ish ordering for sanity)
TABLES=(
  "plans"
  "content_catalog"
  "users"
  "experiments"
  "experiment_assignments"
  "subscriptions"
  "events"
  "sessions"
  "content_views"
)

for table in "${TABLES[@]}"; do
  csv_file="$DATA_DIR/${table}.csv"
  if [ ! -f "$csv_file" ]; then
    echo "❌ Missing: $csv_file"
    exit 1
  fi

  # Get file size for the progress line
  size=$(du -h "$csv_file" | cut -f1)
  echo "📥 Loading $table ($size)..."

  psql -d flowtv -c "\copy $table FROM '$csv_file' DELIMITER ',' CSV HEADER"
done

echo ""
echo "✅ All tables loaded. Row counts:"
psql -d flowtv -c "
SELECT 'plans'                  AS table_name, COUNT(*) FROM plans
UNION ALL SELECT 'content_catalog',          COUNT(*) FROM content_catalog
UNION ALL SELECT 'users',                    COUNT(*) FROM users
UNION ALL SELECT 'experiments',              COUNT(*) FROM experiments
UNION ALL SELECT 'experiment_assignments',   COUNT(*) FROM experiment_assignments
UNION ALL SELECT 'subscriptions',            COUNT(*) FROM subscriptions
UNION ALL SELECT 'events',                   COUNT(*) FROM events
UNION ALL SELECT 'sessions',                 COUNT(*) FROM sessions
UNION ALL SELECT 'content_views',            COUNT(*) FROM content_views;
"
