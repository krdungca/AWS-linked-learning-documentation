#!/bin/bash

echo "=== Manila-Store FULL Connectivity Fix Script ==="

# --- AUTOMATED INPUT SECTION ---
JSON_FILE="../1-cfn-yaml-setup-files/infra-ids.json"

if [ ! -f "$JSON_FILE" ]; then
    echo "Error: $JSON_FILE not found! Run the deployment script first."
    exit 1
fi

# Ensure jq is installed for parsing
if ! command -v jq &> /dev/null; then
    sudo dnf install jq -y > /dev/null
fi

# Extract IDs from our deployment output
WEB_VPC_ID=$(jq -r '.WebVPCId' $JSON_FILE)
DB_VPC_ID=$(jq -r '.DatabaseVPCId' $JSON_FILE)
WEB_RT_ID=$(jq -r '.WebRouteTableId' $JSON_FILE)
DATA_RT_ID=$(jq -r '.DataRouteTableId' $JSON_FILE)
WEB_SG_ID=$(jq -r '.WebSGId' $JSON_FILE)
DATA_SG_ID=$(jq -r '.DataSGId' $JSON_FILE)
DB_INSTANCE_ID=$(jq -r '.DataInstanceId' $JSON_FILE)
IGW_ID=$(jq -r '.DataIGWId' $JSON_FILE)
WEB_IP="10.0.1.10"

# --- 1. FIX SECURITY GROUPS ---
echo "Fixing Security Groups..."

aws ec2 authorize-security-group-ingress --group-id $WEB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $DATA_SG_ID --protocol tcp --port 3306 --cidr ${WEB_IP}/32
aws ec2 authorize-security-group-ingress --group-id $DATA_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0

echo "Security Groups updated."

# --- 2. CREATE VPC PEERING ---
echo "Creating VPC Peering..."

PEERING_ID=$(aws ec2 create-vpc-peering-connection \
  --vpc-id $WEB_VPC_ID \
  --peer-vpc-id $DB_VPC_ID \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
  --output text)

sleep 2 # Brief wait for AWS propagation
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PEERING_ID

echo "Peering ID: $PEERING_ID"

# --- 3. UPDATE ROUTES ---
echo "Updating Route Tables..."

aws ec2 create-route --route-table-id $WEB_RT_ID --destination-cidr-block 172.16.0.0/16 --vpc-peering-connection-id $PEERING_ID
aws ec2 create-route --route-table-id $DATA_RT_ID --destination-cidr-block 10.0.0.0/16 --vpc-peering-connection-id $PEERING_ID

# --- UPDATE CENTRAL JSON FILE ---
# This adds the PEERING_ID to your existing file so you have ONE source of truth
tmp=$(mktemp)
jq --arg pid "$PEERING_ID" '. + {PeeringConnectionId: $pid}' "$JSON_FILE" > "$tmp" && mv "$tmp" "$JSON_FILE"

echo "✅ All Fixes Applied. infra-ids.json updated with Peering ID."
echo "=== FULL FIX COMPLETE ==="
