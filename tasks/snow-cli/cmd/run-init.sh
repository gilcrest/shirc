#!/usr/bin/env bash
set -euo pipefail

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 SQL_FILE"
    echo "Example: $0 tasks/snow-cli/sql/batch-1/001-init.sql"
    exit 1
fi

SQL_FILE="$1"

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "Error: SQL file not found at $SQL_FILE"
    exit 1
fi

# Check if required environment variables are set
REQUIRED_VARS=(
    "DEMO_WAREHOUSE_NAME"
    "YOUR_FIRST_NAME"
    "YOUR_LAST_NAME"
    "EXTERNAL_VOLUME_NAME"
    "INTERNAL_NAMED_STAGE"
    "DEMO_DATABASE_NAME"
    "DEMO_SCHEMA_NAME"
)

MISSING_VARS=()
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR:-}" ]; then
        MISSING_VARS+=("$VAR")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "Error: Missing required environment variables:"
    for VAR in "${MISSING_VARS[@]}"; do
        echo "  - $VAR"
    done
    exit 1
fi

# Strip leading "@" from INTERNAL_NAMED_STAGE if it exists
STAGE_NAME="${INTERNAL_NAMED_STAGE#@}"

echo "Running Snowflake initialization script..."
echo "  Warehouse: $DEMO_WAREHOUSE_NAME"
echo "  First Name: $YOUR_FIRST_NAME"
echo "  Last Name: $YOUR_LAST_NAME"
echo "  External Volume: $EXTERNAL_VOLUME_NAME"
echo "  Stage Name: $STAGE_NAME"
echo ""

# Run snow CLI with templating
snow sql -f "$SQL_FILE" \
  --enable-templating JINJA \
  -D demo_warehouse_name="$DEMO_WAREHOUSE_NAME" \
  -D your_first_name="$YOUR_FIRST_NAME" \
  -D your_last_name="$YOUR_LAST_NAME" \
  -D your_external_volume_name="$EXTERNAL_VOLUME_NAME" \
  -D demo_database_name="$DEMO_DATABASE_NAME" \
  -D demo_schema_name="$DEMO_SCHEMA_NAME" \
  -D demo_stage_name="$STAGE_NAME"

# Check if command was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "Initialization completed successfully"
    echo "Database: $DEMO_DATABASE_NAME"
    echo "Role: ${YOUR_FIRST_NAME}_${YOUR_LAST_NAME}_DATA_ENGINEER"
    echo "User: ${YOUR_FIRST_NAME}_${YOUR_LAST_NAME}_ENGINEER_USER"
else
    echo ""
    echo "Initialization failed"
    exit 1
fi
