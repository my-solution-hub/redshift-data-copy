#!/bin/bash
set -e

# Load environment variables if .env exists
if [ -f .env ]; then
  source .env
  echo "Loaded configuration from .env"
else
  echo "Error: .env file not found. Please run deploy.sh first or set variables manually."
  exit 1
fi

echo "=========================================="
echo "Cross-Account Redshift Cleanup"
echo "=========================================="
echo "Account 1 (Data Source): $ACCOUNT1_ID ($ACCOUNT1_PROFILE)"
echo "Account 2 (Redshift): $ACCOUNT2_ID ($ACCOUNT2_PROFILE)"
echo "Region: $AWS_REGION"
echo "=========================================="
echo ""

read -p "Are you sure you want to delete all resources? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Cleanup cancelled."
  exit 0
fi
echo ""

# Step 1: Delete S3 Event Integration
echo "Step 1: Deleting S3 Event Integration..."
if [ ! -z "$INTEGRATION_ARN" ]; then
  aws redshift delete-integration \
    --integration-arn $INTEGRATION_ARN \
    --region $AWS_REGION \
    --profile $ACCOUNT1_PROFILE || echo "⚠️  Integration already deleted or not found"
  echo "✅ Integration deleted"
else
  echo "⚠️  No integration ARN found, skipping"
fi
echo ""

# Step 2: Empty S3 bucket
echo "Step 2: Emptying S3 bucket..."
aws s3 rm s3://$S3_BUCKET_NAME --recursive --profile $ACCOUNT1_PROFILE || echo "⚠️  Bucket already empty or not found"
echo "✅ S3 bucket emptied"
echo ""

# Step 3: Delete Account1 Stack
echo "Step 3: Deleting S3 Stack in Account1..."
cd cdk-account1
cdk destroy DataSourceStack --profile $ACCOUNT1_PROFILE --force || echo "⚠️  Stack already deleted"
cd ..
echo "✅ S3 Stack deleted"
echo ""

# Step 4: Delete Account2 Stack
echo "Step 4: Deleting Redshift Stack in Account2..."
cd cdk-account2
cdk destroy RedshiftStack --profile $ACCOUNT2_PROFILE --force || echo "⚠️  Stack already deleted"
cd ..
echo "✅ Redshift Stack deleted"
echo ""

# Step 5: Remove .env file
echo "Step 5: Cleaning up environment file..."
rm -f .env
echo "✅ .env file removed"
echo ""

echo "=========================================="
echo "✅ Cleanup Complete!"
echo "=========================================="
