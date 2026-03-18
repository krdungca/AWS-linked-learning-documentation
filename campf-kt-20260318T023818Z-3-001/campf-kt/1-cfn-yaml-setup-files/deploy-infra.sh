#!/bin/bash

STACK_NAME="ManilaStoreLab"
REGION="us-east-1"
TEMPLATE_FILE="manilastorelab-infra.yaml"
JSON_FILE="infra-ids.json"

echo "🚀 Deploying Manila-Store Infrastructure..."

# 1. Start Stack Creation
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --region $REGION

# 2. Wait for completion
echo "⏳ Waiting for CREATE_COMPLETE (approx 3 mins)..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION

if [ $? -eq 0 ]; then
    echo "✅ Success! Generating $JSON_FILE..."
    
    # 3. Pull all outputs and format them into a clean JSON object
    aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[*].{Key:OutputKey,Value:OutputValue}' \
    --output json | jq 'from_entries' > $JSON_FILE

    echo "------------------------------------------------"
    cat $JSON_FILE
    echo -e "\n------------------------------------------------"
    echo "Done. All IDs saved to $JSON_FILE"
else
    echo "❌ Deployment failed."
    exit 1
fi
