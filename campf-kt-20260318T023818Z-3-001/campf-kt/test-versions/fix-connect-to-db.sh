#!/bin/bash

echo "=== Manila-Store DB VPC Internet Fix (No EIP) ==="

# --- PROVIDED VALUES ---
DB_VPC_ID="vpc-0923fc25ddc24cd59"
DATA_RT_ID="rtb-036354cb71fefbb0a"
DATA_SG_ID="sg-0190c314827da217b"

# --- 1. CREATE INTERNET GATEWAY ---
echo "Creating Internet Gateway..."

IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

echo "Created IGW: $IGW_ID"

# --- 2. ATTACH IGW TO DB VPC ---
echo "Attaching IGW to DB VPC..."

aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $DB_VPC_ID

# --- 3. ADD DEFAULT ROUTE ---
echo "Adding default route (0.0.0.0/0)..."

aws ec2 create-route \
  --route-table-id $DATA_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# --- 4. OPEN SSH (PORT 22) ---
echo "Opening SSH (22) to the world..."

aws ec2 authorize-security-group-ingress \
  --group-id $DATA_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# --- DONE ---
echo "=== SETUP COMPLETE ==="
echo "NOTE: Instance still has NO public IP."
echo "If needed, manually enable public IP or attach Elastic IP."
