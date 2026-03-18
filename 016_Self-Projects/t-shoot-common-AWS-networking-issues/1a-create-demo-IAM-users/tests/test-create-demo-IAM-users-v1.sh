#!/bin/bash

# --- Input Section ---
echo -n "How many IAM users do you want to create? "
read USER_COUNT
GROUP_NAME="demo-group"
POLICY_NAME="DemoRestrictedAdminPolicy"

# 1. Create the Group if it doesn't exist
echo "🛠  Ensuring group $GROUP_NAME exists..."
aws iam create-group --group-name $GROUP_NAME 2>/dev/null

# 2. Create the Scoped Admin Policy
# Note: This policy allows AdministratorAccess (*:*) ONLY if the resource has tag Limit:Demo
echo "📜 Creating Restricted Admin Policy..."
cat <<EOF > demo-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/Limit": "Demo"
                }
            }
        }
    ]
}
EOF

# Create policy and capture ARN
POLICY_ARN=$(aws iam create-policy --policy-name $POLICY_NAME --policy-document file://demo-policy.json --query 'Policy.Arn' --output text 2>/dev/null)

# If policy already exists, retrieve its ARN instead
if [ -z "$POLICY_ARN" ]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"
fi

# Attach policy to group
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn $POLICY_ARN

# 3. Create Users Loop
echo -e "\n👤 Creating $USER_COUNT users..."
echo "------------------------------------------------"
printf "%-20s | %-20s\n" "Username" "Password"
echo "------------------------------------------------"

for i in $(seq 1 $USER_COUNT); do
    USER_NAME="demo-user-$i"
    PASSWORD=$(openssl rand -base64 12) # Generates a random 12-char password

    # Create User
    aws iam create-user --user-name $USER_NAME > /dev/null
    
    # Set Login Profile (Password)
    aws iam create-login-profile --user-name $USER_NAME --password "$PASSWORD" --no-password-reset-required > /dev/null
    
    # Add to Group
    aws iam add-user-to-group --user-name $USER_NAME --group-name $GROUP_NAME
    
    printf "%-20s | %-20s\n" "$USER_NAME" "$PASSWORD"
done

echo "------------------------------------------------"
echo "✅ Done. All users added to $GROUP_NAME."
echo "⚠️  Note: Users can only manage resources tagged with 'Limit: Demo'."
