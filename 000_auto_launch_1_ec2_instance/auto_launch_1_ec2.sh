#!/bin/bash

aws ec2 run-instances --image-id "ami-0d8ec96c89ad62005" \
--instance-type "t2.micro" \
--key-name "keypair3" \
--network-interfaces '{"AssociatePublicIpAddress":true,"DeviceIndex":0,"Groups":["sg-0e06a029ee92ed487"]}' \
--credit-specification '{"CpuCredits":"standard"}' \
--metadata-options '{"HttpEndpoint":"enabled","HttpPutResponseHopLimit":2,"HttpTokens":"required"}' \
--private-dns-name-options '{"HostnameType":"ip-name","EnableResourceNameDnsARecord":true,"EnableResourceNameDnsAAAARecord":false}' \
--block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"DeleteOnTermination":true}}]' \
--count "1" \
--region ap-southeast-1

echo "Waiting for EC2-instance to initialize..."

sleep 30

STATUS=$(aws ec2 describe-instance-status --region ap-southeast-1)
FINAL_STATUS=$(echo "$STATUS" | jq -r '.InstanceStatuses[] | "\(.InstanceId)"')

PUBLIC_IP=$(aws ec2 describe-instances  \
  --instance-ids $FINAL_STATUS \
  --query 'Reservations[].Instances[].PublicIpAddress'   \
  --output text   \
  --region ap-southeast-1)

echo "Public IP: $PUBLIC_IP"

aws ec2 describe-instance-status \
  --region ap-southeast-1 | jq -r '.InstanceStatuses[] | "\(.InstanceId)\(.InstanceStatus)"'

echo "Using keypair3.pem as private key..."
echo "Now using ssh to log-in to EC2 instance..."

ssh -i ~/Documents/AWS/CAMPF/Creds/keypair3.pem ec2-user@$PUBLIC_IP
