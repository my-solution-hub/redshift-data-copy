#!/bin/bash

# QuickSight Dataset Creation Script
# This script creates datasets for all sample queries and adds them to the dashboard

set -e

# Configuration
ACCOUNT_ID="613477150601"
REGION="ap-southeast-1"
PROFILE="default"
DATA_SOURCE_ID="5cf32e75-a0f6-44f8-b7ec-e5d8f7337981"
ANALYSIS_ID="7fbd916c-5c88-4a6a-bc46-8ee37b8eca08"
DASHBOARD_ID="9b6601a1-1ab7-4c54-861a-db48643cf45e"

echo "Creating QuickSight datasets from sample queries..."

# Function to create dataset
create_dataset() {
    local dataset_name=$1
    local sql_query=$2
    local columns=$3
    
    echo "Creating dataset: $dataset_name"
    
    # Generate unique dataset ID
    DATASET_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    
    # Create dataset JSON
    cat > /tmp/dataset-${dataset_name}.json <<EOF
{
    "AwsAccountId": "${ACCOUNT_ID}",
    "DataSetId": "${DATASET_ID}",
    "Name": "${dataset_name}",
    "PhysicalTableMap": {
        "physical-table-1": {
            "CustomSql": {
                "DataSourceArn": "arn:aws:quicksight:${REGION}:${ACCOUNT_ID}:datasource/${DATA_SOURCE_ID}",
                "Name": "${dataset_name}",
                "SqlQuery": $(echo "$sql_query" | jq -Rs .),
                "Columns": ${columns}
            }
        }
    },
    "LogicalTableMap": {
        "logical-table-1": {
            "Alias": "${dataset_name}",
            "Source": {
                "PhysicalTableId": "physical-table-1"
            }
        }
    },
    "ImportMode": "SPICE"
}
EOF
    
    # Create dataset
    aws quicksight create-data-set \
        --cli-input-json file:///tmp/dataset-${dataset_name}.json \
        --region ${REGION} \
        --profile ${PROFILE}
    
    echo "Dataset ${dataset_name} created with ID: ${DATASET_ID}"
    echo "${DATASET_ID}" >> /tmp/dataset-ids.txt
}

# Clear previous dataset IDs
rm -f /tmp/dataset-ids.txt

# Dataset 2: Top Products by Revenue
create_dataset "top_products" \
"SELECT 
    p.product_name,
    p.category,
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) as revenue,
    SUM(oi.quantity) as units_sold
FROM analytics.order_items oi
JOIN analytics.products p ON oi.product_id = p.product_id
JOIN analytics.orders o ON oi.order_id = o.order_id
WHERE o.status = 'completed'
GROUP BY p.product_name, p.category
ORDER BY revenue DESC
LIMIT 10" \
'[
    {"Name": "product_name", "Type": "STRING"},
    {"Name": "category", "Type": "STRING"},
    {"Name": "revenue", "Type": "DECIMAL"},
    {"Name": "units_sold", "Type": "INTEGER"}
]'

# Dataset 3: Customer Segment Analysis
create_dataset "customer_segments" \
"SELECT 
    c.customer_segment,
    COUNT(DISTINCT c.customer_id) as customer_count,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value
FROM analytics.customers c
LEFT JOIN analytics.orders o ON c.customer_id = o.customer_id
WHERE o.status = 'completed' OR o.status IS NULL
GROUP BY c.customer_segment
ORDER BY total_revenue DESC" \
'[
    {"Name": "customer_segment", "Type": "STRING"},
    {"Name": "customer_count", "Type": "INTEGER"},
    {"Name": "total_orders", "Type": "INTEGER"},
    {"Name": "total_revenue", "Type": "DECIMAL"},
    {"Name": "avg_order_value", "Type": "DECIMAL"}
]'

# Dataset 4: Daily Sales Trend
create_dataset "daily_sales" \
"SELECT 
    DATE(order_date) as order_date,
    COUNT(DISTINCT order_id) as orders,
    SUM(total_amount) as revenue
FROM analytics.orders
WHERE status = 'completed'
GROUP BY DATE(order_date)
ORDER BY order_date" \
'[
    {"Name": "order_date", "Type": "DATETIME"},
    {"Name": "orders", "Type": "INTEGER"},
    {"Name": "revenue", "Type": "DECIMAL"}
]'

# Dataset 5: Product Category Performance
create_dataset "category_performance" \
"SELECT 
    p.category,
    COUNT(DISTINCT oi.order_id) as orders,
    SUM(oi.quantity) as units_sold,
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) as revenue,
    SUM(oi.quantity * p.unit_cost) as cost,
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) - SUM(oi.quantity * p.unit_cost) as profit
FROM analytics.order_items oi
JOIN analytics.products p ON oi.product_id = p.product_id
JOIN analytics.orders o ON oi.order_id = o.order_id
WHERE o.status = 'completed'
GROUP BY p.category
ORDER BY revenue DESC" \
'[
    {"Name": "category", "Type": "STRING"},
    {"Name": "orders", "Type": "INTEGER"},
    {"Name": "units_sold", "Type": "INTEGER"},
    {"Name": "revenue", "Type": "DECIMAL"},
    {"Name": "cost", "Type": "DECIMAL"},
    {"Name": "profit", "Type": "DECIMAL"}
]'

echo ""
echo "All datasets created successfully!"
echo "Dataset IDs saved to /tmp/dataset-ids.txt"
echo ""
echo "Next steps:"
echo "1. Refresh SPICE ingestion for each dataset"
echo "2. Add visualizations to your analysis: ${ANALYSIS_ID}"
echo "3. Publish updated dashboard: ${DASHBOARD_ID}"
echo ""
echo "To refresh SPICE ingestion, run:"
echo "  ./scripts/refresh-datasets.sh"
