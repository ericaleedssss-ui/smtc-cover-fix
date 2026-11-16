# Rhine M10 稳定版审查

- 已验收源码提交为 $sha
- [Windows x64 验收包](Rhine-M10-stable-Windows-x64.zip)，解压后保留同目录的 resources。
- ZIP SHA-256 为 $zipHash
- EXE SHA-256 为 9B0FA2B566C6DC029E7BAAF8C60568C9F740A72CCB4E57B3A08CB95109D85AFC
- [构建清单](build-manifest.json)记录 Go 工具链、MyGo 依赖和补丁、资源哈希。
- [构建说明](../../scripts/m10/README.md)。Windows 检出时请使用 core.autocrlf=false，以保留补丁的 LF 换行。普通版命令由脚本设置 Windows amd64、CGO_ENABLED=0、-trimpath、-ldflags=-H=windowsgui。
- 用户实机验收报告静止约 100 MB，交互约 150 MB。干净检出已重建成功。重建 EXE 的哈希与验收原件不同，Go 构建信息中可见依赖绝对路径和工作树状态不同。
- 审查可重点查看周谱缓存与刷新时机、资源路径、普通模式和 Type-C 的启动差异，以及 Windows 构建复现。审查分支的父提交为验收源码，本次提交只添加审查和下载材料。
