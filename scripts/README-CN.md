# QuickSight 自动化脚本

此目录包含用于自动化 QuickSight 数据集创建和管理的脚本。

## 脚本概述

### 1. create-quicksight-datasets.sh

为所有示例查询创建 QuickSight 数据集,并为仪表板集成做好准备。

**功能:**
- 从示例查询创建 4 个新数据集(查询 2-5)
- 使用适当的列类型配置每个数据集
- 使用 SPICE 导入模式以获得快速性能
- 保存数据集 ID 以供后续使用

**创建的数据集:**
1. `top_products` - 按收入排名前 10 的产品
2. `customer_segments` - 客户细分分析
3. `daily_sales` - 每日销售趋势
4. `category_performance` - 产品类别盈利能力

**使用方法:**
```bash
chmod +x scripts/create-quicksight-datasets.sh
./scripts/create-quicksight-datasets.sh
```

**先决条件:**
- AWS CLI 已配置 `default` 配置文件
- QuickSight 订阅处于活动状态
- Redshift 数据源已创建
- 已安装 `jq` 和 `uuidgen`

### 2. refresh-datasets.sh

为所有创建的数据集触发 SPICE 摄取,以从 Redshift 加载数据。

**功能:**
- 从上一个脚本读取数据集 ID
- 为每个数据集触发 SPICE 摄取
- 将数据从 Redshift 加载到 QuickSight SPICE

**使用方法:**
```bash
chmod +x scripts/refresh-datasets.sh
./scripts/refresh-datasets.sh
```

**先决条件:**
- 必须先运行 `create-quicksight-datasets.sh`
- 数据集 ID 文件存在于 `/tmp/dataset-ids.txt`

## 完整工作流程

### 步骤 1: 创建数据集

```bash
# 使脚本可执行
chmod +x scripts/*.sh

# 创建所有数据集
./scripts/create-quicksight-datasets.sh
```

**输出:**
- 在 QuickSight 中创建了 4 个新数据集
- 数据集 ID 保存到 `/tmp/dataset-ids.txt`

### 步骤 2: 刷新 SPICE 数据

```bash
# 触发 SPICE 摄取
./scripts/refresh-datasets.sh
```

**输出:**
- 为所有数据集启动 SPICE 摄取
- 从 Redshift 加载数据

### 步骤 3: 添加到仪表板(手动)

创建和刷新数据集后:

1. 打开 QuickSight 控制台
2. 转到您的分析: `orders analysis`
3. 为每个数据集添加新工作表:
   - 工作表 2: 热门产品(条形图)
   - 工作表 3: 客户细分(表格/饼图)
   - 工作表 4: 每日销售(折线图)
   - 工作表 5: 类别绩效(带利润的条形图)
4. 发布更新的仪表板

## 配置

编辑脚本以更改这些设置:

```bash
ACCOUNT_ID="613477150601"          # 您的 AWS 账户 ID
REGION="ap-southeast-1"             # 您的 AWS 区域
PROFILE="default"                   # AWS CLI 配置文件
DATA_SOURCE_ID="5cf32e75-..."       # 您的 Redshift 数据源 ID
ANALYSIS_ID="7fbd916c-..."          # 您的分析 ID
DASHBOARD_ID="9b6601a1-..."         # 您的仪表板 ID
```

## 故障排除

### 错误: "jq: command not found"

安装 jq:
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

### 错误: "uuidgen: command not found"

安装 uuid-runtime:
```bash
# Linux
sudo apt-get install uuid-runtime

# macOS(内置)
```

### 错误: "Dataset already exists"

具有相同名称的数据集已存在。可以:
- 在 QuickSight 控制台中删除现有数据集
- 在脚本中更改数据集名称

### 检查数据集状态

```bash
# 列出所有数据集
aws quicksight list-data-sets \
  --aws-account-id 613477150601 \
  --region ap-southeast-1 \
  --profile default

# 检查特定数据集
aws quicksight describe-data-set \
  --aws-account-id 613477150601 \
  --data-set-id <dataset-id> \
  --region ap-southeast-1 \
  --profile default
```

### 检查摄取状态

```bash
# 列出数据集的摄取
aws quicksight list-ingestions \
  --aws-account-id 613477150601 \
  --data-set-id <dataset-id> \
  --region ap-southeast-1 \
  --profile default
```

## 数据集详情

### top_products
- **查询**: 按收入排名前 10 的产品
- **列**: product_name、category、revenue、units_sold
- **可视化**: 条形图、表格
- **用例**: 识别最畅销产品

### customer_segments
- **查询**: 客户细分分析
- **列**: customer_segment、customer_count、total_orders、total_revenue、avg_order_value
- **可视化**: 饼图、表格
- **用例**: 了解客户分布和价值

### daily_sales
- **查询**: 每日销售趋势
- **列**: order_date、orders、revenue
- **可视化**: 折线图、面积图
- **用例**: 跟踪随时间的销售趋势

### category_performance
- **查询**: 产品类别盈利能力
- **列**: category、orders、units_sold、revenue、cost、profit
- **可视化**: 带利润的条形图、表格
- **用例**: 分析类别盈利能力

## 后续步骤

运行这些脚本后:

1. **验证数据**: 检查所有数据集是否已加载数据
2. **创建可视化**: 向您的分析添加图表
3. **添加筛选器**: 创建日期范围和类别筛选器
4. **添加计算字段**: 创建利润率等指标
5. **发布仪表板**: 与利益相关者共享
6. **安排刷新**: 设置自动 SPICE 刷新

## 手动替代方案

如果您更喜欢手动创建数据集:

1. 转到 QuickSight 控制台
2. 点击"数据集" → "新建数据集"
3. 选择您的 Redshift 数据源
4. 选择"自定义 SQL"
5. 从 `sql/sample_queries.sql` 复制查询
6. 命名数据集
7. 导入到 SPICE
8. 点击"可视化"

## 清理

要删除所有创建的数据集:

```bash
# 读取数据集 ID 并删除
while IFS= read -r dataset_id; do
    aws quicksight delete-data-set \
        --aws-account-id 613477150601 \
        --data-set-id ${dataset_id} \
        --region ap-southeast-1 \
        --profile default
done < /tmp/dataset-ids.txt

# 清理临时文件
rm /tmp/dataset-ids.txt
```
