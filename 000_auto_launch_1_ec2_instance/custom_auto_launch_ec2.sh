#!/bin/bash

# Prompt for number of instances
read -p "How many instances? (default: 1): " INSTANCE_COUNT
INSTANCE_COUNT=${INSTANCE_COUNT:-1}

# Region selection
echo "Select a region:"
REGIONS=("us-east-1" "us-east-2" "us-west-1" "us-west-2" "ap-southeast-1" "ap-southeast-2" "ap-northeast-1")
for i in "${!REGIONS[@]}"; do
  echo "($((i+1))) ${REGIONS[$i]}"
done
read -p "Enter region number (default: ap-southeast-1): " REGION_INDEX
if [[ -z "$REGION_INDEX" ]]; then
  REGION="ap-southeast-1"
else
  REGION="${REGIONS[$((REGION_INDEX-1))]}"
fi

# Availability Zone selection
echo "Fetching AZs for region $REGION..."
AZS=$(aws ec2 describe-availability-zones --region "$REGION" --query 'AvailabilityZones[].ZoneName' --output text)
AZ_ARRAY=($AZS)
echo "Select an Availability Zone:"
for i in "${!AZ_ARRAY[@]}"; do
  echo "($((i+1))) ${AZ_ARRAY[$i]}"
done
read -p "Enter AZ number (default: automatic): " AZ_INDEX
if [[ -z "$AZ_INDEX" ]]; then
  SELECTED_AZ=""
else
  SELECTED_AZ="${AZ_ARRAY[$((AZ_INDEX-1))]}"
fi

# Subnet selection
echo "Fetching subnets in region $REGION..."
SUBNETS=$(aws ec2 describe-subnets --region "$REGION" --query 'Subnets[].{ID:SubnetId,AZ:AvailabilityZone}' --output json)
echo "Available subnets:"
echo "$SUBNETS" | jq -r '.[] | "\(.ID) in \(.AZ)"'
read -p "Enter subnet ID (default: any in default VPC): " SELECTED_SUBNET

# Run EC2 instance
echo "Launching $INSTANCE_COUNT instance(s) in region $REGION..."

NETWORK_INTERFACE="{\"AssociatePublicIpAddress\":true,\"DeviceIndex\":0,\"Groups\":[\"sg-0e06a029ee92ed487\"]"
if [[ -n "$SELECTED_SUBNET" ]]; then
  NETWORK_INTERFACE+=",\"SubnetId\":\"$SELECTED_SUBNET\""
fi
NETWORK_INTERFACE+="}"

aws ec2 run-instances \
  --image-id "ami-0061376a80017c383" \
  --instance-type "t2.micro" \
  --key-name "keypair3" \
  --network-interfaces "$NETWORK_INTERFACE" \
  --credit-specification '{"CpuCredits":"standard"}' \
  --metadata-options '{"HttpEndpoint":"enabled","HttpPutResponseHopLimit":2,"HttpTokens":"required"}' \
  --private-dns-name-options '{"HostnameType":"ip-name","EnableResourceNameDnsARecord":true,"EnableResourceNameDnsAAAARecord":false}' \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"DeleteOnTermination":true}}]' \
  --count "$INSTANCE_COUNT" \
  --region "$REGION"

echo "Waiting for EC2 instance(s) to initialize..."
sleep 30

STATUS=$(aws ec2 describe-instance-status --region "$REGION")
FINAL_STATUS=$(echo "$STATUS" | jq -r '.InstanceStatuses[] | .InstanceId')

for INSTANCE_ID in $FINAL_STATUS; do
  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[].Instances[].PublicIpAddress' \
    --output text \
    --region "$REGION")
  echo "Instance $INSTANCE_ID Public IP: $PUBLIC_IP"
done

aws ec2 describe-instance-status \
  --region "$REGION" | jq -r '.InstanceStatuses[] | "\(.InstanceId) \(.InstanceStatus)"'
