#!/usr/bin/env bash
set -euo pipefail

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 SQL_FILE EXTERNAL_VOLUME_NAME OUTPUT_FILE"
    echo "Example: $0 tasks/snow-cli/batch-0/desc_external_volume.sql iceberg_ext_vol tasks/snow-cli/json/external-volume-desc.json"
    exit 1
fi

SQL_FILE="$1"
EXTERNAL_VOLUME_NAME="$2"
OUTPUT_FILE="${3:-tasks/snow-cli/json/external-volume-desc.json}"

# Derive the storage location output file from the main output file
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
OUTPUT_BASENAME=$(basename "$OUTPUT_FILE" .json)
STORAGE_LOCATION_FILE="${OUTPUT_DIR}/${OUTPUT_BASENAME}-storage-location.json"

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

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Describing Snowflake external volume: $EXTERNAL_VOLUME_NAME"
echo "Output file: $OUTPUT_FILE"
echo ""

# Run snow CLI with templating and JSON_EXT format
snow sql -f "$SQL_FILE" \
  --enable-templating JINJA \
  --format JSON_EXT \
  -D external_volume_name="$EXTERNAL_VOLUME_NAME" \
  > "$OUTPUT_FILE"

# Check if command was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "External volume description saved successfully"
    echo "Output file: $OUTPUT_FILE"
    
    # Extract STORAGE_LOCATION_1 JSON from the output
    echo ""
    echo "Extracting storage location details..."
    
    # Find the element where parent_property = STORAGE_LOCATIONS and property = STORAGE_LOCATION_1
    # The property_value is a JSON string that needs to be unquoted
    STORAGE_LOCATION_JSON=$(jq -r '.[] | select(.parent_property == "STORAGE_LOCATIONS" and .property == "STORAGE_LOCATION_1") | .property_value' "$OUTPUT_FILE")
    
    if [ -n "$STORAGE_LOCATION_JSON" ] && [ "$STORAGE_LOCATION_JSON" != "null" ]; then
        # Parse the JSON string and write it as formatted JSON to the file
        echo "$STORAGE_LOCATION_JSON" | jq '.' > "$STORAGE_LOCATION_FILE"
        echo "Storage location details saved to: $STORAGE_LOCATION_FILE"
    else
        echo "Warning: Could not find STORAGE_LOCATION_1 in the output"
    fi
else
    echo ""
    echo "Failed to describe external volume"
    exit 1
fi
