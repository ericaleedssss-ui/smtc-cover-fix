# 将应用的 QML 扫描限定在 Qt 源码目录，避免遍历部署包和 Node 依赖。 资源、平台依赖和打包钩子由根目录配置完成后再统一结束目标初始化。
qt_add_executable(RhineMusicDatabase WIN32 MACOSX_BUNDLE MANUAL_FINALIZATION ${RHINE_APP_SOURCES})
set_target_properties(RhineMusicDatabase PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")
set_source_files_properties(qml/DrawerFrost.qml PROPERTIES QT_RESOURCE_ALIAS DrawerFrost.qml)
set_source_files_properties(qml/DrawerInputGate.qml PROPERTIES QT_RESOURCE_ALIAS DrawerInputGate.qml)
set_source_files_properties(qml/ArtistMarquee.qml PROPERTIES QT_RESOURCE_ALIAS ArtistMarquee.qml)
set_source_files_properties(qml/ArchiveActionIcon.qml PROPERTIES QT_RESOURCE_ALIAS ArchiveActionIcon.qml)
set_source_files_properties(qml/ArchiveNavigator.qml PROPERTIES QT_RESOURCE_ALIAS ArchiveNavigator.qml)
set_source_files_properties(qml/NowPlayingShortcut.qml PROPERTIES QT_RESOURCE_ALIAS NowPlayingShortcut.qml)
set_source_files_properties(qml/RecordTonearm.qml PROPERTIES QT_RESOURCE_ALIAS RecordTonearm.qml)
set_source_files_properties(qml/NowPlayingPanel.qml PROPERTIES QT_RESOURCE_ALIAS NowPlayingPanel.qml)
set_source_files_properties(qml/ArchiveReading.qml PROPERTIES QT_RESOURCE_ALIAS ArchiveReading.qml)
set_source_files_properties(qml/PlaylistShowcase.qml PROPERTIES QT_RESOURCE_ALIAS PlaylistShowcase.qml)
set_source_files_properties(qml/MessageDrawer.qml PROPERTIES QT_RESOURCE_ALIAS MessageDrawer.qml)
set_source_files_properties(qml/Main.qml PROPERTIES QT_RESOURCE_ALIAS Main.qml)
set_source_files_properties(qml/PerformancePanel.qml PROPERTIES QT_RESOURCE_ALIAS PerformancePanel.qml)
set_source_files_properties(qml/WindowChrome.qml PROPERTIES QT_RESOURCE_ALIAS WindowChrome.qml)
set_source_files_properties(qml/CommentsPage.qml PROPERTIES QT_RESOURCE_ALIAS CommentsPage.qml)
set_source_files_properties(qml/ReadingText.qml PROPERTIES QT_RESOURCE_ALIAS ReadingText.qml)
set_source_files_properties(qml/RecommendationsPage.qml PROPERTIES QT_RESOURCE_ALIAS RecommendationsPage.qml)
set_source_files_properties(qml/DesktopLyrics.qml PROPERTIES QT_RESOURCE_ALIAS DesktopLyrics.qml)
set_source_files_properties(qml/DesktopLyricsSettings.qml PROPERTIES QT_RESOURCE_ALIAS DesktopLyricsSettings.qml)
set_source_files_properties(qml/LiquidGlass.qml PROPERTIES QT_RESOURCE_ALIAS LiquidGlass.qml)
set_source_files_properties(qml/UserProfile.qml PROPERTIES QT_RESOURCE_ALIAS UserProfile.qml)
set_source_files_properties(qml/LyricsReading.qml PROPERTIES QT_RESOURCE_ALIAS LyricsReading.qml)
set_source_files_properties(qml/SideNavigation.qml PROPERTIES QT_RESOURCE_ALIAS SideNavigation.qml)
set_source_files_properties(qml/PlayerTitleMarquee.qml PROPERTIES QT_RESOURCE_ALIAS PlayerTitleMarquee.qml)
set_source_files_properties(qml/PlayerQueueGlass.qml PROPERTIES QT_RESOURCE_ALIAS PlayerQueueGlass.qml)
set_source_files_properties(qml/DiscoverGlass.qml PROPERTIES QT_RESOURCE_ALIAS DiscoverGlass.qml)
set_source_files_properties(qml/RhineIcon.qml PROPERTIES QT_RESOURCE_ALIAS RhineIcon.qml)
set_source_files_properties(qml/GlobalTools.qml PROPERTIES QT_RESOURCE_ALIAS GlobalTools.qml)
set_source_files_properties(qml/RecordStack.qml PROPERTIES QT_RESOURCE_ALIAS RecordStack.qml)
set_source_files_properties(qml/SongContextMenu.qml PROPERTIES QT_RESOURCE_ALIAS SongContextMenu.qml)
set_source_files_properties(qml/PlaylistSearch.qml PROPERTIES QT_RESOURCE_ALIAS PlaylistSearch.qml)
set_source_files_properties(qml/SongHeart.qml PROPERTIES QT_RESOURCE_ALIAS SongHeart.qml)
set_source_files_properties(qml/PlaylistMagazine.qml PROPERTIES QT_RESOURCE_ALIAS PlaylistMagazine.qml)
qt_add_qml_module(
    RhineMusicDatabase
    URI
    RhineMusic
    VERSION
    1.0
    OUTPUT_DIRECTORY
    "${CMAKE_BINARY_DIR}/RhineMusic"
    QML_FILES
    qml/Main.qml
    qml/ArtistMarquee.qml
    qml/ArchiveActionIcon.qml
    qml/ArchiveNavigator.qml
    qml/NowPlayingShortcut.qml
    qml/NowPlayingPanel.qml
    qml/RecordTonearm.qml
    qml/ArchiveReading.qml
    qml/PlaylistShowcase.qml
    qml/MessageDrawer.qml
    qml/DrawerFrost.qml
    qml/DrawerInputGate.qml
    qml/RhineIcon.qml
    qml/GlobalTools.qml
    qml/RecordStack.qml
    qml/SongContextMenu.qml
    qml/PlaylistSearch.qml
    qml/SongHeart.qml
    qml/PlaylistMagazine.qml
    qml/UserProfile.qml
    qml/SideNavigation.qml
    qml/PlayerTitleMarquee.qml
    qml/PlayerQueueGlass.qml
    qml/DiscoverGlass.qml
    qml/LyricsReading.qml
    qml/LiquidGlass.qml
    qml/PerformancePanel.qml
    qml/CommentsPage.qml
    qml/ReadingText.qml
    qml/RecommendationsPage.qml
    qml/DesktopLyrics.qml
    qml/DesktopLyricsSettings.qml
    qml/WindowChrome.qml)
