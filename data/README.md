# Data Directory

This directory contains sample CSV data files for the cross-account S3 to Redshift demo.

## CSV Files

- `customers.csv` - Customer information
- `orders.csv` - Order records
- `order_items.csv` - Order line items
- `products.csv` - Product catalog

## Documentation

All documentation has been moved to the `docs/` directory for better organization and multi-language support.

### English Documentation

See `docs/en/` for English documentation:
- [QuickSight BI Functions Guide](../docs/en/quicksight-guide.md)
- [SPICE vs Direct Query](../docs/en/spice-vs-direct-query.md)
- [Business Intelligence Setup Guide](../docs/en/business-insights.md)

### Chinese Documentation (中文文档)

See `docs/cn/` for Chinese documentation:
- [QuickSight BI 功能指南](../docs/cn/quicksight-guide.md)
- [SPICE 与直接查询对比](../docs/cn/spice-vs-direct-query.md)
- [商业智能设置指南](../docs/cn/business-insights.md)

## Usage

Upload these CSV files to the S3 bucket in Account1 to trigger the automated data copy to Redshift in Account2.

```bash
# Upload data files
aws s3 cp customers.csv s3://719821274597-data-source/ --profile cloudops-demo
aws s3 cp orders.csv s3://719821274597-data-source/ --profile cloudops-demo
aws s3 cp order_items.csv s3://719821274597-data-source/ --profile cloudops-demo
aws s3 cp products.csv s3://719821274597-data-source/ --profile cloudops-demo
```
