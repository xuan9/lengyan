import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import test from 'node:test';

import worker from '../worker.js';

const SUPPORT_SITE_ORIGIN = 'https://xuan9.github.io';
const SIMPLIFIED_PRIVACY_URL = 'https://xuan9.github.io/lengyan/privacy.html';
const TRADITIONAL_PRIVACY_URL = 'https://xuan9.github.io/lengyan/privacy-hant.html';

class MockDB {
  constructor({ failRun = false } = {}) {
    this.calls = [];
    this.failRun = failRun;
  }

  prepare(sql) {
    const db = this;
    return {
      args: [],
      bind(...args) {
        this.args = args;
        return this;
      },
      async run() {
        db.calls.push({ operation: 'run', sql, args: this.args });
        if (db.failRun) throw new Error('mock database failure');
        return { success: true };
      },
      async all() {
        db.calls.push({ operation: 'all', sql, args: this.args });
        return { results: [] };
      },
      async first() {
        db.calls.push({ operation: 'first', sql, args: this.args });
        return { total: 0 };
      },
    };
  }
}

function allowingLimiter() {
  return { async limit() { return { success: true }; } };
}

function submitEnv(db = new MockDB()) {
  return {
    DB: db,
    SUBMIT_ACTOR_RATE_LIMITER: allowingLimiter(),
    SUBMIT_LOCATION_RATE_LIMITER: allowingLimiter(),
    LOGIN_ACTOR_RATE_LIMITER: allowingLimiter(),
    LOGIN_LOCATION_RATE_LIMITER: allowingLimiter(),
    ADMIN_PASSWORD: 'correct horse battery staple',
    ADMIN_SESSION_SECRET: 'a'.repeat(32),
  };
}

async function submit(body, env = submitEnv(), additionalHeaders = {}) {
  const response = await worker.fetch(new Request('https://feedback.example/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...additionalHeaders },
    body: JSON.stringify(body),
  }), env);
  return { response, payload: await response.json(), env };
}

async function adminCookie(env) {
  const response = await worker.fetch(new Request('https://feedback.example/api/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ password: env.ADMIN_PASSWORD }),
  }), env);
  assert.equal(response.status, 200);
  return response.headers.get('Set-Cookie').split(';', 1)[0];
}

test('stores product, content, and public App version and returns an unguessable reference', async () => {
  const db = new MockDB();
  const env = submitEnv(db);
  const { response, payload } = await submit({
    productID: 'lengyan',
    content: '排版在横屏时出现问题',
    appVersion: '2.1',
    build: '73',
    deviceFamily: 'iPad',
    osVersion: 'iOS 19.2.1',
    type: 'bug',
    deviceId: 'must-be-ignored',
  }, env);

  assert.equal(response.status, 200);
  assert.equal(payload.ok, true);
  assert.match(payload.reference, /^[a-f0-9]{32}$/);

  const insert = db.calls.find(call => call.sql.includes('INSERT INTO feedback'));
  assert.ok(insert);
  assert.equal(insert.args.length, 5);
  assert.equal(insert.args[1], 'lengyan');
  assert.equal(insert.args[2], '排版在横屏时出现问题');
  assert.equal(insert.args[3], '2.1');
  assert.match(insert.sql, /product_id/);
  assert.doesNotMatch(insert.sql, /device_id|device_family|os_version|\bbuild\b|\btype\b/);
});

test('maps missing legacy ownership to Lengyan and rejects inactive product IDs', async () => {
  const legacyDB = new MockDB();
  const legacy = await submit({ content: '旧版楞严客户端' }, submitEnv(legacyDB));
  assert.equal(legacy.response.status, 200);
  const legacyInsert = legacyDB.calls.find(call => call.sql.includes('INSERT INTO feedback'));
  assert.equal(legacyInsert.args[1], 'lengyan');

  for (const productID of ['jingang', 'Lengyan', 'lengyan--beta', '', null]) {
    const db = new MockDB();
    const rejected = await submit(
      { productID, content: '不应写入' },
      submitEnv(db)
    );
    assert.equal(rejected.response.status, 400, String(productID));
    assert.equal(rejected.payload.error, 'productID is not supported');
    assert.equal(db.calls.length, 0);
  }
});

test('rejects non-object submission bodies without touching storage', async () => {
  for (const body of [null, [], 'feedback']) {
    const db = new MockDB();
    const rejected = await submit(body, submitEnv(db));
    assert.equal(rejected.response.status, 400, String(body));
    assert.equal(rejected.payload.error, 'invalid JSON object');
    assert.equal(db.calls.length, 0);
  }
});

test('accepts 2000 extended grapheme clusters and rejects 2001', async () => {
  const familyEmoji = '👨‍👩‍👧‍👦';
  const accepted = await submit({ content: familyEmoji.repeat(2_000), appVersion: '2.1' });
  assert.equal(accepted.response.status, 200);

  const rejected = await submit({ content: familyEmoji.repeat(2_001), appVersion: '2.1' });
  assert.equal(rejected.response.status, 413);
  assert.equal(rejected.payload.error, 'content is too long');
});

test('stops reading an oversized chunked request body before storage', async () => {
  const db = new MockDB();
  let cancelled = false;
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new Uint8Array(40 * 1_024));
      controller.enqueue(new Uint8Array(40 * 1_024));
    },
    cancel() {
      cancelled = true;
    },
  });
  const request = new Request('https://feedback.example/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: stream,
    duplex: 'half',
  });

  assert.equal(request.headers.get('Content-Length'), null);
  const response = await worker.fetch(request, submitEnv(db));

  assert.equal(response.status, 413);
  assert.equal((await response.json()).error, 'request is too large');
  assert.equal(cancelled, true);
  assert.equal(db.calls.length, 0);
});

test('discards ambiguous combined diagnostics sent by legacy clients', async () => {
  const db = new MockDB();
  const { response } = await submit({
    content: '旧客户端提交',
    device: 'iPhone15,2',
    os: 'iOS 18.5.1',
    appVersion: '1.8 (42)',
  }, submitEnv(db));

  assert.equal(response.status, 200);
  const insert = db.calls.find(call => call.sql.includes('INSERT INTO feedback'));
  assert.equal(insert.args[3], '');
});

test('never stores device, OS, or build diagnostics', async () => {
  for (const device of [
    'SecretHardware9,9',
    'iPod9,1',
    'Apple Vision',
    'RealityDevice14,1',
    'Simulator',
    'x86_64',
    'Other',
  ]) {
    const db = new MockDB();
    await submit({
      content: '不支持的设备类别',
      deviceFamily: device,
      osVersion: '18.0',
      appVersion: '1.0',
    }, submitEnv(db));

    const insert = db.calls.find(call => call.sql.includes('INSERT INTO feedback'));
    assert.equal(insert.args[3], '1.0', device);
    assert.doesNotMatch(insert.sql, /device_family|os_version|\bbuild\b/, device);
  }

  const macDB = new MockDB();
  await submit({
    content: 'Mac',
    deviceFamily: 'Mac',
    osVersion: '18.5',
    appVersion: '1.0',
    build: '42',
  }, submitEnv(macDB));
  const macInsert = macDB.calls.find(call => call.sql.includes('INSERT INTO feedback'));
  assert.equal(macInsert.args[3], '1.0');
  assert.doesNotMatch(macInsert.sql, /device_family|os_version|\bbuild\b/);
});

test('final schema structurally excludes diagnostic columns', () => {
  const schema = readFileSync(new URL('../schema.sql', import.meta.url), 'utf8');
  assert.doesNotMatch(schema, /device_id|device_family|os_version|\bbuild\b|\btype\b/);
  assert.match(schema, /product_id TEXT NOT NULL DEFAULT 'lengyan'/);
  assert.match(schema, /content TEXT NOT NULL/);
  assert.match(schema, /app_version TEXT NOT NULL/);
});

test('product migration is additive, classifies existing rows, and matches canonical schema', () => {
  const migrationsURL = new URL('../migrations/', import.meta.url);
  const migrationNames = readdirSync(migrationsURL)
    .filter(name => /^\d{4}_.+\.sql$/.test(name))
    .sort();
  assert.equal(migrationNames.at(-1), '0006_add_feedback_product_id.sql');

  const migrated = new DatabaseSync(':memory:');
  for (const name of migrationNames.slice(0, -1)) {
    migrated.exec(readFileSync(new URL(name, migrationsURL), 'utf8'));
  }
  migrated.prepare(
    `INSERT INTO feedback
     (reference, content, app_version, is_read, created_at)
     VALUES (?, ?, ?, ?, ?)`
  ).run(
    '0123456789abcdef0123456789abcdef',
    '迁移前反馈',
    '2.1',
    0,
    '2026-07-27T12:00:00.000Z'
  );

  const productMigration = readFileSync(
    new URL('0006_add_feedback_product_id.sql', migrationsURL),
    'utf8'
  );
  assert.doesNotMatch(productMigration, /DROP\s+TABLE|DELETE\s+FROM|UPDATE\s+feedback/i);
  migrated.exec(productMigration);

  const migratedRow = migrated.prepare(
    'SELECT product_id, content FROM feedback WHERE reference = ?'
  ).get('0123456789abcdef0123456789abcdef');
  assert.equal(migratedRow.product_id, 'lengyan');
  assert.equal(migratedRow.content, '迁移前反馈');
  assert.throws(() => {
    migrated.prepare(
      `INSERT INTO feedback
       (reference, product_id, content, created_at)
       VALUES (?, ?, ?, ?)`
    ).run(
      'fedcba9876543210fedcba9876543210',
      'Invalid--Product',
      '不合法产品',
      '2026-07-27T12:01:00.000Z'
    );
  }, /constraint/i);

  const canonical = new DatabaseSync(':memory:');
  canonical.exec(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8'));
  const columnShape = database => database.prepare('PRAGMA table_info(feedback)').all()
    .map(column => ({
      name: column.name,
      type: column.type,
      notnull: column.notnull,
      defaultValue: column.dflt_value,
    }))
    .sort((left, right) => left.name.localeCompare(right.name));
  const indexNames = database => database.prepare(
    `SELECT name FROM sqlite_master
     WHERE type = 'index' AND name NOT LIKE 'sqlite_autoindex%'
     ORDER BY name`
  ).all().map(index => index.name);

  assert.deepEqual(columnShape(migrated), columnShape(canonical));
  assert.deepEqual(indexNames(migrated), indexNames(canonical));
  migrated.close();
  canonical.close();
});

test('support site receives narrowly scoped CORS for feedback preflight and POST', async () => {
  const preflight = await worker.fetch(new Request('https://feedback.example/', {
    method: 'OPTIONS',
    headers: {
      'Origin': SUPPORT_SITE_ORIGIN,
      'Access-Control-Request-Method': 'POST',
      'Access-Control-Request-Headers': 'content-type',
    },
  }), {});
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('Access-Control-Allow-Origin'), SUPPORT_SITE_ORIGIN);
  assert.equal(preflight.headers.get('Access-Control-Allow-Methods'), 'POST');
  assert.equal(preflight.headers.get('Access-Control-Allow-Headers'), 'Content-Type');
  assert.equal(preflight.headers.get('Vary'), 'Origin');
  assert.equal(preflight.headers.get('Cache-Control'), 'no-store');

  const legacyKeyPreflight = await worker.fetch(new Request('https://feedback.example/', {
    method: 'OPTIONS',
    headers: {
      'Origin': SUPPORT_SITE_ORIGIN,
      'Access-Control-Request-Method': 'POST',
      'Access-Control-Request-Headers': 'content-type, x-api-key',
    },
  }), {});
  assert.equal(legacyKeyPreflight.status, 204);
  assert.equal(legacyKeyPreflight.headers.get('Access-Control-Allow-Origin'), null);
  assert.equal(legacyKeyPreflight.headers.get('Access-Control-Allow-Headers'), null);

  const submitted = await submit(
    { content: '网页反馈', appVersion: '2.1' },
    submitEnv(),
    { Origin: SUPPORT_SITE_ORIGIN }
  );
  assert.equal(submitted.response.status, 200);
  assert.equal(submitted.response.headers.get('Access-Control-Allow-Origin'), SUPPORT_SITE_ORIGIN);
  assert.equal(submitted.response.headers.get('Access-Control-Allow-Methods'), 'POST');
  assert.equal(submitted.response.headers.get('Access-Control-Allow-Headers'), 'Content-Type');
  assert.equal(submitted.response.headers.get('Vary'), 'Origin');
  assert.equal(submitted.response.headers.get('Cache-Control'), 'no-store');

  const nativeSubmission = await submit({ content: '原生 App 反馈' });
  assert.equal(nativeSubmission.response.status, 200);
  assert.equal(nativeSubmission.response.headers.get('Access-Control-Allow-Origin'), null);
  assert.equal(nativeSubmission.response.headers.get('Vary'), null);
});

test('untrusted origins and all administrator routes never receive CORS headers', async () => {
  const evilOrigin = 'https://evil.example';
  const evilPreflight = await worker.fetch(new Request('https://feedback.example/', {
    method: 'OPTIONS',
    headers: {
      'Origin': evilOrigin,
      'Access-Control-Request-Method': 'POST',
      'Access-Control-Request-Headers': 'content-type',
    },
  }), {});
  assert.equal(evilPreflight.status, 204);
  assert.equal(evilPreflight.headers.get('Access-Control-Allow-Origin'), null);
  assert.equal(evilPreflight.headers.get('Access-Control-Allow-Methods'), null);
  assert.equal(evilPreflight.headers.get('Access-Control-Allow-Headers'), null);

  const evilPost = await submit(
    { content: '不应写入' },
    submitEnv(),
    { Origin: evilOrigin }
  );
  assert.equal(evilPost.response.status, 403);
  assert.equal(evilPost.response.headers.get('Access-Control-Allow-Origin'), null);
  assert.equal(evilPost.env.DB.calls.length, 0);

  for (const request of [
    new Request('https://feedback.example/admin', {
      headers: { Origin: SUPPORT_SITE_ORIGIN },
    }),
    new Request('https://feedback.example/api/list', {
      headers: { Origin: SUPPORT_SITE_ORIGIN },
    }),
    new Request('https://feedback.example/api/login', {
      method: 'OPTIONS',
      headers: {
        'Origin': SUPPORT_SITE_ORIGIN,
        'Access-Control-Request-Method': 'POST',
      },
    }),
  ]) {
    const response = await worker.fetch(request, submitEnv());
    assert.equal(response.headers.get('Access-Control-Allow-Origin'), null);
    assert.equal(response.headers.get('Access-Control-Allow-Methods'), null);
    assert.equal(response.headers.get('Access-Control-Allow-Headers'), null);
  }
});

test('privacy endpoint redirects without caching according to preferred Chinese variant', async () => {
  const cases = [
    [null, SIMPLIFIED_PRIVACY_URL],
    ['en-US,en;q=0.9', SIMPLIFIED_PRIVACY_URL],
    ['zh-Hans-CN', SIMPLIFIED_PRIVACY_URL],
    ['zh-CN;q=0.9,zh-TW;q=0.4', SIMPLIFIED_PRIVACY_URL],
    ['zh-Hant', TRADITIONAL_PRIVACY_URL],
    ['zh-TW', TRADITIONAL_PRIVACY_URL],
    ['zh-HK', TRADITIONAL_PRIVACY_URL],
    ['zh-MO', TRADITIONAL_PRIVACY_URL],
    ['zh-Hant;q=0.7,zh-Hans;q=0.9', SIMPLIFIED_PRIVACY_URL],
  ];

  for (const [language, expectedLocation] of cases) {
    const headers = language === null ? {} : { 'Accept-Language': language };
    const response = await worker.fetch(new Request('https://feedback.example/privacy', {
      headers,
    }), {});
    assert.equal(response.status, 302, language || 'no language');
    assert.equal(response.headers.get('Location'), expectedLocation, language || 'no language');
    assert.equal(response.headers.get('Cache-Control'), 'no-store');
    assert.equal(response.headers.get('Vary'), 'Accept-Language');
    assert.equal(await response.text(), '');
  }
});

test('rate limiting is enforced and missing bindings fail closed', async () => {
  const limitedEnv = submitEnv();
  let sharedLimiterCalled = false;
  limitedEnv.SUBMIT_ACTOR_RATE_LIMITER = { async limit() { return { success: false }; } };
  limitedEnv.SUBMIT_LOCATION_RATE_LIMITER = {
    async limit() {
      sharedLimiterCalled = true;
      return { success: true };
    },
  };
  const limited = await submit({ content: 'test' }, limitedEnv);
  assert.equal(limited.response.status, 429);
  assert.equal(limited.response.headers.get('Retry-After'), '60');
  assert.equal(sharedLimiterCalled, false);

  const missingEnv = submitEnv();
  delete missingEnv.SUBMIT_ACTOR_RATE_LIMITER;
  const missing = await submit({ content: 'test' }, missingEnv);
  assert.equal(missing.response.status, 503);

  let actorKey;
  const hashedEnv = submitEnv();
  hashedEnv.SUBMIT_ACTOR_RATE_LIMITER = {
    async limit({ key }) { actorKey = key; return { success: true }; },
  };
  await worker.fetch(new Request('https://feedback.example/', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'CF-Connecting-IP': '203.0.113.42',
    },
    body: JSON.stringify({ content: 'test' }),
  }), hashedEnv);
  assert.match(actorKey, /^[a-f0-9]{64}$/);
  assert.doesNotMatch(actorKey, /203\.0\.113\.42/);
});

test('admin reference lookup is authenticated, exact, and parameterized', async () => {
  const db = new MockDB();
  const env = submitEnv(db);
  const cookie = await adminCookie(env);

  const reference = '0123456789abcdef0123456789abcdef';
  const listResponse = await worker.fetch(new Request('https://feedback.example/api/find', {
    method: 'POST',
    headers: { Cookie: cookie, 'Content-Type': 'application/json' },
    body: JSON.stringify({ reference }),
  }), env);
  assert.equal(listResponse.status, 200);

  const listCall = db.calls.find(call => call.operation === 'all');
  assert.match(listCall.sql, /reference = \?/);
  assert.equal(listCall.args[0], reference);
});

test('admin product filtering is allowlisted and parameterized', async () => {
  const db = new MockDB();
  const env = submitEnv(db);
  const cookie = await adminCookie(env);
  const filtered = await worker.fetch(new Request(
    'https://feedback.example/api/list?status=unread&productID=lengyan&page=2&limit=20',
    { headers: { Cookie: cookie } }
  ), env);
  assert.equal(filtered.status, 200);

  const listCall = db.calls.find(call => call.operation === 'all');
  const countCall = db.calls.find(call => call.operation === 'first');
  assert.match(listCall.sql, /product_id = \?/);
  assert.match(listCall.sql, /product_id AS productID/);
  assert.deepEqual(listCall.args, ['lengyan', 20, 20]);
  assert.deepEqual(countCall.args, ['lengyan']);

  const rejectedDB = new MockDB();
  const rejectedEnv = submitEnv(rejectedDB);
  const rejectedCookie = await adminCookie(rejectedEnv);
  const rejected = await worker.fetch(new Request(
    'https://feedback.example/api/list?productID=jingang',
    { headers: { Cookie: rejectedCookie } }
  ), rejectedEnv);
  assert.equal(rejected.status, 400);
  assert.equal((await rejected.json()).error, 'productID is not supported');
  assert.equal(rejectedDB.calls.length, 0);
});

test('admin rejects weak configuration and logout expires the browser session', async () => {
  const weakEnv = submitEnv();
  weakEnv.ADMIN_PASSWORD = 'too-short';
  const rejectedLogin = await worker.fetch(new Request('https://feedback.example/api/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ password: weakEnv.ADMIN_PASSWORD }),
  }), weakEnv);
  assert.equal(rejectedLogin.status, 503);

  const reusedSecretEnv = submitEnv();
  reusedSecretEnv.ADMIN_PASSWORD = 'same secret must not serve two purposes';
  reusedSecretEnv.ADMIN_SESSION_SECRET = reusedSecretEnv.ADMIN_PASSWORD;
  const reusedSecretLogin = await worker.fetch(new Request('https://feedback.example/api/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ password: reusedSecretEnv.ADMIN_PASSWORD }),
  }), reusedSecretEnv);
  assert.equal(reusedSecretLogin.status, 503);

  const logout = await worker.fetch(new Request('https://feedback.example/api/logout', {
    method: 'POST',
  }), {});
  assert.equal(logout.status, 200);
  assert.match(logout.headers.get('Set-Cookie'), /Max-Age=0/);

  const adminPageResponse = await worker.fetch(new Request('https://feedback.example/admin'), {});
  const adminHTML = await adminPageResponse.text();
  assert.match(adminHTML, /onclick="logout\(\)"/);
  assert.match(adminHTML, /id="productFilter"/);
  assert.match(adminHTML, /<option value="lengyan">楞严经<\/option>/);
});

test('scheduled cleanup deletes rows at the 21-day active-table boundary', async () => {
  const db = new MockDB();
  const fixedNow = Date.parse('2026-07-18T12:34:56.789Z');
  const originalDateNow = Date.now;

  try {
    Date.now = () => fixedNow;
    await worker.scheduled({}, { DB: db });
  } finally {
    Date.now = originalDateNow;
  }

  const deletion = db.calls.find(call => call.sql.includes('DELETE FROM feedback'));
  assert.ok(deletion);
  assert.match(deletion.sql, /created_at <= \?/);
  assert.deepEqual(deletion.args, [
    new Date(fixedNow - 21 * 24 * 60 * 60 * 1_000).toISOString(),
  ]);
});

test('scheduled cleanup rejects database failures for operational alerting', async () => {
  await assert.rejects(
    worker.scheduled({}, { DB: new MockDB({ failRun: true }) }),
    /Feedback retention cleanup failed/
  );
});
