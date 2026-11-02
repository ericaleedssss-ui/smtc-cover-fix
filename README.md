# Rhine Music Database — 独立维护完整源码

完整应用源码位于 [`app/`](app/)。后续独立开发应直接修改其中的 C++、QML、shader、资源与构建脚本。

用户已于 2026-11-02 确认采用完整源码结构。正式开发分支为 `main`，本地开发目录为原目录同级的 `smtc-source-migration/`。应用从已成功构建的 `6a1639c`（G98）完整还原，本地与 [GitHub Actions 候选构建](https://github.com/ericaleedssss-ui/smtc-cover-fix/actions/runs/41447801633) 的完整编译、回归、打包和玻璃 UI 307/307 检查已通过。正式工作流现在直接编译本仓库 `app/`。迁移详情、验证结果和未完成项目见 [`MIGRATION-REPORT.md`](MIGRATION-REPORT.md)。

[首次正式 main 构建](https://github.com/ericaleedssss-ui/smtc-cover-fix/actions/runs/41451386632) 同样成功，玻璃 UI 307/307、CTest 7/7、桥接 48 项与打包检查全部通过。[Windows 程序包](https://github.com/ericaleedssss-ui/smtc-cover-fix/actions/runs/41451386632/artifacts/13145696581) 保留至 2026-11-16。

日常修改直接发生在 `app/`，提交到开发分支后合入 `main`；不再修改 `maintained/` 或新增历史补丁。原目录 `smtc-cover-fix/` 保留旧分支和所有未提交设计工作，这些尚未验收的设计没有自动进入正式版本。

## 目录

| 路径 | 用途 |
| --- | --- |
| `app/` | 可直接编译的完整应用，包含依赖锁文件、测试、资源、MIT 许可证及原版权声明 |
| `migration/` | 独立构建辅助、来源清单和迁移验证 |
| `.github/workflows/build-smtc.yml` | 正式完整源码构建；响应 `main` 的相关源码推送、面向 `main` 的 PR 或手动触发 |
| `.github/workflows/standalone-candidate.yml` | 保留的迁移分支候选验证入口 |
| `maintained/`、`patches/`、根目录 `scripts/` | 原补丁开发历史，原样保留；独立构建不执行它们 |
| `migration/legacy-workflows/` | 原补丁构建和 G53 导出工作流的逐字节归档，GitHub 不会执行此目录中的工作流 |

`app/.github/workflows/` 是原项目保留的文件。GitHub 不会将子目录内这些文件作为本仓库工作流运行。

## Windows 本地开发

需要 Qt **6.12.0 / MSVC 2022 x64**（包含 ShaderTools、Multimedia 和对应私有头文件）、MSVC C++20 工具链与 Windows SDK、Node **22.14.0**、Python 3、CMake ≥ 3.24 和 Ninja。第三方 npm 依赖由锁文件安装；TagLib、utfcpp 和二维码库源码已保留在 `app/vendor/`。

在 x64 Developer PowerShell 中执行以下示例；路径按自己的安装位置填写：

```powershell
./migration/build-local.ps1 `
  -QtRoot 'C:/Qt/6.12.0/msvc2022_64' `
  -NodeRoot 'C:/Tools/node-v22.14.0-win-x64' `
  -CMakeBin 'C:/Tools/cmake/bin' `
  -NinjaBin 'C:/Tools/ninja' `
  -Python 'python' `
  -Share
```

脚本直接执行源码检查、`npm ci`、`npm run build`、`npm test`，并在指定 `-Share` 时打包。完整玻璃界面检查额外使用 `-CheckUi`，会打开播放器、桌面歌词和任务栏测试窗口。多屏不同缩放比例下，可指定测试屏幕并让本次进程使用原生像素：

```powershell
python migration/run-ui-check.py --output migration/results/manual-ui `
  --screen 'Type-C' --native-dpi --geometry '1280x720+60+2220'
```

屏幕名和几何位置按实际机器填写。`--native-dpi` 只影响测试子进程，不改变 Windows 设置；`--screen` 只影响自测窗口，不改变正式应用布局。没有这些参数时沿用原测试行为。

也可在配置好同样环境变量后进入 `app/`，直接运行原项目的 npm 构建命令。原项目平台说明保留在 [`app/README.md`](app/README.md)。本轮仅验证 Windows x64。

产物：`app/output/RhineMusicDatabase-v1.2.0-Windows-x64.zip`。解压整个目录后运行 EXE，保留旁边的 DLL、插件和资源。

## 迁移检查

```powershell
python migration/verify-source.py --compare-baseline
python migration/check-integrations.py
python migration/test-verification.py
```

`--compare-baseline` 仅用于本次迁移的逐文件等价核对，允许 `ui-validation-changes.json` 中明确记录的两份测试窗口定位改动。未来正常开发使用不带该参数的检查；无需把源码改动重新制成补丁。`migration/source-baseline.json` 保持为迁移时的来源证据。

正式工作流仅检出本仓库，直接编译 `app/`，不执行历史补丁。原正式工作流已完整归档至 `migration/legacy-workflows/build-smtc.yml`，G53 导出工具也在该目录保留。历史分支和候选验证分支继续保留。正式构建产物名为 `Rhine-Windows-x64`，日志与验证记录为 `Rhine-build-evidence`。

应用及第三方许可沿用 [`app/LICENSE`](app/LICENSE)、[`app/NOTICE`](app/NOTICE)、`app/licenses/` 和各依赖自带声明；迁移没有更换原作者署名。
