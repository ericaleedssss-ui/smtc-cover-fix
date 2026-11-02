# Rhine 完整源码迁移报告

日期：2026-11-02。当前状态：**独立源码已通过本地与 GitHub Actions 完整编译、离线回归、打包核对和玻璃 UI 307/307 检查；用户已确认采用，正式开发与构建切换到 `main` / `app/`。** 第 11 节记录本次正式采用；第 9、10 节记录候选验证。后续记录优先于初次迁移时的待完成状态。

## 1. 基线与隔离方式

| 项目 | 实际结果 |
| --- | --- |
| 原仓库/分支 | `ericaleedssss-ui/smtc-cover-fix` / `rhine-g95-unified-record` |
| 已验证的源码提交 | `6a1639ce227da15deb2e69d757d00c09fbe62d15`，G98 |
| 原工作流成功运行 | [Actions 41258315791](https://github.com/ericaleedssss-ui/smtc-cover-fix/actions/runs/41258315791)，主构建 job `124706115199` 成功 |
| 固定上游 | `MikeQu223/Rhine-Music-Database@b8b8ad5ed661fa32404731f1b09f7c37d34bf070` |
| 迁移分支 | `migration/full-source-20261102` |
| 迁移工作树 | 原目录同级的 `smtc-source-migration/` |
| 临时还原/工具/证据 | 原目录同级的 `rhine-migration-work-20261102/` |

原工作区保持在原分支，未切换、覆盖或清理。其未提交修改与设计文件共 **145 个文件 / 64,499,204 字节**，均已单独备份，最终再次核对 SHA-256，全部保持原样。备份为临时证据目录中的 `original-uncommitted.zip` 和 `original-uncommitted.json`，不进入发布包。

G99 Editorial 等未提交工作尚未经完整包验收，未混入 G98 迁移基线；原文件完整保留，后续可以单独移植和审阅。视觉设计任务未继续。

## 2. 完整源码的生成与来源核对

在独立临时目录中下载固定上游完整归档，按原工作流的生产顺序：

1. 应用 `patches/G53-base.patch`。
2. 执行 **`6a1639c` 已提交版本**的 `scripts/apply-maintained.py`，应用当时的 maintained 文件、补丁及 enable 脚本链，直到 G98。
3. 运行原来源保护检查、嵌入工作流补丁校验及差异检查。
4. 将最终应用的完整输入复制到 `app/`，不复制临时 `.git`、依赖安装目录、编译产物或账户数据。

上游归档 SHA-256：

```text
0da5547a376ad3a2a2b7ae7624effbb5f77856caf4e6b3a6e72872bb5ed287a3
```

旧流程还原出 **326 个输入文件 / 59,846,815 字节**，复制后曾逐文件 SHA-256 完全相同。最终迁移树中 **325 个文件保持原字节**；唯一调整是 `app/.gitattributes`，增加禁止自动换行转换的规则，让已有混合 CRLF/LF 的源码在 Git 暂存及重新检出时保持已验证字节。所有应用代码、资源、测试和构建脚本均未改动。已逐个比较 326 个 Git 暂存 blob 与磁盘文件，全部相等；属性文件的迁移前后哈希单独记录。

成功 CI 发布的 `MAINTAINED-SOURCE.json` 中全部 **9 个应用源码哈希**也与 `app/` 一致，包括 Main、原生控制器、歌曲桥接、magazine、搜索及唱片页面等。CI 来源清单保存在 [`migration/evidence/baseline-ci-source.json`](migration/evidence/baseline-ci-source.json)。

临时目录通过 ZIP 还原而非原上游 Git checkout，因此当地旧校验器写出的 `legacy-source-stamp.json` 的 `upstream_commit` 是临时初始化提交；**不把它当作上游身份依据**。真正固定上游由下载归档地址、上述归档哈希、原工作流与成功 CI 来源清单共同核对；应用生成文件哈希一致。

所有应用文件哈希及历史输入哈希记录于 [`migration/source-baseline.json`](migration/source-baseline.json)。`--compare-baseline` 是本次迁移的等价检查；日常构建不要求未来代码一直等于旧版。

## 3. 已吸收的历史修改

下表记录的是实际有效调用链，不假设每一个 G 编号都有单独补丁。较早修改已合并在 G53 基础补丁内，部分后续版本体现在最终 maintained 文件中。

| 历史来源 | 已进入完整源码的内容 |
| --- | --- |
| `G53-base.patch`、最初 maintained 覆盖 | 原 SMTC/封面修复、原生应用及玻璃 UI 基础、发现和桥接扩展 |
| `enable-scrobble.py` | 真实播放时长与每次播放一次的听歌上报 |
| G57、G57 UI、G58–G64 | 私人 FM、胶囊播放栏、封面和社交状态、队列、圆形裁切、布局及大队列性能处理 |
| G65–G68、G66 lifecycle | 原生可交互队列、分层玻璃、来源追踪、全局队列/收藏浮层、页面保留和生命周期检查 |
| G69–G71 | 杂志式歌单、稳定搜索与唱片选择、有序播放会话、账号与红心资源 |
| G73–G79 | 扫描性能、滚动与返回状态、收藏初始状态、真实消息抽屉、统一输入/材质、资料库展示 |
| G81–G86 | 连续玻璃组件、真实专辑曲目、滚轮路由、页面保留、二级列控制器、正在播放内容 |
| G88–G91、G93 | 沉浸唱片/歌词、全局播放页入口、统一专辑杂志、热度数据、矢量唱臂 |
| G98 与最终 maintained 文件 | 心动模式退出顺序、红心预热、底栏与调度处理、已提交的唱片材质和方向高光 |

`apply-maintained.py` 实际依次调用：

```text
enable-scrobble.py
enable-g57.py, enable-g57-ui.py
enable-g58.py … enable-g65.py
enable-g66.py, enable-g66-lifecycle.py
enable-g67.py … enable-g71.py
enable-g73.py … enable-g79.py
enable-g81.py … enable-g86.py
enable-g88.py … enable-g91.py
enable-g93.py, enable-g98.py
```

G65、G66、G67、G68 两份 QA、G69、G70、G71 的独立 `.patch` 由对应脚本应用；其最终结果已体现在 `app/`。**独立构建无需再执行以上任何历史步骤。**

旧 `maintained/`、`patches/`、根 `scripts/` 全部保留；清单中 **152 个历史输入文件**哈希未改变。原有根工作流逐字节未改变。

## 4. 新的维护与构建结构

完整应用集中在 `app/`，包含 CMake、C++、QML、shader、模型、图片、字体、资源、依赖锁文件、测试、平台构建脚本以及许可。后续功能修改直接发生在 `app/`。

新增 [`standalone-candidate.yml`](.github/workflows/standalone-candidate.yml)：

- 仅迁移分支 `migration/full-source-20261102` 的相关文件推送或 `workflow_dispatch`，只检出当前仓库一次；默认工作目录 `app`。
- 不检出原作者仓库，不执行根历史补丁或 enable 链。
- 沿用 MSVC 2022、Qt 6.12.0、Node 22.14.0，执行原构建、玻璃检查、离线回归与打包。
- 保留原工作流的 scrobble/FM 来源断言，使用 `migration/check-integrations.py`。
- 验证压缩包与部署目录一致、必需版权声明存在、应用根目录个人数据被排除。
- 上传候选包与验证证据；图形测试失败仍保留失败，不修改断言来通过。

旧 `.github/workflows/build-smtc.yml` 保持原样。`app/.github/workflows/` 为原文件保留，GitHub 不会从这一子目录自动执行工作流。新工作流尚未推送或运行，正式构建尚未切换。

本地入口与具体命令见 [README](README.md)。`migration/build-local.ps1` 是独立编译辅助脚本；支持已有 Developer PowerShell，或显式指定便携 MSVC 工具链。其语法检查已通过，但未把整个新 wrapper 再执行一遍；底层实际 build/test/share 已分别成功执行。

## 5. 仍需要的依赖

| 依赖 | 本轮使用/保留方式 |
| --- | --- |
| Windows C++ 工具链 | MSVC 2022，14.44.35207 工具目录，编译器 19.44.35229；Windows SDK 10.0.26100.0，含 C++/WinRT |
| Qt | 6.12.0 MSVC 2022 x64，Core/Gui/QML/Quick/Network/Concurrent/ShaderTools/Multimedia，以及构建需要的私有头文件 |
| Node/npm | Node 22.14.0；根及 MusicBridge 依赖按各自 lockfile 安装；运行时 Node 随绿色包携带 |
| CMake/Ninja/Python | CMake ≥ 3.24；本轮 CMake 4.4.4、Ninja 1.13.2、Python 3.12.14；候选 Actions 使用 Python 3.12 |
| 本地 vendor 源码 | TagLib 2.1.1、utfcpp 4.0.6 归档与校验值、qrcodegen；不会每次获取原作者应用源码 |
| 音乐桥接/API 依赖 | 保留 `MusicBridge/upstream`、来源哈希、client/worker 与锁定 npm 包；业务运行仍依赖相应音乐服务 |
| FFmpeg/Qt 插件/VC 运行库 | 原部署逻辑随包携带，迁移未更换音频后端或插件方案 |

首次配置工具链、安装 npm 包仍需下载依赖。独立维护完整应用源码不意味着所有第三方依赖均离线。sccache 是可选加速项，候选工作流未依赖它。

本地编译使用隔离的便携工具目录，未要求安装完整 Visual Studio，也未将 SDK、环境变量转储或本机工具包加入仓库。Qt 部署时已将其软件 OpenGL DLL 放至 kit 的正确 bin 位置，以恢复原包文件集合；这不涉及应用源码改动。

## 6. 已通过的验证

| 项目 | 结果 |
| --- | --- |
| 完整源码与旧流程还原结果 | 325/326 文件哈希一致；仅 Git 换行属性有已记录调整，应用输入未变 |
| Git 暂存/检出字节保护 | 326/326 暂存 blob 与磁盘文件相等；向新目录重新检出后，326/326 哈希仍相等 |
| 成功 CI 的应用源码指纹 | 9/9 一致 |
| 完整本地 Release 编译/部署 | 成功，355 个 Ninja 构建步骤 |
| `npm test` | exit 0：源码边界、Qt/桥接来源、发布版本/发布流程夹具、包审计等通过 |
| CTest | 7/7：平台、音频播放、HTTP 流、离线、原生 HUD、更新器、本地音乐 |
| Node 桥接测试 | 48/48（9+3+4+5+16+11）；评论和本地歌词 IPC 另有检查通过 |
| 原生包检查 | Host/场景/播放检查通过，音乐核心 34 项通过，部署包隔离 Qt 路径的离线 GPU 冒烟通过 |
| scrobble/FM 原工作流断言 | 通过 |
| 迁移保护负向测试 | 正确树通过；改动基线、错误 GITHUB_SHA、压缩包混入账户数据均被拒绝；未来正常源码修改允许 |
| 最终 `npm run share` | 成功；ZIP 所有文件与当前部署目录对应一致 |
| 新工作流静态检查 | YAML 可解析、仅手动触发、只检出自身、无历史补丁重建步骤 |
| 本地辅助脚本 | PowerShell 语法通过；Python 辅助与保护检查通过 |

新增迁移脚本/文档的 `git diff --check` 通过。完整源码首次入库时，检查会报告原 vendor 源码/许可等自带的空白问题；这些继承问题未自动格式化，以保留原字节。

### 产物比较

旧成功 CI artifact ID `13063959895`，下载 ZIP SHA-256：

```text
1837042707b54f56c5e3621247a30b06f1774b69b500411b702d0be16cefa74c
```

去除应用根目录个人 `data/` 后，新旧部署包均 **7,766 个文件**，无增加、无缺失，其中 **7,763 个哈希相同**。差异：

- `RHINE MUSIC DATABASE.exe`：重新编译，包含不同的构建路径/元数据等；没有声称可重现的二进制等价。
- `dxcompiler.dll`、`dxil.dll`：由 windeployqt 从本机 DirectX 环境选择，和原 CI 主机版本不同。未擅自替换 DLL 消除差异。

封面/字体/模型/桥接资源和其他运行库保持原包字节。最终候选 ZIP：

`app/output/RhineMusicDatabase-v1.2.0-Windows-x64.zip`（本地验证产物，不入 Git）

SHA-256：

```text
7c11ae0ad0e2f1ee2674340770ab062e056d9cb3248720303474263845d8c340
```

## 7. 界面专项结果与未完成项目

**没有达到完整界面验收通过。** 使用原 `--frosted-self-test` 和原评论夹具：

- 候选首次检查 **306/307**，失败项：`hover reveals progress controls and only the actual chorus marker`。
- 下载的旧成功 CI 包在同一台电脑检查也为 **306/307**，其失败项不同：`close click actually dismisses the queue`。
- 两轮生成的 37 张截图文件名、尺寸相同，仅 3 张逐像素相同。其余差异不能当作视觉等价已证明；动画/交互时序及机器环境尚未完全控制。
- 随后一次错误的多屏几何参数试验为 **301/307**。窗口后来确认位于不可见区域；该轮有专辑路由、曲目 artwork、歌单入口、推荐滚动、歌词 blur、Following 滚动共六项失败，完整列表保存在验证摘要中。原因未完全定位，不将这些失败归咎于迁移或自动忽略。
- 已找到 Type-C 副屏可见的预览位置，且用户确认能看到。后续不再打开图形测试窗口；未在修正位置后重跑全套 GUI，因此图形验证仍待完成。未修改任何生产代码或原测试断言。

仍待：

1. 在稳定可见的测试环境完成原玻璃 UI 检查并人工确认界面、导航、动画、缩放、歌词/队列行为；验证上述失败和两份 DirectX DLL 的实际影响。
2. 候选工作流在 GitHub Actions 的实际运行。当前只完成本地编译和工作流静态检查，不能称远端 CI 已通过。
3. 新 `build-local.ps1` 完整端到端调用；现有底层命令已经运行成功。
4. 真实账号在线搜索、收藏、播放、私人 FM、上报/评论等人工回归；本轮未登录或操作用户账号。本地歌词测试真实文件数为 0，不能代表用户真实曲库已测。
5. macOS/Linux 编译与打包、长时间播放/性能、不同硬件和干净系统安装验收。

不会为完成迁移而顺便修复现有 UI 或弱化回归测试。上述未完成验证前保留原正式构建。

## 8. 许可与交付边界

原 `app/LICENSE` 保留 **MIT / Copyright (c) 2026 LBEILC**；`NOTICE`、`licenses/`、桥接来源/许可、vendor 许可和字体记录全部原样保留。部署脚本的原第三方许可复制逻辑保留，最终包验证必需法律声明存在。没有替换作者署名或重新授权第三方素材。

本轮未合并 G99 或设计实验，没有更改 UI/动画/数据/播放器源码，没有删除原补丁，没有推送、发布或建立新正式仓库。原构建路径继续存在作为回退方式。

主要新增内容：`app/`、`.github/workflows/standalone-candidate.yml`、`migration/`、本报告，以及根 README 和仅忽略本地验证结果的 `.gitignore`。简明验证摘要保存在 [`migration/evidence/verification-summary.json`](migration/evidence/verification-summary.json)；详细日志和截图位于本地 `migration/results/`，不会自动进入 Git。

后续可先审阅当前候选。在图形验收及候选 CI 实际成功后，再决定是否采用新的工作流和将本地迁移提交推送到现有仓库。正式采用前无需删除历史文件。

## 9. 2026-11-02 追加：本地完整界面检查通过

用户授权继续验收后，先在不显示窗口的 offscreen 平台对新旧原样包进行对照：两者均为 **305/307**，同样失败于 Windows 任务栏和歌词 shader。日志明确显示 offscreen 没有 QRhi；该平台不能作为 Windows 图形验收依据。

三屏使用不同缩放比例，原样测试通过 `QMouseEvent` 的本地/全局坐标注入鼠标事件，检查结果随窗口位置和 DPI 环境变化。将测试进程设为原生像素（`QT_ENABLE_HIGHDPI_SCALING=0`，不更改 Windows 设置），并明确指定 Type-C 副屏后，独立诊断程序 **307/307** 通过。随后已在真正部署的候选包上重复验证，同样 **exit 0 / 307/307**，生成 37 张截图。

为安全地将所有自测窗口放在副屏，最终仅修改两份测试文件：

- `app/Qt/tests/UiChecks.cpp`：可选 `RHINE_QA_SCREEN` 指定主测试窗和桌面歌词窗的位置。
- `app/Qt/tests/TaskbarChecks.cpp`：同一可选环境变量指定任务栏自测窗位置。

没有修改生产主入口、UI、shader、播放器或业务逻辑。两份文件中原有全部 `check(...)` 表达式和标签已与还原的 G98 源码逐项核对，完全保留。无测试屏幕参数时沿用原测试行为；找不到明确指定的屏幕则失败。两份文件修改前后哈希及用途见 `migration/ui-validation-changes.json`；等价检查只允许这两项记录的精确变更，负向测试覆盖额外变更及非法生产源码例外。

因此最终 326 个输入中 **323 个与旧还原结果逐字节相同**；另外三项为 Git 换行属性和两份测试窗口定位文件。初次导入的完全等价证据保持原记录，后续测试改动单独列明。

`migration/run-ui-check.py` 增加 `--screen` / `--native-dpi`，只给测试子进程设置环境，不影响用户常规启动。命令：

```powershell
python migration/run-ui-check.py --output migration/results/candidate-final-native-dpi `
  --screen Type-C --native-dpi --geometry 1280x720+60+2220
```

`migration/build-local.ps1 -Share` 已真正从头调用完成：源码检查、npm ci、编译/部署、npm test、share、ZIP 全文件校验均 **exit 0**。修复了 Windows PowerShell 5 将重定向的原生 stderr 普通警告误判为终止异常的问题，仍严格按非零退出码报错。

最终候选包仍为 7,766 文件，与旧包 7,763 文件字节相同，无增加/缺失。变化仍为 EXE、`dxcompiler.dll`、`dxil.dll`。本轮最终 ZIP SHA-256 更新为：

```text
ba9a024373ff4230c9204fba28e87968fcafc6c14af36b3c0724058ceeec07a1
```

证据摘要：[`migration/evidence/ui-followup-verification.json`](migration/evidence/ui-followup-verification.json)。原工作区 145 个文件及 152 个历史输入哈希再次确认未变。测试窗口已自动退出。

本地自动化界面检查和 wrapper 端到端验证不再待完成。仍需远端候选 CI、用户主观体验确认、真实账号在线端到端回归、macOS/Linux 与不同硬件验收。截图不能提供跨机器逐像素等价保证。新候选工作流增加仅迁移分支的 push 触发，用于在现有仓库隔离验证；正式构建工作流仍原样保留，不合并或切换正式分支。

## 10. 最终：独立源码远端候选构建成功

迁移分支 `migration/full-source-20261102` 已推送到现有仓库；实际验证提交 `f89fa4bbf7c8d5bbb44ad47da8642563c168a023`。

- [Actions 41447801633](https://github.com/ericaleedssss-ui/smtc-cover-fix/actions/runs/41447801633)，job `125285152941`，最终 **success**。
- 云端从本仓库完整 `app/` 直接编译/部署，来源清单记录 `migration_equal=true`、`historical_patches_required=false`。
- 玻璃 UI **307/307**、CTest **7/7**、桥接 **48 项**、包隔离/GPU/资源审计全部通过。
- 绿色 ZIP **7,766 文件**与部署树逐文件相符，许可证存在，个人数据已排除。
- [候选 Windows 下载](https://github.com/ericaleedssss-ui/smtc-cover-fix/actions/runs/41447801633/artifacts/13143298236)：`Rhine-Standalone-Candidate-Windows-x64`。
- [云端证据下载](https://github.com/ericaleedssss-ui/smtc-cover-fix/actions/runs/41447801633/artifacts/13144147006)：`Standalone-migration-evidence`。

已下载约 9.6 MB 云端证据并核对 artifact SHA-256，确认来源清单和包校验记录。云端应用 ZIP（artifact 内部的实际分发 ZIP）SHA-256：

```text
eb444e92b7ab9b600d56a9ee7d68d6b126a25106d50380532119f765f589c429
```

GitHub artifact 外层 ZIP 有独立哈希，不与上述内部应用 ZIP 混用。两份 artifact 保留至 2026-11-16；届时需要重新构建获取。简明证据在 `migration/evidence/remote-ci-verification.json`。

**本轮迁移实现与 Windows 自动化验证已完成。** 没有合并、修改默认分支或切换原正式构建；也没有删除任何历史补丁。接下来用户可以下载候选包，按日常方式体验搜索、播放、切歌、队列和喜欢等内容；真实账号在线验收、主观视觉验收、macOS/Linux/其他硬件仍不属于已证明结果。用户确认采用后，再单独切换正式开发/构建流程。

## 11. 用户确认采用：正式开发与构建入口

用户在确认以后直接修改源文件的开发方式后，明确回复「确认哦」。据此采用已通过验证的完整源码，将迁移历史保留并快进合入仓库现有默认分支 `main`。默认分支名称无需修改；原 `rhine-g95-unified-record` 和 `migration/full-source-20261102` 分支继续保留。

- 正式维护目录为 `app/`，本地工作树为 `../smtc-source-migration/`，分支为 `main`。应用源文件与已通过 307/307 的候选没有任何变更。
- `.github/workflows/build-smtc.yml` 使用已验证的独立源码构建步骤，响应 `main` 相关文件推送、面向 `main` 的 PR 和手动触发。新增加并发取消以避免同一分支重复消耗构建资源。正式产物名为 `Rhine-Windows-x64`。
- 原补丁构建工作流逐字节保存在 `migration/legacy-workflows/build-smtc.yml`；原 G53 导出工作流逐字节保存在 `migration/legacy-workflows/export-g53.yml`，不再作为活跃工作流。所有原始文件仍在旧分支及 Git 历史中，历史补丁和 maintained 源文件没有清理或改写。
- 本轮仅调整工作流触发入口、产物标签和文档；正式工作流的权限、依赖版本、编译、玻璃 UI、原生/桥接回归和打包校验步骤沿用成功候选。
- 原目录所有未提交源码和设计保留；仅在其未跟踪的 `SESSION-HANDOFF.md` 顶部追加正式开发目录提示，旧交接正文完整保留。这不是把未验收 G99 合入正式版本。

正式采用提交 `4cd76ffbf230646e5f9c7957a9cd1b496b30f34f` 已成功推送至 `origin/main`，没有强制推送。新正式构建 [41451386632](https://github.com/ericaleedssss-ui/smtc-cover-fix/actions/runs/41451386632) 已由该推送触发，最后核对为 `in_progress`，尚未取得最终结果。源码逐文件基线核对、集成保护和验证器负向检查通过；归档后的 Git blob 与原工作流逐字节一致。正式触发路径排除 `migration/evidence/`、`migration/legacy-workflows/`，单独更新证据或归档不消耗重复构建。

候选成功记录仍为 [41447801633](https://github.com/ericaleedssss-ui/smtc-cover-fix/actions/runs/41447801633)。不将候选成功冒充为新工作流运行结果。真实账号在线操作、长期使用、macOS/Linux 与其他机器测试仍未完成。
