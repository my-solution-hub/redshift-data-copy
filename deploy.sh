#!/bin/bash
set -e

# Configuration
export ACCOUNT1_PROFILE="cloudops-demo"
export ACCOUNT2_PROFILE="default"
export AWS_REGION="ap-southeast-1"

# Get Account IDs
export ACCOUNT1_ID=$(aws sts get-caller-identity --profile $ACCOUNT1_PROFILE --query Account --output text)
export ACCOUNT2_ID=$(aws sts get-caller-identity --profile $ACCOUNT2_PROFILE --query Account --output text)

# S3 Bucket Name
export S3_BUCKET_NAME="${ACCOUNT1_ID}-data-source"

echo "=========================================="
echo "Cross-Account Redshift Setup"
echo "=========================================="
echo "Account 1 (Data Source): $ACCOUNT1_ID ($ACCOUNT1_PROFILE)"
echo "Account 2 (Redshift): $ACCOUNT2_ID ($ACCOUNT2_PROFILE)"
echo "Region: $AWS_REGION"
echo "S3 Bucket: $S3_BUCKET_NAME"
echo "=========================================="
echo ""

# Step 1: Bootstrap CDK (if needed)
echo "Step 1: Bootstrapping CDK..."
cdk bootstrap aws://$ACCOUNT1_ID/$AWS_REGION --profile $ACCOUNT1_PROFILE || true
cdk bootstrap aws://$ACCOUNT2_ID/$AWS_REGION --profile $ACCOUNT2_PROFILE || true
echo "✅ CDK Bootstrap complete"
echo ""

# Step 2: Deploy Account2 (Redshift)
echo "Step 2: Deploying Redshift Stack in Account2..."
cd cdk-account2
npm install
cdk deploy RedshiftStack --profile $ACCOUNT2_PROFILE \
  -c account1Id=$ACCOUNT1_ID \
  -c s3BucketName=$S3_BUCKET_NAME \
  --require-approval never
cd ..
echo "✅ Redshift Stack deployed"
echo ""

# Step 3: Get Redshift outputs
echo "Step 3: Retrieving Redshift Stack outputs..."
export REDSHIFT_ROLE_ARN=$(aws cloudformation describe-stacks \
  --stack-name RedshiftStack \
  --query 'Stacks[0].Outputs[?OutputKey==`RedshiftRoleArn`].OutputValue' \
  --output text \
  --profile $ACCOUNT2_PROFILE)

export CLUSTER_NAMESPACE_ARN=$(aws cloudformation describe-stacks \
  --stack-name RedshiftStack \
  --query 'Stacks[0].Outputs[?OutputKey==`ClusterNamespaceArn`].OutputValue' \
  --output text \
  --profile $ACCOUNT2_PROFILE)

echo "Redshift Role ARN: $REDSHIFT_ROLE_ARN"
echo "Cluster Namespace ARN: $CLUSTER_NAMESPACE_ARN"
echo "✅ Outputs retrieved"
echo ""

# Step 4: Deploy Account1 (S3)
echo "Step 4: Deploying S3 Stack in Account1..."
cd cdk-account1
npm install
cdk deploy DataSourceStack --profile $ACCOUNT1_PROFILE \
  -c account2Id=$ACCOUNT2_ID \
  -c redshiftRoleArn=$REDSHIFT_ROLE_ARN \
  --require-approval never
cd ..
echo "✅ S3 Stack deployed"
echo ""

# Step 5: Create S3 Event Integration
echo "Step 5: Creating S3 Event Integration..."
INTEGRATION_OUTPUT=$(aws redshift create-integration \
  --integration-name s3-data-source-integration \
  --source-arn arn:aws:s3:::$S3_BUCKET_NAME \
  --target-arn $CLUSTER_NAMESPACE_ARN \
  --region $AWS_REGION \
  --profile $ACCOUNT1_PROFILE)

export INTEGRATION_ARN=$(echo $INTEGRATION_OUTPUT | jq -r '.IntegrationArn')
echo "Integration ARN: $INTEGRATION_ARN"
echo "✅ Integration created"
echo ""

# Step 6: Wait for integration to become active
echo "Step 6: Waiting for integration to become active..."
for i in {1..30}; do
  STATUS=$(aws redshift describe-integrations \
    --integration-arn $INTEGRATION_ARN \
    --region $AWS_REGION \
    --profile $ACCOUNT1_PROFILE \
    --query 'Integrations[0].Status' \
    --output text)
  
  echo "Integration status: $STATUS (attempt $i/30)"
  
  if [ "$STATUS" = "active" ]; then
    echo "✅ Integration is active"
    break
  fi
  
  if [ $i -eq 30 ]; then
    echo "⚠️  Integration not active after 30 attempts. Check manually."
    exit 1
  fi
  
  sleep 10
done
echo ""

# Step 7: Save environment variables
echo "Step 7: Saving environment variables..."
cat > .env << EOF
# AWS Configuration
export ACCOUNT1_PROFILE="$ACCOUNT1_PROFILE"
export ACCOUNT2_PROFILE="$ACCOUNT2_PROFILE"
export AWS_REGION="$AWS_REGION"

# Account IDs
export ACCOUNT1_ID="$ACCOUNT1_ID"
export ACCOUNT2_ID="$ACCOUNT2_ID"

# Resources
export S3_BUCKET_NAME="$S3_BUCKET_NAME"
export REDSHIFT_ROLE_ARN="$REDSHIFT_ROLE_ARN"
export CLUSTER_NAMESPACE_ARN="$CLUSTER_NAMESPACE_ARN"
export INTEGRATION_ARN="$INTEGRATION_ARN"
EOF
echo "✅ Environment variables saved to .env"
echo ""

# Step 8: Display next steps
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo ""
echo "1. Connect to Redshift Query Editor v2:"
echo "   https://console.aws.amazon.com/sqlworkbench/home?region=$AWS_REGION"
echo ""
echo "2. Run the SQL script to create tables and COPY JOBs:"
echo "   - Open sql/create_tables.sql"
echo "   - Replace \$S3_BUCKET_NAME with: $S3_BUCKET_NAME"
echo "   - Replace \$REDSHIFT_ROLE_ARN with: $REDSHIFT_ROLE_ARN"
echo "   - Execute the script"
echo ""
echo "3. Upload test data:"
echo "   aws s3 cp data/orders.csv s3://$S3_BUCKET_NAME/orders/ --profile $ACCOUNT1_PROFILE"
echo "   aws s3 cp data/order_items.csv s3://$S3_BUCKET_NAME/order_items/ --profile $ACCOUNT1_PROFILE"
echo "   aws s3 cp data/customers.csv s3://$S3_BUCKET_NAME/customers/ --profile $ACCOUNT1_PROFILE"
echo "   aws s3 cp data/products.csv s3://$S3_BUCKET_NAME/products/ --profile $ACCOUNT1_PROFILE"
echo ""
echo "4. Verify data in Redshift:"
echo "   SELECT COUNT(*) FROM analytics.orders;"
echo "   SELECT COUNT(*) FROM analytics.order_items;"
echo "   SELECT COUNT(*) FROM analytics.customers;"
echo "   SELECT COUNT(*) FROM analytics.products;"
echo ""
echo "To load environment variables later, run:"
echo "   source .env"
echo ""
