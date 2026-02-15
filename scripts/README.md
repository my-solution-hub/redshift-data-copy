# QuickSight Automation Scripts

This directory contains scripts to automate QuickSight dataset creation and management.

## Scripts Overview

### 1. create-quicksight-datasets.sh

Creates QuickSight datasets for all sample queries and prepares them for dashboard integration.

**What it does:**
- Creates 4 new datasets from sample queries (queries 2-5)
- Configures each dataset with proper column types
- Uses SPICE import mode for fast performance
- Saves dataset IDs for later use

**Datasets created:**
1. `top_products` - Top 10 products by revenue
2. `customer_segments` - Customer segment analysis
3. `daily_sales` - Daily sales trend
4. `category_performance` - Product category profitability

**Usage:**
```bash
chmod +x scripts/create-quicksight-datasets.sh
./scripts/create-quicksight-datasets.sh
```

**Prerequisites:**
- AWS CLI configured with profile `default`
- QuickSight subscription active
- Redshift data source already created
- `jq` and `uuidgen` installed

### 2. refresh-datasets.sh

Triggers SPICE ingestion for all created datasets to load data from Redshift.

**What it does:**
- Reads dataset IDs from previous script
- Triggers SPICE ingestion for each dataset
- Loads data from Redshift into QuickSight SPICE

**Usage:**
```bash
chmod +x scripts/refresh-datasets.sh
./scripts/refresh-datasets.sh
```

**Prerequisites:**
- Must run `create-quicksight-datasets.sh` first
- Dataset IDs file exists at `/tmp/dataset-ids.txt`

## Complete Workflow

### Step 1: Create Datasets

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Create all datasets
./scripts/create-quicksight-datasets.sh
```

**Output:**
- 4 new datasets created in QuickSight
- Dataset IDs saved to `/tmp/dataset-ids.txt`

### Step 2: Refresh SPICE Data

```bash
# Trigger SPICE ingestion
./scripts/refresh-datasets.sh
```

**Output:**
- SPICE ingestion started for all datasets
- Data loaded from Redshift

### Step 3: Add to Dashboard (Manual)

After datasets are created and refreshed:

1. Open QuickSight console
2. Go to your analysis: `orders analysis`
3. Add new sheets for each dataset:
   - Sheet 2: Top Products (bar chart)
   - Sheet 3: Customer Segments (table/pie chart)
   - Sheet 4: Daily Sales (line chart)
   - Sheet 5: Category Performance (bar chart with profit)
4. Publish updated dashboard

## Configuration

Edit the scripts to change these settings:

```bash
ACCOUNT_ID="613477150601"          # Your AWS account ID
REGION="ap-southeast-1"             # Your AWS region
PROFILE="default"                   # AWS CLI profile
DATA_SOURCE_ID="5cf32e75-..."       # Your Redshift data source ID
ANALYSIS_ID="7fbd916c-..."          # Your analysis ID
DASHBOARD_ID="9b6601a1-..."         # Your dashboard ID
```

## Troubleshooting

### Error: "jq: command not found"

Install jq:
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

### Error: "uuidgen: command not found"

Install uuid-runtime:
```bash
# Linux
sudo apt-get install uuid-runtime

# macOS (built-in)
```

### Error: "Dataset already exists"

Datasets with the same name already exist. Either:
- Delete existing datasets in QuickSight console
- Change dataset names in the script

### Check Dataset Status

```bash
# List all datasets
aws quicksight list-data-sets \
  --aws-account-id 613477150601 \
  --region ap-southeast-1 \
  --profile default

# Check specific dataset
aws quicksight describe-data-set \
  --aws-account-id 613477150601 \
  --data-set-id <dataset-id> \
  --region ap-southeast-1 \
  --profile default
```

### Check Ingestion Status

```bash
# List ingestions for a dataset
aws quicksight list-ingestions \
  --aws-account-id 613477150601 \
  --data-set-id <dataset-id> \
  --region ap-southeast-1 \
  --profile default
```

## Dataset Details

### top_products
- **Query**: Top 10 products by revenue
- **Columns**: product_name, category, revenue, units_sold
- **Visualizations**: Bar chart, table
- **Use case**: Identify best-selling products

### customer_segments
- **Query**: Customer segment analysis
- **Columns**: customer_segment, customer_count, total_orders, total_revenue, avg_order_value
- **Visualizations**: Pie chart, table
- **Use case**: Understand customer distribution and value

### daily_sales
- **Query**: Daily sales trend
- **Columns**: order_date, orders, revenue
- **Visualizations**: Line chart, area chart
- **Use case**: Track sales trends over time

### category_performance
- **Query**: Product category profitability
- **Columns**: category, orders, units_sold, revenue, cost, profit
- **Visualizations**: Bar chart with profit, table
- **Use case**: Analyze category profitability

## Next Steps

After running these scripts:

1. **Verify Data**: Check that all datasets have data loaded
2. **Create Visualizations**: Add charts to your analysis
3. **Add Filters**: Create date range and category filters
4. **Add Calculated Fields**: Create metrics like profit margin
5. **Publish Dashboard**: Share with stakeholders
6. **Schedule Refresh**: Set up automatic SPICE refresh

## Manual Alternative

If you prefer to create datasets manually:

1. Go to QuickSight console
2. Click "Datasets" → "New dataset"
3. Select your Redshift data source
4. Choose "Custom SQL"
5. Copy query from `sql/sample_queries.sql`
6. Name the dataset
7. Import to SPICE
8. Click "Visualize"

## Cleanup

To delete all created datasets:

```bash
# Read dataset IDs and delete
while IFS= read -r dataset_id; do
    aws quicksight delete-data-set \
        --aws-account-id 613477150601 \
        --data-set-id ${dataset_id} \
        --region ap-southeast-1 \
        --profile default
done < /tmp/dataset-ids.txt

# Clean up temp file
rm /tmp/dataset-ids.txt
```
