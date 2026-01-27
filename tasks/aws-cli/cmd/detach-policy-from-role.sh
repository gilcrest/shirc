#!/usr/bin/env bash
set -euo pipefail

# Path to the JSON output file
JSON_FILE="output/aws-output.json"

# Check if JSON file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: JSON file not found at $JSON_FILE"
    exit 1
fi

# Extract the role ARN and policy ARN from the JSON file
ROLE_ARN=$(jq -r '.iam_role.Role.Arn // empty' "$JSON_FILE")
POLICY_ARN=$(jq -r '.iam_policy.Policy.Arn // empty' "$JSON_FILE")

# Check if role ARN was found
if [ -z "$ROLE_ARN" ] || [ "$ROLE_ARN" = "null" ]; then
    echo "Warning: No IAM role ARN found in $JSON_FILE"
    echo "Nothing to detach."
    exit 0
fi

# Check if policy ARN was found
if [ -z "$POLICY_ARN" ] || [ "$POLICY_ARN" = "null" ]; then
    echo "Warning: No IAM policy ARN found in $JSON_FILE"
    echo "Nothing to detach."
    exit 0
fi

# Extract role name from ARN
ROLE_NAME=$(echo "$ROLE_ARN" | awk -F'/' '{print $NF}')
POLICY_NAME=$(echo "$POLICY_ARN" | awk -F'/' '{print $NF}')

echo "Role name: $ROLE_NAME"
echo "Policy name: $POLICY_NAME"

# Check if the role exists in AWS
echo "Checking if role exists..."
if ! aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    echo "Warning: Role $ROLE_NAME does not exist or is not accessible"
    echo "Nothing to detach."
    exit 0
fi

# Check if the policy exists in AWS
echo "Checking if policy exists..."
if ! aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    echo "Warning: Policy $POLICY_ARN does not exist or is not accessible"
    echo "Nothing to detach."
    exit 0
fi

# Check if the policy is attached to the role
echo "Checking if policy is attached to role..."
if ! aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[?PolicyArn=='$POLICY_ARN']" --output text | grep -q .; then
    echo "Warning: Policy $POLICY_NAME is not attached to role $ROLE_NAME"
    echo "Nothing to detach."
    exit 0
fi

# Detach the policy from the role
echo "Detaching policy $POLICY_NAME from role $ROLE_NAME..."
aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"

# Check if detachment was successful
if [ $? -eq 0 ]; then
    echo "Policy detached successfully"
    echo "   Role: $ROLE_NAME"
    echo "   Policy: $POLICY_NAME"
else
    echo "Failed to detach policy from role"
    exit 1
fi
