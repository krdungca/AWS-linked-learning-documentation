#!/bin/bash

echo "=== Manila-Store Demo Reversal & Stack Deletion ==="

JSON_FILE="../1-cfn-yaml-setup-files/infra-ids.json"
STACK_NAME="ManilaStoreLab"

# --- 1. USER CONFIRMATION ---
echo "⚠️  NOTICE: This should only be executed when you performed full-fix-automated.sh."
read -p "Proceed? (y/n): " confirm

case "$confirm" in
    [yY][eE][sS]|[yY]) 
        echo "Proceeding with reversal..."
        ;;
    *)
        echo "Operation cancelled by user."
        exit 0
        ;;
esac

# --- 2. CHECK FILE ---
if [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: $JSON_FILE not found! Nothing to delete."
    exit 1
fi

# --- 3. EXTRACT DATA FROM JSON ---
# Ensure jq is installed
if ! command -v jq &> /dev/null; then sudo dnf install jq -y > /dev/null; fi

DATA_SG_ID=$(jq -r '.DataSGId' $JSON_FILE)
WEB_SG_ID=$(jq -r '.WebSGId' $JSON_FILE)
DATA_RT_ID=$(jq -r '.DataRouteTableId' $JSON_FILE)
WEB_RT_ID=$(jq -r '.WebRouteTableId' $JSON_FILE)
PEERING_ID=$(jq -r '.PeeringConnectionId // empty' $JSON_FILE)
WEB_IP="10.0.1.10"

# --- 4. REVERSE MANUAL SECURITY GROUP RULES ---
echo "Revoking manual Security Group rules..."
aws ec2 revoke-security-group-ingress --group-id $WEB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 2>/dev/null
aws ec2 revoke-security-group-ingress --group-id $DATA_SG_ID --protocol tcp --port 3306 --cidr ${WEB_IP}/32 2>/dev/null
aws ec2 revoke-security-group-ingress --group-id $DATA_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 2>/dev/null

# --- 5. REVERSE MANUAL ROUTES & PEERING ---
echo "Deleting manual Peering Routes..."
aws ec2 delete-route --route-table-id $WEB_RT_ID --destination-cidr-block 172.16.0.0/16 2>/dev/null
aws ec2 delete-route --route-table-id $DATA_RT_ID --destination-cidr-block 10.0.0.0/16 2>/dev/null

if [ ! -z "$PEERING_ID" ] && [ "$PEERING_ID" != "null" ]; then
    echo "Deleting VPC Peering Connection: $PEERING_ID..."
    aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $PEERING_ID
fi

# --- 6. DELETE CLOUDFORMATION STACK ---
echo "🔥 Initiating CloudFormation Stack Deletion: $STACK_NAME..."
aws cloudformation delete-stack --stack-name $STACK_NAME

echo "⏳ Waiting for stack-delete-complete (3-5 mins)..."
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME

if [ $? -eq 0 ]; then
    echo "✅ Success. Infrastructure and manual fixes wiped."
    rm $JSON_FILE
else
    echo "⚠️ Deletion finished with warnings. Check AWS Console."
fi
