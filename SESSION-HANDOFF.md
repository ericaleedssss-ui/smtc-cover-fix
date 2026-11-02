# 独立源码迁移交接 · 2026-11-02

当前工作树：`smtc-source-migration`，分支 `migration/full-source-20261102`。先读根 `MIGRATION-REPORT.md`、检查 `git status` / 最新提交。本轮只有源码维护方式迁移，视觉设计暂停。

完整应用在 `app/`，325 个输入文件与旧 G98 流程完全一致；第 326 个 `.gitattributes` 仅增加禁止换行转换的规则，防止 Git 改写已验证的混合换行。生产源码/资源/构建/测试无改动，326 个暂存 blob 均与磁盘字节一致。原始工作区 `../smtc-cover-fix` 仍在 `rhine-g95-unified-record@6a1639c`；145 个未提交文件完整保留并备份。不要把未验收的 G99 混入迁移，不要清理旧补丁或擅自改 UI。

本地编译、npm test（CTest 7/7、桥接 48 项等）、share 与包一致性检查通过。完整玻璃 UI 验收未通过：候选 306/307，原 CI 下载包 306/307，失败项不同；另一次错误窗口位置试验 301/307。证据和未完成项目见报告与 `migration/evidence/verification-summary.json`。不能称全部验证完成。

新工作流 `.github/workflows/standalone-candidate.yml` 仅手动触发，直接从 app 构建。原 `build-smtc.yml` 保持原样。未推送、未远端运行候选 CI、未切换正式工作流。未来应先完成图形验收和候选 CI，再由用户决定采用。

工具、原始备份、上游还原源、旧 CI 下载包保存在 `../rhine-migration-work-20261102/`；编译环境位于其中 `toolchain/build-env.json`，含本机环境，不要提交或上传。Qt kit 是 `toolchain/qt`，Node 是 `toolchain/node-v22.14.0-win-x64`，MSVC 是 `toolchain/msvc`。本地详细日志与截图在 `migration/results/`，被 Git 忽略。最终绿色包在 `app/output/RhineMusicDatabase-v1.2.0-Windows-x64.zip`。

用户要求所有桌面操作都在 **Type-C 横屏副屏**，不要占用主屏。三屏存在不同 DPI。已确认 Qt 启动参数 `-qwindowgeometry 1000x600+40+1140` 能让当前离线预览可见（Computer Use 捕获 origin 80,2280），用户明确回答能看到；此前 `1280x720+60+2220` 造成窗口不可见。该参数只是本机预览证据，不要作为通用布局或修改生产源码。

用户询问能否关闭 “GPT using your computer”，已答复可以关闭，后续仅后台核对与写报告，不再弹测试窗口。**不要在没有新需求时重新启动 GUI 检查或 Computer Use。** 留下的可见窗口是我们构建的离线候选预览，账户数据隔离在本地候选目录；不操作用户正式播放器，不关机。
