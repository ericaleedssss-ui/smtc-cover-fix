// 发布包测试使用本地 HTTP 响应，保持真实上游协议模块参与执行。
const path = require('node:path');
const bridge = process.env.RHINE_TEST_BRIDGE;
const originalFetch = global.fetch;
// 新的共用 QQ 接口使用 Fetch；本地桥接 HTTP 仍走真实回环服务。
global.fetch = async (input, init) => {
    const request = new Request(input, init);
    if (new URL(request.url).hostname !== 'u.y.qq.com') {
        return originalFetch(input, init);
    }
    const raw =
        request.method === 'POST' ? await request.text() : new URL(request.url).searchParams.get('data');
    const payload = JSON.parse(raw || '{}');
    const response = { code: 0 };
    for (const [key, rpc] of Object.entries(payload)) {
        if (!rpc?.method) {
            continue;
        }
        if (rpc.method === 'DoSearchForQQMusicLite') {
            const keys = { 0: 'item_song', 1: 'singer', 2: 'item_album', 3: 'item_songlist' };
            const type = rpc.param.search_type;
            const entries = {
                0: {
                    mid: 'fixtureMID',
                    id: 42,
                    type: 0,
                    name: 'QQ fixture',
                    singer: [],
                    album: { mid: 'albumMID' },
                },
                1: { singerMID: 'singerMID', singerName: 'QQ fixture artist' },
                2: { albummid: 'albumMID', name: 'QQ fixture album' },
                3: { dissid: '70001', dissname: 'QQ fixture playlist' },
            };
            response[key] = {
                code: 0,
                data: {
                    meta: { sum: 1, curpage: 1, nextpage: -1, ret: 0 },
                    body: { [keys[type]]: [entries[type]] },
                },
            };
        } else {
            throw new Error('Unexpected QQ Fetch operation: ' + rpc.method);
        }
    }
    return Response.json(response);
};
const axios = require(
    require.resolve('axios', {
        paths: [bridge],
    }),
);
const upstreamCrypto = require(
    path.join(bridge, 'node_modules/@neteasecloudmusicapienhanced/api/util/crypto'),
);
// 本地响应使用测试密钥加密；请求仍经过上游注册校验、加密和响应解密。
const crypto = require('node:crypto');
const keyPair = crypto.generateKeyPairSync('x25519');
const publicKey = keyPair.publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64');
let keyRegistrations = 0;
const xeapiRequests = new Map();
const originalXeapi = upstreamCrypto.xeapi;
upstreamCrypto.xeapi = (uri, payload, options) => {
    const encrypted = originalXeapi(uri, payload, options);
    xeapiRequests.set(encrypted.C, { payload, version: options.publicKeyState.version });
    return encrypted;
};
function encryptFixture(value, key) {
    const cipher = crypto.createCipheriv(`aes-${key.length * 8}-ecb`, key, null);
    return Buffer.concat([cipher.update(JSON.stringify(value)), cipher.final()]);
}
axios.defaults.adapter = async (settings) => {
    const destination = (settings.baseURL || '') + settings.url;
    if(process.env.RHINE_TEST_TRACE==='1')console.error('Fixture HTTP',destination.split('?')[0]);
    if (/music\.163\.com\/weapi\/v1\/comment\/(?:like|unlike)/.test(destination)) {
        return {status:200,data:{code:200},headers:{},config:settings};
    }
    if (/music\.163\.com\/(?:weapi|eapi|api)\/user\/profile\/update/.test(destination)) {
        return {status:200,data:{code:200,profileSignatureFixture:true},headers:{},config:settings};
    }
    if (/music\.163\.com\/(?:weapi|eapi|api)\/user\/getfolloweds\/42/.test(destination)) {
        return {status:200,data:{code:200,followeds:[{userId:99,nickname:'Profile follower'}],more:false},headers:{},config:settings};
    }
    if (/music\.163\.com\/(?:weapi|eapi|api)\/djradio\/get\/subed/.test(destination)) {
        return {status:200,data:{code:200,djRadios:[{id:901,name:'Profile radio',programCount:12}],count:1,hasMore:false},headers:{},config:settings};
    }
    if (destination === 'https://music.163.com/api/song/chorus') {
        if (settings.method !== 'get' || settings.headers.Cookie) throw new Error('Invalid chorus request');
        const ids = JSON.parse(settings.params.ids);
        if (!/^\d+$/.test(String(ids[0]))) throw new Error('Invalid chorus ID');
        return { status: 200, data: { code: 200, chorus: [{ id: ids[0], startTime: 69500, endTime: 81500 }] }, headers: {}, config: settings };
    }
    if (/music\.163\.com\/api\/(?:v1\/)?discovery\/simi(?:Song|Playlist)/.test(destination)) {
        if (settings.method !== 'get' || settings.headers.Cookie || !/^\d+$/.test(String(settings.params.songid))) throw new Error('Invalid recommendation request');
        const playlists = destination.endsWith('simiPlaylist');
        return {status:200,data:{code:200,[playlists ? 'playlists' : 'songs']:[{id:42,name:'真实桥接测试',coverImgUrl:'https://p1.music.126.net/cover.jpg'}]},headers:{},config:settings};
    }
    if (/music\.163\.com\/api\/v1\/resource\/(?:hotcomments|comments)\/(?:R_SO_4_|R_AL_3_)/.test(destination)) {
        if (settings.method !== 'get' || settings.params.limit > 20 || settings.headers.Cookie?.includes('qqmusic_session')) {
            throw new Error('Invalid read-only comments request');
        }
        const row = { commentId: 42, content: '<b>原样显示的评论</b>', user: { nickname: '测试听众' }, time: 1700000000000, likedCount: 3 };
        return { status: 200, data: { code: 200, total: 1, more: false, hasMore: false, comments: [row], hotComments: [row] }, headers: {}, config: settings };
    }
    if (/\.kugou\.com/.test(destination)) {
        if (destination.endsWith('/v1/search')) {
            return {
                status: 200,
                data: { status: 200, candidates: [{ id: '42', accesskey: 'fixture-key' }] },
                headers: {},
                config: settings,
            };
        }
        if (destination.endsWith('/download')) {
            const content = '[1000,1000]<0,500,0>本地<500,500,0>歌词\n[3000,1000]<0,1000,0>第二句';
            const bytes = require('node:zlib').deflateSync(Buffer.from(content));
            const key = [64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105];
            for (let i = 0; i < bytes.length; i++) {
                bytes[i] ^= key[i % key.length];
            }
            return {
                status: 200,
                data: {
                    status: 200,
                    contenttype: 0,
                    content: Buffer.concat([Buffer.from('krc1'), bytes]).toString('base64'),
                },
                headers: {},
                config: settings,
            };
        }
        // 保留酷狗原包的签名和 Cookie 注入，只提供本地 HTTP 响应。
        if (!settings.params?.mid || !settings.params?.signature) {
            throw new Error('Kugou upstream device or signature missing');
        }
        let data = { status: 1, data: { info: [{ rankid: 1, rankname: '本地榜单' }] } };
        if (destination.endsWith('/v2/qrcode')) {
            const config = require(path.join(bridge, 'node_modules/kugoumusicapi/util/config.json'));
            const appid = process.env.RHINE_KUGOU_EDITION === 'lite' ? config.liteAppid : config.appid;
            if (!settings.params.qrcode_txt.includes('appid=' + appid + '&')) {
                throw new Error('Kugou QR used the wrong edition appid');
            }
            data = { status: 1, data: { qrcode: 'fixture-kugou-qr' } };
        } else if (destination.endsWith('/v2/get_userinfo_qrcode')) {
            data = { status: 1, data: { status: 4, token: 'fixture-kugou-token', userid: 42 } };
        } else if (destination.endsWith('/v2/search/song')) {
            if (settings.params.token !== 'fixture-kugou-token' || settings.params.dfid !== 'fixture-dfid') {
                throw new Error('Kugou credentials or registered device missing');
            }
            data = {
                status: 1,
                data: { lists: [{ FileHash: 'A'.repeat(32), SongName: '本地歌曲' }], total: 1 },
            };
        }
        return { status: 200, data, headers: {}, config: settings };
    }
    if (/music\.163\.com\/(?:weapi|eapi|api)\/(?:msg\/|pl\/count|forwards\/get|v1\/user\/comments)/.test(destination)) {
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
    if (!/music\.163\.com|y\.qq\.com/.test(destination)) {
        throw new Error('Unexpected upstream');
    }
    const qq = destination.includes('qq.com');
    if (qq && process.env.QQ_AUTH_STATE_PATH !== process.env.RHINE_QQ_DEVICE_STATE_PATH) {
        throw new Error('QQ bridge discarded persistent device path');
    }
    let data = qq
        ? {
              code: 0,
              data: {
                  song: {
                      list: [
                          {
                              mid: 'fixtureMID',
                              name: 'QQ fixture',
                              singer: [],
                              album: {
                                  mid: 'albumMID',
                              },
                          },
                      ],
                      totalnum: 1,
                  },
                  topList: [
                      {
                          id: 4,
                          topTitle: 'Fixture chart',
                      },
                  ],
              },
          }
        : {
              code: 200,
              result: {
                  songs: [],
                  songCount: 0,
              },
              data: [
                  {
                      id: 1,
                      url: 'https://music.126.net/fixture',
                  },
              ],
          };
    if (destination.includes('/song/lyric/v1')) {
        data = { code: 200, lrc: { lyric: '[00:01.00]本地歌词\n[00:03.00]第二句' } };
    }
    if (destination.includes('fcg_query_lyric_new.fcg')) {
        data = { code: 0, lyric: Buffer.from('[00:01.00]本地歌词\n[00:03.00]第二句').toString('base64') };
    }
    if (qq && settings.params?.data) {
        const request = JSON.parse(settings.params.data);
        if (request.req_1?.method === 'GetAll') {
            data = {
                code: 0,
                req_1: {
                    code: 0,
                    data: {
                        group: [
                            {
                                toplist: [
                                    {
                                        topId: 4,
                                        title: 'Fixture chart',
                                        period: '2026-10-12',
                                    },
                                ],
                            },
                        ],
                    },
                },
            };
        } else if (request.req_1?.method === 'GetDetail') {
            if (request.req_1.param.period !== '2026-10-12') {
                throw new Error('Chart period changed');
            }
            data = {
                code: 0,
                req_1: {
                    code: 0,
                    data: {
                        data: {
                            totalNum: 1,
                        },
                        songInfoList: [
                            {
                                mid: 'fixtureMID',
                                name: 'QQ fixture',
                            },
                        ],
                    },
                },
            };
        }
    }
    if (destination.endsWith('/api/bsr/sk/get')) {
        keyRegistrations++;
        // 留出并发窗口，验证同一桥接只发起一次注册。
        await new Promise((resolve) => setTimeout(resolve, 15));
        const payload = new URLSearchParams(settings.data);
        if (
            !payload.get('deviceId') ||
            payload.get('signature') !==
                upstreamCrypto.xeapiSign(payload.get('timestamp'), payload.get('nonce'))
        ) {
            throw new Error('XEAPI registration must retain upstream device and signature');
        }
        const timestamp = String(Date.now());
        let nextUpdateTime = Date.now() + 3600000;
        if (process.env.RHINE_TEST_XEAPI_EXPIRE_FIRST === '1' && keyRegistrations === 1) {
            nextUpdateTime = Date.now() - 1;
        }
        const encryptedData = encryptFixture(
            { publicKey, version: String(keyRegistrations), sk: 'fixture-sk', nextUpdateTime },
            Buffer.from('ab1d5a430f6bb04a3f01e81ddd72bd916d5ce591248ac128714806d7f8fb1b84', 'hex'),
        ).toString('base64');
        const shouldFail = process.env.RHINE_TEST_XEAPI_FAIL_FIRST === '1' && keyRegistrations === 1;
        data = {
            code: 200,
            data: {
                encryptedData,
                timestamp,
                signature: shouldFail ? 'invalid' : upstreamCrypto.xeapiSign(timestamp, payload.get('nonce')),
            },
        };
    } else if (destination.split('?')[0].endsWith('/xeapi/song/enhance/player/url/v1')) {
        const encrypted = new URLSearchParams(settings.data);
        const request = xeapiRequests.get(encrypted.get('C'));
        xeapiRequests.delete(encrypted.get('C'));
        if (!request || !settings.headers['x-deviceid']) {
            throw new Error('Expected genuine upstream XEAPI request');
        }
        data = {
            code: 200,
            data: [
                {
                    id: 1,
                    url: 'https://music.126.net/fixture.flac',
                    type: 'flac',
                    level: request.payload.level,
                    authenticated: settings.headers['x-music-u'] === 'fixture-account',
                    keyRegistrations,
                    keyVersion: request.version,
                },
            ],
        };
        if (String(JSON.parse(request.payload.ids)[0]) === '2') {
            data = { code: 403, message: 'fixture permission denied' };
        }
        data = encryptFixture(data, Buffer.from('e82ckenh8dichen8'));
    } else if (destination.includes('/song/enhance/player/url')) {
        throw new Error('Quality requests must not silently fall back to the legacy bitrate endpoint');
    }
    return {
        status: 200,
        data,
        headers: {},
        config: settings,
    };
};
