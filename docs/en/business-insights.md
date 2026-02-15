# Amazon QuickSight Business Intelligence Setup Guide

This guide walks you through setting up Amazon QuickSight to build interactive dashboards and reports on top of your Redshift data warehouse.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Subscribe to QuickSight](#subscribe-to-quicksight)
3. [Connect to Redshift](#connect-to-redshift)
4. [Create Datasets](#create-datasets)
5. [Build Your First Analysis](#build-your-first-analysis)
6. [Create Visualizations](#create-visualizations)
7. [Publish Dashboard](#publish-dashboard)
8. [Advanced Features](#advanced-features)

---

## Prerequisites

Before starting, ensure you have:

- ✅ Redshift cluster deployed and running (from main setup)
- ✅ QuickSight VPC connection created (QuickSightStack deployed)
- ✅ Data loaded into `analytics` schema tables
- ✅ AWS account with appropriate permissions

## Subscribe to QuickSight

### Step 1: Sign up for QuickSight

1. Navigate to the [QuickSight console](https://quicksight.aws.amazon.com/)
2. Click **Sign up for QuickSight**
3. Choose **Enterprise Edition** for:
   - Row-level security
   - Hourly SPICE refresh
   - Active Directory integration

### Step 2: Configure Account

1. **Authentication method**: Choose IAM or Active Directory
2. **QuickSight region**: Select `ap-southeast-1` (same as Redshift)
3. **Account name**: Enter a unique name (e.g., `my-company-analytics`)
4. **Notification email**: Enter admin email address

### Step 3: Grant Permissions

Enable access to AWS services:

- ✅ **Amazon Redshift**: Auto-discover clusters
- ✅ **Amazon S3**: Access S3 buckets (if needed for exports)
- ✅ **Amazon Athena**: Query data lakes (optional)

Click **Finish** to complete setup.

---

## Connect to Redshift

### Step 1: Create Data Source

1. In QuickSight console, click **Datasets** → **New dataset**
2. Select **Redshift Auto-discovered**
3. Choose your cluster: `redshift-cluster`

### Step 2: Configure Connection

#### Connection Settings

- **Data source name**: `redshift-analytics`
- **Database name**: `dev`
- **Connection type**: **Use VPC connection**
- **VPC connection**: Select `redshift-vpc-connection` (created by CDK)

#### Authentication

- **Method**: Use IAM credentials
- **IAM role**: Select the QuickSightRedshiftRole ARN from CloudFormation outputs

### Step 3: Test Connection

Click **Validate connection** to ensure QuickSight can reach Redshift.

---

## Create Datasets

### Dataset 1: Orders Analysis

1. Click **New dataset** → Select `redshift-analytics` data source
2. **Schema**: `analytics`
3. **Table**: `orders`
4. Click **Edit/Preview data**

#### Join with Customers

1. Click **Add data** → Select `customers` table
2. Join type: **Left join**
3. Join clauses: `orders.customer_id = customers.customer_id`

#### Import to SPICE

- ✅ Enable **Import to SPICE** for faster performance
- SPICE provides sub-second query response times
- Automatically compresses and optimizes data

Click **Save & publish** → Name: `orders_with_customers`

### Dataset 2: Product Sales

1. Create new dataset from `order_items` table
2. Join with `products`: `order_items.product_id = products.product_id`
3. Join with `orders`: `order_items.order_id = orders.order_id`
4. Import to SPICE
5. Save as: `product_sales`

### Configure Refresh Schedule

For SPICE datasets, set up automatic refresh:

1. Go to **Datasets** → Select dataset → **Refresh** tab
2. Click **Create schedule**
3. **Frequency**: Daily at 2:00 AM
4. **Time zone**: Your local timezone
5. Click **Create**

---

## Build Your First Analysis

### Step 1: Create Analysis

1. Go to **Datasets** → Select `orders_with_customers`
2. Click **Create analysis**
3. QuickSight opens the analysis workspace

### Step 2: Understanding the Interface

#### Left Panel - Fields

- Dimensions (blue): Categorical data (customer_segment, region, status)
- Measures (green): Numeric data (total_amount, order_id count)

#### Top Bar - Visual Types

- AutoGraph (automatic selection)
- Bar charts, Line charts, Pie charts
- Tables, Pivot tables, KPIs
- Maps, Scatter plots, Heatmaps

#### Canvas

- Drag and drop visuals
- Resize and arrange
- Add filters and parameters

---

## Create Visualizations

### Visual 1: Sales by Region (Bar Chart)

1. Click **Add** → **Add visual**
2. Select **Vertical bar chart**
3. Field wells:
   - X-axis: Drag `region`
   - Value: Drag `total_amount` → Aggregate: **Sum**
4. Format:
   - Title: "Total Sales by Region"
   - Y-axis label: "Revenue ($)"
   - Sort: Descending by value

### Visual 2: Revenue Trend (Line Chart)

1. Add new visual → **Line chart**
2. Field wells:
   - X-axis: Drag `order_date`
   - Value: `total_amount` → Aggregate: **Sum**
3. Format:
   - Show data labels: On
   - Line style: Smooth

### Visual 3: Customer Segment Performance (Pie Chart)

1. Add new visual → **Pie chart**
2. Field wells:
   - Group/Color: Drag `customer_segment`
   - Value: `total_amount` → Aggregate: **Sum**
3. Format:
   - Show percentages: On
   - Legend position: Right

### Visual 4: Top 10 Products (Table)

1. Add new visual → **Table**
2. Field wells:
   - Rows: Drag `product_name`
   - Values:
     - `quantity` → Aggregate: **Sum** → Rename: "Units Sold"
     - `total_amount` → Aggregate: **Sum** → Rename: "Revenue"
3. Filters:
   - Add filter on `product_name`
   - Filter type: **Top and bottom**
   - Top 10 by Revenue
4. Format:
   - Conditional formatting: Color scale on Revenue column

### Visual 5: KPI - Total Revenue

1. Add new visual → **KPI**
2. Field wells:
   - Value: Drag `total_amount` → Aggregate: **Sum**
3. Format:
   - Number format: Currency ($)
   - Comparison: Month over month (if time-series data available)

### Visual 6: Order Status Distribution (Donut Chart)

1. Add new visual → **Donut chart**
2. Field wells:
   - Group/Color: Drag `status`
   - Value: `order_id` → Aggregate: **Count distinct**
3. Format:
   - Show percentages: On

---

## Advanced Features

### Calculated Fields

Create custom metrics and dimensions:

#### Example 1: Profit Margin

1. Click **Add** → **Add calculated field**
2. **Name**: `profit_margin`
3. **Formula**: `(sum({total_amount}) - sum({unit_cost} * {quantity})) / sum({total_amount})`
4. Click **Save**
5. Use in visuals as a measure

#### Example 2: Order Size Category

1. Add calculated field: `order_size_category`
2. **Formula**:
```
ifelse(
  {total_amount} < 500, 'Small',
  {total_amount} < 1500, 'Medium',
  'Large'
)
```
3. Use as a dimension for segmentation

#### Example 3: Days Since Order

1. Add calculated field: `days_since_order`
2. **Formula**:
```
dateDiff(now(), {order_date}, 'DD')
```

### Filters and Parameters

#### Add Filter

1. Click **Filter** pane → **Add filter**
2. Select field (e.g., `order_date`)
3. Configure:
   - Filter type: **Relative dates**
   - Time range: Last 30 days
4. Apply to: All visuals or specific visuals

#### Create Parameter

1. Click **Parameters** → **Create parameter**
2. **Name**: `min_order_amount`
3. **Data type**: Decimal
4. **Default value**: 100
5. Use in calculated field or filter

### Interactive Features

#### Drill-down

1. Select a visual
2. Click **Field wells** → Add hierarchy
3. Example: Region → Country → City
4. Users can click to drill down

#### Actions

1. Select visual → **Actions** menu
2. Add action: **Filter same-sheet visuals**
3. When user clicks a bar, other visuals filter automatically

#### Tooltips

1. Select visual → **Format visual**
2. **Tooltips** section
3. Add fields to show on hover

---

## Publish Dashboard

### Step 1: Prepare Analysis

1. Review all visuals for accuracy
2. Add titles and descriptions
3. Arrange layout for readability
4. Test filters and interactions

### Step 2: Publish

1. Click **Share** → **Publish dashboard**
2. **Dashboard name**: "Sales Analytics Dashboard"
3. **Description**: "Daily sales performance and customer insights"
4. Click **Publish dashboard**

### Step 3: Share with Users

#### Share with individuals

1. Click **Share** → **Share dashboard**
2. Enter user email addresses
3. Set permissions:
   - **Viewer**: Can view only
   - **Co-owner**: Can edit and reshare
4. Click **Share**

#### Share with groups

1. Create groups in QuickSight admin panel
2. Share dashboard with entire group
3. Manage permissions at group level

### Step 4: Embed (Optional)

For embedding in web applications:

1. Click **Share** → **Embed**
2. Choose embedding option:
   - **Anonymous embed**: Public access
   - **Private embed**: Requires AWS credentials
3. Copy embed code
4. Integrate into your application

---

## Best Practices

### Performance Optimization

1. **Use SPICE**: Import data to SPICE for sub-second performance
2. **Incremental refresh**: For large datasets, use incremental refresh
3. **Aggregate at source**: Pre-aggregate data in Redshift views
4. **Limit data**: Use filters to reduce dataset size

### Dashboard Design

1. **Keep it simple**: 5-7 visuals per dashboard
2. **Tell a story**: Arrange visuals in logical flow
3. **Use consistent colors**: Match company branding
4. **Add context**: Include titles, descriptions, and tooltips
5. **Mobile-friendly**: Test on mobile devices

### Security

1. **Row-level security**: Restrict data access by user
2. **Column-level security**: Hide sensitive fields
3. **VPC connectivity**: Keep data private within VPC
4. **IAM roles**: Use least-privilege access

### Maintenance

1. **Monitor SPICE usage**: Track capacity and costs
2. **Schedule refreshes**: During off-peak hours
3. **Version control**: Save analysis versions before major changes
4. **User feedback**: Regularly collect and incorporate feedback

---

## Sample Dashboard Ideas

### Executive Dashboard

- Total revenue KPI
- Revenue trend (line chart)
- Sales by region (map)
- Top products (table)
- Customer segments (pie chart)

### Sales Performance Dashboard

- Daily/weekly/monthly sales trends
- Sales by product category
- Sales rep performance
- Conversion funnel
- Year-over-year comparison

### Customer Analytics Dashboard

- Customer lifetime value
- Customer acquisition trends
- Churn analysis
- Customer segmentation
- Geographic distribution

### Product Analytics Dashboard

- Product performance comparison
- Inventory levels
- Profit margins by product
- Product category trends
- Cross-sell analysis

---

## Troubleshooting

### Connection Issues

**Problem**: Cannot connect to Redshift

- ✅ Verify VPC connection is active
- ✅ Check security group rules allow QuickSight
- ✅ Confirm IAM role has correct permissions
- ✅ Test connection from QuickSight console

### Performance Issues

**Problem**: Slow dashboard loading

- ✅ Import data to SPICE instead of direct query
- ✅ Reduce dataset size with filters
- ✅ Pre-aggregate data in Redshift
- ✅ Limit number of visuals per dashboard

### Data Issues

**Problem**: Data not refreshing

- ✅ Check SPICE refresh schedule
- ✅ Verify Redshift cluster is running
- ✅ Review refresh history for errors
- ✅ Manually trigger refresh to test

---

## Cost Optimization

### Pricing Overview

#### Enterprise Edition

- Authors: $18/month per user
- Readers: $0.30/session (max $5/month per user)

#### SPICE

- $0.25/GB/month
- 10GB free per author

#### Tips to Reduce Costs

1. Use reader accounts for view-only users
2. Optimize SPICE datasets (remove unused fields)
3. Share dashboards instead of creating duplicates
4. Monitor SPICE usage regularly
5. Use direct query for infrequently accessed data

---

## Next Steps

1. **Explore Amazon Q**: Use natural language to query data
2. **Set up alerts**: Get notified when metrics exceed thresholds
3. **Create pixel-perfect reports**: Schedule and email formatted reports
4. **Build mobile dashboards**: Optimize for mobile viewing
5. **Integrate with applications**: Embed dashboards in your apps

---

## Additional Resources

- [QuickSight User Guide](https://docs.aws.amazon.com/quicksight/latest/user/)
- [QuickSight API Reference](https://docs.aws.amazon.com/quicksight/latest/APIReference/)
- [QuickSight Community](https://repost.aws/tags/TA4iiGCS8iRGCR8OHN_wjBxw/amazon-quick-sight)
- [Sample Dashboards Gallery](https://aws.amazon.com/quicksight/gallery/)
- [QuickSight Training](https://aws.amazon.com/quicksight/resources/)
