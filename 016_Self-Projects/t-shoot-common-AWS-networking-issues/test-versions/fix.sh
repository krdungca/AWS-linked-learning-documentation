#!/bin/bash

echo "=== Manila-Store Connectivity Fix Script ==="

# --- INPUT SECTION (dynamic) ---
read -p "Enter Web VPC ID: " WEB_VPC_ID
read -p "Enter Database VPC ID: " DB_VPC_ID

read -p "Enter Web Route Table ID: " WEB_RT_ID
read -p "Enter Data Route Table ID: " DATA_RT_ID

read -p "Enter Web Security Group ID: " WEB_SG_ID
read -p "Enter Data Security Group ID: " DATA_SG_ID

read -p "Enter Web Server Private IP (e.g., 10.0.1.10): " WEB_IP

# --- 1. FIX SECURITY GROUPS ---
echo "Fixing Security Groups..."

# Allow HTTP to Web Server
aws ec2 authorize-security-group-ingress \
  --group-id $WEB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Allow MySQL from Web Server to DB
aws ec2 authorize-security-group-ingress \
  --group-id $DATA_SG_ID \
  --protocol tcp \
  --port 3306 \
  --cidr ${WEB_IP}/32

echo "Security Groups updated."

# --- 2. CREATE VPC PEERING ---
echo "Creating VPC Peering..."

PEERING_ID=$(aws ec2 create-vpc-peering-connection \
  --vpc-id $WEB_VPC_ID \
  --peer-vpc-id $DB_VPC_ID \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
  --output text)

echo "Peering ID: $PEERING_ID"

# Accept peering
aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id $PEERING_ID

echo "Peering accepted."

# --- 3. UPDATE ROUTE TABLES ---
echo "Updating Route Tables..."

# Route from Web → DB
aws ec2 create-route \
  --route-table-id $WEB_RT_ID \
  --destination-cidr-block 172.16.0.0/16 \
  --vpc-peering-connection-id $PEERING_ID

# Route from DB → Web
aws ec2 create-route \
  --route-table-id $DATA_RT_ID \
  --destination-cidr-block 10.0.0.0/16 \
  --vpc-peering-connection-id $PEERING_ID

echo "Routes added."

# --- DONE ---
echo "=== FIX COMPLETE ==="
echo "Now open your Web URL and verify DB status."
