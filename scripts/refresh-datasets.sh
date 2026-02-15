#!/bin/bash

# QuickSight Dataset SPICE Refresh Script
# This script triggers SPICE ingestion for all created datasets

set -e

# Configuration
ACCOUNT_ID="613477150601"
REGION="ap-southeast-1"
PROFILE="default"

echo "Refreshing SPICE ingestion for all datasets..."

# Check if dataset IDs file exists
if [ ! -f /tmp/dataset-ids.txt ]; then
    echo "Error: /tmp/dataset-ids.txt not found"
    echo "Please run create-quicksight-datasets.sh first"
    exit 1
fi

# Read dataset IDs and trigger ingestion
while IFS= read -r dataset_id; do
    echo "Triggering SPICE ingestion for dataset: ${dataset_id}"
    
    INGESTION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    
    aws quicksight create-ingestion \
        --aws-account-id ${ACCOUNT_ID} \
        --data-set-id ${dataset_id} \
        --ingestion-id ${INGESTION_ID} \
        --region ${REGION} \
        --profile ${PROFILE} || echo "Failed to refresh ${dataset_id}"
    
    echo "Ingestion started with ID: ${INGESTION_ID}"
    sleep 2
done < /tmp/dataset-ids.txt

echo ""
echo "All SPICE ingestions triggered!"
echo "Check status with: aws quicksight list-ingestions --aws-account-id ${ACCOUNT_ID} --data-set-id <dataset-id> --region ${REGION} --profile ${PROFILE}"
