---
inclusion: auto
---

# Multi-Language Documentation Reminder

This project maintains documentation in multiple languages. When updating documentation, you MUST update ALL language versions to keep them in sync.

## Documentation Files

### Root Level
- `README.md` - English version (primary)
- `README-CN.md` - Chinese version (中文版本)

### Data Directory
- `data/README.md` - English data directory guide
- `data/README-CN.md` - Chinese data directory guide (中文数据目录指南)

### Scripts Directory
- `scripts/README.md` - English scripts documentation
- `scripts/README-CN.md` - Chinese scripts documentation (中文脚本文档)

### Documentation Directory (docs/)
- `docs/en/quicksight-guide.md` - English QuickSight BI functions guide
- `docs/cn/quicksight-guide.md` - Chinese QuickSight BI functions guide (中文 QuickSight BI 功能指南)
- `docs/en/spice-vs-direct-query.md` - English SPICE vs Direct Query comparison
- `docs/cn/spice-vs-direct-query.md` - Chinese SPICE vs Direct Query comparison (中文 SPICE 与直接查询对比)
- `docs/en/business-insights.md` - English Business Intelligence setup guide
- `docs/cn/business-insights.md` - Chinese Business Intelligence setup guide (中文商业智能设置指南)

## Update Process

When making ANY changes to documentation:

1. Update the English version first (e.g., `README.md`, `docs/en/*.md`, `scripts/README.md`)
2. Update the corresponding Chinese version with equivalent content (e.g., `README-CN.md`, `docs/cn/*.md`, `scripts/README-CN.md`)
3. Ensure both language versions have matching:
   - Section structure
   - Code examples
   - Configuration instructions
   - Troubleshooting steps
   - Architecture diagrams (if text-based)
4. For new documentation files:
   - Create both English and Chinese versions
   - Add them to the appropriate directory (`docs/en/` and `docs/cn/`)
   - Update this steering file to track the new documentation

## Common Mistakes to Avoid

- ❌ Updating only the English version
- ❌ Forgetting to translate new sections
- ❌ Leaving outdated information in one language
- ❌ Inconsistent formatting between versions

## Verification Checklist

Before completing documentation updates, verify:

- [ ] Both English and Chinese versions have been updated for all affected files
- [ ] Root README files (README.md and README-CN.md) are in sync
- [ ] Data directory READMEs (data/README.md and data/README-CN.md) are in sync
- [ ] Scripts READMEs (scripts/README.md and scripts/README-CN.md) are in sync
- [ ] Documentation files in docs/en/ and docs/cn/ are in sync
- [ ] New sections exist in both languages
- [ ] Code examples are identical (except for comments)
- [ ] All links and references work in both versions
- [ ] Version numbers and dates match

## Why This Matters

Users may rely on either language version. Inconsistent documentation leads to:
- Confusion and frustration
- Incorrect implementations
- Support burden
- Loss of trust

Always maintain parity between language versions.
