# 数据目录

此目录包含跨账户 S3 到 Redshift 演示的示例 CSV 数据文件。

## CSV 文件

- `customers.csv` - 客户信息
- `orders.csv` - 订单记录
- `order_items.csv` - 订单明细项
- `products.csv` - 产品目录

## 文档

所有文档已移至 `docs/` 目录,以实现更好的组织和多语言支持。

### 英文文档

查看 `docs/en/` 获取英文文档:
- [QuickSight BI 功能指南](../docs/en/quicksight-guide.md)
- [SPICE 与直接查询对比](../docs/en/spice-vs-direct-query.md)
- [商业智能设置指南](../docs/en/business-insights.md)

### 中文文档

查看 `docs/cn/` 获取中文文档:
- [QuickSight BI 功能指南](../docs/cn/quicksight-guide.md)
- [SPICE 与直接查询对比](../docs/cn/spice-vs-direct-query.md)
- [商业智能设置指南](../docs/cn/business-insights.md)

## 使用方法

将这些 CSV 文件上传到 Account1 中的 S3 存储桶,以触发自动数据复制到 Account2 中的 Redshift。

```bash
# 上传数据文件
aws s3 cp customers.csv s3://719821274597-data-source/ --profile cloudops-demo
aws s3 cp orders.csv s3://719821274597-data-source/ --profile cloudops-demo
aws s3 cp order_items.csv s3://719821274597-data-source/ --profile cloudops-demo
aws s3 cp products.csv s3://719821274597-data-source/ --profile cloudops-demo
```
