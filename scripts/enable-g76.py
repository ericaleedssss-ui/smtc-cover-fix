"""G76: shared initial like state, verified subscriber counts and stable cover resources."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def edit(name,old,new):
 p=Path(name);s=p.read_text(encoding='utf-8')
 if s.count(old)!=1:raise RuntimeError(f'G76 anchor changed: {name}: {old[:85]}')
 p.write_text(s.replace(old,new,1),encoding='utf-8')
edit('Qt/src/MusicLibrary.h','    void like(QJsonObject value = {});','''    void ensureLikedIDs(Completion done = {});
    bool likedIDsLoading() const {return m_likedIDsAccount==m_accountGeneration&&m_likedIDsLoading;}
    QString likedIDsError() const {return m_likedIDsAccount==m_accountGeneration?m_likedIDsError:QString();}
    void like(QJsonObject value = {});''')
edit('Qt/src/MusicLibrary.h','    quint64 m_subscriptionGeneration = 0;','''    bool m_likedIDsLoading=false;
    quint64 m_likedIDsAccount=0;
    QString m_likedIDsError;
    QVector<Completion> m_likedIDWaiters;
    quint64 m_subscriptionGeneration = 0;''')
edit('Qt/src/MusicMutation.cpp','void MusicLibrary::like(QJsonObject value) {',(root/'maintained/G76-liked-ids.cppfrag').read_text(encoding='utf-8')+'\nvoid MusicLibrary::like(QJsonObject value) {')
p=Path('Qt/src/MusicMutation.cpp');s=p.read_text(encoding='utf-8');a=s.index('    if (!likedIDs) {',s.index('void MusicLibrary::like('));b=s.index('    // The complete server ID list',a)
s=s[:a]+'''    if (!likedIDs) {
        ensureLikedIDs([this,value](bool ok){if(ok)like(value);else {status=likedIDsError();changed();}});
        return;
    }
'''+s[b:];p.write_text(s,encoding='utf-8')
p=Path('Qt/src/MusicLibrary.cpp');s=p.read_text(encoding='utf-8');a=s.index('void MusicLibrary::loadLikedIDs(');b=s.index('\nvoid MusicLibrary::loadMoreSource(',a);method=s[a:b]
method=method.replace('                likedIDs = ids;\n','')
method=method.replace('                lists[1] = MusicData::unique(lists[1], MusicData::ordered(chunk, result.value.toArray()));','''                QJsonArray confirmed;
                for(const auto &v:MusicData::ordered(chunk,result.value.toArray()))
                    if(likedIDs&&MusicData::indexOf(*likedIDs,v.toObject()["id"])>=0)confirmed.append(v);
                lists[1] = MusicData::unique(lists[1], confirmed);''')
method=method.replace('totals[1] = int(ids.size());','totals[1] = int(likedIDs?likedIDs->size():ids.size());').replace('hasMore[1] = likedCursor < ids.size();','hasMore[1] = likedCursor < totals[1];')

a1=method.index('    } else {\n        api.call(',method.index('    if (likedIDs)'))
method=method[:a1]+'''    } else {
        ensureLikedIDs([this,lane,fetch,alive](bool ok){
            if(!alive())return;
            if(!ok){completePersonal(lane,likedIDsError());return;}
            fetch(*likedIDs);
        });
    }
}
'''
s=s[:a]+method+s[b:];p.write_text(s,encoding='utf-8')
print('G76: initial like queries, click toggles and personal-list paging share one authoritative ID request.')
