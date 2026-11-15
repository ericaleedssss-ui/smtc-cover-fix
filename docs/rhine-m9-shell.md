# M9 外壳迁移记录

Qt 的 [AppHeaderB.qml](../../smtc-source-migration/app/Qt/qml/AppHeaderB.qml)、[HomePlayerB.qml](../../smtc-source-migration/app/Qt/qml/HomePlayerB.qml) 和 [RhineTheme.qml](../../smtc-source-migration/app/Qt/qml/RhineTheme.qml) 是这轮的来源。头部和播放栏各自沿用当前 QML 宽度曲线。主窗内容改为占全宽，页面测量直接用全窗宽。

| 清单 | 调整前 | 本次检查 |
|---|---|---|
| S01–S04 | 部分一致，主窗仍走侧栏布局 | 全宽主体、顶部标志和胶囊导航、搜索／设置／头像、返回入口已接入。原生标题栏沿用 MyGo，Qt 的窗口按钮显隐与原生命中仍需真窗验收。 |
| S05–S09 | 部分一致，Cloudy 底栏分区 | 居中 860×72 DIP 基准播放岛，左右分区和控制顺序按 QML。使用 Go 现有的玻璃着色器，增加深色岛材质。已接入播放、波形定位、待播浮层、评论、音量和菜单。玻璃折射、封面与详情间的过渡及长文字滚动仍需与 Qt 实测。 |
| S10、L01–L03 | 部分一致，账号和其它入口分散 | 头像悬停预览、点击固定菜单与「我的」的个人主页入口已分开。账号弹层和待播的 Esc 行为通过离屏测试。原版的完整账号统计、会员、切换账号和消息预览还有差距。 |
| D08、P08 | 部分一致 | 头部接搜索建议。搜索结果仍用 Go 当前路由，完整搜索浮层待后续专项。待播按钮可在当前页面上打开独立浮层，复用队列交互。原版抽屉位置和「收藏全部」还待 P08–P09 验收。 |

下载入口从一级导航移到头像菜单，现有数据和实现保留。原侧栏的可见设置项随侧栏撤下。原有侧栏组件测试改在单独夹具中保留，创建、重命名、取消收藏走新的可见入口做测试。「我的」测试直接进入本人主页。排行榜和播客仍复用 Go 现有内容路由，M9 只改进入这些内容的主窗口入口。

## 截图与测试

| 逻辑宽度 | Qt / Go 并排 |
|---|---|
| 960 DIP | [对照](../../rhine-go-artifacts/M9/compare-960.png) |
| 1280 DIP | [对照](../../rhine-go-artifacts/M9/compare-1280.png) |
| 1920 DIP | [对照](../../rhine-go-artifacts/M9/compare-1920.png) |

左侧为历史 Qt 截图，右侧为 MyGo `NM_FRAMES` 的离屏夹具。截图使用不同数据及窗口高度，保持各自图像纵横比。原生窗口按钮和 GPU 玻璃不能用这组图验收。内容区仍为 M10 之前的首页。

离屏测试核对三档下的入口边界、头像预览、账号浮层与待播的 Esc、个人主页及设置。三档各在测试时钟推进 15 秒期间没有请求新帧。真实窗口帧率、p95、切歌耗时和常驻工作集需在获准使用 Type‑C 副屏后实测。选歌墙首次打开的历史数据及状态见 [M7](rhine-m7-performance.md)。

`TestRhineShell*` 连续运行 5 次通过。用 PowerShell 每 250ms 读取同一离屏测试进程的 `WorkingSet64`，92 次采样最高为 128,098,304 字节（122.2 MiB），包含离屏渲染及 PNG 导出。真实应用的常驻工作集留待实测。

`go test ./internal/...` 仍报 M8 已记录的 `TestNotchGreetsOnce` 与 `TestNotchGreetingKeptUnderPointer`，其余包通过。

## Type‑C 副屏真窗复测

在 Windows 的 Type‑C 副屏以两个独立进程运行 `6a21080`。用 Go overlay 安排窗口位置、填充测试账号与待播夹具，数据目录各自隔离。M9 外壳使用原代码路径。菜单由测试代码设置开合状态，离屏测试补足点击和 Esc。运行结束后测试窗口自动退出。

- 真窗截图：[960 DIP](../../rhine-go-artifacts/M9/live/native-960.png)、[1280 DIP](../../rhine-go-artifacts/M9/live/native-1280.png)、[账号菜单](../../rhine-go-artifacts/M9/live/native-account.png)、[待播](../../rhine-go-artifacts/M9/live/native-queue.png)。副屏工作区宽 2560 像素、DPI 144，1920 DIP 需要 2880 像素。该档保留离屏证据。
- 两轮各 15 秒空闲均为 0 帧。每 500ms 读取 `WorkingSet64`，两轮各 29 个空闲样本，合计 167.41–173.37 MiB。
- 头像菜单按 280ms 动画窗口从 MyGo 帧日志计数，用最近秩求 p95。首轮首开 64.3 fps / 9.9ms，最大帧间隙 160.6ms，后四次均为 157.1 fps / 1.5–2.1ms。复测首开 150.0 fps / 1.6ms，后四次为 110.7–135.7 fps / 1.2–1.6ms，其中两次低于 120 fps。日志记录应用渲染完成时间，未测屏幕扫描输出。此次使用暂停的离线队列，切歌与在线账号未复测。
- 主窗口 `WM_NCHITTEST` 对头部空白、导航和搜索均报客户区。MyGo 的 `DragWindow` 从客户区按下事件调用窗口拖动，因此这次探测无法验收鼠标拖动、双击或独立标题栏按钮。客户端截图确认账号菜单和待播实际绘出，Qt 的账号内容、抽屉位置和玻璃效果仍待对齐。

原始记录：[首轮帧日志](../../rhine-go-artifacts/M9/live/frames.log)、[复测帧日志](../../rhine-go-artifacts/M9/live-recheck/frames.log)、[首轮指标](../../rhine-go-artifacts/M9/live/account-frame-results.csv)、[复测指标](../../rhine-go-artifacts/M9/live-recheck/account-frame-results.csv)。M9 保持部分一致。
