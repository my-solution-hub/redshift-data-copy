# QuickSight BI Functions Guide

## Overview

Amazon QuickSight is a cloud-native business intelligence service that lets you create interactive dashboards and perform ad-hoc analysis. This guide covers the key BI functions you can use with your sales data.

## Available Datasets

Based on the sample queries, you have access to:
- **Sales by Region** - Regional performance metrics
- **Top Products** - Product revenue and sales volume
- **Customer Segments** - Customer behavior by segment
- **Daily Sales Trend** - Time-series sales data
- **Category Performance** - Product category profitability

## Key QuickSight BI Functions

### 1. Visual Types

**Bar Charts**
- Use for: Sales by Region, Top Products, Category Performance
- Shows: Comparisons across categories
- Example: Compare revenue across North, South, East, West regions

**Line Charts**
- Use for: Daily Sales Trend
- Shows: Trends over time
- Example: Track revenue growth day-by-day

**Pie/Donut Charts**
- Use for: Customer Segment Distribution, Category Mix
- Shows: Part-to-whole relationships
- Example: Percentage of revenue by customer segment

**Tables**
- Use for: Detailed product listings, customer details
- Shows: Granular data with multiple dimensions
- Example: Top 10 products with revenue, units sold, category

**KPI Visuals**
- Use for: Total Revenue, Total Orders, Average Order Value
- Shows: Single key metrics with comparison
- Example: This month's revenue vs last month

### 2. Calculated Fields

Create custom metrics directly in QuickSight:

**Profit Margin**
```
(revenue - cost) / revenue * 100
```

**Revenue per Customer**
```
sum(total_revenue) / distinctCount(customer_id)
```

**Order Conversion Rate**
```
count(completed_orders) / count(total_orders) * 100
```

**Year-over-Year Growth**
```
(current_year_revenue - previous_year_revenue) / previous_year_revenue * 100
```

### 3. Filters

**Date Filters**
- Last 7 days, Last 30 days, Last quarter
- Custom date ranges
- Relative date filters (e.g., "This month")

**Dimension Filters**
- Region: Filter to specific regions
- Customer Segment: Focus on Enterprise, SMB, etc.
- Product Category: Analyze specific categories
- Order Status: Show only completed orders

**Top/Bottom N Filters**
- Top 10 products by revenue
- Bottom 5 regions by sales
- Top 20% of customers (by revenue)

### 4. Parameters

Create interactive dashboards with user controls:

**Revenue Threshold**
- Let users filter products above a certain revenue
- Control: Slider or input box

**Date Range**
- Allow users to select custom date ranges
- Control: Date picker

**Region Selection**
- Multi-select dropdown for regions
- Control: Dropdown list

### 5. Drill-Downs

Create hierarchical navigation:

**Geographic Drill-Down**
- Region → Country → City

**Product Drill-Down**
- Category → Subcategory → Product

**Time Drill-Down**
- Year → Quarter → Month → Day

### 6. Forecasting

QuickSight ML-powered forecasting:

**Revenue Forecast**
- Predict next 30 days of revenue
- Based on historical daily sales trend
- Shows confidence intervals

**Demand Forecast**
- Predict product demand
- Helps with inventory planning

### 7. Anomaly Detection

Automatically detect unusual patterns:

**Revenue Anomalies**
- Detect unexpected spikes or drops
- Get alerts for significant changes

**Order Volume Anomalies**
- Identify unusual order patterns
- Investigate potential issues

### 8. Conditional Formatting

Highlight important data:

**Revenue Targets**
- Green: Above target
- Yellow: Near target
- Red: Below target

**Profit Margins**
- Color scale from red (low) to green (high)

**Order Status**
- Different colors for completed, pending, cancelled

## Sample Dashboard Layout

### Executive Dashboard

**Row 1: KPIs**
- Total Revenue (current month)
- Total Orders (current month)
- Average Order Value
- Customer Count

**Row 2: Trends**
- Daily Sales Trend (line chart)
- Revenue by Region (bar chart)

**Row 3: Analysis**
- Customer Segment Performance (table)
- Top 10 Products (bar chart)

### Product Performance Dashboard

**Row 1: Overview**
- Total Products Sold
- Total Revenue
- Average Profit Margin

**Row 2: Category Analysis**
- Category Performance (bar chart with profit)
- Category Mix (pie chart)

**Row 3: Details**
- Top Products Table (with revenue, units, profit)
- Product Trend (line chart)

### Customer Analytics Dashboard

**Row 1: Metrics**
- Total Customers
- Revenue per Customer
- Average Orders per Customer

**Row 2: Segmentation**
- Customer Segment Distribution (pie chart)
- Segment Performance (table)

**Row 3: Behavior**
- Order Frequency Distribution
- Customer Lifetime Value

## Best Practices

1. **Start Simple**: Begin with basic charts, add complexity as needed
2. **Use Filters**: Make dashboards interactive with filters and parameters
3. **Color Consistently**: Use the same colors for the same dimensions across visuals
4. **Add Context**: Include comparison periods (vs last month, vs last year)
5. **Optimize Performance**: Use SPICE for faster queries
6. **Mobile-Friendly**: Design dashboards that work on mobile devices
7. **Share Insights**: Publish dashboards and set up email reports

## Next Steps

1. Import your dataset from Redshift into QuickSight
2. Create calculated fields for profit margin and growth rates
3. Build your first dashboard with 3-4 key visuals
4. Add filters for date range and region
5. Set up scheduled email reports for stakeholders
6. Enable ML insights for forecasting and anomaly detection
