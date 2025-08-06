STATUS=$(aws ec2 describe-instance-status --region ap-southeast-1)
FINAL_STATUS=$(echo "$STATUS" | jq -r '.InstanceStatuses[] | "\(.InstanceId)"')

aws ec2 terminate-instances \
  --instance-ids $FINAL_STATUS \
  --region ap-southeast-1
