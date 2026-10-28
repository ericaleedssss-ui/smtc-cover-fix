"""G75: source-aware return labels and identity-preserving card handoff."""
from pathlib import Path

def edit(name,old,new):
    p=Path(name);s=p.read_text(encoding='utf-8')
    if s.count(old)!=1:raise RuntimeError(f'G75 anchor changed: {name}: {old[:80]}')
    p.write_text(s.replace(old,new,1),encoding='utf-8')

edit('Qt/src/NativeHud.h','    void rememberPage();','    QString navigationSourceName() const;\n    void rememberPage();')
edit('Qt/src/NativeHud.cpp','            {"focusAction", focusAction}', '            {"returnSource", navigationSourceName()},\n            {"focusAction", focusAction}')
helper='''QString NativeHud::navigationSourceName() const {
    const auto folder=m_music->directory;
    const auto key=folder&&m_music->directoryInfo?folder->item["key"].toString():m_music->current["key"].toString();
    const auto profileName=[this]{return profileFilter=="collected"?QString("我的收藏"):profileFilter=="created"?QString("我的歌单"):QString("个人主页");};
    if(!m_viewBack.isEmpty()&&m_viewBack.last().target==key&&m_viewBack.last().account==m_music->accountGeneration()){
        const auto &source=m_viewBack.last();
        if(source.modal=="search")return "搜索结果";
        if(source.modal=="discover"){
            const auto section=m_music->discover->tab;
            return section=="charts"?"排行榜":section=="daily"?"每日推荐":section=="albums"?"新专辑":"主页";
        }
        if(source.modal=="profile")return profileName();
        if(source.modal=="collection")return "我的收藏";
        if(source.mode=="detail"&&source.item["kind"]=="song")return source.item["title"].toString();
        if(source.directory&&source.directoryInfo)return source.directory->item["title"].toString();
        if(source.lane==3||source.lane==4)return "我的收藏";
        if(source.lane==2)return "我的歌单";
        return "主页";
    }
    if(profileNavigated&&!m_profileItem.isEmpty()&&key==m_profileItem)return profileName();
    if(folder){
        if(folder->parentSongDetails)return folder->parentItem["title"].toString();
        if(folder->parent&&folder->parentInfo)return folder->parent->item["title"].toString();
        if(folder->parentLane==3||folder->parentLane==4)return "我的收藏";
        if(folder->parentLane==2)return "我的歌单";
    }
    return "主页";
}
'''
edit('Qt/src/NativeHud.cpp','void NativeHud::brand() {',helper+'\nvoid NativeHud::brand() {')
edit('Qt/src/NativeHud.cpp','    text("RHINE / 音乐资料库", 100, 59, 14, "demibold", .4);','''    text("RHINE / 音乐资料库", 100, 59, 14, "demibold", .4);
    limited(navigationSourceName(),100,80,11,450,"regular");''')
# Render the subtitle at lower contrast without introducing a panel.
edit('Qt/src/NativeHud.cpp','    limited(navigationSourceName(),100,80,11,450,"regular");','''    save();alpha(.58);limited(navigationSourceName(),100,80,11,450,"regular");restore();''')
edit('Qt/src/NativeHudMusic.cpp','''        if(next&&next!=previous){
''','''        if(next&&next!=previous){
            if(profileNavigated&&m_profileItem==key)m_profileItem=item["key"].toString();
''')
edit('Qt/src/NativeHudProfile.cpp','''!m_profileItem.isEmpty() && m_music->current["key"] == m_profileItem''','''!m_profileItem.isEmpty() && (m_music->current["key"] == m_profileItem ||
        (m_music->directory && (m_music->directoryInfo || m_music->current.isEmpty()) && m_music->directory->item["key"] == m_profileItem))''')
print('G75: lightweight return source and original profile destination retained across record turns.')
