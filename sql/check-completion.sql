-- Check COPY JOB status
SELECT job_id, job_name, data_source FROM sys_copy_job WHERE job_name LIKE '%_import_job';

-- View loaded data counts
SELECT COUNT(*) as order_count FROM analytics.orders;
SELECT COUNT(*) as order_item_count FROM analytics.order_items;
SELECT COUNT(*) as customer_count FROM analytics.customers;
SELECT COUNT(*) as product_count FROM analytics.products;
