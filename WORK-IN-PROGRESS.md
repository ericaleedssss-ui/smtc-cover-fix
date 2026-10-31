# G98 工作交接：构建回归修复，先读最新状态

## 最新状态（2026-10-31，优先于下方历史调查）

- 第二次构建 `41200398052` / 提交 `6e449e5`：编译、部署及**全部界面检查已通过**；之后 `npm test` 的七个 CTest 中只有 `qt_offline` 失败，输出定位为 Native Host 检查。其余六项通过，尚未打包。
- 已复现 Host 新调度检查的真实计时缺陷：offline send 多一次0ms事件循环投递，但 lastStart 在该投递前记录；Windows事件循环下25ms要求实际首两次只有9–13ms。用同一 Windows PySide6 Qt 事件循环模拟生产 pump，修改前12/12次失败（最大并发3和排队边界通过），修复后12/12次全部>=25ms。
- 本轮改为 QElapsedTimer 单调计时，offline 在真正 service entry 更新并继续 pump，live 仍在 send 边界更新；dispatch 再核对最小间隔。非调度直达请求不重置 metadata 计时。保留 max3并发/优先级/缓存/去重/cooldown；增加具名诊断，未跳过离线检查。最终 C++ 集成仍需下一次CI验证。

- G98 已在 `6ee5dfdb67aab47589fc50ee9df0b163cbd433f5` 提交并推送至 `rhine-g95-unified-record`。下方“未提交”“未应用”等均为此前调查的历史状态。
- 用户报告的失败运行：<https://github.com/ericaleedssss-ui/smtc-cover-fix/actions/runs/41198449420>，job `124529271414`。Qt 6.12/MSVC 编译、部署、源码保护和仓库边界检查通过；失败在界面回归，打包尚未运行。
- 六项失败：删除心动 resume seed、stop 后空歌曲、进度 hover/时间/副歌比例三项、旧歌词 ShaderEffect status 断言。其余新增心动边界和 G88 布局检查通过。
- 本轮修复：`PlaylistShowcase::syncHeart` 改用 `.value("kind")`，防止读取不存在字段时将空 current 写成 `{kind:null}`；stop 断言继续保留且使用真实同步观察者。
- 心动用例 `exitFrom` 原只 leaveHeart，再直接替换 public queue/current，会保留上一用例私有 resume anchor（末尾用例留下1，下一用例想从0开始）。每个场景改用 stop 重置。测试歌曲用 MusicData::item 创建，避免换 id 却保留旧 key。
- 整组心动检查改用独立 offline Host + MusicLibrary + PlaylistShowcase，仍执行生产代码；避免 play/stop 清歌词、媒体 state、加载和异步请求后仅恢复四个 public 字段，污染后续 GUI。未删除功能断言。
- 单独运行生产 `LyricsReading.qml`、原 `lyricsEdge.frag`，本地 Windows D3D11 实际渲染成功，status 却为0。旧 `status==1` 不适用于这种预编译 QSB；改为资源存在、无Error/无log以及抓取 shader 输出有实际非透明像素。临时英文 Shader regression 只在 TEMP 测试窗口，不进产品。
- 已从134个固定上游文件重建 `%TEMP%/rhine-motion-qa/g98-ci-fix`，完整 G53 + apply-maintained 成功；唱头位置和动画未再修改。最终 MSVC、集成检查、offline regressions、打包仍需新CI核验。
- 日志无需重新全文读取：上一轮 functions store `g98logtext` 有完整日志；极大，筛选输出，不要整段打印。旧日志的 sccache/Node 警告不是此次失败根因。

---

以下为此前排查记录，保留供追溯；状态以上述最新记录为准。

更新时间：2026-10-31。本文件记录当前调查结果与未完成改动，防止压缩后重复排查。

### 最新增量（优先于下面较早的状态）

- 最最新用户“可以再出来一点点”：沿左上再挪上一轮一半，**pivot当前1.154w/.370h**，头部26%放大保持。上一轮1.158/.374已完整D3D回归通过并对照图确认方向，当前小幅调整待验证。
- 心动边界补丁最新追加：resumeIndex在删除/插入/clearUpcoming时更新；原歌单最后一首按off模式结束不重播。enable-g98最新几处追加尚未重新从基线应用，务必重建验证；特别检查 `queue.removeAt(selected)` anchor 是否唯一。

- 用户最新进一步明确：**当前26%唱头大小基础上，画面方向向左上稍微挪一点，多露出来**。已改pivot从1.166w/.382h到**1.158w/.374h**，QA预期同步；未向封面内大幅移动。此后不要按更早“只能右上移动”的描述覆盖最新反馈，仍需保证避开刻字和封面。

- 用户最新反馈唱头变化看不出来；此前10%方案不足，**当前改为局部26%放大**，同步拓宽shader绘制域1.34x.28 ->1.42x.32以免针头本身被局部纹理截断。QML影子/实体位置及旋转origin同步，支点保持1.166w/.382h，不向封面和刻字内挪。这个最新幅度需GPU重测、同尺寸前后近景对照，尚未用户验收。

- 最终版 `test-g86-qml.py` 软件和 RTX3080Ti D3D11 均已通过；歌词current+next完整显示/半句隐藏、音频柱居中均通过。更早GPU失败记录仅用于解释为何改断言。
- 新增 `maintained/G98-host-pump.cppfrag`，enable-g98已开始实现全局metadata限3并发、请求开始间距1200->250ms、detail/likedIDs优先于wiki；沿用cache、dedupe、cooldown。**此Host修改尚未应用/编译/测试，必须重点验证：pumpScheduled定时、超时/失败释放、回调重入、shutdown、账号epoch、FIFO同优先级和限速。**
- 第三项不再只是warm likes：Host调度器是本轮新增实质修改，但仍未完成验证。
- 新 `%TEMP%/rhine-motion-qa/g98-generated` 已从134个固定上游基线文件重新生成，G53 + 整套apply-maintained（包括最新版G98、Host并发和原生测试注入）完整成功。早先 `generated` 留在旧版，不要混用。
- Host原生回归新增 slow wiki nested event loop + fast album 抢先完成验证；尚未编译运行。
- GPU截图已目检：唱头在右上，方向正确；初始 resize 时歌词跟随可能因新行高/viewport变化未及时更新，刚补 `onWidthChanged/onHeightChanged/onContentHeightChanged: Qt.callLater(page.follow)`，这最后3行尚未重测。

## 当前状态与用户授权

- 用户是中文交流的代码初学者，通过截图、效果图和使用反馈提供需求。继续自主实施、验证；不要要求用户解释代码。
- G97 成品用户已经拿到，反馈暂停/播放大幅改善，但切歌仍有明显顿点。
- 当前分支 `rhine-g95-unified-record`；HEAD 为 `4013f9613b78d0060bb9531faf35495c02a3cbcd`。
- **G98 所有改动仍在工作区，未提交、未推送、未触发新构建。不能说已经修好或已经发布。**
- 用户最新希望把已排查的细节也写下来，避免压缩后重复调查。
- 不启用子代理，除非用户明确要求。

## 本轮需求：全部仍属于在办事项

1. 唱头只稍微放大并轻微上移，仍从右上方伸入；利用右上方留白；不能向左压住封面或刻字。用户发了潦草修图，表示的是相对大小和位置。
2. 切下一首时唱臂、唱片仍有顿点；用户在本地测试窗口出现时再次确认仍感到卡顿。不能用拉长动画时间代替排查。
3. 歌单首次/再次加载、红心状态、玻璃底部曲风加载慢，希望优化。
4. 检查更广泛的 UI、图标视觉中心和间距；歌单/专辑列表封面与歌名太分离、表头和内容观感不好。
5. 心动模式切回顺序播放，队列仍是推荐顺序；必须恢复进入心动前的歌单顺序，下一首也应遵循原歌单。
6. 新补充：播放栏左右/中间按钮和信息间距也要调整，缩小窗口不能挤压重叠。
7. 新补充：正在播放页歌词上下两句各裁一半；时间戳难看；歌词布局重做，兼顾翻译、无翻译和长行，并保留手动滚动/跟随/点击跳转。

保留现有原版玻璃材质、唱片/封面尺寸与位置、透视、真实播放/收藏/导航功能。此前喜欢的动画方向不等于本轮改动已验收。

## 仓库机制：不要直接在不存在的完整应用目录找代码

本仓库是 overlay，完整上游不在仓库内。构建流程：

1. checkout `MikeQu223/Rhine-Music-Database` 的固定提交 `b8b8ad5ed661fa32404731f1b09f7c37d34bf070`。
2. 应用 `patches/G53-base.patch`；workflow 中两大段 base64/gzip 补丁不可改坏。
3. 执行 `scripts/apply-maintained.py`，按顺序运行 `enable-*.py`，复制 `maintained/` 文件。
4. Qt 6.12/MSVC 原生测试和 Windows 打包在 GitHub Actions。

新增 `scripts/enable-g98.py` 放在最后 `enable-g93.py` 后；不能把最终修改放在早期会被后续覆盖的位置。

## 本轮已经确认的根因与位置

### 心动模式

- G53 `MusicPlayer::startHeart()` 成功后直接 `queue = replacement; index = 0; mode = "heart"`。
- `NativeHud::playerAction()` 的 `name == "mode"` 分支退出时只是 cancelHeart + 改 mode，没有恢复原队列。
- `cancelHeart()` 只增加请求代数、清 pending，本身没有队列恢复语义。
- `next()` 在心动队列尾请求新推荐；原 fail lambda 在 advance 失败时会改为 off，这也会使退出无法识别心动状态。
- 漫游 FM 与心动是两套逻辑；`startRoam/leaveRoam` 已有完整原队列恢复和 `m_restoringRoamContext`，不能破坏它。
- 原始实现可在 canonical G53 补丁中检索，也可读临时生成树里的最终 C++。

### 切歌性能

- `Host::loadCover` 网络图片解码本来已经使用 `QtConcurrent` + `QFutureWatcher<QImage>`，不应重复声称原解码一直在 UI 线程。
- **NowPlaying.cpp 的 circularPNG() 则在 Host 完成回调（界面线程）里同步做圆形 QPainter 裁切、平滑缩放、PNG 编码、base64。** cover 为 512，avatar 为 96。
- sync() 在 m_cover 空且 player.coverImage 已到达时也有同步 circularPNG 路径。
- 上述工作是已确认的界面线程工作，但**未实测证明它就是用户全部顿点来源**。
- QML incoming deck 原来 preparing 阶段 invisible，只有 Image.Ready 就开动画；GPU layer/文字纹理可能要等第一次可见才准备。正在试验提前微透明绘制两帧，不能宣称已解决。
- G97 两个持久 deck 交换身份机制继续保留；不要回退成切换时复制封面/销毁重建整个唱片。

### 曲风/红心/歌单

- NowPlaying::sync 原本固定等 700ms 才 loadTags()；loadTags 只缓存非空成功标签。
- wiki API 返回完整歌曲百科文本，wikiTags 从包含“标签”或 tag 的行拆出 `/` 分隔项。
- 曲风原文案在请求未返回时也显示“曲风暂无”，混淆加载中与真正无标签。
- NetEase `likedIDs` 在 `MusicBridge/client/netease.mjs`：先 `/user/playlist` 找 specialType=5 且 creator.uid 匹配，再 `/playlist/detail` 取 trackIds。这保留了喜欢歌单顺序，不应随便用无序 likelist 替代。
- `MusicLibrary::ensureLikedIDs` 已存在（G76），多个调用者共享 in-flight 请求，结果存在 optional likedIDs。
- `PlaylistMagazine::sync` 原来等进目录后才调 ensureLikedIDs。rebuild 会先显示 lists[1] 中已知喜欢项，完整 ID 到达后再更新。
- Host 已对 native/detail 缓存 21600 秒，native/wiki 和 songs 缓存 86400 秒，native/likedIDs 等缓存 60 秒；账号凭据、metadataRevision 参与 key。不是完全没有缓存。
- Host 磁盘缓存只对 guest 部分 raw routes 开启，native 适配请求不是同一缓存边界。
- `MusicDirectory::enterDirectory` 创建目录后调用 showDirectoryInfo -> loadDirectoryDetails；该路径已有立即发请求，没有此处人为延时。原 MusicLibrary::choose 则有 300ms 详情延迟、loadCover 有 200ms 延迟，但不应混为同一个歌单加载路径。
- **目前对歌单主体加载还没有实施新缓存或请求合并方案；第三项只做了初步优化，不能说全修完。**
- 更新发现：`Host::requestJson` 对所有 cached 路径入同一个 queue，`Host::pump` 在 `active` 非空时直接返回，意味着歌曲百科、歌单详情、likedIDs、artistAlbums 等元数据**全局串行**。一个慢 wiki 可能挡住后面的歌单/红心。这比单纯缓存缺失更值得优先检查。`send` 的 uncached路径直接发；`finish` 会释放active并pump。应考虑有界并发或交互优先队列，并保留平台冷却、账户epoch、去重和限速；尚未修改Host调度器。

### 图标/排版/歌词

- `NowPlayingShortcut.qml` 内容宽度 22u，4 根柱 x=3,8,13,18u、宽 2u，实际左右边界中心为 11.5u，偏离内容中心 11u；改为按实际 17u 总宽居中。
- QML Controls.Button 用 padding 仍可能继承 Basic 样式显式 horizontal/vertical padding，Action 和 More 改成四边明确设置。
- `RhineIcon.qml` 用 24x24 路径；不同 path 自身视觉中心并非完全一致，尚未做全面 icon path 调整。
- `PlaylistMagazine.qml` 原标题与艺术家居中，艺术家 x=.42w，专辑 x=.65w；导致封面和标题间大片空白。
- 歌词旧 delegate 最小高度 78u，字体 22u，翻译 12.5u，当前句居中，161u 高区域容不下前后完整双语三句。
- 旧 hover 时间戳占左侧 33u gutter，主词也因此比上方标题、下方动作缩进。

## 目前工作区改动（仍需审核）

### maintained/Qt/qml/NowPlayingPanel.qml

- 唱臂 pivotX 从 1.16w 到 1.166w，pivotY 从 .405h 到 .382h；armLength 仍 .54w，swing 仍 -149+18*pose。
- shader 唱头局部坐标 q / 1.10，仅放大 cartridge/head assembly，shaft 长度不变，影子同坐标。见 recordAtmosphere.frag。
- preparing 时 back deck visible，opacity=.001，FrameAnimation 等 artwork ready 后至少 2 帧才开 swap；reduced motion 直接走，不等帧。
- 歌词改为自适应高度 min38u，20u 主词 + 11.5u 翻译，不用当前行改变字重（避免字宽/行高因选中变化）。取消两行截断。
- follow 优先容纳 prev/current/next 三完整条；放不下则 current 距顶部6u，显示 current+next；自动跟随时超出视口的半句 opacity=0，手动滚动可看全文。
- 时间戳移至 hover ToolTip，仍可点击 seek，移除左侧大 gutter。
- 标签新增 tagsLoading/tagsFailed 文案。
- **长双语歌词和 opacity 临界跳变还需视觉核对，不能认为此设计已经最终接受。**

### maintained/Qt/src/NowPlaying.{h,cpp}

- 新 preparePixels：QFutureWatcher<QString> + QtConcurrent::run，把 circularPNG 移到线程池；回调检查 generation/account，in-flight key 去重。
- sync 中 player.coverImage fallback 也走 preparePixels。
- wiki 延迟 700 -> 0ms，支持 loading/failed 状态，成功空标签也缓存。
- 新文件需显式 include QImage/QSet 或依赖上游包含，建议编译前检查；当前 header 从 MusicLibrary 传递包含 QImage，尚未 native 编译验证。
- 注意相同 track 更新 cover URL、同 generation 内旧 cover 返回的竞争目前未新增专门 URL token（既有问题，视需要处理）。
- 需要检查 QtConcurrent 链接，生产 CMake 原本已有 Qt6::Concurrent；模型测试脚本已经补 include/link。

### PlaylistMagazine.qml

- rowHeight 65 -> 62u，封面44 ->42u，标题17 ->15u。
- 标题与艺术家、专辑列左对齐，统一 helper：titleX=74u+max(40,42u)，artistX=.44w，artistWidth=.23w-20u，secondaryX=.67w，secondaryWidth=max(24u,w-secondaryX-188u)。
- 热度仍居中，喜欢/时长在右侧保留。
- 大多数其他页面尚未做广泛目检。

### scripts/enable-g98.py（新文件，未跟踪）

- 新 leaveHeart、m_heartSavedQueue/index/context、m_heartResumeIndex。
- 第一次成功推荐前保留原 queue/index；续推荐不覆盖原 snapshot。
- 退出恢复原 queue；当前曲在原列表则定位；不在则 index=-1，当前音频不停，next 从 seed 下一首恢复。
- 显式新 source/stop 清 snapshot，避免以后退出恢复旧歌单。
- controller 正在 pending 或 heart 模式时统一 leaveHeart，防迟到回复改队列。
- refill 失败保留 heart 模式，允许退出恢复。
- restoreAccount 成功后提前 ensureLikedIDs；首次进入歌单仍共享同一请求。
- 播放栏 prev/next 从±81到±72、mode/queue 从±156/155到±144；漫游 dislike 从218到208。
- volume vx width-310 -> width-278，mute vx-25 ->vx-32，desktop width-148 ->width-132；NowPlaying 快捷入口 x=width-86u（旧-98u），y=1012u（旧1011u）。
- **必须检查无空格 center+218 绘制坐标：最新脚本已补替换，临时生成树还没重新应用最新版。**
- 新集成 QA 注入 Qt/tests/UiChecks.cpp：原队列恢复、推荐不属于原队列时 Next 恢复、请求退出后迟到不覆盖。
- 此脚本早期版本在临时 generated 树应用成功；**后补 native tests 和无空格坐标替换版本尚未完整从零 reapply。**

## 已跑的验证与失败原因（不要盲目重复）

1. 成功取得固定上游约134个需要的源文件（GitHub connector 并行读取，写在临时目录），G53 git apply --check 和实际 apply 成功，整个 apply-maintained 到 G98 初版成功。
2. 最新 `scripts/test-g86-qml.py` **软件渲染完整通过**：pause/play/reversal/heartbeat/loading、rapid/queued swaps、deck identity、late/missing art、reduced motion、4视口/玻璃/歌词滚动跟随seek/按钮等。
3. 软件测试新增 current+next 完整可见、partial previous 不显示、音频柱实际绘制边界居中断言，也通过。
4. D3D11 GPU 测试已跑一次：所有动画回归、mask、ripple通过，随后失败在新增“3条完整双语歌词同时可见”的断言。数据：51.44px一条，区域134.17px，三条本来放不下。已修正为检测current+next完整、previous部分隐藏；**GPU 最终版尚未重跑**。
5. 原测试 assert lyric height>=78u 是过时固定高度，已经改为38u<=height<78u。
6. `test-g71-qml.py <source> --album-description-only` **软件模式4种尺寸通过**：1400x900、960x540、960x720、1920x1080，表头/行列一致、album portrait、长短介绍/真实wheel/关闭。
7. 此脚本原来 qsb/rcc 硬编码 Linux `/root/.local/bin`，已改从 PySide6 包路径找 exe；删除旧“album heat必须恰好在artist和heart中心中点”的审美假设，保留不重叠和列对齐验证。
8. **没有本地 C++ 编译器/完整Qt SDK**：where clang++/g++/cmake都没找到，VS2022不存在；WSL未安装发行版。Native C++ 仍需安排可信验证（CI，或另装工具但需衡量）；不要说已通过。
9. 没做真实登录账号接口速度测量、真实音频播放端到端帧耗时测量。

## 环境、工具和临时目录

工作区：`C:/Users/Administrator.DESKTOP-OBJIDBO/Desktop/Codex-Test/smtc-cover-fix`

系统 python 是商店 stub；可用：

- `%TEMP%/rhine-motion-qa/venv/Scripts/python.exe`：PySide6 6.10.1、PyYAML。
- Bundled Python：`C:/Users/Administrator.DESKTOP-OBJIDBO/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`。
- Node：`E:/New Folder/node.exe`（where node可找到）。

临时 source：

- `%TEMP%/rhine-motion-qa/upstream`：**仅原版LiquidGlass.qml、shader、font等旧QML测试依赖，不是完整upstream**。
- `%TEMP%/rhine-motion-qa/generated`：通过GitHub fetch_file取的134个固定上游源文件，git init后应用G53+apply-maintained+G98初版，**不是完整可编译工程**，有 .git，无基线提交。
- generated 包括所有 Qt/src cpp/h、主要 Qt/tests cpp、MusicBridge/client、worker、Main.qml、CMake 和 scripts cjs。
- 重建 generated 应先还原基线所需原始文件再apply，不能重复在已应用tree上跑整个apply-maintained。
- 下载 codeload ZIP 两次超时，45秒版约1.3MB、300秒版约21MB，都不是完整ZIP。`upstream.zip/source.zip/full-source.zip`不要当完整包使用。
- raw.githubusercontent curl 也 reset，**GitHub connector fetch_file 已成功**，不要反复等大ZIP。
- GitHub fetch工具 schema可通过 functions.exec ALL_TOOLS description 发现。

测试示例（PowerShell，各 env 必须本次命令指定）：

```powershell
$env:PYTHONUTF8='1'
$env:RHINE_TEST_SOURCE="$env:TEMP/rhine-motion-qa/upstream"
$env:RHINE_TEST_OUTPUT="$env:TEMP/rhine-motion-qa/g98-software"
$env:QT_QPA_PLATFORM='offscreen'
$env:QT_QUICK_BACKEND='software'
& "$env:TEMP/rhine-motion-qa/venv/Scripts/python.exe" scripts/test-g86-qml.py
```

GPU用 Windows platform（offscreen是黑图），basic render loop（threaded Python会卡）：

```powershell
$env:QT_QPA_PLATFORM='windows';$env:QT_QUICK_BACKEND='rhi'
$env:QSG_RHI_BACKEND='d3d11';$env:QSG_RHI_PREFER_SOFTWARE_RENDERER='0'
$env:QSG_RENDER_LOOP='basic'
$env:RHINE_TEST_OUTPUT="$env:TEMP/rhine-motion-qa/g98-gpu"
```

GPU RTX3080Ti，屏幕DPR=2，像素探针需乘DPR。

## 继续顺序与必须处理的问题

1. 审查心动恢复语义、边界：原列表最后一首、队列空、当前推荐不在原列表、pending退出、反复开关、新选歌单、漫游进入退出、stop、手动删除/清空队列。
   - 当前 m_heartResumeIndex 在 next 中 clamp(seed+direction)，最后一首会重播末尾，需按顺序播放结束语义决定处理。
   - 当前 current 不在queue时 index=-1：检查队列UI和其它读取 player.index 的地方，避免负索引或错误标记。
   - clearUpcoming/remove 尚未调整 resumeIndex，检查用户在退出后编辑队列的行为。
2. 让最新版enable-g98从基线完整应用一次，验证所有anchor包括新UiChecks。不要只验证初版。
3. **scripts/verify-build-source.py 固定保护哈希会因G98修改 MusicPlayer.cpp/.h、NativeHudPlayer.cpp、NativeHudController.cpp 而失败**。必须在审查最终生成代码后更新这些确切哈希，保留原版Glass和LyricsReading保护。不要直接删校验。
4. `scripts/test-g70-roam.py` 抽取的play/stop会引用G98字段，fixture已补字段，尚未跑C++。
5. `scripts/test-g86-model.py` 已加 QtConcurrent include/link、即时wiki fixture，尚未编译；async pixels完成可能需要waitFor而非仅固定80ms。
6. `maintained/G88-ui-checks.cppfrag` 原生UI测试可能还有旧歌词高度/坐标假设，搜78、pivot、歌词等更新真正过时部分，保留有效回归。
7. 调查数据加载剩余内容：当前只warm likes+wiki0ms+empty cache；不要把它当作整个歌单加载慢的完整修复。
8. GPU最终回归、唱头近景和完整摆动目检；目前安全测试只用沿shaft采样+固定margin，10%头部几何应再核对。
9. 检查播放栏新间距实际绘制/点击区域，含漫游图标，宽窄窗口。更广泛UI目检尚未做完。
10. 记录性能优化的实际范围，避免承诺完全零卡顿。
11. 完成 Python/YAML/embedded patches 校验、git diff --check、相关JS测试、native测试。CI标签/ZIP/artifact仍G97，准备构建时改G98（不要触碰base64）。
12. 写G98说明、提交推送到现有branch（用户之前授权提交/构建工作流），观察CI，失败继续修；未全部完成前别报告本轮已完成。

## 已告知用户的口径

- 本地弹出的窗口是验证中版本，不是最终版。
- 唱头约10%放大+轻微上移；用户再次提醒卡顿，仍需继续。
- 录屏可补充，但不要求用户为了录屏排查VS Code；我们先独立调查。
- 上下文压缩可能丢掉临时推理细节；已保存代码不会被撤销；本文用于可靠交接。不要保证完美记忆。
