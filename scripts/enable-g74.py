"""G74 magazine motion and scroll controls."""
from pathlib import Path

# The magazine uses a separate masked band for its fixed title and actions.
import shutil
root=Path(__file__).resolve().parents[1]
shutil.copyfile(root/"maintained/Qt/shaders/magazineEdgeFade.frag", "Qt/shaders/magazineEdgeFade.frag")
cmake=Path("CMakeLists.txt")
source=cmake.read_text(encoding="utf-8")
anchor="Qt/shaders/softEdgeFade.frag"
if source.count(anchor)!=1:raise RuntimeError("Expected one soft-edge shader build anchor")
cmake.write_text(source.replace(anchor,anchor+"\n    Qt/shaders/magazineEdgeFade.frag"),encoding="utf-8")

# Preserve the server's collection state, even beyond the first personal-list page.
p=Path("MusicBridge/client/items.mjs")
s=p.read_text(encoding="utf-8")
anchor="...Object.fromEntries(['subscribedCount','commentCount','playCount']"
if s.count(anchor)!=1:raise RuntimeError("Collection metadata normalization anchor changed")
s=s.replace(anchor,"...(typeof rawItem.subscribed === 'boolean' ? {subscribed:rawItem.subscribed} : {}),\n        "+anchor)
p.write_text(s,encoding="utf-8")
p=Path("Qt/src/MusicData.cpp")
s=p.read_text(encoding="utf-8")
anchor='    for (const auto &field : {"subscribedCount", "commentCount", "playCount"})'
if s.count(anchor)!=1:raise RuntimeError("Native collection metadata anchor changed")
s=s.replace(anchor,'    if(raw["subscribed"].isBool())value["subscribed"]=raw["subscribed"];\n'+anchor)
p.write_text(s,encoding="utf-8")
print("G74: continuous record handoff, asymmetric previous corner, two-edge fade and frosted collection controls installed.")

# Albums in the same record sequence must keep the persistent magazine alive.
p=Path("Qt/src/NativeHudDetail.cpp")
s=p.read_text(encoding="utf-8")
anchor='if (music.directoryInfo && music.directory && item["kind"] == "playlist") return;'
if s.count(anchor)!=1:raise RuntimeError("Native magazine handoff anchor changed")
s=s.replace(anchor,'if (music.directoryInfo && music.directory && (item["kind"] == "playlist" || (item["kind"] == "album" && music.directory->recordBrowse))) return;')
p.write_text(s,encoding="utf-8")
