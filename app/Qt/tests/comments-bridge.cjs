const assert = require('node:assert/strict');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { bridgeRuntime } = require('./fixtures/bridge-runtime.cjs');
const { bridge, runtime } = bridgeRuntime();
const child = spawn(runtime, ['--require', path.resolve(__dirname, 'fixtures/bridge-http.cjs'), path.join(bridge, 'worker.cjs')], {
    cwd: bridge, env: { ...process.env, RHINE_TEST_BRIDGE: bridge }, stdio: ['pipe', 'pipe', 'pipe'],
});
let buffer = '', errors = '', serial = 0;
const pending = new Map();
const timeout = setTimeout(() => { child.kill(); throw new Error('Comments bridge test timed out'); }, 15000);
child.stderr.on('data', x => errors += x);
child.stdout.on('data', chunk => {
    buffer += chunk;
    let end;
    while ((end = buffer.indexOf('\n')) >= 0) {
        const row = JSON.parse(buffer.slice(0, end)); buffer = buffer.slice(end + 1);
        const receive = pending.get(row.id);
        if (receive) { pending.delete(row.id); receive(row); }
    }
});
const send = (route, id) => new Promise(resolve => {
    const key = String(++serial); pending.set(key, resolve);
    child.stdin.write(JSON.stringify({ id: key, route, params: { id, limit: 4 }, cookies: { qqmusic_session: 'must-not-forward' } }) + '\n');
});
(async () => {
    for (const route of ['/comment/hot', '/comment/music', '/comment/album']) {
        const result = await send(route, '2085028155');
        assert.equal(result.body.code, 200);
        assert.equal(result.body.comments[0].content, '<b>原样显示的评论</b>');
        assert.deepEqual(result.cookies, []);
    }
    for (const route of ['/simi/song', '/simi/playlist']) {
        const result = await send(route, '2713981584');
        assert.equal(result.body.code, 200);
        assert.equal(result.body[route.endsWith('playlist') ? 'playlists' : 'songs'][0].id, 42);
        assert.deepEqual(result.cookies, []);
        assert.equal((await send(route, '../invalid')).body.code, 400);
    }
    const chorus = await send('/song/chorus', '3447996825');
    assert.equal(chorus.body.chorus[0].startTime, 69500);
    assert.deepEqual(chorus.cookies, []);
    assert.equal((await send('/song/chorus', '../invalid')).body.code, 400);
    assert.equal((await send('/comment/music', '../invalid')).body.code, 400);
    child.stdin.end();
    await new Promise((resolve, reject) => child.once('close', code => code === 0 ? resolve() : reject(new Error(errors))));
    assert.equal(errors, ''); clearTimeout(timeout);
    console.log('Packaged comments IPC, read-only GET, invalid IDs and cookie isolation passed');
})().catch(error => { clearTimeout(timeout); child.kill(); console.error(error); process.exitCode = 1; });
