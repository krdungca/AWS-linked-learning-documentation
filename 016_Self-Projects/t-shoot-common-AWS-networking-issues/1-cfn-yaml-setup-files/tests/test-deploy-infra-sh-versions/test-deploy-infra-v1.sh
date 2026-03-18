#!/bin/bash

# --- New Input Section ---
echo -n "Enter the test version number: "
read VERSION

# Dynamically update names based on input
STACK_NAME="ManilaStoreLab-TestVersion-$VERSION"
TEMPLATE_FILE="test-cfn-template-v$VERSION.yaml"
# -------------------------

REGION="us-east-1"
JSON_FILE="infra-ids.json"

echo "🚀 Deploying $STACK_NAME using $TEMPLATE_FILE..."

# 1. Start Stack Creation
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --region $REGION \
    --tags Key=Limit,Value=Demo

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
