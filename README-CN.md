# 跨账户 S3 到 Redshift 数据复制解决方案

## 概述

这是一个跨账户 S3 到 Redshift 数据复制解决方案，使用 **Redshift 原生 COPY JOB** 功能和 **S3 事件集成**。无需使用 Lambda 函数或 EventBridge，使其更简单、更高效。

已部署账户：

- Account1: $ACCOUNT1_ID ($ACCOUNT1_PROFILE profile) - 数据源
- Account2: $ACCOUNT2_ID ($ACCOUNT2_PROFILE profile) - 数据处理
- Region: $AWS_REGION

集成状态：✅ 活跃

## 架构概述

此解决方案使用 Redshift 原生 S3 事件集成和 COPY JOB 功能，实现从 Account1 中的 S3 存储桶自动复制 CSV 文件到 Account2 中的 Redshift 集群。

### 组件

Account1 ($ACCOUNT1_PROFILE profile - $ACCOUNT1_ID) - 数据源账户：

- S3 存储桶：`$ACCOUNT1_ID-data-source`
- S3 存储桶策略允许 Redshift 服务管理事件通知
- S3 存储桶策略允许 Account2 Redshift IAM 角色读取数据

Account2 ($ACCOUNT2_PROFILE profile - $ACCOUNT2_ID) - 数据处理账户：

- Amazon Redshift 集群（ra3.xlplus，单节点）
- 带有公有/私有子网的 VPC，NAT 网关
- Redshift 访问 Account1 S3 的 IAM 角色
- Redshift 资源策略允许 Account1 创建集成
- Secrets Manager 存储数据库凭证

### 数据流

```text
Account1 ($ACCOUNT1_ID)                 Account2 ($ACCOUNT2_ID)
┌─────────────────────┐                    
│  S3 存储桶          │                    
│  $ACCOUNT1_ID-      │                    
│  data-source        │                    
│                     │                    
│  CSV 文件           │                    
└──────────┬──────────┘                    
           │                                
           │ 上传新文件              
           │                                
           ▼                                
┌─────────────────────┐                    ┌──────────────────────┐
│  S3 事件            │                     │  S3 事件             │
│  通知               │───────────────────▶ │  集成                │
│  (自动)             │   跨账户             │  (Redshift 原生)     │
└─────────────────────┘                    └──────────┬───────────┘
                                                      │
                                                      │ 触发
                                                      ▼
                                           ┌──────────────────────┐
                                           │  COPY JOB            │
                                           │  (自动复制)           │
                                           └──────────┬───────────┘
                                                      │
                                                      │ 执行
                                                      ▼
                                           ┌──────────────────────┐
                                           │  Redshift 集群       │
                                           │  (加载数据)           │
                                           └──────────┬───────────┘
                                                      │
                                                      │ 通过 IAM 角色读取
                                                      ▼
                                           ┌──────────────────────┐
                                           │  Account1 S3         │
                                           │  (跨账户              │
                                           │   读取访问)           │
                                           └──────────────────────┘
```

### 主要特性

1. **原生 Redshift 集成**：使用 Redshift 内置的 S3 事件集成和 COPY JOB
2. **无需 Lambda**：Redshift 直接管理自动复制过程
3. **跨账户安全**：适当的 IAM 角色和资源策略确保安全访问
4. **自动跟踪**：Redshift 跟踪已加载的文件以防止重复
5. **可扩展**：Redshift 自动批处理文件以获得最佳性能
6. **完全由 CDK 管理**：通过 CDK 自动化基础设施和策略

## 前提条件

- 配置了两个 profile 的 AWS CLI：
  - Account1 ($ACCOUNT1_ID) 的 profile - 设置为 `$ACCOUNT1_PROFILE`
  - Account2 ($ACCOUNT2_ID) 的 profile - 设置为 `$ACCOUNT2_PROFILE`
- 已安装 Node.js 18+ 和 AWS CDK
- 两个账户在同一 AWS 区域（设置为 `$AWS_REGION`）
- Account1 中具有创建 Redshift 集成的 IAM 权限
- 两个账户中已完成 CDK bootstrap（如果尚未完成，将在快速开始中执行）：
  ```bash
  cdk bootstrap aws://$ACCOUNT1_ID/$AWS_REGION --profile $ACCOUNT1_PROFILE
  cdk bootstrap aws://$ACCOUNT2_ID/$AWS_REGION --profile $ACCOUNT2_PROFILE
  ```

## 快速开始

使用 CDK 自动化完成端到端部署，共 7 个步骤。

**注意：** 如果您已经通过控制台手动创建了 S3 存储桶和 Redshift 集群，请跳转到[附录：现有资源的手动设置](#附录现有资源的手动设置)。

### 1. 设置初始环境变量

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

### 2. 部署 Account2（Redshift）

```bash
cd cdk-account2 && npm install
cdk deploy --profile $ACCOUNT2_PROFILE -c account1Id=$ACCOUNT1_ID -c s3BucketName=$S3_BUCKET_NAME
```

### 3. 捕获 Redshift 输出

```bash
export REDSHIFT_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name RedshiftStack --query 'Stacks[0].Outputs[?OutputKey==`RedshiftRoleArn`].OutputValue' --output text --profile $ACCOUNT2_PROFILE)
export CLUSTER_NAMESPACE_ARN=$(aws cloudformation describe-stacks --stack-name RedshiftStack --query 'Stacks[0].Outputs[?OutputKey==`ClusterNamespaceArn`].OutputValue' --output text --profile $ACCOUNT2_PROFILE)
```

### 4. 部署 Account1（S3）

```bash
cd ../cdk-account1 && npm install
cdk deploy --profile $ACCOUNT1_PROFILE -c account2Id=$ACCOUNT2_ID -c redshiftRoleArn=$REDSHIFT_ROLE_ARN
```

### 5. 创建 S3 事件集成

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

### 6. 在 Redshift 中创建 COPY JOB

使用 Query Editor v2 连接到 Redshift 并运行 SQL 脚本：

```bash
# SQL 脚本将创建：
# - analytics 模式
# - 4 个表：orders, order_items, customers, products
# - 4 个 COPY JOB 用于自动数据加载
cat sql/create_tables.sql
```

或手动执行：

```sql
-- 创建模式
CREATE SCHEMA IF NOT EXISTS analytics;

-- 订单事实表
CREATE TABLE IF NOT EXISTS analytics.orders (
    order_id INTEGER PRIMARY KEY,
    customer_id VARCHAR(10) NOT NULL,
    order_date TIMESTAMP NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    region VARCHAR(50) NOT NULL
) SORTKEY(order_date);

-- 订单明细事实表
CREATE TABLE IF NOT EXISTS analytics.order_items (
    order_id INTEGER NOT NULL,
    product_id VARCHAR(10) NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount DECIMAL(3,2) DEFAULT 0.00,
    PRIMARY KEY (order_id, product_id)
) DISTKEY(order_id) SORTKEY(order_id);

-- 客户维度表
CREATE TABLE IF NOT EXISTS analytics.customers (
    customer_id VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    signup_date DATE NOT NULL,
    customer_segment VARCHAR(20) NOT NULL,
    country VARCHAR(50) NOT NULL
) DISTSTYLE ALL;

-- 产品维度表
CREATE TABLE IF NOT EXISTS analytics.products (
    product_id VARCHAR(10) PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(50) NOT NULL,
    unit_cost DECIMAL(10,2) NOT NULL,
    supplier_id VARCHAR(10) NOT NULL
) DISTSTYLE ALL;

-- 为每个表创建 COPY JOB（替换环境变量）
COPY analytics.orders
FROM 's3://$S3_BUCKET_NAME/orders/'
IAM_ROLE '$REDSHIFT_ROLE_ARN'
CSV
IGNOREHEADER 1
JOB CREATE orders_import_job
AUTO ON;

COPY analytics.order_items
FROM 's3://$S3_BUCKET_NAME/order_items/'
IAM_ROLE '$REDSHIFT_ROLE_ARN'
CSV
IGNOREHEADER 1
JOB CREATE order_items_import_job
AUTO ON;

COPY analytics.customers
FROM 's3://$S3_BUCKET_NAME/customers/'
IAM_ROLE '$REDSHIFT_ROLE_ARN'
CSV
IGNOREHEADER 1
JOB CREATE customers_import_job
AUTO ON;

COPY analytics.products
FROM 's3://$S3_BUCKET_NAME/products/'
IAM_ROLE '$REDSHIFT_ROLE_ARN'
CSV
IGNOREHEADER 1
JOB CREATE products_import_job
AUTO ON;
```

### 7. 上传测试数据并验证

```bash
# 上传测试数据到不同的前缀
aws s3 cp data/orders.csv s3://$S3_BUCKET_NAME/orders/ --profile $ACCOUNT1_PROFILE
aws s3 cp data/order_items.csv s3://$S3_BUCKET_NAME/order_items/ --profile $ACCOUNT1_PROFILE
aws s3 cp data/customers.csv s3://$S3_BUCKET_NAME/customers/ --profile $ACCOUNT1_PROFILE
aws s3 cp data/products.csv s3://$S3_BUCKET_NAME/products/ --profile $ACCOUNT1_PROFILE
```

在 Redshift 中验证：

```sql
-- 检查 COPY JOB
SELECT job_id, job_name, data_source 
FROM sys_copy_job 
WHERE job_name LIKE '%_import_job';

-- 查看加载的数据
SELECT COUNT(*) as order_count FROM analytics.orders;
SELECT COUNT(*) as order_item_count FROM analytics.order_items;
SELECT COUNT(*) as customer_count FROM analytics.customers;
SELECT COUNT(*) as product_count FROM analytics.products;

-- 示例分析查询
SELECT 
    c.customer_segment,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_revenue
FROM analytics.orders o
JOIN analytics.customers c ON o.customer_id = c.customer_id
WHERE o.status = 'completed'
GROUP BY c.customer_segment
ORDER BY total_revenue DESC;
```

## 项目结构

```text
.
├── README.md                          # 完整文档
├── data/
│   ├── orders.csv                     # 订单事实表（10 条记录）
│   ├── order_items.csv                # 订单明细（16 条记录）
│   ├── customers.csv                  # 客户维度（7 条记录）
│   └── products.csv                   # 产品维度（8 条记录）
├── sql/
│   ├── create_tables.sql              # 表结构和 COPY JOB
│   └── sample_queries.sql             # 示例分析查询
├── cdk-account1/                      # Account1 CDK ($ACCOUNT1_PROFILE)
│   ├── bin/app.ts
│   ├── lib/
│   │   └── data-source-stack.ts       # S3 存储桶及策略
│   ├── package.json
│   ├── tsconfig.json
│   └── cdk.json
└── cdk-account2/                      # Account2 CDK ($ACCOUNT2_PROFILE)
    ├── bin/app.ts
    ├── lib/
    │   ├── redshift-stack.ts          # Redshift 集群及策略
    │   ├── quicksight-stack.ts        # QuickSight VPC 连接
    │   └── lambda/
    │       └── resource-policy-handler.js
    ├── package.json
    ├── tsconfig.json
    └── cdk.json
```

## 安全考虑

1. **S3 存储桶策略**：允许 Redshift 服务管理通知（集成创建时无条件限制）
2. **Redshift 资源策略**：允许 Account1 root 创建集成
3. **跨账户 IAM 角色**：Account2 中的 Redshift 角色可以从 Account1 S3 读取
4. **加密**：S3 存储桶使用 SSE-S3 加密
5. **VPC**：Redshift 部署在私有子网中
6. **密钥管理**：数据库凭证存储在 Secrets Manager 中

## 监控

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

## 故障排除

### 集成创建失败并出现权限错误

- 确保从 Account1（$ACCOUNT1_PROFILE profile）创建集成
- 验证 Redshift 资源策略包含 Account1 主体
- 检查 S3 存储桶策略允许 Redshift 服务且无条件限制

**检查集成状态：**

```bash
aws redshift describe-integrations \
  --integration-arn <integration-arn> \
  --region $AWS_REGION \
  --profile $ACCOUNT1_PROFILE
```

**检查 Redshift 资源策略：**

```bash
aws redshift get-resource-policy \
  --resource-arn <cluster-namespace-arn> \
  --region $AWS_REGION \
  --profile $ACCOUNT2_PROFILE
```

### COPY JOB 未触发

- 验证集成状态为 `active`
- 检查 S3 事件通知已配置（集成后自动配置）
- 查看 `sys_copy_job_info` 获取消息

**检查集成详情：**

```sql
SELECT * FROM svv_copy_job_integrations;
```

### S3 权限被拒绝

- 验证 Account2 中的 Redshift 角色 ARN 具有 S3 读取权限
- 检查 S3 存储桶策略允许 Redshift 角色
- 确保角色信任关系允许 redshift.amazonaws.com

**检查 S3 存储桶策略：**

```bash
aws s3api get-bucket-policy \
  --bucket $S3_BUCKET_NAME \
  --profile $ACCOUNT1_PROFILE
```

**检查 Redshift IAM 角色：**

```bash
aws iam get-role \
  --role-name <redshift-role-name> \
  --profile $ACCOUNT2_PROFILE
```

### 数据未出现在表中

- 检查 `sys_copy_job_detail` 获取文件状态
- 查看 `stl_load_errors` 获取 COPY 错误
- 验证 CSV 格式与表架构匹配

**检查加载错误：**

```sql
SELECT * FROM stl_load_errors 
ORDER BY starttime DESC 
LIMIT 10;
```

**检查加载历史：**

```sql
SELECT query, filename, curtime, status 
FROM stl_load_commits 
ORDER BY curtime DESC 
LIMIT 20;
```

## 清理

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
cdk destroy --profile $ACCOUNT1_PROFILE

# 4. Delete Account2 Stack
cd cdk-account2
cdk destroy --profile $ACCOUNT2_PROFILE
```

## 关键经验

### 1. 集成创建位置

**必须**从 Account1（S3 存储桶所在位置）创建 S3 事件集成，而不是从 Account2（Redshift 所在位置）。

### 2. S3 存储桶策略

Redshift 服务权限在集成创建期间**不应**有条件限制（`aws:SourceArn`、`aws:SourceAccount`）：

```typescript
// ✅ Correct - No conditions
bucket.addToResourcePolicy(new iam.PolicyStatement({
  effect: iam.Effect.ALLOW,
  principals: [new iam.ServicePrincipal('redshift.amazonaws.com')],
  actions: ['s3:GetBucketNotification', 's3:PutBucketNotification', 's3:GetBucketLocation'],
  resources: [bucket.bucketArn]
}));
```

### 3. Redshift 资源策略

必须允许 Account1 root 主体创建集成：

```json
{
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::$ACCOUNT1_ID:root"},
  "Action": "redshift:CreateInboundIntegration",
  "Resource": "$CLUSTER_NAMESPACE_ARN"
}
```

**注意：** 运行命令时将替换环境变量。

### 4. IAM 权限

除了资源策略外，Account1 用户/角色还需要 `redshift:CreateIntegration` IAM 权限。

### 5. 跨账户要求

跨账户集成需要资源策略（S3 和 Redshift）和 IAM 策略。

## 后续步骤

1. 在 COPY 之前添加数据验证
2. 实现错误处理和重试逻辑
3. 添加失败的 SNS 通知
4. 创建 CloudWatch 仪表板进行监控
5. 添加对不同文件格式的支持（JSON、Parquet）
6. 实现数据去重逻辑

## QuickSight 集成

### 部署 QuickSight 堆栈

```bash
cd cdk-account2
cdk deploy QuickSightStack --profile $ACCOUNT2_PROFILE \
  -c account1Id=$ACCOUNT1_ID \
  -c s3BucketName=$S3_BUCKET_NAME \
  -c enableQuickSight=true
```

### 设置 QuickSight

1. **订阅 QuickSight**（如果尚未订阅）：
   - 进入 QuickSight 控制台
   - 选择企业版
   - 选择区域：ap-southeast-1

2. **创建 VPC 连接**（手动 - 必需）：
   
   由于 CloudFormation 的 IAM 权限验证时序问题，QuickSight VPC 连接必须在控制台手动创建。
   
   - 进入 QuickSight 控制台 → 管理 QuickSight → 管理 VPC 连接
   - 点击"添加 VPC 连接"
   - 使用堆栈输出中的以下值：
     - VPC 连接名称：`redshift-vpc-connection`
     - VPC ID：从 RedshiftStack VPC 获取（例如：`vpc-08a5c1c6297ed920e`）
     - 子网 ID：从 RedshiftStack 输出获取（例如：`subnet-06373a3eeae5fc367`, `subnet-09c8f4f3660a2c01e`）
     - 安全组：从 QuickSightStack 输出 `QuickSightSecurityGroupId` 获取
     - IAM 角色：使用 QuickSightStack 输出中的 `QuickSightRoleArn`
   - 点击"创建"
   - 等待状态从"创建中"变为"可用"（可能需要几分钟）

3. **创建数据源**：
   - 在 QuickSight 控制台，进入数据集 → 新建数据集
   - 选择"Redshift 自动发现的集群"
   - 选择您的集群：`redshift-cluster`
   - 数据库：`dev`
   - 连接类型：使用 VPC 连接
   - VPC 连接：选择 `redshift-vpc-connection`（您刚创建的）
   - 身份验证：使用 IAM 凭证
   - IAM 角色：使用堆栈输出中的 QuickSightRedshiftRole ARN

3. **创建数据集**：
   - 从 `analytics` 模式选择表：`orders`, `order_items`, `customers`, `products`
   - 连接表进行综合分析
   - 导入到 SPICE 以获得更好的性能
   - 点击"可视化"

4. **构建仪表板**：
   - 按区域销售（柱状图）
   - 收入趋势（折线图）
   - 热门产品（表格）
   - 客户细分分析（饼图）
   - 添加过滤器、计算字段
   - 发布仪表板以供共享

### QuickSight 成本

- **企业版**：每位作者 $18/月，读者 $0.30/会话（最高 $5/月）
- **SPICE**：$0.25/GB/月（每位作者免费 10GB）
- **VPC 连接**：无额外费用

### 清理 QuickSight

```bash
# 删除 QuickSight 堆栈
cd cdk-account2
cdk destroy QuickSightStack --profile $ACCOUNT2_PROFILE

# 取消 QuickSight 订阅（在控制台手动操作）
```

## 附录：现有资源的手动设置

如果您已经通过控制台手动创建了 S3 存储桶和 Redshift 集群，则需要配置以下策略和权限。本节提供 CLI 命令来设置所需的配置，无需使用 CDK。

### Account1（S3 存储桶账户）- 手动配置

#### 1. S3 存储桶策略 - 允许 Redshift 服务

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

#### 2. IAM 用户策略 - 允许集成创建

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

### Account2（Redshift 账户）- 手动配置

#### 1. 为 Redshift 创建 IAM 角色

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

#### 2. 将 IAM 角色附加到 Redshift 集群

```bash
# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name RedshiftS3AccessRole --query 'Role.Arn' --output text --profile $ACCOUNT2_PROFILE)

# Attach role to cluster
aws redshift modify-cluster-iam-roles \
  --cluster-identifier YOUR-CLUSTER-ID \
  --add-iam-roles $ROLE_ARN \
  --profile $ACCOUNT2_PROFILE
```

#### 3. 配置 Redshift 资源策略

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

#### 4. 创建 S3 事件集成（从 Account1）

```bash
aws redshift create-integration \
  --integration-name s3-data-source-integration \
  --source-arn arn:aws:s3:::YOUR-BUCKET-NAME \
  --target-arn $NAMESPACE_ARN \
  --region $AWS_REGION \
  --profile $ACCOUNT1_PROFILE
```

#### 5. 在 Redshift 中创建 COPY JOB

连接到 Redshift 并运行：

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
