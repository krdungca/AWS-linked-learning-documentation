#!/bin/bash

echo "=== Manila-Store Cleanup Script ==="

# --- INPUTS ---
read -p "Enter DB VPC ID: " DB_VPC_ID
read -p "Enter Data Route Table ID: " DATA_RT_ID
read -p "Enter Data Security Group ID: " DATA_SG_ID
read -p "Enter Database VPC Internet Gateway ID (IGW): " IGW_ID
read -p "Enter VPC Peering Connection ID (or press enter to skip): " PEERING_ID

# --- NEW STEP: STOP INSTANCE ---
read -p "Enter DB Instance ID (to stop and release public IP): " DB_INSTANCE_ID

echo "Stopping DB instance..."

aws ec2 stop-instances \
  --instance-ids $DB_INSTANCE_ID

echo "Waiting for instance to fully stop..."

aws ec2 wait instance-stopped \
  --instance-ids $DB_INSTANCE_ID

echo "Instance stopped. Temporary public IP released."

# --- 1. REMOVE SSH RULE ---
echo "Removing SSH (22) rule..."

aws ec2 revoke-security-group-ingress \
  --group-id $DATA_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# --- 2. DELETE DEFAULT ROUTE ---
echo "Deleting default route..."

aws ec2 delete-route \
  --route-table-id $DATA_RT_ID \
  --destination-cidr-block 0.0.0.0/0

# --- 3. DETACH IGW ---
echo "Detaching Internet Gateway..."

aws ec2 detach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $DB_VPC_ID

# --- 4. DELETE IGW ---
echo "Deleting Internet Gateway..."

aws ec2 delete-internet-gateway \
  --internet-gateway-id $IGW_ID

# --- 5. DELETE VPC PEERING (OPTIONAL) ---
if [ -n "$PEERING_ID" ]; then
  echo "Deleting VPC Peering..."

  aws ec2 delete-vpc-peering-connection \
    --vpc-peering-connection-id $PEERING_ID
fi

# --- DONE ---
echo "=== CLEANUP COMPLETE ==="
echo "You can now safely delete the CloudFormation stack."
