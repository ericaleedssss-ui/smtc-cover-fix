# RHINE MUSIC DATABASE

私人音乐播放器项目，使用 C++ / Qt Quick，音乐服务桥接使用 Node.js。

## 下载运行

在 [Releases](https://github.com/ericaleedssss-ui/smtc-cover-fix/releases) 下载最新 Windows x64 程序包，完整解压后运行 `RHINE MUSIC DATABASE.exe`。请保留同目录的 DLL、插件和 `resources`，不要只复制 EXE。

程序包不包含开发者账号、登录凭据、个人数据或测试用 EXE。发布页同时提供对应源码与 SHA-256 校验文件。

## 当前源码

完整应用位于 [`app/`](app/)，包括 C++、QML、Shader、资源、依赖锁文件、测试及打包脚本。仓库已用当前应用替换旧补丁工程，旧 `maintained/`、`patches/`、设计试稿和迁移开发文件不再作为当前源码分发。

2026-11-09 程序包使用已经验证的当前 Release 程序。本次上传没有重新设计界面；资料库使用二维浅色背景，保留玻璃、唱片和唱臂。选歌/待播界面按可见行读取队列，详情转场结束后释放不再使用的遮罩离屏层。全场景低于 200MB、稳定 60/120FPS 和长期播放内存增长仍未完成验证。

## Windows 构建

需要 Qt 6.12.0 / MSVC 2022 x64（ShaderTools、Multimedia 和匹配的私有头文件）、Windows SDK、Node 22.14.0、Python 3、CMake ≥3.24 和 Ninja。将工具加入 PATH，并配置 Qt 路径；在 x64 Developer PowerShell 中：

```powershell
cd app
$env:RHINE_VERSION = 'v1.2.0'
$env:RHINE_BUILD_TYPE = 'Release'
$env:QT_ROOT = 'C:/Qt/6.12.0/msvc2022_64'
$env:RHINE_NODE_BINARY = 'C:/Tools/node-v22.14.0-win-x64/node.exe'
$env:RHINE_NODE_LICENSE = 'C:/Tools/node-v22.14.0-win-x64/LICENSE'
npm ci
npm run build
npm test
npm run share
```

Node 运行时必须与其 LICENSE 配对。构建、部署与打包逻辑均在 `app/scripts/`；其他平台说明见 [`app/README.md`](app/README.md)。此发布仅提供 Windows x64，未声明其他平台已验证。

## 许可与参考

应用许可与第三方来源见 [`app/LICENSE`](app/LICENSE)、[`app/NOTICE`](app/NOTICE)、[`app/licenses/`](app/licenses/) 及各依赖声明。Cloudy 参考源码和许可证保留在 `app/vendor/` 与 `app/licenses/cloudy/`。分发源码时请保留这些文件。
