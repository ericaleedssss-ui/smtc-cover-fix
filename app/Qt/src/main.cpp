#include "AppIdentity.h"
#include "AppStorage.h"
#include "Engine.h"
#include "StartupMemory.h"
#include "ArtworkNetwork.h"
#include "FrameProfiler.h"
#include "Hud.h"
#include <QDir>
#include <QFileInfo>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QLoggingCategory>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickGraphicsConfiguration>
#include <QQuickWindow>
#include <QScreen>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QCryptographicHash>
#include <QTimer>
#include <cstdio>
#include <cstring>
#include "../tests/CollectionPerformanceProbe.h"
#if defined(_MSC_VER) && defined(_DEBUG)
#include <crtdbg.h>
#include <process.h>
static int __cdecl reportQaCrtFailure(int type, char *message, int *) {
    if(type==_CRT_ASSERT||type==_CRT_ERROR) {
        std::fprintf(stderr,"QA Debug runtime failure: %s\n",message);
        std::fflush(stderr);
        _exit(86);
    }
    return FALSE;
}
#endif
int makeIcon(const QString &directory);
int runFrostedChecks(Engine &backend, QQuickWindow *window, const QString &output);
int runUiChecks(Engine &backend, QQuickWindow *window, const QString &output, FrameProfiler &profiler);
#ifdef Q_OS_WIN
void initializeWindowsGraphics();
#endif
/**
 * 建立应用身份、Qt 引擎和原生窗口。
 * 离线测试与正式播放沿用同一入口，资源只从独立应用读取。
 */
int main(int argc, char **argv) {
#if defined(_MSC_VER) && defined(_DEBUG)
    if(qEnvironmentVariableIsSet("RHINE_QA_PASSIVE_PROBE")||qEnvironmentVariableIsSet("RHINE_QA_CRT_REPORT"))
        _CrtSetReportHook(reportQaCrtFailure);
#endif
    QElapsedTimer startupClock;
    startupClock.start();
#ifdef Q_OS_WIN
    const auto storageError = AppStorage::initializePortable(AppStorage::executableDirectory());
    if (!storageError.isEmpty()) {
        std::fprintf(stderr, "%s\n", storageError.toUtf8().constData());
        return 1;
    }
#endif
    // 两个平台都明确使用 FFmpeg，设备切换和重连由播放器独立处理。
    // 必须在 Qt 初始化多媒体前选择后端，显式环境变量仍可用于兼容性对照。
    if (qEnvironmentVariableIsEmpty("QT_MEDIA_BACKEND")) {
        qputenv("QT_MEDIA_BACKEND", "ffmpeg");
    }
    if(PipelineDiagnostics::enabled())qInstallMessageHandler([](QtMsgType type,const QMessageLogContext &context,const QString &message){
        const auto text=qFormatLogMessage(type,context,message).toUtf8();std::fprintf(stderr,"%s\n",text.constData());std::fflush(stderr);
    });
    // Windows GUI 子系统默认可能将 Qt 日志送到调试器；测试必须写入 CTest 的标准错误管道。
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--self-test") == 0 || std::strcmp(argv[i], "--ui-self-test") == 0 ||
            std::strcmp(argv[i], "--frosted-self-test") == 0) {
            qInstallMessageHandler(
                [](QtMsgType type, const QMessageLogContext &context, const QString &message) {
                    const auto text = qFormatLogMessage(type, context, message).toUtf8();
                    std::fprintf(stderr, "%s\n", text.constData());
                    std::fflush(stderr);
                });
            break;
        }
    }
    QLoggingCategory::setFilterRules("qt.qml.usedbeforedeclared=false");
#ifdef Q_OS_MACOS
    // Qt 需在创建 QGuiApplication 前找到包内平台插件；某些 kit 会忽略资源目录里的 qt.conf。
    const QDir bundledPlugins(QFileInfo(QString::fromLocal8Bit(argv[0])).absolutePath() + "/../PlugIns");
    if (bundledPlugins.exists("platforms/libqcocoa.dylib")) {
        qputenv("QT_PLUGIN_PATH", bundledPlugins.absolutePath().toUtf8());
    }
#endif
#ifdef Q_OS_WIN
    startupMemory("graphics-probe-begin");
    initializeWindowsGraphics();
    startupMemory("graphics-probe-ready");
#endif
    QGuiApplication application(argc, argv);
    startupMemory("gui-application-ready");
    application.setWindowIcon(QIcon(":/icons/icon-256.png"));
    QCoreApplication::setApplicationVersion(AppUpdater::currentVersion());
    QCoreApplication::setOrganizationName(AppIdentity::Organization);
    QCoreApplication::setOrganizationDomain(AppIdentity::Id);
    QCoreApplication::setApplicationName(AppIdentity::Id);
    QGuiApplication::setApplicationDisplayName(AppIdentity::DisplayName);
    const auto args = application.arguments();
    if (args.contains("--make-icon")) {
        return makeIcon(args.value(args.indexOf("--make-icon") + 1));
    }
    QString root = qEnvironmentVariable("RHINE_RESOURCES");
    if (root.isEmpty()) {
        // macOS 使用 Resources ；其他平台使用 resources
        const auto base = QCoreApplication::applicationDirPath();
#ifdef Q_OS_MACOS
        const QStringList candidates{base + "/../Resources"};
#else
        const QStringList candidates{base + "/resources", base + "/../resources"};
#endif
        for (const auto &candidate : candidates) {
            if (QFileInfo(candidate + "/slots.json").exists()) {
                root = QDir(candidate).absolutePath();
                break;
            }
        }
        if (root.isEmpty()) {
            root = QDir::currentPath() + "/output/resources";
        }
    }
    const bool test = args.contains("--self-test");
    const bool visual = args.contains("--visual-fixtures");
    const bool offline = test || visual || args.contains("--ui-self-test") || args.contains("--frosted-self-test") ||
                         args.contains("--offline") ||
                         qEnvironmentVariableIntValue("RHINE_OFFLINE") == 1;
    Engine backend(root, offline);
    startupMemory("engine-ready");
    if (test) {
        return backend.selfTest();
    }
    if (visual) {
        const int i = args.indexOf("--visual-fixtures");
        return backend.renderFixtures(args.value(i + 1), args.value(i + 2));
    }
    QString profilePath;
    if (args.contains("--frame-profile")) {
        profilePath = args.value(args.indexOf("--frame-profile") + 1);
        if (profilePath.isEmpty() || profilePath.startsWith("--")) {
            qWarning() << "--frame-profile requires an output CSV path";
            return 1;
        }
    }
    FrameProfiler profiler(&backend, profilePath);
    QObject::connect(&backend, &Engine::performanceRequested, &profiler, &FrameProfiler::toggleVisible);
    backend.start();
    qmlRegisterType<Hud>("Rhine.Native", 1, 0, "Hud");
    qmlRegisterUncreatableType<Engine>("Rhine.Native", 1, 0, "Engine", "Provided by application");
    ArtworkNetworkFactory artworkNetwork;
    CollectionArtworkBlock collectionArtworkBlock;
    QQmlApplicationEngine engine;
    if(qEnvironmentVariableIntValue("RHINE_QA_COLLECTION_NO_COVERS")==1)
        engine.addUrlInterceptor(&collectionArtworkBlock);
    engine.setNetworkAccessManagerFactory(&artworkNetwork);
    // 无边框
    if (qEnvironmentVariableIntValue("RHINE_FRAMELESS_PREVIEW") == 1) {
        engine.setInitialProperties({{"windowsFrameless", true}});
    }
#ifdef Q_OS_WIN
    // 创建窗口时先保持隐藏，配置管线缓存后再显示，避免首次渲染写到系统缓存。
    engine.setInitialProperties({{"visible", false}, {"windowsFrameless", true}});
#endif
    const auto fontId = QFontDatabase::addApplicationFont(root + "/RhineMiSans-regular.otf");
    const auto families = QFontDatabase::applicationFontFamilies(fontId);
    backend.initializeUiFont(families.isEmpty() ? QString("sans-serif") : families.first());
    startupMemory("ui-fonts-ready");
    engine.rootContext()->setContextProperty("rhineFontFamily", backend.uiFont());
    QObject::connect(&backend,&Engine::uiFontChanged,&engine,[&]{engine.rootContext()->setContextProperty("rhineFontFamily",backend.uiFont());});
    engine.rootContext()->setContextProperty("rhine", &backend);
    engine.rootContext()->setContextProperty("rhinePipelineLegacy",PipelineDiagnostics::enabled()&&qEnvironmentVariableIntValue("RHINE_QA_PIPELINE_LEGACY")==1);
    engine.rootContext()->setContextProperty("rhineCollectionBaseline",
        qEnvironmentVariableIsSet("RHINE_QA_COLLECTION_PROBE")&&qEnvironmentVariableIntValue("RHINE_QA_COLLECTION_ORIGINAL")==1);
    // Temporary comparison escape hatch: launch with RHINE_GLASS_ORIGINAL=1.
    engine.rootContext()->setContextProperty("rhineRefractiveGlass",
                                             qEnvironmentVariableIntValue("RHINE_GLASS_ORIGINAL") != 1);
    engine.rootContext()->setContextProperty("profiler", &profiler);
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &application,
        [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("RhineMusic", "Main");
    startupMemory("qml-ready");
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }
    auto window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
#ifdef Q_OS_WIN
    QQuickGraphicsConfiguration graphics;
    if(PipelineDiagnostics::enabled())graphics.setTimestamps(true);
    graphics.setAutomaticPipelineCache(false);
    const auto pipelineCache = AppStorage::cacheDirectory() + "/shaders/pipeline.cache";
    if (QFileInfo::exists(pipelineCache)) {
        graphics.setPipelineCacheLoadFile(pipelineCache);
    }
    graphics.setPipelineCacheSaveFile(pipelineCache);
    window->setGraphicsConfiguration(graphics);
    window->show();
#endif
    backend.setWindow(window);
    if (!offline && RHINE_RELEASE_BUILD) {
        QTimer::singleShot(8000, &backend.host, [&backend] {
            if (backend.host.preference("auto-update") != "off") {
                backend.host.updater.check();
            }
        });
    }
    window->installEventFilter(&backend);
    profiler.attach(window);
    const auto collectionOutput=qEnvironmentVariable("RHINE_QA_COLLECTION_PROBE");
    if(!collectionOutput.isEmpty())new CollectionPerformanceProbe(backend,window,profiler,collectionOutput);
    // Opt-in passive benchmark: normal startup, saved settings and real bridge.
    // No fixture, navigation, account action or change to normal launches.
    const auto passiveOutput=qEnvironmentVariable("RHINE_QA_PASSIVE_PROBE");
    if(!passiveOutput.isEmpty()&&collectionOutput.isEmpty()) {
        QDir().mkpath(passiveOutput);
        const auto screenName=qEnvironmentVariable("RHINE_QA_SCREEN");
        for(auto *screen:QGuiApplication::screens())if(screen->name()==screenName){window->setScreen(screen);window->setPosition(screen->availableGeometry().topLeft()+QPoint(40,40));break;}
        profiler.setReportDirectory(passiveOutput);
        profiler.startRecording();
        QTimer::singleShot(5000,&application,[&,passiveOutput]{
            QJsonArray images;
            for(auto *object:window->findChildren<QObject *>()) {
                const auto sourceSize=object->property("sourceSize");
                if(!sourceSize.isValid())continue;
                const auto source=object->property("source").toString();
                QStringList ancestry;
                for(auto *parent=object;parent&&ancestry.size()<6;parent=parent->parent())
                    ancestry<<QString::fromLatin1(parent->metaObject()->className())+":"+parent->objectName();
                const auto size=sourceSize.toSize();
                images.append(QJsonObject{{"ancestry",ancestry.join(" / ")},
                    {"source_sha256",QString::fromLatin1(QCryptographicHash::hash(source.toUtf8(),QCryptographicHash::Sha256).toHex())},
                    {"source_width",size.width()},{"source_height",size.height()},
                    {"width",object->property("width").toDouble()},{"height",object->property("height").toDouble()}});
            }
            QFile file(passiveOutput+"/image-sizes.json");if(file.open(QIODevice::WriteOnly))file.write(QJsonDocument(images).toJson());
        });
        QObject::connect(window,&QQuickWindow::frameSwapped,&application,[&,passiveOutput,first=true]() mutable {
            if(!first)return;first=false;
            QFile file(passiveOutput+"/startup.json");if(file.open(QIODevice::WriteOnly))file.write(QJsonDocument(QJsonObject{{"first_present_notification_ms",startupClock.elapsed()},{"logical_width",window->width()},{"logical_height",window->height()},{"dpr",window->devicePixelRatio()}}).toJson());
        },Qt::QueuedConnection);
        const int milliseconds=qMax(10000,qEnvironmentVariableIntValue("RHINE_QA_PASSIVE_MS"));
        QTimer::singleShot(milliseconds,&application,[&,passiveOutput]{window->grabWindow().save(passiveOutput+"/window.png");profiler.saveRecording();application.quit();});
    }
    // Pause background animation while retaining the Qt Quick glass resources.
    window->setPersistentSceneGraph(true);
    window->setPersistentGraphics(true);
    if (args.contains("--frosted-self-test")) {
        return runFrostedChecks(backend, window,
                               args.value(args.indexOf("--frosted-self-test") + 1));
    }
    if (args.contains("--ui-self-test")) {
        return runUiChecks(backend, qobject_cast<QQuickWindow *>(engine.rootObjects().first()),
                           args.value(args.indexOf("--ui-self-test") + 1), profiler);
    }
    if (args.contains("--capture")) {
        const auto index = args.indexOf("--capture");
        const auto path = args.value(index + 1);
        if (path.isEmpty()) {
            return 1;
        }
        auto poll = new QTimer(&backend);
        poll->setInterval(200);
        bool *reviewed = new bool(false);
        QObject::connect(poll, &QTimer::timeout, &backend, [&, path, poll, reviewed] {
            if (!backend.ready()) {
                return;
            }
            if (!*reviewed) {
                *reviewed = true;
                backend.scene.review("archive");
                return;
            }
            backend.step(50);
            if (backend.frame().isEmpty()) {
                return;
            }
            poll->stop();
            delete reviewed;
            backend.snapshot(path);
            auto window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
            if (window) {
                window->grabWindow().save(path + "/qt-window.png");
            }
            application.quit();
        });
        poll->start();
    }
    return application.exec();
}
