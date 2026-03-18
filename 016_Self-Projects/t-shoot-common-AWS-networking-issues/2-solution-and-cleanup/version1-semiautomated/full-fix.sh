#!/bin/bash

echo "=== Manila-Store FULL Connectivity Fix Script ==="

# --- INPUT SECTION ---
read -p "Enter Web VPC ID: " WEB_VPC_ID
read -p "Enter Database VPC ID: " DB_VPC_ID

read -p "Enter Web Route Table ID: " WEB_RT_ID
read -p "Enter Data Route Table ID: " DATA_RT_ID

read -p "Enter Web Security Group ID: " WEB_SG_ID
read -p "Enter Data Security Group ID: " DATA_SG_ID

read -p "Enter Web Server Private IP (e.g., 10.0.1.10): " WEB_IP
read -p "Enter DB Instance ID: " DB_INSTANCE_ID

read -p "Enter DB VPC Internet Gateway ID: " IGW_ID

# --- 1. FIX SECURITY GROUPS ---
echo "Fixing Security Groups..."

aws ec2 authorize-security-group-ingress \
  --group-id $WEB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id $DATA_SG_ID \
  --protocol tcp \
  --port 3306 \
  --cidr ${WEB_IP}/32

aws ec2 authorize-security-group-ingress \
  --group-id $DATA_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

echo "Security Groups updated."

# --- 2. CREATE VPC PEERING ---
echo "Creating VPC Peering..."

PEERING_ID=$(aws ec2 create-vpc-peering-connection \
  --vpc-id $WEB_VPC_ID \
  --peer-vpc-id $DB_VPC_ID \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
  --output text)

aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id $PEERING_ID

echo "Peering ID: $PEERING_ID"

# --- 3. UPDATE ROUTES ---
echo "Updating Route Tables..."

aws ec2 create-route \
  --route-table-id $WEB_RT_ID \
  --destination-cidr-block 172.16.0.0/16 \
  --vpc-peering-connection-id $PEERING_ID

aws ec2 create-route \
  --route-table-id $DATA_RT_ID \
  --destination-cidr-block 10.0.0.0/16 \
  --vpc-peering-connection-id $PEERING_ID

echo "IGW ID: $IGW_ID"

# --- SAVE IDS TO FILE ---
echo "Saving IDs to input-ids.json..."

cat <<EOF > input-ids.json
{
  "WEB_VPC_ID": "$WEB_VPC_ID",
  "DB_VPC_ID": "$DB_VPC_ID",
  "WEB_RT_ID": "$WEB_RT_ID",
  "DATA_RT_ID": "$DATA_RT_ID",
  "WEB_SG_ID": "$WEB_SG_ID",
  "DATA_SG_ID": "$DATA_SG_ID",
  "WEB_IP": "$WEB_IP",
  "DB_INSTANCE_ID": "$DB_INSTANCE_ID",
  "PEERING_ID": "$PEERING_ID",
  "IGW_ID": "$IGW_ID"
}
EOF

echo "Saved to input-ids.json ✅"

# --- DONE ---
echo "=== FULL FIX COMPLETE ==="
