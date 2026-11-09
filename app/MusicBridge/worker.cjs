const { AsyncLocalStorage } = require('node:async_hooks');
const playbackDiagnosticContext = new AsyncLocalStorage();

/** 记录 HTTP 传输 */
function recordHttpResult(events, started, status, error, phase) {
    if (events.length >= 64) {
        events.omitted = (events.omitted || 0) + 1;
        return;
    }
    const values = {
        operation: 5,
        workerMs: performance.now() - started,
        transportFailed: !!error,
        httpPhase: phase,
        workerOffsetMs: started - events.started,
    };
    if (Number.isInteger(status) && status >= 100 && status <= 599) {
        values.upstreamHttpStatus = status;
    }
    if (error) {
        values.networkError = Math.max(
            0,
            [
                'other',
                'ETIMEDOUT',
                'ECONNRESET',
                'ENOTFOUND',
                'EAI_AGAIN',
                'ECONNREFUSED',
                'ENETUNREACH',
                'EHOSTUNREACH',
                'ERR_CANCELED',
            ].indexOf(error.code || error.cause?.code),
        );
    }
    events.push(values);
}

const axios = require('axios');
const httpTimings = new WeakMap();
axios.interceptors.request.use((config) => {
    const events = playbackDiagnosticContext.getStore();
    if (events) {
        httpTimings.set(config, { events, started: performance.now() });
    }
    return config;
});
axios.interceptors.response.use(
    (response) => {
        const timing = httpTimings.get(response.config);
        if (timing) {
            recordHttpResult(timing.events, timing.started, response.status, undefined, 2);
        }
        return response;
    },
    (error) => {
        const timing = error.config && httpTimings.get(error.config);
        if (timing) {
            recordHttpResult(timing.events, timing.started, error.response?.status, error, 2);
        }
        return Promise.reject(error);
    },
);
const originalFetch = global.fetch;
global.fetch = function (...args) {
    const events = playbackDiagnosticContext.getStore();
    if (!events) {
        return originalFetch(...args);
    }
    const started = performance.now();
    return originalFetch(...args).then(
        (response) => {
            recordHttpResult(events, started, response.status, undefined, 1);
            return response;
        },
        (error) => {
            recordHttpResult(events, started, undefined, error, 1);
            throw error;
        },
    );
};
// 网易云协议使用锁定的 Enhanced 原包；QQ 协议使用锁定的 QQ API 原包。
// 本文件仅通过父子进程的私有管道传递请求。
// 替代音源组件的日志也必须静默，避免污染私有 IPC。
process.env.LOG_LEVEL = 'silent';
process.env.JSON_LOG = 'true';
delete process.env.LOG_FILE;
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');
const tokenPath = path.join(require('node:os').tmpdir(), 'anonymous_token');
if (!fs.existsSync(tokenPath)) {
    fs.writeFileSync(tokenPath, '', {
        mode: 0o600,
    });
}
// 上游诊断可能包含 URL 或 Cookie，禁止混入 IPC 消息和日志。
console.log = console.info = console.warn = console.error = console.debug = () => {};
const apiRoot = path.join(__dirname, 'node_modules', '@neteasecloudmusicapienhanced', 'api');
const routes = Object.freeze({
    '/pl/count': 'pl_count',
    '/msg/private': 'msg_private',
    '/msg/comments': 'msg_comments',
    '/msg/forwards': 'msg_forwards',
    '/msg/notices': 'msg_notices',
    '/msg/private/history': 'msg_private_history',
    '/send/text': 'send_text',
    '/comment/playlist': 'comment_playlist',
    '/playlist/subscribers': 'playlist_subscribers',
    '/song/download/url/v1': 'song_download_url_v1',
    '/fm_trash': 'fm_trash',
    '/song/red/count': 'song_red_count',
    '/scrobble': 'scrobble',
    '/dj/hot': 'dj_hot',
    '/user/follows': 'user_follows',
    '/user/followeds': 'user_followeds',
    '/dj/sublist': 'dj_sublist',
    '/personal/fm/mode': 'personal_fm_mode',
    '/user/detail': 'user_detail',
    '/user/update': 'user_update',
    '/user/level': 'user_level',
    '/vip/info/v2': 'vip_info_v2',
    '/user/record': 'user_record',
    '/user/event': 'user_event',
    '/user/audio': 'user_audio',
    '/record/recent/song': 'record_recent_song',
    '/record/recent/album': 'record_recent_album',
    '/record/recent/playlist': 'record_recent_playlist',
    '/dj/program': 'dj_program',
    '/artist/detail': 'artist_detail',
    '/song/chorus': 'song_chorus',
    '/playmode/intelligence/list': 'playmode_intelligence_list',
    '/simi/song': 'simi_song',
    '/simi/playlist': 'simi_playlist',
    '/comment/music': 'comment_music',
    '/comment/like': 'comment_like',
    '/comment/album': 'comment_album',
    '/comment/hot': 'comment_hot',
    '/login/qr/key': 'login_qr_key',
    '/login/qr/check': 'login_qr_check',
    '/user/account': 'user_account',
    '/search': 'search',
    '/search/suggest': 'search_suggest',
    '/song/detail': 'song_detail',
    '/album': 'album',
    '/playlist/detail': 'playlist_detail',
    '/user/playlist': 'user_playlist',
    '/likelist': 'likelist',
    '/album/sublist': 'album_sublist',
    '/artists': 'artists',
    '/artist/album': 'artist_album',
    '/playlist/delete': 'playlist_delete',
    '/like': 'like',
    '/album/sub': 'album_sub',
    '/playlist/subscribe': 'playlist_subscribe',
    '/artist/sub': 'artist_sub',
    '/artist/sublist': 'artist_sublist',
    '/playlist/create': 'playlist_create',
    '/playlist/name/update': 'playlist_name_update',
    '/playlist/tracks': 'playlist_tracks',
    '/login/cellphone': 'login_cellphone',
    '/login': 'login',
    '/song/url': 'song_url',
    '/song/url/v1': 'song_url_v1',
    '/personalized': 'personalized',
    '/recommend/songs': 'recommend_songs',
    '/album/newest': 'album_newest',
    '/top/playlist': 'top_playlist',
    '/playlist/catlist': 'playlist_catlist',
    '/toplist': 'toplist',
    '/song/wiki/summary': 'song_wiki_summary',
    '/lyric/new': 'lyric_new',
    '/lyric': 'lyric',
});
// 沿用上游 main.js 的函数适配方式，只加载允许的接口。
// 接口和加密文件保持上游原始字节内容。
const { cookieToJson, generateDeviceId } = require(path.join(apiRoot, 'util'));
const { getXeapiPublicKey } = require(path.join(apiRoot, 'util', 'xeapiKey'));
const xeapiKeyPath = path.join(require('node:os').tmpdir(), 'xeapi_public_key');
global.deviceId = generateDeviceId();
let xeapiPublicKey;
let xeapiInitializing;
let requestModule;
/**
 * 在真实 XEAPI 请求前准备上游密钥，并让并发请求共享一次初始化或刷新。
 * 密钥仅写入当前桥接的私有临时目录；不修改上游协议和加密实现。
 */
async function prepareXeapiKey() {
    if (xeapiInitializing) {
        return xeapiInitializing;
    }
    if (!xeapiPublicKey && fs.existsSync(xeapiKeyPath)) {
        try {
            const cachedKey = JSON.parse(fs.readFileSync(xeapiKeyPath, 'utf8'));
            if (cachedKey.publicKey && cachedKey.sk) {
                xeapiPublicKey = cachedKey;
                global.deviceId = cachedKey.deviceId || global.deviceId;
            }
        } catch {
            // 损坏的临时缓存不能作为可用密钥，接下来重新向上游注册。
        }
    }
    const nextUpdateTime = Number(xeapiPublicKey?.nextUpdateTime) || 0;
    const updateAtMs = nextUpdateTime < 1e12 ? nextUpdateTime * 1000 : nextUpdateTime;
    if (xeapiPublicKey && (!updateAtMs || Date.now() < updateAtMs)) {
        return;
    }
    xeapiInitializing = (async () => {
        try {
            const publicKey = await getXeapiPublicKey(xeapiPublicKey || {}, global.deviceId);
            if (!publicKey.publicKey || !publicKey.sk) {
                throw new Error('Incomplete XEAPI key');
            }
            fs.writeFileSync(xeapiKeyPath, JSON.stringify(publicKey), { mode: 0o600 });
            xeapiPublicKey = publicKey;
            // 上游 request 在模块内缓存密钥和会话，刷新后重新载入以使用新密钥。
            const requestPath = require.resolve(path.join(apiRoot, 'util', 'request'));
            delete require.cache[requestPath];
            requestModule = undefined;
        } catch {
            // 初始化错误不得悄悄改成旧版码率接口，否则母带等档位会丢失。
            const error = new Error('网易云音源初始化失败，请重试');
            error.body = { code: 503, message: error.message };
            throw error;
        } finally {
            xeapiInitializing = undefined;
        }
    })();
    return xeapiInitializing;
}
const api = Object.fromEntries(
    Object.values(routes).map((name) => {
        const endpoint = require(path.join(apiRoot, 'module', name + '.js'));
        return [
            name,
            (data = {}) =>
                endpoint(
                    {
                        ...data,
                        cookie:
                            typeof data.cookie === 'string' ? cookieToJson(data.cookie) : data.cookie || {},
                    },
                    async (...args) => {
                        if (args[2]?.crypto === 'xeapi') {
                            await prepareXeapiKey();
                        }
                        requestModule ||= require(path.join(apiRoot, 'util', 'request'));
                        return requestModule(...args);
                    },
                ),
        ];
    }),
);
// 原样执行上游前端的认证和用户函数；加载时仅适配 ES 模块的
// 导入导出语法，使其能使用私有传输层。
const vm = require('node:vm');
const clientScripts = new Map();
/**
 * 载入锁定的上游认证或用户模块。
 * 仅适配导入导出和请求入口，禁止改写协议实现。
 */
function loadClient(name, request) {
    let script = clientScripts.get(name);
    if (!script) {
        const source = fs.readFileSync(path.join(__dirname, 'upstream', name + '.js'), 'utf8');
        const names = [...source.matchAll(/export function (\w+)/g)].map((m) => m[1]);
        const executable = source
            .replace(/^import request from '@\/utils\/request';\s*/m, '')
            .replace(/export function /g, 'function ');
        script = new vm.Script(executable + '\n({' + names.join(',') + '})');
        clientScripts.set(name, script);
    }
    // Compiled source is immutable; each request keeps its own transport/cookies.
    return script.runInNewContext({
        request,
        Date,
    });
}
/**
 * 根据私有 IPC 消息分派允许的音乐请求。
 * 沿用锁定上游的协议与错误语义，响应 Cookie 交给父进程隔离处理。
 */
async function dispatchRequest(message) {
    if (message.route === '/song/red/count') {
        const id = String(message.params?.id || '');
        if (!/^[0-9]{1,20}$/.test(id)) {
            return { body: { code: 400, message: '歌曲编号无效' }, cookies: [] };
        }
        const cookie = Object.entries(message.cookies || {})
            .filter(([key, value]) => /^[A-Za-z0-9_]+$/.test(key) &&
                !key.startsWith('__') && key !== 'qqmusic_session' && typeof value === 'string')
            .map(([key, value]) => `${key}=${encodeURIComponent(value)}`).join('; ');
        const response = await axios.get('https://music.163.com/api/song/red/count', {
            params: { songId: id },
            timeout: 15000,
            headers: {
                Referer: 'https://music.163.com/',
                'User-Agent': 'Mozilla/5.0',
                ...(cookie ? { Cookie: cookie } : {}),
            },
        });
        return { body: response.data, cookies: [] };
    }
    if (message.route === '/song/chorus') {
        const id = String(message.params?.id || '');
        if (!/^\d{1,20}$/.test(id)) return { body: { code: 400 }, cookies: [] };
        const response = await axios.get('https://music.163.com/api/song/chorus', {
            params: { ids: JSON.stringify([id]) }, timeout: 15000,
            headers: { Referer: 'https://music.163.com/', 'User-Agent': 'Mozilla/5.0' },
        });
        return { body: response.data, cookies: [] };
    }
    if (message.route === '/simi/song' || message.route === '/simi/playlist') {
        const p = message.params || {};
        if (!/^\d+$/.test(String(p.id || ''))) {
            return { body: { code: 400, message: '歌曲编号无效' }, cookies: [] };
        }
        const song = message.route === '/simi/song';
        const response = await axios.get('https://music.163.com' + (song ? '/api/v1/discovery/simiSong' : '/api/discovery/simiPlaylist'), {
            params: { songid: p.id, limit: song ? 10 : 3, offset: 0 }, timeout: 15000,
            headers: { Referer: 'https://music.163.com/', 'User-Agent': 'Mozilla/5.0' },
        });
        return { body: response.data, cookies: [] };
    }
    if (message.route === '/comment/music' || message.route === '/comment/album' || message.route === '/comment/hot') {
        const p = message.params || {};
        if (!/^\d+$/.test(String(p.id || ''))) {
            return { body: { code: 400, message: '评论对象编号无效' }, cookies: [] };
        }
        const hot = message.route === '/comment/hot';
        const resource = message.route === '/comment/album' || (hot && Number(p.type) === 1) ? 'R_AL_3_' : 'R_SO_4_';
        const cookie = Object.entries(message.cookies || {})
            .filter(([key, value]) => /^[A-Za-z0-9_]+$/.test(key) && !key.startsWith('__') && key !== 'qqmusic_session' && typeof value === 'string')
            .map(([key, value]) => `${key}=${encodeURIComponent(value)}`).join('; ');
        // 公开评论的只读 Web 接口；固定域名和路径，不改变上游加密模块。
        const response = await axios.get(`https://music.163.com/api/v1/resource/${hot ? 'hotcomments' : 'comments'}/${resource}${p.id}`, {
            params: { limit: Math.max(1, Math.min(20, Number(p.limit) || 4)), offset: Math.max(0, Number(p.offset) || 0), beforeTime: Math.max(0, Number(p.before) || 0) },
            timeout: 15000,
            headers: { Referer: 'https://music.163.com/', 'User-Agent': 'Mozilla/5.0', ...(cookie ? { Cookie: cookie } : {}) },
        });
        return { body: response.data, cookies: [] };
    }
    if (message.route === '/local/lyrics') {
        const content = message.params?.content;
        if (typeof content !== 'string' || content.length > 1000000) {
            return { body: { code: 400, message: '本地歌词内容无效' }, cookies: [] };
        }
        const result = require('./lyrics-format.cjs').normalizeLyrics('netease', { lrc: { lyric: content } });
        if (result.document) {
            result.document.source = 'local';
        }
        return { body: result, cookies: [] };
    }
    if (message.route?.startsWith('/native/')) {
        const client = await import('./client/dispatch.mjs');
        return client.dispatch(message, dispatch);
    }
    if (message.route?.startsWith('/qq/')) {
        return require('./qq.cjs').dispatch(message);
    }
    if (message.route?.startsWith('/kugou/')) {
        return require('./kugou.cjs').dispatch(message);
    }
    let responseCookies = [];
    const request = async (config) => {
        const moduleName = routes[config.url];
        if (!moduleName) {
            throw new Error('Unsupported metadata route');
        }
        const query = Object.fromEntries(Object.entries(config.params || {}).map(([k, v]) => [k, String(v)]));
        query.cookie = Object.fromEntries(
            Object.entries(message.cookies || {}).filter(
                ([key]) => !key.startsWith('__') && key !== 'qqmusic_session',
            ),
        );
        const result = await api[moduleName](query);
        responseCookies.push(...(result.cookie || []));
        return result.body;
    };
    const p = message.params || {};
    const calls = {
        '/login/qr/key': () => loadClient('auth', request).loginQrCodeKey(),
        '/login/qr/check': () => loadClient('auth', request).loginQrCodeCheck(p.key),
        '/user/account': () => loadClient('user', request).userAccount(),
        '/user/playlist': () => loadClient('user', request).userPlaylist(p),
        '/likelist': () => loadClient('user', request).userLikedSongsIDs(p.uid),
        '/album/sublist': () => loadClient('user', request).likedAlbums(p),
    };
    const body = await (calls[message.route]
        ? calls[message.route]()
        : request({
              url: message.route,
              params: p,
          }));
    return {
        body: ['/lyric', '/lyric/new'].includes(message.route)
            ? require('./lyrics-format.cjs').normalizeLyrics('netease', body, message.params)
            : body,
        cookies: responseCookies,
    };
}

/** 诊断期间记录音源请求的数值结果 */
async function dispatch(message) {
    const events = playbackDiagnosticContext.getStore();
    if (!events || message.route?.startsWith('/native/')) {
        return dispatchRequest(message);
    }
    const started = performance.now();
    const values = { operation: 4, workerOffsetMs: started - events.started };
    try {
        const result = await dispatchRequest(message);
        const body = result?.body;
        for (const [source, target] of [
            ['code', 'serviceCode'],
            ['upstreamHttpStatus', 'upstreamHttpStatus'],
            ['upstreamCode', 'upstreamCode'],
        ]) {
            if (typeof body?.[source] === 'number' && Number.isFinite(body[source])) {
                values[target] = body[source];
            }
        }
        values.transportFailed = false;
        return result;
    } catch (error) {
        values.transportFailed = true;
        if (typeof error?.body?.code === 'number' && Number.isFinite(error.body.code)) {
            values.serviceCode = error.body.code;
        }
        const status = error?.response?.status;
        if (Number.isInteger(status) && status >= 100 && status <= 599) {
            values.upstreamHttpStatus = status;
        }
        values.networkError = Math.max(
            0,
            [
                'other',
                'ETIMEDOUT',
                'ECONNRESET',
                'ENOTFOUND',
                'EAI_AGAIN',
                'ECONNREFUSED',
                'ENETUNREACH',
                'EHOSTUNREACH',
                'ERR_CANCELED',
            ].indexOf(error?.code),
        );
        throw error;
    } finally {
        if (events.length < 64) {
            values.workerMs = performance.now() - started;
            events.push(values);
        } else {
            events.omitted = (events.omitted || 0) + 1;
        }
    }
}

function send(value) {
    process.stdout.write(JSON.stringify(value) + '\n');
}
readline
    .createInterface({
        input: process.stdin,
    })
    .on('line', async (line) => {
        let message;
        try {
            message = JSON.parse(line);
            const collect =
                message._collectPlaybackDiagnostics === true &&
                /^\/native\/(netease|qq|kugou)\/(playback|preview)$/.test(message.route);
            const events = collect ? [] : undefined;
            if (events) {
                events.started = performance.now();
            }
            const result = await playbackDiagnosticContext.run(events, () => dispatch(message));
            send({
                id: message.id,
                ...result,
                ...(events
                    ? { _playbackDiagnostics: events, _playbackDiagnosticsOmitted: events.omitted || 0 }
                    : {}),
            });
        } catch (error) {
            send({
                id: message?.id,
                body: error.body || {
                    code: 503,
                    message: '音乐请求失败，请重试',
                },
                cookies: error.cookie || [],
            });
        }
    })
    .on('close', () => process.exit(0));
