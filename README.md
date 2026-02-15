# Cross-Account S3 to Redshift Data Copy with QuickSight Analytics

## 🎯 What This Demo Does

This demo shows you how to:
1. **Automatically copy data** from S3 (Account1) to Redshift (Account2) using native AWS features
2. **Analyze data** in Redshift with pre-built SQL queries
3. **Visualize insights** in QuickSight dashboards

**No Lambda, No EventBridge** - Uses Redshift's native S3 event integration for simplicity.

## 📊 Demo Scenario

**Business Context**: E-commerce sales analytics
- **Data**: Orders, customers, products, order items
- **Analysis**: Sales by region, top products, customer segments, daily trends
- **Visualization**: Interactive QuickSight dashboards

## ⏱️ Time to Complete

- **Infrastructure Setup**: 20-30 minutes
- **Data Loading**: 2-3 minutes
- **QuickSight Setup**: 10-15 minutes
- **Total**: ~45 minutes

## 🏗️ Architecture

**Account1** (Data Source) → **Account2** (Analytics)
- S3 Bucket → Redshift Cluster → QuickSight Dashboards

## Architecture Overview

This solution enables automatic copying of CSV files from an S3 bucket in Account1 to a Redshift cluster in Account2 using Redshift's native S3 event integration and COPY JOB features.

### Components

Account1 ($ACCOUNT1_PROFILE profile - $ACCOUNT1_ID) - Data Source Account:

- S3 bucket: `$ACCOUNT1_ID-data-source`
- S3 bucket policy allowing Redshift service to manage event notifications
- S3 bucket policy allowing Account2 Redshift IAM role to read data

Account2 ($ACCOUNT2_PROFILE profile - $ACCOUNT2_ID) - Data Processing Account:

- Amazon Redshift Cluster (ra3.xlplus, single-node)
- VPC with public/private subnets, NAT Gateway
- IAM role for Redshift to access Account1 S3
- Redshift resource policy allowing Account1 to create integration
- Secrets Manager for database credentials

### Data Flow

```text
Account1 ($ACCOUNT1_ID)                 Account2 ($ACCOUNT2_ID)
┌─────────────────────┐                    
│  S3 Bucket          │                    
│  $ACCOUNT1_ID-      │                    
│  data-source        │                    
│                     │                    
│  CSV files          │                    
└──────────┬──────────┘                    
           │                                
           │ New file uploaded              
           │                                
           ▼                                
┌─────────────────────┐                    ┌──────────────────────┐
│  S3 Event           │                    │  S3 Event            │
│  Notification       │───────────────────▶│  Integration         │
│  (automatic)        │   cross-account    │  (Redshift native)   │
└─────────────────────┘                    └──────────┬───────────┘
                                                      │
                                                      │ triggers
                                                      ▼
                                           ┌──────────────────────┐
                                           │  COPY JOB            │
                                           │  (auto-copy)         │
                                           └──────────┬───────────┘
                                                      │
                                                      │ executes
                                                      ▼
                                           ┌──────────────────────┐
                                           │  Redshift Cluster    │
                                           │  (loads data)        │
                                           └──────────┬───────────┘
                                                      │
                                                      │ reads via IAM role
                                                      ▼
                                           ┌──────────────────────┐
                                           │  Account1 S3         │
                                           │  (cross-account      │
                                           │   read access)       │
                                           └──────────────────────┘
```

### Key Features

1. **Native Redshift Integration**: Uses Redshift's built-in S3 event integration and COPY JOB
2. **No Lambda Required**: Redshift directly manages the auto-copy process
3. **Cross-Account Security**: Proper IAM roles and resource policies for secure access
4. **Automatic Tracking**: Redshift tracks loaded files to prevent duplicates
5. **Scalable**: Redshift batches files automatically for optimal performance
6. **Fully Managed by CDK**: Infrastructure and policies automated via CDK

## 📋 Prerequisites

Before starting, ensure you have:

### Required
- ✅ Two AWS accounts (or one account with cross-account simulation)
- ✅ AWS CLI installed and configured
- ✅ Node.js 18+ installed
- ✅ AWS CDK installed (`npm install -g aws-cdk`)
- ✅ `jq` installed (for JSON parsing)

### AWS Profiles
Configure two AWS CLI profiles:
```bash
# Account1 profile (Data Source)
aws configure --profile cloudops-demo

# Account2 profile (Analytics)
aws configure --profile default
```

### Permissions Required
- **Account1**: S3, IAM, Redshift integration creation
- **Account2**: Redshift, VPC, Secrets Manager, QuickSight, CloudFormation

### Optional (for QuickSight)
- QuickSight Enterprise Edition subscription
- QuickSight user account

## 🚀 Quick Start (Complete Demo in 7 Steps)

### Step 1: Set Environment Variables

```bash
# AWS Profiles
export ACCOUNT1_PROFILE="cloudops-demo"  # Your Account1 profile name
export ACCOUNT2_PROFILE="default"        # Your Account2 profile name

# Get Account IDs automatically
export ACCOUNT1_ID=$(aws sts get-caller-identity --profile $ACCOUNT1_PROFILE --query Account --output text)
export ACCOUNT2_ID=$(aws sts get-caller-identity --profile $ACCOUNT2_PROFILE --query Account --output text)

# Set Region
export AWS_REGION="ap-southeast-1"  # Change to your preferred region

# S3 Bucket Name
export S3_BUCKET_NAME="${ACCOUNT1_ID}-data-source"

# Verify settings
echo "Account1: $ACCOUNT1_ID ($ACCOUNT1_PROFILE)"
echo "Account2: $ACCOUNT2_ID ($ACCOUNT2_PROFILE)"
echo "Region: $AWS_REGION"
echo "S3 Bucket: $S3_BUCKET_NAME"
```

### Step 2: Bootstrap CDK (First Time Only)

```bash
# Bootstrap Account2 (Redshift account)
cd cdk-account2
cdk bootstrap aws://$ACCOUNT2_ID/$AWS_REGION --profile $ACCOUNT2_PROFILE

# Bootstrap Account1 (S3 account)
cd ../cdk-account1
cdk bootstrap aws://$ACCOUNT1_ID/$AWS_REGION --profile $ACCOUNT1_PROFILE
cd ..
```

### Step 3: Deploy Redshift Stack (Account2)

```bash
cd cdk-account2
npm install

# Deploy Redshift cluster, VPC, and IAM roles
cdk deploy RedshiftStack --profile $ACCOUNT2_PROFILE \
  -c account1Id=$ACCOUNT1_ID \
  -c s3BucketName=$S3_BUCKET_NAME

# ⏱️ This takes ~15-20 minutes (Redshift cluster creation)
```

**What gets created:**
- Redshift cluster (ra3.xlplus, single-node)
- VPC with public/private subnets
- IAM role for S3 access
- Secrets Manager for database credentials
- Security groups

### Step 4: Capture Redshift Outputs

```bash
# Save important values from CloudFormation outputs
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

# Verify
echo "Redshift Role: $REDSHIFT_ROLE_ARN"
echo "Cluster Namespace: $CLUSTER_NAMESPACE_ARN"
```

### Step 5: Deploy S3 Stack (Account1)

```bash
cd ../cdk-account1
npm install

# Deploy S3 bucket with cross-account policies
cdk deploy --profile $ACCOUNT1_PROFILE \
  -c account2Id=$ACCOUNT2_ID \
  -c redshiftRoleArn=$REDSHIFT_ROLE_ARN

# ⏱️ This takes ~2-3 minutes
```

**What gets created:**
- S3 bucket with encryption
- Bucket policies for Redshift access
- Cross-account permissions

### Step 6: Create S3 Event Integration

```bash
# Create integration from Account1
INTEGRATION_OUTPUT=$(aws redshift create-integration \
  --integration-name s3-data-source-integration \
  --source-arn arn:aws:s3:::$S3_BUCKET_NAME \
  --target-arn $CLUSTER_NAMESPACE_ARN \
  --region $AWS_REGION \
  --profile $ACCOUNT1_PROFILE)

export INTEGRATION_ARN=$(echo $INTEGRATION_OUTPUT | jq -r '.IntegrationArn')

# Wait for integration to become active (takes ~30 seconds)
echo "Waiting for integration to become active..."
sleep 30

# Check status
aws redshift describe-integrations \
  --integration-arn $INTEGRATION_ARN \
  --region $AWS_REGION \
  --profile $ACCOUNT1_PROFILE
```

**Expected output:** Status should be "active"

### Step 7: Create Tables and COPY JOBs in Redshift

**Option A: Using Redshift Query Editor v2 (Recommended)**

1. Open AWS Console → Redshift → Query Editor v2
2. Connect to cluster: `redshift-cluster`
3. Database: `dev`
4. Run the SQL script:

```bash
# View the SQL script
cat sql/create_tables_ready.sql
```

Copy and paste the entire script into Query Editor v2 and execute.

**Option B: Using AWS CLI**

```bash
# Get database credentials from Secrets Manager
SECRET_ARN=$(aws cloudformation describe-stacks \
  --stack-name RedshiftStack \
  --query 'Stacks[0].Outputs[?OutputKey==`SecretArn`].OutputValue' \
  --output text \
  --profile $ACCOUNT2_PROFILE)

# Execute SQL (requires aws redshift-data CLI)
aws redshift-data execute-statement \
  --cluster-identifier redshift-cluster \
  --database dev \
  --secret-arn $SECRET_ARN \
  --sql file://sql/create_tables_ready.sql \
  --region $AWS_REGION \
  --profile $ACCOUNT2_PROFILE
```

**What gets created:**
- `analytics` schema
- 4 tables: orders, order_items, customers, products
- 4 COPY JOBs for automatic data loading

### Step 8: Upload Test Data

```bash
# Upload sample CSV files to S3
aws s3 cp data/orders.csv s3://$S3_BUCKET_NAME/orders/ --profile $ACCOUNT1_PROFILE
aws s3 cp data/order_items.csv s3://$S3_BUCKET_NAME/order_items/ --profile $ACCOUNT1_PROFILE
aws s3 cp data/customers.csv s3://$S3_BUCKET_NAME/customers/ --profile $ACCOUNT1_PROFILE
aws s3 cp data/products.csv s3://$S3_BUCKET_NAME/products/ --profile $ACCOUNT1_PROFILE

echo "✅ Data uploaded! COPY JOBs will automatically load data into Redshift."
```

### Step 9: Verify Data Loading

Wait 1-2 minutes for COPY JOBs to process, then verify in Redshift Query Editor:

```sql
-- Check COPY JOB status
SELECT job_id, job_name, data_source, job_status 
FROM sys_copy_job 
WHERE job_name LIKE '%_import_job';

-- Verify data loaded
SELECT 'orders' as table_name, COUNT(*) as row_count FROM analytics.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM analytics.order_items
UNION ALL
SELECT 'customers', COUNT(*) FROM analytics.customers
UNION ALL
SELECT 'products', COUNT(*) FROM analytics.products;
```

**Expected results:**
- orders: 10 rows
- order_items: 16 rows
- customers: 7 rows
- products: 8 rows

### Step 10: Run Sample Analytics Queries

```bash
# View sample queries
cat sql/sample_queries.sql
```

Try these queries in Redshift Query Editor:
1. Sales by Region
2. Top Products by Revenue
3. Customer Segment Analysis
4. Daily Sales Trend
5. Product Category Performance

## 🎨 QuickSight Setup (Optional)

## Project Structure

```text
.
├── README.md                          # Complete documentation
├── data/
│   ├── orders.csv                     # Orders fact table (10 records)
│   ├── order_items.csv                # Order line items (16 records)
│   ├── customers.csv                  # Customer dimension (7 records)
│   └── products.csv                   # Product dimension (8 records)
├── sql/
│   ├── create_tables.sql              # Table schemas and COPY JOBs
│   └── sample_queries.sql             # Sample analytics queries
├── cdk-account1/                      # Account1 CDK ($ACCOUNT1_PROFILE)
│   ├── bin/app.ts
│   ├── lib/
│   │   └── data-source-stack.ts       # S3 bucket with policies
│   ├── package.json
│   ├── tsconfig.json
│   └── cdk.json
└── cdk-account2/                      # Account2 CDK ($ACCOUNT2_PROFILE)
    ├── bin/app.ts
    ├── lib/
    │   ├── redshift-stack.ts          # Redshift cluster + policies
    │   ├── quicksight-stack.ts        # QuickSight VPC connection
    │   └── lambda/
    │       └── resource-policy-handler.js
    ├── package.json
    ├── tsconfig.json
    └── cdk.json
```

## Security Considerations

1. **S3 Bucket Policy**: Allows Redshift service to manage notifications (no conditions for integration creation)
2. **Redshift Resource Policy**: Allows Account1 root to create integrations
3. **Cross-Account IAM Role**: Redshift role in Account2 can read from Account1 S3
4. **Encryption**: S3 bucket uses SSE-S3 encryption
5. **VPC**: Redshift deployed in private subnets
6. **Secrets Management**: Database credentials stored in Secrets Manager

## Monitoring

```sql
-- View COPY JOB status
SELECT * FROM sys_copy_job;

-- View file processing details
SELECT * FROM sys_copy_job_detail;

-- View load history
SELECT * FROM sys_load_history ORDER BY start_time DESC LIMIT 10;

-- Check for errors
SELECT * FROM stl_load_errors ORDER BY starttime DESC LIMIT 10;

-- View integration details
SELECT * FROM svv_copy_job_integrations;
```

## Troubleshooting

### Integration creation fails with permission error

- Ensure you're creating the integration from Account1 ($ACCOUNT1_PROFILE profile)
- Verify Redshift resource policy includes Account1 principal
- Check S3 bucket policy allows Redshift service without conditions

**Check integration status:**

```bash
aws redshift describe-integrations \
  --integration-arn <integration-arn> \
  --region $AWS_REGION \
  --profile $ACCOUNT1_PROFILE
```

**Check Redshift resource policy:**

```bash
aws redshift get-resource-policy \
  --resource-arn <cluster-namespace-arn> \
  --region $AWS_REGION \
  --profile $ACCOUNT2_PROFILE
```

### COPY JOB not triggering

- Verify integration status is `active`
- Check S3 event notifications are configured (automatic after integration)
- Review `sys_copy_job_info` for messages

**Check integration details:**

```sql
SELECT * FROM svv_copy_job_integrations;
```

### Permission denied on S3

- Verify Redshift role ARN in Account2 has S3 read permissions
- Check S3 bucket policy allows the Redshift role
- Ensure role trust relationship allows redshift.amazonaws.com

**Check S3 bucket policy:**

```bash
aws s3api get-bucket-policy \
  --bucket $S3_BUCKET_NAME \
  --profile $ACCOUNT1_PROFILE
```

**Check Redshift IAM role:**

```bash
aws iam get-role \
  --role-name <redshift-role-name> \
  --profile $ACCOUNT2_PROFILE
```

### Data not appearing in table

- Check `sys_copy_job_detail` for file status
- Review `stl_load_errors` for COPY errors
- Verify CSV format matches table schema

**Check for load errors:**

```sql
SELECT * FROM stl_load_errors 
ORDER BY starttime DESC 
LIMIT 10;
```

**Check load history:**

```sql
SELECT query, filename, curtime, status 
FROM stl_load_commits 
ORDER BY curtime DESC 
LIMIT 20;
```

## Cleanup

```bash
# 1. Delete S3 Event Integration (from Account1)
aws redshift delete-integration \
  --integration-arn $INTEGRATION_ARN \
  --region $AWS_REGION \
  --profile $ACCOUNT1_PROFILE

# 2. Drop COPY JOB (in Redshift)
COPY JOB DROP data_import_job;

# 3. Delete Account1 Stack
cd cdk-account1
cdk destroy --profile $ACCOUNT1_PROFILE --force

cd ..

# 4. Delete Account2 Stack
cd cdk-account2
cdk destroy --profile $ACCOUNT2_PROFILE --force
```

## Key Learnings

### 1. Integration Creation Location

**MUST** create S3 event integration from Account1 (where S3 bucket is), not Account2 (where Redshift is).

### 2. S3 Bucket Policy

Redshift service permissions should **NOT** have conditions (`aws:SourceArn`, `aws:SourceAccount`) during integration creation:

```typescript
// ✅ Correct - No conditions
bucket.addToResourcePolicy(new iam.PolicyStatement({
  effect: iam.Effect.ALLOW,
  principals: [new iam.ServicePrincipal('redshift.amazonaws.com')],
  actions: ['s3:GetBucketNotification', 's3:PutBucketNotification', 's3:GetBucketLocation'],
  resources: [bucket.bucketArn]
}));
```

### 3. Redshift Resource Policy

Must allow Account1 root principal to create integrations:

```json
{
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::$ACCOUNT1_ID:root"},
  "Action": "redshift:CreateInboundIntegration",
  "Resource": "$CLUSTER_NAMESPACE_ARN"
}
```

**Note:** The environment variables will be substituted when you run the commands.

### 4. IAM Permissions

Account1 users/roles need `redshift:CreateIntegration` IAM permission in addition to resource policies.

### 5. Cross-Account Requirements

Both resource policies (S3 and Redshift) and IAM policies are required for cross-account integrations.

## Next Steps

1. Add data validation before COPY
2. Implement error handling and retry logic
3. Add SNS notifications for failures
4. Create CloudWatch dashboard for monitoring
5. Add support for different file formats (JSON, Parquet)
6. Implement data deduplication logic

## QuickSight Integration

### Deploy QuickSight Stack

```bash
cd cdk-account2
cdk deploy QuickSightStack --profile $ACCOUNT2_PROFILE \
  -c account1Id=$ACCOUNT1_ID \
  -c s3BucketName=$S3_BUCKET_NAME \
  -c enableQuickSight=true
```

### Setup QuickSight

1. **Subscribe to QuickSight** (if not already):
   - Go to QuickSight console
   - Choose Enterprise Edition
   - Select region: ap-southeast-1

2. **Create VPC Connection** (Manual - Required):
   
   The QuickSight VPC connection must be created manually in the console due to IAM permission validation timing issues with CloudFormation.
   
   - Go to QuickSight console → Manage QuickSight → Manage VPC connections
   - Click "Add VPC connection"
   - Use these values from stack outputs:
     - VPC connection name: `redshift-vpc-connection`
     - VPC ID: Get from RedshiftStack VPC (e.g., `vpc-08a5c1c6297ed920e`)
     - Subnet IDs: Get from RedshiftStack outputs (e.g., `subnet-06373a3eeae5fc367`, `subnet-09c8f4f3660a2c01e`)
     - Security group: Get from QuickSightStack output `QuickSightSecurityGroupId`
     - IAM role: Use the `QuickSightRoleArn` from QuickSightStack outputs
   - Click "Create"
   - Wait for status to change from "Creation in progress" to "Available" (may take a few minutes)

3. **Create Data Source**:
   - In QuickSight console, go to Datasets → New dataset
   - Choose "Redshift Auto-discovered cluster"
   - Select your cluster: `redshift-cluster`
   - Database: `dev`
   - Connection type: Use VPC connection
   - VPC connection: Select `redshift-vpc-connection` (the one you just created)
   - Authentication: Use IAM credentials
   - IAM role: Use the QuickSightRedshiftRole ARN from stack outputs

3. **Create Dataset**:
   - Select tables from `analytics` schema: `orders`, `order_items`, `customers`, `products`
   - Join tables for comprehensive analysis
   - Import to SPICE for better performance
   - Click "Visualize"

4. **Build Dashboard**:
   - Sales by Region (bar chart)
   - Revenue Trend (line chart)
   - Top Products (table)
   - Customer Segment Analysis (pie chart)
   - Add filters, calculated fields
   - Publish dashboard for sharing

### QuickSight Costs

- **Enterprise Edition**: $18/month per author, $0.30/session for readers (max $5/month)
- **SPICE**: $0.25/GB/month (10GB free per author)
- **VPC Connection**: No additional charge

### Cleanup QuickSight

```bash
# Delete QuickSight stack
cd cdk-account2
cdk destroy QuickSightStack --profile $ACCOUNT2_PROFILE

# Cancel QuickSight subscription (manual in console)
```

## Appendix: Manual Setup for Existing Resources

If you already have S3 bucket and Redshift cluster created manually via console, you need to configure the following policies and permissions. This section provides CLI commands to set up the required configuration without using CDK.

### Account1 (S3 Bucket Account) - Manual Configuration

#### 1. S3 Bucket Policy - Allow Redshift Service

```bash
# Create policy file
cat > ./tmp/s3-bucket-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RedshiftServiceAccess",
      "Effect": "Allow",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Action": [
        "s3:GetBucketNotification",
        "s3:PutBucketNotification",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME"
    },
    {
      "Sid": "RedshiftRoleAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT2-ID:role/YOUR-REDSHIFT-ROLE"
      },
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR-BUCKET-NAME",
        "arn:aws:s3:::YOUR-BUCKET-NAME/*"
      ]
    }
  ]
}
EOF

# Apply bucket policy
aws s3api put-bucket-policy \
  --bucket YOUR-BUCKET-NAME \
  --policy file://./tmp/s3-bucket-policy.json \
  --profile $ACCOUNT1_PROFILE
```

#### 2. IAM User Policy - Allow Integration Creation

```bash
# Create policy file
cat > ./tmp/user-integration-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "redshift:CreateIntegration",
        "redshift:DeleteIntegration",
        "redshift:DescribeIntegrations"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach policy to user
aws iam put-user-policy \
  --user-name YOUR-USERNAME \
  --policy-name RedshiftIntegrationPolicy \
  --policy-document file://./tmp/user-integration-policy.json \
  --profile $ACCOUNT1_PROFILE
```

### Account2 (Redshift Account) - Manual Configuration

#### 1. Create IAM Role for Redshift

```bash
# Create trust policy
cat > ./tmp/redshift-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name RedshiftS3AccessRole \
  --assume-role-policy-document file://./tmp/redshift-trust-policy.json \
  --profile $ACCOUNT2_PROFILE

# Create S3 access policy
cat > ./tmp/redshift-s3-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::ACCOUNT1-BUCKET-NAME",
        "arn:aws:s3:::ACCOUNT1-BUCKET-NAME/*"
      ]
    }
  ]
}
EOF

# Attach policy to role
aws iam put-role-policy \
  --role-name RedshiftS3AccessRole \
  --policy-name S3AccessPolicy \
  --policy-document file://./tmp/redshift-s3-policy.json \
  --profile $ACCOUNT2_PROFILE
```

#### 2. Attach IAM Role to Redshift Cluster

```bash
# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name RedshiftS3AccessRole --query 'Role.Arn' --output text --profile $ACCOUNT2_PROFILE)

# Attach role to cluster
aws redshift modify-cluster-iam-roles \
  --cluster-identifier YOUR-CLUSTER-ID \
  --add-iam-roles $ROLE_ARN \
  --profile $ACCOUNT2_PROFILE
```

#### 3. Configure Redshift Resource Policy

```bash
# Get cluster namespace ARN
NAMESPACE_ARN=$(aws redshift describe-clusters \
  --cluster-identifier YOUR-CLUSTER-ID \
  --query 'Clusters[0].ClusterNamespaceArn' \
  --output text \
  --profile $ACCOUNT2_PROFILE)

# Create resource policy
cat > ./tmp/redshift-resource-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Action": "redshift:AuthorizeInboundIntegration",
      "Resource": "$NAMESPACE_ARN"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT1-ID:root"
      },
      "Action": "redshift:CreateInboundIntegration",
      "Resource": "$NAMESPACE_ARN"
    }
  ]
}
EOF

# Apply resource policy
aws redshift put-resource-policy \
  --resource-arn "$NAMESPACE_ARN" \
  --policy file://./tmp/redshift-resource-policy.json \
  --profile $ACCOUNT2_PROFILE
```

#### 4. Create S3 Event Integration (from Account1)

```bash
aws redshift create-integration \
  --integration-name s3-data-source-integration \
  --source-arn arn:aws:s3:::YOUR-BUCKET-NAME \
  --target-arn $NAMESPACE_ARN \
  --region $AWS_REGION \
  --profile $ACCOUNT1_PROFILE
```

#### 5. Create COPY JOB in Redshift

Connect to Redshift and run:

```sql
-- Create target table
CREATE TABLE IF NOT EXISTS public.data_import (
    id INTEGER,
    name VARCHAR(255),
    value DECIMAL(10,2),
    timestamp TIMESTAMP
);

-- Create auto-copy job
COPY public.data_import
FROM 's3://YOUR-BUCKET-NAME/'
IAM_ROLE 'arn:aws:iam::ACCOUNT2-ID:role/RedshiftS3AccessRole'
CSV
IGNOREHEADER 1
JOB CREATE data_import_job
AUTO ON;
```
