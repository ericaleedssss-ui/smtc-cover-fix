import test from 'node:test';
import assert from 'node:assert/strict';
import { API } from '../../MusicBridge/client/netease.mjs';
import { parse } from '../../MusicBridge/client/items.mjs';
import { createFakeHost } from './fixtures/client-harness.mjs';
test('album derives ordered IDs from songs without playlist trackIds',async()=>{
 const {host,calls}=createFakeHost({responses:{'/album':{code:200,album:{id:101,name:'Actual album',size:3,artists:[{id:5,name:'Artist',img1v1Url:'https://example.org/artist.png'}]},songs:[{id:3,name:'Third',dt:180000},{id:1,name:'First',dt:60000},{id:2,name:'Second',dt:120000}],privileges:[{id:2,st:-200}]}}});
 const [info,songs,ids]=await new API(host).detail({kind:'album',id:'101'});
 assert.deepEqual(ids,['3','1','2']);assert.deepEqual(songs.map(s=>s.id),ids);assert.equal(songs.reduce((sum,s)=>sum+s.duration,0),360000);assert.equal(songs[2].unavailable,true);assert.equal(info.artists[0].avatar,'https://example.org/artist.png');assert.deepEqual(calls.map(c=>c.route),['/album']);
});
test('playlist IDs remain complete when only preview song metadata returns',async()=>{
 const {host}=createFakeHost({responses:{'/playlist/detail':{code:200,playlist:{id:102,name:'Playlist',trackCount:3,trackIds:[{id:3},{id:1},{id:2}],tracks:[{id:3,name:'Third',dt:180000}]}}}});
 const [,songs,ids]=await new API(host).detail({kind:'playlist',id:'102'});assert.deepEqual(ids,['3','1','2']);assert.equal(songs.length,1);
});
test('identity artwork keeps real creator and artist URLs, never album cover',()=>{
 const album=parse({id:103,name:'Album',picUrl:'https://example.org/cover.png',artists:[{id:5,name:'Artist'}]},'album');assert.equal(album.artists[0].avatar,'');assert.notEqual(album.artists[0].avatar,album.cover);
 const playlist=parse({id:104,name:'Playlist',creator:{userId:6,nickname:'Creator',avatarUrl:'https://example.org/user.png'}},'playlist');assert.equal(playlist.creatorAvatar,'https://example.org/user.png');
});

test('archive metadata keeps actual tags and creation/publication dates separate',()=>{
 const playlist=parse({id:105,name:'Tagged',tags:['摇滚','实验'],createTime:new Date(2025,5,12,12).getTime()},'playlist');
 assert.deepEqual(playlist.tags,['摇滚','实验']);assert.equal(playlist.createdDate,'2025-06-12');assert.ok(!playlist.date);
 const album=parse({id:106,name:'Released',publishTime:new Date(2024,3,9,12).getTime()},'album');assert.equal(album.date,'2024-04-09');assert.ok(!album.createdDate);
});
