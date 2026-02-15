-- Create schema for analytics tables
CREATE SCHEMA IF NOT EXISTS analytics;

-- Orders fact table
CREATE TABLE IF NOT EXISTS analytics.orders (
    order_id INTEGER PRIMARY KEY,
    customer_id VARCHAR(10) NOT NULL,
    order_date TIMESTAMP NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    region VARCHAR(50) NOT NULL
) SORTKEY(order_date);

-- Order items fact table
CREATE TABLE IF NOT EXISTS analytics.order_items (
    order_id INTEGER NOT NULL,
    product_id VARCHAR(10) NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount DECIMAL(3,2) DEFAULT 0.00,
    PRIMARY KEY (order_id, product_id)
) DISTKEY(order_id) SORTKEY(order_id);

-- Customers dimension table
CREATE TABLE IF NOT EXISTS analytics.customers (
    customer_id VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    signup_date DATE NOT NULL,
    customer_segment VARCHAR(20) NOT NULL,
    country VARCHAR(50) NOT NULL
) DISTSTYLE ALL;

-- Products dimension table
CREATE TABLE IF NOT EXISTS analytics.products (
    product_id VARCHAR(10) PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(50) NOT NULL,
    unit_cost DECIMAL(10,2) NOT NULL,
    supplier_id VARCHAR(10) NOT NULL
) DISTSTYLE ALL;

-- Create COPY JOBs for each table
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
