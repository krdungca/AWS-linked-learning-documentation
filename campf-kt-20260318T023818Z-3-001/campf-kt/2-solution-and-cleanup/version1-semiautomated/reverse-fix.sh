#!/bin/bash

echo "=== Manila-Store Cleanup Script (AUTO) ==="

# --- CHECK FILE ---
if [ ! -f input-ids.json ]; then
  echo "ERROR: input-ids.json not found!"
  exit 1
fi

# --- PARSE JSON ---
DB_VPC_ID=$(jq -r '.DB_VPC_ID' input-ids.json)
DATA_RT_ID=$(jq -r '.DATA_RT_ID' input-ids.json)
DATA_SG_ID=$(jq -r '.DATA_SG_ID' input-ids.json)
IGW_ID=$(jq -r '.IGW_ID' input-ids.json)
PEERING_ID=$(jq -r '.PEERING_ID' input-ids.json)
DB_INSTANCE_ID=$(jq -r '.DB_INSTANCE_ID' input-ids.json)

# --- STOP INSTANCE ---
echo "Stopping DB instance..."

aws ec2 stop-instances \
  --instance-ids $DB_INSTANCE_ID

aws ec2 wait instance-stopped \
  --instance-ids $DB_INSTANCE_ID

echo "Instance stopped."

# --- REMOVE SSH ---
echo "Removing SSH rule..."

aws ec2 revoke-security-group-ingress \
  --group-id $DATA_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# --- DELETE ROUTE ---
echo "Deleting default route..."

aws ec2 delete-route \
  --route-table-id $DATA_RT_ID \
  --destination-cidr-block 0.0.0.0/0

# --- DELETE PEERING ---
if [ "$PEERING_ID" != "null" ]; then
  echo "Deleting VPC Peering..."

  aws ec2 delete-vpc-peering-connection \
    --vpc-peering-connection-id $PEERING_ID
fi

# --- DONE ---
echo "=== CLEANUP COMPLETE ==="
