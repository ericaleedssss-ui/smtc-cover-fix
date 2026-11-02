import test from 'node:test';
import assert from 'node:assert/strict';
import {API} from '../../MusicBridge/client/netease.mjs';
import {parse} from '../../MusicBridge/client/items.mjs';
import {createFakeHost} from './fixtures/client-harness.mjs';
test('collection playlists use stable real offsets and expose subsequent pages',async()=>{
    const {host,calls}=createFakeHost({responses:{'/user/playlist':(params)=>({code:200,more:params.offset<200,playlist:Array.from({length:params.offset<200?100:3},(_,i)=>({id:params.offset+i+1,name:'Collection '+(params.offset+i+1),creator:{userId:42,nickname:'Owner'}}))})}});
    const api=new API(host);let offset=0;const ids=[];let more=true;
    while(more){const page=await api.userPlaylists('42',offset);ids.push(...page.items.map(x=>x.id));offset+=page.rawCount;more=page.more;}
    assert.equal(ids.length,203);assert.equal(new Set(ids).size,203);assert.deepEqual(calls.map(x=>x.params.offset),[0,100,200]);assert.ok(calls.every(x=>x.params.limit===2000));
});
test('album collection pages advance with the actual count and raw page cursor',async()=>{
    const {host,calls}=createFakeHost({responses:{'/album/sublist':(params)=>({code:200,count:105,data:Array.from({length:params.offset?5:100},(_,i)=>({id:params.offset+i+1,name:'Album'}))})}});
    const api=new API(host);const first=await api.likedAlbums(0);const last=await api.likedAlbums(first.rawCount);
    assert.equal(first.more,true);assert.equal(last.more,false);assert.equal(last.items[0].id,'101');assert.deepEqual(calls.map(x=>x.params.offset),[0,100]);
});
test('account metadata preserves actual avatar and VIP type without inventing a tier',async()=>{
    const {host}=createFakeHost({responses:{'/user/account':{code:200,profile:{userId:42,nickname:'Listener',avatarUrl:'https://example.org/avatar',vipType:11}}}});
    assert.deepEqual(await new API(host).account(),['42','Listener',{avatar:'https://example.org/avatar',vipType:11}]);
    const missing=createFakeHost({responses:{'/user/account':{code:200,profile:{userId:43,nickname:'No tier'}}}});assert.deepEqual((await new API(missing.host).account())[2],{avatar:'',vipType:0});
});
test('playlist tags remain real API strings',()=>{assert.deepEqual(parse({id:5,name:'Actual',tags:['独立','摇滚',42]},'playlist').tags,['独立','摇滚']);assert.deepEqual(parse({id:6,name:'Missing'},'playlist').tags,[]);});
