"""G77: account-scoped real messages and a bounded, readable frosted drawer."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
def edit(file,old,new):
 p=Path(file);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(file,old);p.write_text(s.replace(old,new),encoding='utf-8')
for file in ['Qt/src/MessageCenter.h','Qt/src/MessageCenter.cpp','Qt/qml/MessageDrawer.qml']:
 shutil.copyfile(root/'maintained'/file,file)
edit('CMakeLists.txt','    Qt/src/PlaylistMagazine.cpp','    Qt/src/MessageCenter.cpp\n    Qt/src/MessageCenter.h\n    Qt/src/PlaylistMagazine.cpp')
edit('Qt/CMakeLists.txt','set_source_files_properties(qml/Main.qml','set_source_files_properties(qml/MessageDrawer.qml PROPERTIES QT_RESOURCE_ALIAS MessageDrawer.qml)\nset_source_files_properties(qml/Main.qml')
edit('Qt/CMakeLists.txt','    qml/Main.qml\n','    qml/Main.qml\n    qml/MessageDrawer.qml\n')
edit('Qt/src/Engine.h','#include "PlaylistMagazine.h"','#include "PlaylistMagazine.h"\n#include "MessageCenter.h"')
edit('Qt/src/Engine.h','    Q_PROPERTY(QObject *magazine READ magazine CONSTANT)','    Q_PROPERTY(QObject *messages READ messages CONSTANT)\n    Q_PROPERTY(QObject *magazine READ magazine CONSTANT)')
edit('Qt/src/Engine.h','    QObject *magazine() const','    QObject *messages() const {return m_messages;}\n    QObject *magazine() const')
edit('Qt/src/Engine.h','    PlaylistMagazine *m_magazine = nullptr;','    PlaylistMagazine *m_magazine = nullptr;\n    MessageCenter *m_messages = nullptr;')
edit('Qt/src/Engine.cpp','    m_magazine = new PlaylistMagazine','    m_messages = new MessageCenter(&app->music,this);\n    connect(m_messages,&MessageCenter::navigate,this,&Engine::action);\n    m_magazine = new PlaylistMagazine')
edit('Qt/src/Engine.cpp','    delete m_magazine; m_magazine=nullptr;','    delete m_messages; m_messages=nullptr;\n    delete m_magazine; m_magazine=nullptr;')
# G71 copies this file before this installer; integrate only the existing inbox and Escape hook.
p=Path('Qt/qml/GlobalTools.qml');s=p.read_text();s=s.replace('function dismiss(){','function dismiss(){if(inbox.dismiss())return true;')
s=s.replace('Tool {objectName:"globalInbox";iconName:"message";label:"私信 · 尚未启用";available:false}', '''Tool {objectName:"globalInbox";iconName:"message";label:"消息中心";onInvoked:inbox.open()
            Rectangle {anchors.right:parent.right;y:0;width:7*tools.u;height:width;radius:width/2;color:"#c95454";visible:(rhine.messages.state.counts||[]).some(n=>Number(n)>0)}
        }''')
s=s.replace('    Controls.Menu {','    MessageDrawer {id:inbox;controller:rhine.messages;sceneBackground:tools.background;dark:!!rhine.state.dark;unit:tools.u}\n    Controls.Menu {',1)
p.write_text(s,encoding='utf-8')
edit('MusicBridge/worker.cjs',"const routes = Object.freeze({", """const routes = Object.freeze({
    '/pl/count': 'pl_count',
    '/msg/private': 'msg_private',
    '/msg/comments': 'msg_comments',
    '/msg/forwards': 'msg_forwards',
    '/msg/notices': 'msg_notices',
    '/msg/private/history': 'msg_private_history',
    '/send/text': 'send_text',""")
print('G77 real message controller, existing inbox and frosted drawer installed.')

fragment=(root/'maintained/G77-ui-checks.cppfrag').read_text(encoding='utf-8')
edit('Qt/tests/UiChecks.cpp','            clickVisual(findVisual(window->contentItem(),"playlistSearch"));',fragment+'            clickVisual(findVisual(window->contentItem(),"playlistSearch"));')
edit('Qt/tests/fixtures/bridge-http.cjs','    if (!/music\\.163\\.com|y\\.qq\\.com/.test(destination)) {',"""    if (/music\\.163\\.com\\/(?:weapi|eapi|api)\\/(?:msg\\/|pl\\/count|forwards\\/get|v1\\/user\\/comments)/.test(destination)) {
        const user = {userId:7,nickname:'G77 protocol fixture'};
        let data = {code:200};
        if(destination.includes('/pl/count'))Object.assign(data,{msg:505,comment:2,forward:1,notice:0});
        else if(destination.includes('/msg/private/users'))data.msgs=[{fromUser:user,lastMsg:JSON.stringify({msg:'fixture'}),newMsgCount:63}];
        else if(destination.includes('/msg/private/history'))data.msgs=[{id:1,fromUser:user,msg:JSON.stringify({msg:'history'}),time:1000}];
        else if(destination.includes('/msg/notices'))data.notices=[];
        else if(destination.includes('/forwards/get'))data.forwards=[];
        else if(destination.includes('/user/comments/'))data.comments=[];
        return {status:200,data,headers:{},config:settings};
    }
    if (!/music\\.163\\.com|y\\.qq\\.com/.test(destination)) {""")
edit('scripts/check-packaged-bridge.cjs',"        const search = await request('search', '/search', {", """        for(const [route,key] of [['/pl/count','msg'],['/msg/private','msgs'],['/msg/comments','comments'],['/msg/forwards','forwards'],['/msg/notices','notices'],['/msg/private/history','msgs']]) {
            const result=await request('g77-'+route,route,{uid:'42',limit:30},{MUSIC_U:'fixture-account'});
            assert.equal(result.body.code,200);assert(Object.hasOwn(result.body,key));
        }
        const sent=await request('g77-send','/send/text',{user_ids:'7',msg:'G77 offline message'},{MUSIC_U:'fixture-account'});
        assert.equal(sent.body.code,200);
        const search = await request('search', '/search', {""")
