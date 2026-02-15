#!/bin/bash

# Create a single QuickSight dataset
# Usage: ./create-single-dataset.sh <dataset-name> <sql-query-file>

set -e

ACCOUNT_ID="613477150601"
REGION="ap-southeast-1"
PROFILE="default"
DATA_SOURCE_ARN="arn:aws:quicksight:ap-southeast-1:613477150601:datasource/5cf32e75-a0f6-44f8-b7ec-e5d8f7337981"

DATASET_NAME=$1
DATASET_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

echo "Creating dataset: ${DATASET_NAME} with ID: ${DATASET_ID}"

# Customer Segments Dataset
if [ "$DATASET_NAME" == "customer_segments" ]; then
cat > /tmp/dataset.json <<'EOF'
{
    "AwsAccountId": "613477150601",
    "DataSetId": "DATASET_ID_PLACEHOLDER",
    "Name": "customer_segments",
    "PhysicalTableMap": {
        "physical-1": {
            "CustomSql": {
                "DataSourceArn": "arn:aws:quicksight:ap-southeast-1:613477150601:datasource/5cf32e75-a0f6-44f8-b7ec-e5d8f7337981",
                "Name": "customer_segments",
                "SqlQuery": "SELECT c.customer_segment, COUNT(DISTINCT c.customer_id) as customer_count, COUNT(DISTINCT o.order_id) as total_orders, SUM(o.total_amount) as total_revenue, AVG(o.total_amount) as avg_order_value FROM analytics.customers c LEFT JOIN analytics.orders o ON c.customer_id = o.customer_id WHERE o.status = 'completed' OR o.status IS NULL GROUP BY c.customer_segment ORDER BY total_revenue DESC",
                "Columns": [
                    {"Name": "customer_segment", "Type": "STRING"},
                    {"Name": "customer_count", "Type": "INTEGER"},
                    {"Name": "total_orders", "Type": "INTEGER"},
                    {"Name": "total_revenue", "Type": "DECIMAL", "SubType": "FIXED"},
                    {"Name": "avg_order_value", "Type": "DECIMAL", "SubType": "FIXED"}
                ]
            }
        }
    },
    "LogicalTableMap": {
        "logical-1": {
            "Alias": "customer_segments",
            "Source": {"PhysicalTableId": "physical-1"}
        }
    },
    "ImportMode": "SPICE"
}
EOF
fi

# Daily Sales Dataset
if [ "$DATASET_NAME" == "daily_sales" ]; then
cat > /tmp/dataset.json <<'EOF'
{
    "AwsAccountId": "613477150601",
    "DataSetId": "DATASET_ID_PLACEHOLDER",
    "Name": "daily_sales",
    "PhysicalTableMap": {
        "physical-1": {
            "CustomSql": {
                "DataSourceArn": "arn:aws:quicksight:ap-southeast-1:613477150601:datasource/5cf32e75-a0f6-44f8-b7ec-e5d8f7337981",
                "Name": "daily_sales",
                "SqlQuery": "SELECT DATE(order_date) as order_date, COUNT(DISTINCT order_id) as orders, SUM(total_amount) as revenue FROM analytics.orders WHERE status = 'completed' GROUP BY DATE(order_date) ORDER BY order_date",
                "Columns": [
                    {"Name": "order_date", "Type": "DATETIME"},
                    {"Name": "orders", "Type": "INTEGER"},
                    {"Name": "revenue", "Type": "DECIMAL", "SubType": "FIXED"}
                ]
            }
        }
    },
    "LogicalTableMap": {
        "logical-1": {
            "Alias": "daily_sales",
            "Source": {"PhysicalTableId": "physical-1"}
        }
    },
    "ImportMode": "SPICE"
}
EOF
fi

# Category Performance Dataset
if [ "$DATASET_NAME" == "category_performance" ]; then
cat > /tmp/dataset.json <<'EOF'
{
    "AwsAccountId": "613477150601",
    "DataSetId": "DATASET_ID_PLACEHOLDER",
    "Name": "category_performance",
    "PhysicalTableMap": {
        "physical-1": {
            "CustomSql": {
                "DataSourceArn": "arn:aws:quicksight:ap-southeast-1:613477150601:datasource/5cf32e75-a0f6-44f8-b7ec-e5d8f7337981",
                "Name": "category_performance",
                "SqlQuery": "SELECT p.category, COUNT(DISTINCT oi.order_id) as orders, SUM(oi.quantity) as units_sold, SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) as revenue, SUM(oi.quantity * p.unit_cost) as cost, SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) - SUM(oi.quantity * p.unit_cost) as profit FROM analytics.order_items oi JOIN analytics.products p ON oi.product_id = p.product_id JOIN analytics.orders o ON oi.order_id = o.order_id WHERE o.status = 'completed' GROUP BY p.category ORDER BY revenue DESC",
                "Columns": [
                    {"Name": "category", "Type": "STRING"},
                    {"Name": "orders", "Type": "INTEGER"},
                    {"Name": "units_sold", "Type": "INTEGER"},
                    {"Name": "revenue", "Type": "DECIMAL", "SubType": "FIXED"},
                    {"Name": "cost", "Type": "DECIMAL", "SubType": "FIXED"},
                    {"Name": "profit", "Type": "DECIMAL", "SubType": "FIXED"}
                ]
            }
        }
    },
    "LogicalTableMap": {
        "logical-1": {
            "Alias": "category_performance",
            "Source": {"PhysicalTableId": "physical-1"}
        }
    },
    "ImportMode": "SPICE"
}
EOF
fi

# Replace placeholder with actual ID
sed -i.bak "s/DATASET_ID_PLACEHOLDER/${DATASET_ID}/g" /tmp/dataset.json

# Create dataset
aws quicksight create-data-set \
    --cli-input-json file:///tmp/dataset.json \
    --region ${REGION} \
    --profile ${PROFILE}

echo "Dataset created: ${DATASET_ID}"
echo "${DATASET_ID}" >> /tmp/all-dataset-ids.txt

# Trigger SPICE ingestion
INGESTION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
aws quicksight create-ingestion \
    --aws-account-id ${ACCOUNT_ID} \
    --data-set-id ${DATASET_ID} \
    --ingestion-id ${INGESTION_ID} \
    --region ${REGION} \
    --profile ${PROFILE}

echo "SPICE ingestion triggered: ${INGESTION_ID}"
