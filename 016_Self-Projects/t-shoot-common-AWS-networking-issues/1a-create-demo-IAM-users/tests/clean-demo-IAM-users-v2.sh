#!/bin/bash

GROUP_NAME="demo-group"
POLICY_NAME="ManilaStoreLab-RestrictedAdmin"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"

echo "🔍 Identifying all demo-user-* accounts..."

# Get list of all users starting with 'demo-user-'
USERS=$(aws iam list-users --query 'Users[?starts_with(UserName, `demo-user-`)].UserName' --output text)

if [ -z "$USERS" ]; then
    echo "icon ℹ️ No demo users found."
else
    for USER_NAME in $USERS; do
        echo "  - Purging $USER_NAME..."

        # 1. Remove from group
        aws iam remove-user-from-group --user-name "$USER_NAME" --group-name "$GROUP_NAME" 2>/dev/null

        # 2. Delete login profile (Console Access)
        aws iam delete-login-profile --user-name "$USER_NAME" 2>/dev/null

        # 3. Delete the user
        aws iam delete-user --user-name "$USER_NAME" 2>/dev/null
    done
    echo "✅ All demo users deleted."
fi

# --- Cleanup Group and Policy ---
echo "📜 Detaching and deleting lab policy/group..."

# Detach policy from group
aws iam detach-group-policy --group-name "$GROUP_NAME" --policy-arn "$POLICY_ARN" 2>/dev/null

# Delete the group
aws iam delete-group --group-name "$GROUP_NAME" 2>/dev/null

# Delete the policy
aws iam delete-policy --policy-arn "$POLICY_ARN" 2>/dev/null

# Remove local policy file
rm -f manila-policy.json

echo "------------------------------------------------"
echo "🏁 Infrastructure Cleanup Complete."
