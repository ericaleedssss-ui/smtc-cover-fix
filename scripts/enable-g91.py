"""G91: production album portrait and existing magazine alignment/record refinements."""
from pathlib import Path
p=Path('Qt/tests/UiChecks.cpp');s=p.read_text()
old='''        if (route.endsWith("/detail")) {'''
new='''        if (route == "/artist/detail")return QJsonObject{{"code",200},{"data",QJsonObject{{"artist",QJsonObject{{"avatar",artworkURL}}}}}};
        if (route.endsWith("/detail")) {'''
assert s.count(old)==1;s=s.replace(old,new)
old='''            item["trackCount"] = 10;'''
new=old+'''
            if(item["kind"]=="album")item["artists"]=QJsonArray{QJsonObject{{"id","91001"},{"name","Actual test artist"}}};'''
assert s.count(old)==1;s=s.replace(old,new)
old='''          "G90 ordinary artist-album route renders the shared magazine and heat column");'''
new=old+'''
    {
        QElapsedTimer avatarWait;avatarWait.start();
        while(avatarWait.elapsed()<2000){auto *avatar=findVisual(window->contentItem(),"magazineArtistAvatar");if(avatar&&avatar->property("status").toInt()==1&&avatar->property("source").toUrl().toString().startsWith("data:image/png;base64,"))break;settle(30);}
        auto *avatar=findVisual(window->contentItem(),"magazineArtistAvatar");
        check(avatar&&avatar->isVisible()&&avatar->property("status").toInt()==1&&avatar->property("source").toUrl().toString().startsWith("data:image/png;base64,"),"G91 album artist portrait loads through actual API, Host cache and QML decoding");
    }'''
assert s.count(old)==1;s=s.replace(old,new);p.write_text(s)
print('G91: production album portrait integration QA installed.')
