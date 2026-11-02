# Rhine Music Database — 独立源码迁移候选

完整应用源码位于 [`app/`](app/)。后续独立开发应直接修改其中的 C++、QML、shader、资源与构建脚本。

当前候选从已成功构建的 `6a1639c`（G98）完整还原，尚未切换正式构建。迁移详情、验证结果和未完成项目见 [`MIGRATION-REPORT.md`](MIGRATION-REPORT.md)。

## 目录

| 路径 | 用途 |
| --- | --- |
| `app/` | 可直接编译的完整应用，包含依赖锁文件、测试、资源、MIT 许可证及原版权声明 |
| `migration/` | 独立构建辅助、来源清单和迁移验证 |
| `.github/workflows/standalone-candidate.yml` | 手动触发的独立源码候选构建，仅检出本仓库 |
| `maintained/`、`patches/`、根目录 `scripts/` | 原补丁开发历史，原样保留；独立构建不执行它们 |
| `.github/workflows/build-smtc.yml` | 原正式构建，暂时保持原样 |

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

脚本直接执行源码检查、`npm ci`、`npm run build`、`npm test`，并在指定 `-Share` 时打包。`npm test` 含应用启动/GPU 冒烟检查，可能短暂显示窗口；完整玻璃界面检查额外使用 `-CheckUi`，会打开测试窗口。多屏不同缩放比例下，先确认窗口位置再运行图形检查。

也可在配置好同样环境变量后进入 `app/`，直接运行原项目的 npm 构建命令。原项目平台说明保留在 [`app/README.md`](app/README.md)。本轮仅验证 Windows x64。

产物：`app/output/RhineMusicDatabase-v1.2.0-Windows-x64.zip`。解压整个目录后运行 EXE，保留旁边的 DLL、插件和资源。

## 迁移检查

```powershell
python migration/verify-source.py --compare-baseline
python migration/check-integrations.py
python migration/test-verification.py
```

`--compare-baseline` 仅用于本次迁移的逐文件等价核对。未来正常开发使用不带该参数的检查；无需把源码改动重新制成补丁。`migration/source-baseline.json` 保持为迁移时的来源证据。

新工作流只有 `workflow_dispatch`，目前未推送、未在 Actions 运行。界面专项验收尚未全部通过，暂不采用它替换正式工作流。

应用及第三方许可沿用 [`app/LICENSE`](app/LICENSE)、[`app/NOTICE`](app/NOTICE)、`app/licenses/` 和各依赖自带声明；迁移没有更换原作者署名。
