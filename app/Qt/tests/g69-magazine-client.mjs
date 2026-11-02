import test from 'node:test';
import assert from 'node:assert/strict';
import {parse} from '../../MusicBridge/client/items.mjs';
import {API} from '../../MusicBridge/client/netease.mjs';
import {createFakeHost} from './fixtures/client-harness.mjs';
test('magazine preserves real creator, creation date and counts; missing values stay absent',()=>{
    const item=parse({id:123,name:'Actual playlist',creator:{userId:42,nickname:'Owner',avatarUrl:'https://example.org/avatar'},createTime:1700000000000,subscribedCount:84,commentCount:23},'playlist');
    assert.equal(item.creatorID,'42');assert.equal(item.creatorAvatar,'https://example.org/avatar');assert.equal(item.subscribedCount,84);assert.equal(item.commentCount,23);assert.match(item.createdDate,/^\d{4}-\d{2}-\d{2}$/);
    const missing=parse({id:124,name:'No statistics'},'playlist');assert.equal(missing.artist,'');assert.equal(missing.subscribedCount,undefined);assert.equal(missing.createdDate,undefined);
});
test('magazine pages join privileges by song ID, not response position',async()=>{
    const {host}=createFakeHost({responses:{'/song/detail':{code:200,songs:[{id:12,name:'Available'},{id:13,name:'Unavailable'}],privileges:[{id:13,st:-200},{id:12,st:0}]}}});
    const tracks=await new API(host).songs(['12','13']);assert.equal(tracks[0].unavailable,false);assert.equal(tracks[1].unavailable,true);
});
test('magazine playlist details preserve full IDs and per-track rights without invoking playback',async()=>{
    const {host,calls}=createFakeHost({responses:{'/playlist/detail':{code:200,playlist:{id:123,name:'Collection',creator:{userId:42,nickname:'Owner'},trackCount:5000,trackIds:[{id:12},{id:13}],tracks:[{id:12,name:'A'},{id:13,name:'B'}]},privileges:[{id:13,st:-200}]}}});
    const [info,tracks,ids]=await new API(host).detail({kind:'playlist',id:'123'});assert.equal(info.trackCount,5000);assert.deepEqual(ids,['12','13']);assert.equal(tracks[1].unavailable,true);assert.deepEqual(calls.map(c=>c.route),['/playlist/detail']);
});
