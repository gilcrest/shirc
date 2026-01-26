#!/usr/bin/env bash
set -euo pipefail

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 SQL_FILE EXTERNAL_VOLUME_NAME"
    echo "Example: $0 tasks/snow-cli/batch-0/drop-external-volume.sql iceberg_ext_vol"
    exit 1
fi

SQL_FILE="$1"
EXTERNAL_VOLUME_NAME="${2:-}"

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "Error: SQL file not found at $SQL_FILE"
    exit 1
fi

# Check if EXTERNAL_VOLUME_NAME is set
if [ -z "$EXTERNAL_VOLUME_NAME" ]; then
    echo "Error: EXTERNAL_VOLUME_NAME not provided"
    exit 1
fi

echo "Dropping Snowflake external volume: $EXTERNAL_VOLUME_NAME"
echo ""

# Run snow CLI with templating
snow sql -f "$SQL_FILE" \
  --enable-templating JINJA \
  -D external_volume_name="$EXTERNAL_VOLUME_NAME"

# Check if drop was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "External volume dropped successfully: $EXTERNAL_VOLUME_NAME"
else
    echo ""
    echo "Failed to drop external volume (it may not exist)"
    exit 0
fi
