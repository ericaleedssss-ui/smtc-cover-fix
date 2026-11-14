# 从旧版 Rhine 导入

在同一 Windows 用户下，用 PowerShell 启动新版本，将两个示例路径替换为你指定的旧数据和旧下载目录。验收时请使用真实数据的副本。

```powershell
& 'H:\Development\Rhine\rhine-go-artifacts\M2\windows-amd64\RHINE.exe' --import-rhine 'D:\旧版数据副本\data' --import-rhine-downloads 'D:\旧版下载副本\RhineMusic'
```

下载目录参数可省略。导入在新版还没有 `settings.json` 时执行。需要先退出已运行的 Go 版。新版的数据写入独立的 MyGo 数据目录，已有新版记录优先。旧目录、账号文件和下载音频均按只读方式访问。

| 旧版 | 新版 |
| --- | --- |
| `panel/theme`、`ui-font`、`motion` | 外观、可识别字体和动效，旧版 `reduced` 对应新版 `lite` |
| `panel/volume`、`quality`、`disc-rotation` | 音量、两版均支持的播放音质、播放栏唱片旋转 |
| `panel/lyric-scale`、`lyric-translation`、`stage-style`、`stage-sparks` | 歌词缩放、翻译、共用的律动样式、火花开关 |
| `panel/desktop-lyrics`、`desktop-lyrics-locked`、`desktop-lyrics-style`、`desktop-lyrics-scale` | 桌面歌词开关、锁定、共用样式和缩放 |
| `panel/search-history` | `settings.json` 中的搜索词 |
| `panel/play-history` | `history.json` 中的网易云歌曲，保留旧版顺序。旧记录没有播放时间 |
| `recent-bookmarks`、`weekly-score`、`weekly-score-quote`、`playlist-listens` | 保留可解析数据到 `rhine-listening.json`，供后续页面接入 |
| `account.dpapi` | 在原 Windows 用户下尝试迁移网易云登录到新版系统凭据存储。失效或无法解密时重新扫码。QQ、酷狗账号仍保存在旧版 |
| 显式指定的旧下载目录 | MP3 和 FLAC 通过现有扫描器加入 `downloads.json`，新版跳过自动补标签和删除。旧版没有持久化下载队列 |

旧版有些音质、Qt 窗口与外观参数、音效参数、本地库和缓存依赖旧版功能或格式。导入日志记录未识别的设置键，保留新版默认值。自动更新保持关闭。M4 以后才接入首页备忘等保留数据。当前下载扫描器只支持 MP3 和 FLAC，M4A、WAV 文件留在旧目录。
