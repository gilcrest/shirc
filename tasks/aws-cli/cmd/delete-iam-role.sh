#!/usr/bin/env bash
set -euo pipefail

# Path to the JSON output file
JSON_FILE="tasks/aws-cli/json/aws-output.json"

# Check if JSON file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: JSON file not found at $JSON_FILE"
    exit 1
fi

# Extract the role ARN from the JSON file
ROLE_ARN=$(jq -r '.iam_role.Role.Arn // empty' "$JSON_FILE")

# Check if role ARN was found
if [ -z "$ROLE_ARN" ] || [ "$ROLE_ARN" = "null" ]; then
    echo "Warning: No IAM role ARN found in $JSON_FILE"
    echo "Nothing to delete."
    exit 0
fi

# Extract role name from ARN
ROLE_NAME=$(echo "$ROLE_ARN" | awk -F'/' '{print $NF}')

echo "Found role ARN: $ROLE_ARN"
echo "Role name: $ROLE_NAME"

# Check if the role exists in AWS
echo "Checking if role exists..."
if ! aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    echo "Warning: Role $ROLE_NAME does not exist or is not accessible"
    echo "Nothing to delete."
    exit 0
fi

# Check for attached policies
echo "Checking for attached policies..."
ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[*].PolicyArn' --output text)

if [ -n "$ATTACHED_POLICIES" ]; then
    echo "Warning: Role has attached policies"
    echo "Role cannot be deleted while policies are attached."
    echo ""
    echo "Attached policies:"
    for POLICY in $ATTACHED_POLICIES; do
        echo "  - $POLICY"
    done
    echo ""
    echo "Detach policies before deleting the role:"
    echo "  task aws-cli:detach-policy-from-role"
    exit 1
fi

# Check for inline policies
echo "Checking for inline policies..."
INLINE_POLICIES=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames' --output text)

if [ -n "$INLINE_POLICIES" ]; then
    echo "Deleting inline policies..."
    for POLICY_NAME in $INLINE_POLICIES; do
        echo "  Deleting inline policy: $POLICY_NAME"
        aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$POLICY_NAME"
    done
fi

# Delete the role
echo "Deleting IAM role: $ROLE_NAME"
aws iam delete-role --role-name "$ROLE_NAME"

# Check if deletion was successful
if [ $? -eq 0 ]; then
    echo "IAM role deleted successfully: $ROLE_NAME"
    echo "   ARN: $ROLE_ARN"
else
    echo "Failed to delete IAM role"
    exit 1
fi
