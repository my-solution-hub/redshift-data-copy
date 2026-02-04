# Cross-Account S3 to Redshift Data Copy Solution

## Overview

A cross-account S3 to Redshift data copy solution using **Redshift's native COPY JOB** feature with **S3 event integration**. This eliminates the need for Lambda functions or EventBridge, making it simpler and more efficient.

Deployed Accounts:

- Account1: $ACCOUNT1_ID ($ACCOUNT1_PROFILE profile) - Data Source
- Account2: $ACCOUNT2_ID ($ACCOUNT2_PROFILE profile) - Data Processing
- Region: $AWS_REGION

Integration Status: ✅ Active

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

## Prerequisites

- AWS CLI configured with two profiles:
  - Profile for Account1 ($ACCOUNT1_ID) - set as `$ACCOUNT1_PROFILE`
  - Profile for Account2 ($ACCOUNT2_ID) - set as `$ACCOUNT2_PROFILE`
- Node.js 18+ and AWS CDK installed
- Both accounts in the same AWS region (set as `$AWS_REGION`)
- IAM permissions in Account1 to create Redshift integrations
- CDK bootstrapped in both accounts (will be done in Quick Start if not already):
  ```bash
  cdk bootstrap aws://$ACCOUNT1_ID/$AWS_REGION --profile $ACCOUNT1_PROFILE
  cdk bootstrap aws://$ACCOUNT2_ID/$AWS_REGION --profile $ACCOUNT2_PROFILE
  ```

## Quick Start

Complete end-to-end deployment in 7 steps using CDK automation.

**Note:** If you already have S3 bucket and Redshift cluster created manually, skip to [Appendix: Manual Setup for Existing Resources](#appendix-manual-setup-for-existing-resources).

### 1. Set Initial Environment Variables

```bash
# AWS Profiles
export ACCOUNT1_PROFILE="xxx"
export ACCOUNT2_PROFILE="xxx"

# Account IDs
export ACCOUNT1_ID="xxx"
export ACCOUNT2_ID="xxx"
export AWS_REGION="xxx"

# S3 Bucket
export S3_BUCKET_NAME="${ACCOUNT1_ID}-data-source"
```

### 2. Deploy Account2 (Redshift)

```bash
cd cdk-account2 && npm install
cdk deploy --profile $ACCOUNT2_PROFILE -c account1Id=$ACCOUNT1_ID -c s3BucketName=$S3_BUCKET_NAME
```

### 3. Capture Redshift Outputs

```bash
export REDSHIFT_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name RedshiftStack --query 'Stacks[0].Outputs[?OutputKey==`RedshiftRoleArn`].OutputValue' --output text --profile $ACCOUNT2_PROFILE)
export CLUSTER_NAMESPACE_ARN=$(aws cloudformation describe-stacks --stack-name RedshiftStack --query 'Stacks[0].Outputs[?OutputKey==`ClusterNamespaceArn`].OutputValue' --output text --profile $ACCOUNT2_PROFILE)
```

### 4. Deploy Account1 (S3)

```bash
cd ../cdk-account1 && npm install
cdk deploy --profile $ACCOUNT1_PROFILE -c account2Id=$ACCOUNT2_ID -c redshiftRoleArn=$REDSHIFT_ROLE_ARN
```

### 5. Create S3 Event Integration

```bash
INTEGRATION_OUTPUT=$(aws redshift create-integration \
  --integration-name s3-data-source-integration \
  --source-arn arn:aws:s3:::$S3_BUCKET_NAME \
  --target-arn $CLUSTER_NAMESPACE_ARN \
  --region $AWS_REGION --profile $ACCOUNT1_PROFILE)

export INTEGRATION_ARN=$(echo $INTEGRATION_OUTPUT | jq -r '.IntegrationArn')

# Wait for integration to become active
aws redshift describe-integrations \
  --integration-arn $INTEGRATION_ARN \
  --region $AWS_REGION \
  --profile $ACCOUNT1_PROFILE
```

### 6. Create COPY JOB in Redshift

Connect to Redshift using Query Editor v2 and run:

```sql
-- Create target table
CREATE TABLE IF NOT EXISTS public.data_import (
    id INTEGER,
    name VARCHAR(255),
    value DECIMAL(10,2),
    timestamp TIMESTAMP
);

-- Create auto-copy job (use environment variables)
COPY public.data_import
FROM 's3://$S3_BUCKET_NAME/'
IAM_ROLE '$REDSHIFT_ROLE_ARN'
CSV
IGNOREHEADER 1
JOB CREATE data_import_job
AUTO ON;
```

### 7. Upload Test Data and Verify

```bash
# Upload test data
aws s3 cp data/sample1.csv s3://$S3_BUCKET_NAME/ --profile $ACCOUNT1_PROFILE
aws s3 cp data/sample2.csv s3://$S3_BUCKET_NAME/ --profile $ACCOUNT1_PROFILE
```

Verify in Redshift:

```sql
-- Check COPY JOB
SELECT job_id, job_name, data_source 
FROM sys_copy_job 
WHERE job_name = 'data_import_job';

-- View loaded data
SELECT * FROM public.data_import ORDER BY id;
```

## Project Structure

```text
.
├── README.md                          # Complete documentation
├── data/
│   ├── sample1.csv                    # 5 sample records
│   └── sample2.csv                    # 5 sample records
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
DROP JOB data_import_job;

# 3. Delete Account1 Stack
cd cdk-account1
cdk destroy --profile $ACCOUNT1_PROFILE

# 4. Delete Account2 Stack
cd cdk-account2
cdk destroy --profile $ACCOUNT2_PROFILE
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
