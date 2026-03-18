#!/bin/bash

# --- Setup Variables ---
echo -n "How many IAM users to create? "
read USER_COUNT
GROUP_NAME="demo-group"
POLICY_NAME="ManilaStoreLab-RestrictedAdmin"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# 1. Create Group
aws iam create-group --group-name $GROUP_NAME 2>/dev/null

# 2. Create the Restricted Policy
cat <<EOF > manila-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowFullVPCActionsAndConsoleNavigation",
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "ec2:*Vpc*",
                "ec2:*Subnet*",
                "ec2:*Gateway*",
                "ec2:*RouteTable*",
                "ec2:*Address*",
                "ec2:*SecurityGroup*",
                "ec2:*NetworkInterface*",
                "ec2:*VpcPeeringConnection*",
                "cloudformation:Describe*",
                "cloudformation:List*",
                "tag:GetResources"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowCreateAndAcceptOnlyIfTaggingDemo",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateVpc*",
                "ec2:CreateSubnet",
                "ec2:CreateRouteTable",
                "ec2:CreateVpcPeeringConnection",
                "ec2:AcceptVpcPeeringConnection",
                "ec2:CreateTags"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": { "aws:RequestTag/Limit": "Demo" }
            }
        },
        {
            "Sid": "AdminAccessOnlyToTaggedLabResources",
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*",
            "Condition": {
                "StringEquals": { "aws:ResourceTag/Limit": "Demo" }
            }
        },
        {
            "Sid": "ExplicitDenyAllNonLabResources",
            "Effect": "Deny",
            "Action": "*",
            "Resource": "*",
            "Condition": {
                "StringNotEqualsIfExists": { "aws:ResourceTag/Limit": "Demo" },
                "Null": { "aws:ResourceTag/Limit": "false" }
            }
        },
        {
            "Sid": "AllowSelfPasswordChange",
            "Effect": "Allow",
            "Action": [
                "iam:ChangePassword",
                "iam:GetAccountPasswordPolicy"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Create/Update the Custom Policy
POLICY_ARN=$(aws iam create-policy --policy-name $POLICY_NAME --policy-document file://manila-policy.json --query 'Policy.Arn' --output text 2>/dev/null || echo "arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME")

# 3. Attach Policy to Group
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn $POLICY_ARN

# 4. User Creation Loop
echo -e "\n🔐 Console Login URL: https://$ACCOUNT_ID.signin.aws.amazon.com/console"
echo "------------------------------------------------"
printf "%-20s | %-20s\n" "Username" "Password"
echo "------------------------------------------------"

for i in $(seq 1 $USER_COUNT); do
    USER_NAME="demo-user-$i"
    PASSWORD="Temp$(openssl rand -hex 4)!"

    # Create User & Console Access (NO RESET REQUIRED)
    aws iam create-user --user-name $USER_NAME > /dev/null
    aws iam create-login-profile --user-name $USER_NAME --password "$PASSWORD" --no-password-reset-required > /dev/null
    aws iam add-user-to-group --user-name $USER_NAME --group-name $GROUP_NAME

    printf "%-20s | %-20s\n" "$USER_NAME" "$PASSWORD"
done

echo "------------------------------------------------"
echo "✅ Done. Users created with full VPC/Peering permissions for tagged resources."
