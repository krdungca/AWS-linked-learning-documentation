STATUS=$(aws ec2 describe-instance-status --region ap-southeast-1)
FINAL_STATUS=$(echo "$STATUS" | jq -r '.InstanceStatuses[] | "\(.InstanceId)"')

aws ec2 describe-instances  \
  --instance-ids $FINAL_STATUS \
  --query 'Reservations[].Instances[].PublicIpAddress'   \
  --output text   \
  --region ap-southeast-1

aws ec2 describe-instance-status \
  --region ap-southeast-1 | jq -r '.InstanceStatuses[] | "\(.InstanceId)\(.InstanceStatus)"'
