#!/usr/bin/env bash
set -euo pipefail

# Path to the JSON files
STORAGE_LOCATION_FILE="output/external-volume-desc-storage-location.json"
AWS_OUTPUT_FILE="output/aws-output.json"
TEMP_TRUST_POLICY_FILE="output/trust-policy-updated.json"

# Check if storage location file exists
if [ ! -f "$STORAGE_LOCATION_FILE" ]; then
    echo "Error: Storage location file not found at $STORAGE_LOCATION_FILE"
    echo "Please run 'task snow-cli:desc-external-volume' first."
    exit 1
fi

# Check if AWS output file exists
if [ ! -f "$AWS_OUTPUT_FILE" ]; then
    echo "Error: AWS output file not found at $AWS_OUTPUT_FILE"
    echo "Please run 'task aws-resources-up' first."
    exit 1
fi

# Extract Snowflake's IAM user ARN from storage location
SNOWFLAKE_IAM_USER_ARN=$(jq -r '.STORAGE_AWS_IAM_USER_ARN // empty' "$STORAGE_LOCATION_FILE")

if [ -z "$SNOWFLAKE_IAM_USER_ARN" ] || [ "$SNOWFLAKE_IAM_USER_ARN" = "null" ]; then
    echo "Error: Could not find STORAGE_AWS_IAM_USER_ARN in $STORAGE_LOCATION_FILE"
    exit 1
fi

# Extract role name from aws-output.json
ROLE_ARN=$(jq -r '.iam_role.Role.Arn // empty' "$AWS_OUTPUT_FILE")

if [ -z "$ROLE_ARN" ] || [ "$ROLE_ARN" = "null" ]; then
    echo "Error: Could not find IAM role ARN in $AWS_OUTPUT_FILE"
    exit 1
fi

ROLE_NAME=$(echo "$ROLE_ARN" | awk -F'/' '{print $NF}')

echo "Updating trust policy for role: $ROLE_NAME"
echo "Snowflake IAM User ARN: $SNOWFLAKE_IAM_USER_ARN"
echo ""

# Get the current trust policy
echo "Fetching current trust policy..."
CURRENT_TRUST_POLICY=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json)

if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch trust policy for role $ROLE_NAME"
    exit 1
fi

# Update the Principal.AWS in the trust policy to use Snowflake's IAM user ARN
echo "Updating Principal.AWS with Snowflake IAM user..."
UPDATED_TRUST_POLICY=$(echo "$CURRENT_TRUST_POLICY" | jq --arg arn "$SNOWFLAKE_IAM_USER_ARN" \
    '.Statement[0].Principal.AWS = $arn')

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$TEMP_TRUST_POLICY_FILE")"

# Save the updated trust policy to a file
echo "$UPDATED_TRUST_POLICY" > "$TEMP_TRUST_POLICY_FILE"

echo "Updated trust policy saved to: $TEMP_TRUST_POLICY_FILE"
echo ""

# Update the role's assume role policy
echo "Applying updated trust policy to role..."
aws iam update-assume-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-document file://"$TEMP_TRUST_POLICY_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "Trust policy updated successfully"
    echo "Role: $ROLE_NAME"
    echo "Principal (Snowflake IAM User): $SNOWFLAKE_IAM_USER_ARN"
else
    echo ""
    echo "Failed to update trust policy"
    exit 1
fi
