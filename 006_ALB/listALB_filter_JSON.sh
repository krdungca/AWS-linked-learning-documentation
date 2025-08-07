echo "Listing load-balancers in ap-southeast-1..."
aws elbv2 describe-load-balancers --region ap-southeast-1 | jq -r '.LoadBalancers[]'

echo "Filtering Availability Zones..."
aws elbv2 describe-load-balancers --region ap-southeast-1 | jq -r '.LoadBalancers[]["AvailabilityZones"]'
