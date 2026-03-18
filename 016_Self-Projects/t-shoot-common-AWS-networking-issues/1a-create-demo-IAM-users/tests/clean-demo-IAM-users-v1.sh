#!/bin/bash

# --- Input Section ---
echo -n "How many IAM users do you want to delete? "
read USER_COUNT
GROUP_NAME="demo-group"
POLICY_NAME="DemoRestrictedAdminPolicy"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"

echo "🧹 Starting cleanup for $USER_COUNT users and $GROUP_NAME..."

# 1. Loop through and delete Users
for i in $(seq 1 $USER_COUNT); do
    USER_NAME="demo-user-$i"
    
    echo "  - Removing $USER_NAME..."

    # Must remove from group first
    aws iam remove-user-from-group --user-name $USER_NAME --group-name $GROUP_NAME 2>/dev/null

    # Must delete login profile (password) before deleting user
    aws iam delete-login-profile --user-name $USER_NAME 2>/dev/null

    # Finally delete the user
    aws iam delete-user --user-name $USER_NAME 2>/dev/null
done

# 2. Cleanup Group and Policy
echo "📜 Detaching and deleting policy/group..."

# Detach policy from group
aws iam detach-group-policy --group-name $GROUP_NAME --policy-arn $POLICY_ARN 2>/dev/null

# Delete the group
aws iam delete-group --group-name $GROUP_NAME 2>/dev/null

# Delete the policy
aws iam delete-policy --policy-arn $POLICY_ARN 2>/dev/null

# Remove the local temp JSON file if it exists
rm -f demo-policy.json

echo "------------------------------------------------"
echo "✅ Cleanup Complete. All Demo resources removed."
