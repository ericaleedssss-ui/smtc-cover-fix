# 将应用的 QML 扫描限定在 Qt 源码目录，避免遍历部署包和 Node 依赖。 资源、平台依赖和打包钩子由根目录配置完成后再统一结束目标初始化。
qt_add_executable(RhineMusicDatabase WIN32 MACOSX_BUNDLE MANUAL_FINALIZATION ${RHINE_APP_SOURCES})
set_target_properties(RhineMusicDatabase PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")
set_source_files_properties(qml/DrawerFrost.qml PROPERTIES QT_RESOURCE_ALIAS DrawerFrost.qml)
set_source_files_properties(qml/DrawerInputGate.qml PROPERTIES QT_RESOURCE_ALIAS DrawerInputGate.qml)
set_source_files_properties(qml/ArtistMarquee.qml PROPERTIES QT_RESOURCE_ALIAS ArtistMarquee.qml)
set_source_files_properties(qml/ArchiveActionIcon.qml PROPERTIES QT_RESOURCE_ALIAS ArchiveActionIcon.qml)
set_source_files_properties(qml/ArchiveNavigator.qml PROPERTIES QT_RESOURCE_ALIAS ArchiveNavigator.qml)
set_source_files_properties(qml/NowPlayingShortcut.qml PROPERTIES QT_RESOURCE_ALIAS NowPlayingShortcut.qml)
set_source_files_properties(qml/PlayingBars.qml PROPERTIES QT_RESOURCE_ALIAS PlayingBars.qml)
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
set_source_files_properties(qml/DesktopLyricsPreferences.qml PROPERTIES QT_RESOURCE_ALIAS DesktopLyricsPreferences.qml)
set_source_files_properties(qml/LiquidGlass.qml PROPERTIES QT_RESOURCE_ALIAS LiquidGlass.qml)
set_source_files_properties(qml/PopupGlass.qml PROPERTIES QT_RESOURCE_ALIAS PopupGlass.qml)
set_source_files_properties(qml/UserProfile.qml PROPERTIES QT_RESOURCE_ALIAS UserProfile.qml)
set_source_files_properties(qml/ProfileArtwork.qml PROPERTIES QT_RESOURCE_ALIAS ProfileArtwork.qml)
set_source_files_properties(qml/ProfileTabs.qml PROPERTIES QT_RESOURCE_ALIAS ProfileTabs.qml)
set_source_files_properties(qml/InterfaceFonts.qml PROPERTIES QT_RESOURCE_ALIAS InterfaceFonts.qml)
set_source_files_properties(qml/SettingsPage.qml PROPERTIES QT_RESOURCE_ALIAS SettingsPage.qml)
set_source_files_properties(qml/SongDetailPage.qml PROPERTIES QT_RESOURCE_ALIAS SongDetailPage.qml)
set_source_files_properties(qml/SongComments.qml PROPERTIES QT_RESOURCE_ALIAS SongComments.qml)
set_source_files_properties(qml/LyricStage.qml PROPERTIES QT_RESOURCE_ALIAS LyricStage.qml)
set_source_files_properties(qml/StageLayout.js PROPERTIES QT_RESOURCE_ALIAS StageLayout.js)
set_source_files_properties(qml/ProgressSmoke.qml PROPERTIES QT_RESOURCE_ALIAS ProgressSmoke.qml)
set_source_files_properties(qml/VisualEffectsSettings.qml PROPERTIES QT_RESOURCE_ALIAS VisualEffectsSettings.qml)
set_source_files_properties(qml/SongWall.qml PROPERTIES QT_RESOURCE_ALIAS SongWall.qml)
set_source_files_properties(qml/SongQueue.qml PROPERTIES QT_RESOURCE_ALIAS SongQueue.qml)
set_source_files_properties(qml/LyricsReading.qml PROPERTIES QT_RESOURCE_ALIAS LyricsReading.qml)
set_source_files_properties(qml/SideNavigation.qml PROPERTIES QT_RESOURCE_ALIAS SideNavigation.qml)
set_source_files_properties(qml/PlayerTitleMarquee.qml PROPERTIES QT_RESOURCE_ALIAS PlayerTitleMarquee.qml)
set_source_files_properties(qml/PlayerQueueGlass.qml PROPERTIES QT_RESOURCE_ALIAS PlayerQueueGlass.qml)
set_source_files_properties(qml/DiscoverGlass.qml PROPERTIES QT_RESOURCE_ALIAS DiscoverGlass.qml)
set_source_files_properties(qml/RhineIcon.qml PROPERTIES QT_RESOURCE_ALIAS RhineIcon.qml)
set_source_files_properties(qml/GlobalTools.qml PROPERTIES QT_RESOURCE_ALIAS GlobalTools.qml)
set_source_files_properties(qml/MusicFolder.qml PROPERTIES QT_RESOURCE_ALIAS MusicFolder.qml)
set_source_files_properties(qml/RecordStack.qml PROPERTIES QT_RESOURCE_ALIAS RecordStack.qml)
set_source_files_properties(qml/SongContextMenu.qml PROPERTIES QT_RESOURCE_ALIAS SongContextMenu.qml)
set_source_files_properties(qml/SoundEffectsDialog.qml PROPERTIES QT_RESOURCE_ALIAS SoundEffectsDialog.qml)
set_source_files_properties(qml/GlassSeekThumb.qml PROPERTIES QT_RESOURCE_ALIAS GlassSeekThumb.qml)
set_source_files_properties(qml/SoftSeekTrack.qml PROPERTIES QT_RESOURCE_ALIAS SoftSeekTrack.qml)
set_source_files_properties(qml/PlaylistSearch.qml PROPERTIES QT_RESOURCE_ALIAS PlaylistSearch.qml)
set_source_files_properties(qml/SongHeart.qml PROPERTIES QT_RESOURCE_ALIAS SongHeart.qml)
set_source_files_properties(qml/PlaylistMagazine.qml PROPERTIES QT_RESOURCE_ALIAS PlaylistMagazine.qml)
set_source_files_properties(qml/PlaylistHoverGlass.qml PROPERTIES QT_RESOURCE_ALIAS PlaylistHoverGlass.qml)
set_source_files_properties(qml/RhineTheme.qml PROPERTIES QT_RESOURCE_ALIAS RhineTheme.qml QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/RhineColorPicker.qml PROPERTIES QT_RESOURCE_ALIAS RhineColorPicker.qml)
set_source_files_properties(qml/RhineButton.qml PROPERTIES QT_RESOURCE_ALIAS RhineButton.qml)
set_source_files_properties(qml/RhinePopup.qml PROPERTIES QT_RESOURCE_ALIAS RhinePopup.qml)
set_source_files_properties(qml/RhineDialog.qml PROPERTIES QT_RESOURCE_ALIAS RhineDialog.qml)
set_source_files_properties(qml/RhineMenu.qml PROPERTIES QT_RESOURCE_ALIAS RhineMenu.qml)
set_source_files_properties(qml/RhineMenuItem.qml PROPERTIES QT_RESOURCE_ALIAS RhineMenuItem.qml)
set_source_files_properties(qml/RhineComboBox.qml PROPERTIES QT_RESOURCE_ALIAS RhineComboBox.qml)
set_source_files_properties(qml/RhineToolTip.qml PROPERTIES QT_RESOURCE_ALIAS RhineToolTip.qml)
set_source_files_properties(qml/RhineContentMotion.qml PROPERTIES QT_RESOURCE_ALIAS RhineContentMotion.qml)
set_source_files_properties(qml/RhineSongActions.qml PROPERTIES QT_RESOURCE_ALIAS RhineSongActions.qml)
set_source_files_properties(qml/RhineCreditLine.qml PROPERTIES QT_RESOURCE_ALIAS RhineCreditLine.qml)
qt_add_qml_module(
    RhineMusicDatabase
    URI
    RhineMusic
    VERSION
    1.0
    OUTPUT_DIRECTORY
    "${CMAKE_BINARY_DIR}/RhineMusic"
    QML_FILES
    qml/RhineTheme.qml
    qml/RhineColorPicker.qml
    qml/RhineButton.qml
    qml/RhinePopup.qml
    qml/RhineDialog.qml
    qml/RhineMenu.qml
    qml/RhineMenuItem.qml
    qml/RhineComboBox.qml
    qml/RhineToolTip.qml
    qml/RhineContentMotion.qml
    qml/RhineSongActions.qml
    qml/RhineCreditLine.qml
    qml/Main.qml
    qml/ArtistMarquee.qml
    qml/ArchiveActionIcon.qml
    qml/ArchiveNavigator.qml
    qml/NowPlayingShortcut.qml
    qml/PlayingBars.qml
    qml/NowPlayingPanel.qml
    qml/RecordTonearm.qml
    qml/ArchiveReading.qml
    qml/PlaylistShowcase.qml
    qml/MessageDrawer.qml
    qml/DrawerFrost.qml
    qml/DrawerInputGate.qml
    qml/RhineIcon.qml
    qml/GlobalTools.qml
    qml/MusicFolder.qml
    qml/RecordStack.qml
    qml/SongContextMenu.qml
    qml/SoundEffectsDialog.qml
    qml/GlassSeekThumb.qml
    qml/SoftSeekTrack.qml
    qml/PlaylistSearch.qml
    qml/SongHeart.qml
    qml/PlaylistMagazine.qml
    qml/PlaylistHoverGlass.qml
    qml/UserProfile.qml
    qml/ProfileArtwork.qml
    qml/ProfileTabs.qml
    qml/InterfaceFonts.qml
    qml/SettingsPage.qml
    qml/SongDetailPage.qml
    qml/SongComments.qml
    qml/LyricStage.qml
    qml/StageLayout.js
    qml/ProgressSmoke.qml
    qml/VisualEffectsSettings.qml
    qml/SongWall.qml
    qml/SongQueue.qml
    qml/SideNavigation.qml
    qml/PlayerTitleMarquee.qml
    qml/PlayerQueueGlass.qml
    qml/DiscoverGlass.qml
    qml/LyricsReading.qml
    qml/LiquidGlass.qml
    qml/PopupGlass.qml
    qml/PerformancePanel.qml
    qml/CommentsPage.qml
    qml/ReadingText.qml
    qml/RecommendationsPage.qml
    qml/DesktopLyrics.qml
    qml/DesktopLyricsSettings.qml
    qml/DesktopLyricsPreferences.qml
    qml/WindowChrome.qml)
