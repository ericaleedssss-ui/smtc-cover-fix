# 历史补丁工作流归档

用户于 2026-11-02 确认采用完整源码维护方式后，将原工作流逐字节归档到这里：

- `build-smtc.yml`：原上游源码下载与 G53–G98 补丁构建。
- `export-g53.yml`：原 G53 补丁恢复工具。

原文件来自迁移候选提交 `e4104d3`，在 `rhine-g95-unified-record@6a1639c` 中也保持相同内容。文件名和全部原始字节均保留。GitHub 只执行根 `.github/workflows/` 内的工作流，因此不会自动执行这些归档。

当前正式构建位于根 `.github/workflows/build-smtc.yml`，直接使用 `app/`。这些归档仅供审计和历史查阅；日常开发不再执行补丁链。
