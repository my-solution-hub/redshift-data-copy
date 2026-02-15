-- Sample analytics queries for QuickSight

-- 1. Sales by Region
SELECT 
    region,
    COUNT(DISTINCT order_id) as total_orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value
FROM analytics.orders
WHERE status = 'completed'
GROUP BY region
ORDER BY total_revenue DESC;

-- 2. Top Products by Revenue
SELECT 
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
LIMIT 10;

-- 3. Customer Segment Analysis
SELECT 
    c.customer_segment,
    COUNT(DISTINCT c.customer_id) as customer_count,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value
FROM analytics.customers c
LEFT JOIN analytics.orders o ON c.customer_id = o.customer_id
WHERE o.status = 'completed' OR o.status IS NULL
GROUP BY c.customer_segment
ORDER BY total_revenue DESC;

-- 4. Daily Sales Trend
SELECT 
    DATE(order_date) as order_date,
    COUNT(DISTINCT order_id) as orders,
    SUM(total_amount) as revenue
FROM analytics.orders
WHERE status = 'completed'
GROUP BY DATE(order_date)
ORDER BY order_date;

-- 5. Product Category Performance
SELECT 
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
ORDER BY revenue DESC;
