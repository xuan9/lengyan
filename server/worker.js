//
//  Cloudflare Worker — 楞严经 App 反馈收集服务
//
//  POST /           →  App 提交反馈（存 D1）
//  GET  /privacy    →  按语言跳转到支持站隐私政策
//  GET  /admin      →  管理页面（HTML）
//  GET  /api/list   →  查询反馈列表（JSON）
//  POST /api/find   →  按随机反馈编号精确查找
//  POST /api/read   →  标记已读
//  DELETE /api/:id  →  删除反馈
//
//  环境变量（wrangler secret put）:
//    ADMIN_PASSWORD        — 至少 16 字符的管理页面密码
//    ADMIN_SESSION_SECRET  — 至少 32 字符，用于签名管理员会话
//

const MAX_FEEDBACK_GRAPHEMES = 2_000;
const MAX_FEEDBACK_UTF8_BYTES = 64 * 1_024;
const MAX_JSON_BODY_UTF8_BYTES = 72 * 1_024;
// Keep active rows for 21 days. D1 Free Time Travel can retain recoverable
// history for up to 7 more days; the remaining margin keeps every copy below
// the public 30-day maximum despite hourly scheduling jitter or a brief retry.
const ACTIVE_DATABASE_RETENTION_DAYS = 21;
const MIN_ADMIN_PASSWORD_LENGTH = 16;
const ADMIN_SESSION_SECONDS = 8 * 60 * 60;
const ADMIN_COOKIE_NAME = '__Host-lengyan_admin';
const REFERENCE_PATTERN = /^[a-f0-9]{32}$/;
const SUPPORT_SITE_ORIGIN = 'https://xuan9.github.io';
const SIMPLIFIED_PRIVACY_URL = 'https://xuan9.github.io/lengyan/privacy.html';
const TRADITIONAL_PRIVACY_URL = 'https://xuan9.github.io/lengyan/privacy-hant.html';

export default {
  async fetch(request, env) {
    let response;
    try {
      response = await routeRequest(request, env);
    } catch {
      // 不记录异常对象或请求正文，避免反馈内容进入平台日志。
      console.error('Unhandled feedback service failure');
      response = json({ error: 'request failed' }, 500);
    }
    return addSubmissionCorsHeaders(request, response);
  },
  async scheduled(_controller, env) {
    try {
      await deleteExpiredFeedback(env);
    } catch {
      // Keep the message generic, but reject the scheduled event so Workers
      // observability can alert on a failed retention cleanup.
      console.error('Feedback retention cleanup failed');
      throw new Error('Feedback retention cleanup failed');
    }
  },
};

async function routeRequest(request, env) {
  const url = new URL(request.url);
  const path = url.pathname;

  // 仅支持站的公开反馈表单可预检 POST /。管理路由永不返回 CORS 授权。
  if (request.method === 'OPTIONS') {
    return handleOptions(request, path);
  }

  // ── App 提交反馈 ──
  if (path === '/' && request.method === 'POST') {
    const origin = request.headers.get('Origin');
    if (origin !== null && origin !== SUPPORT_SITE_ORIGIN) {
      return json({ error: 'origin not allowed' }, 403);
    }
    return handleSubmit(request, env);
  }

  // ── 公开隐私政策（无需管理员配置或登录）──
  if (path === '/privacy' && request.method === 'GET') {
    return privacyRedirect(request);
  }

  // ── 管理页面 ──
  if (path === '/admin' && request.method === 'GET') {
    return adminPage();
  }

  // ── 管理员登录验证 ──
  if (path === '/api/login' && request.method === 'POST') {
    return handleLogin(request, env);
  }
  if (path === '/api/logout' && request.method === 'POST') {
    return handleLogout();
  }

  // ── 以下 API 需要签名管理员会话 ──
  if (!adminConfigurationIsValid(env)) {
    return json({ error: 'service unavailable' }, 503);
  }
  const adminToken = cookieValue(request, ADMIN_COOKIE_NAME);
  if (!adminToken || !(await verifyAdminSession(adminToken, env.ADMIN_SESSION_SECRET))) {
    return json({ error: 'unauthorized' }, 401);
  }

  if (path === '/api/list' && request.method === 'GET') {
    return handleList(url, env);
  }
  if (path === '/api/find' && request.method === 'POST') {
    return handleFind(request, env);
  }
  if (path === '/api/read' && request.method === 'POST') {
    return handleRead(request, env);
  }
  if (path.startsWith('/api/') && request.method === 'DELETE') {
    return handleDelete(path, env);
  }

  return json({ error: 'not found' }, 404);
}

function handleOptions(request, path) {
  const headers = new Headers({
    'Allow': path === '/' ? 'POST, OPTIONS' : 'GET, POST, DELETE, OPTIONS',
    'Cache-Control': 'no-store',
  });
  if (path !== '/' || request.headers.get('Origin') !== SUPPORT_SITE_ORIGIN) {
    return new Response(null, { status: 204, headers });
  }

  const requestedMethod = request.headers.get('Access-Control-Request-Method')
    ?.trim().toUpperCase();
  const requestedHeaders = (request.headers.get('Access-Control-Request-Headers') || '')
    .split(',')
    .map(value => value.trim().toLowerCase())
    .filter(Boolean);
  const requestsOnlyAllowedHeaders = requestedHeaders.every(value => value === 'content-type');
  if (requestedMethod !== 'POST' || !requestsOnlyAllowedHeaders) {
    return new Response(null, { status: 204, headers });
  }

  setSubmissionCorsHeaders(headers);
  return new Response(null, { status: 204, headers });
}

function addSubmissionCorsHeaders(request, response) {
  const url = new URL(request.url);
  if (url.pathname !== '/'
    || request.method !== 'POST'
    || request.headers.get('Origin') !== SUPPORT_SITE_ORIGIN) {
    return response;
  }

  const headers = new Headers(response.headers);
  setSubmissionCorsHeaders(headers);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

function setSubmissionCorsHeaders(headers) {
  headers.set('Access-Control-Allow-Origin', SUPPORT_SITE_ORIGIN);
  headers.set('Access-Control-Allow-Methods', 'POST');
  headers.set('Access-Control-Allow-Headers', 'Content-Type');
  headers.set('Cache-Control', 'no-store');

  const varyValues = (headers.get('Vary') || '')
    .split(',')
    .map(value => value.trim())
    .filter(Boolean);
  if (!varyValues.some(value => value.toLowerCase() === 'origin')) {
    varyValues.push('Origin');
  }
  headers.set('Vary', varyValues.join(', '));
}

// ── 提交反馈 ──

async function handleSubmit(request, env) {
  const rateLimitResponse = await enforceRequestRateLimits(
    request,
    env.ADMIN_SESSION_SECRET,
    env.SUBMIT_ACTOR_RATE_LIMITER,
    env.SUBMIT_LOCATION_RATE_LIMITER,
    'feedback-submit'
  );
  if (rateLimitResponse) return rateLimitResponse;

  if (!request.headers.get('Content-Type')?.toLowerCase().includes('application/json')) {
    return json({ error: 'content type must be application/json' }, 415);
  }

  const parsed = await readJsonBody(request, MAX_JSON_BODY_UTF8_BYTES);
  if (!parsed.ok) {
    return json({ error: parsed.error }, parsed.status);
  }

  const body = parsed.value;
  const content = typeof body.content === 'string' ? body.content.trim() : '';
  if (!content) {
    return json({ error: 'content is required' }, 400);
  }
  if (utf8ByteLength(content) > MAX_FEEDBACK_UTF8_BYTES) {
    return json({ error: 'content is too long' }, 413);
  }
  if (graphemeCountExceeds(content, MAX_FEEDBACK_GRAPHEMES)) {
    return json({ error: 'content is too long' }, 413);
  }

  const now = new Date();
  // Device, OS, and build diagnostics are deliberately ignored, even if a
  // modified or older client sends them. Keep only the shared public App version.
  // Legacy releases combined that version with a build number, so their
  // ambiguous value is blanked as well.
  const isLegacySubmission = ['device', 'os'].some(key => (
    Object.prototype.hasOwnProperty.call(body, key)
  ));
  const appVersion = isLegacySubmission ? '' : cleanMetadata(body.appVersion, 50);
  const reference = createFeedbackReference();

  // 存入 D1
  try {
    await env.DB.prepare(
      `INSERT INTO feedback
       (reference, content, app_version, created_at)
       VALUES (?, ?, ?, ?)`
    ).bind(
      reference,
      content,
      appVersion,
      now.toISOString()
    ).run();
  } catch {
    // 不把异常对象、SQL 参数或反馈正文写入日志。
    console.error('Feedback storage failed');
    return json({ error: 'storage failed' }, 500);
  }

  return json({ ok: true, reference });
}

// ── 登录 ──

async function handleLogin(request, env) {
  const rateLimitResponse = await enforceRequestRateLimits(
    request,
    env.ADMIN_SESSION_SECRET,
    env.LOGIN_ACTOR_RATE_LIMITER,
    env.LOGIN_LOCATION_RATE_LIMITER,
    'admin-login'
  );
  if (rateLimitResponse) return rateLimitResponse;

  if (!adminConfigurationIsValid(env)) {
    return json({ error: 'service unavailable' }, 503);
  }

  const parsed = await readJsonBody(request, 2_000);
  if (!parsed.ok || typeof parsed.value.password !== 'string') {
    return json({ error: 'invalid request' }, 400);
  }
  if (!(await secretsMatch(parsed.value.password, env.ADMIN_PASSWORD))) {
    return json({ error: 'wrong password' }, 401);
  }

  const sessionToken = await createAdminSession(env.ADMIN_SESSION_SECRET);
  return json({ ok: true }, 200, {
    'Set-Cookie': `${ADMIN_COOKIE_NAME}=${sessionToken}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${ADMIN_SESSION_SECONDS}`,
  });
}

function handleLogout() {
  return json({ ok: true }, 200, {
    'Set-Cookie': `${ADMIN_COOKIE_NAME}=; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=0`,
  });
}

// ── 列表查询 ──

async function handleList(url, env) {
  const requestedPage = Number.parseInt(url.searchParams.get('page') || '1', 10);
  const requestedLimit = Number.parseInt(url.searchParams.get('limit') || '20', 10);
  const page = Number.isSafeInteger(requestedPage) && requestedPage > 0 ? requestedPage : 1;
  const limit = Number.isSafeInteger(requestedLimit)
    ? Math.min(Math.max(requestedLimit, 1), 100)
    : 20;
  const status = url.searchParams.get('status'); // unread | read | all
  const offset = (page - 1) * limit;

  const conds = [];
  const params = [];
  if (status === 'unread') { conds.push('is_read = 0'); }
  else if (status === 'read') { conds.push('is_read = 1'); }
  const where = conds.length ? 'WHERE ' + conds.join(' AND ') : '';

  const [items, countResult] = await Promise.all([
    env.DB.prepare(
      `SELECT id, reference, content, app_version, is_read, created_at
       FROM feedback ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`
    ).bind(...params, limit, offset).all(),
    env.DB.prepare(`SELECT COUNT(*) as total FROM feedback ${where}`).bind(...params).first(),
  ]);

  return json({
    items: items.results,
    total: Number(countResult?.total || 0),
    page,
    limit,
  });
}

async function handleFind(request, env) {
  const parsed = await readJsonBody(request, 512);
  const reference = parsed.ok && typeof parsed.value.reference === 'string'
    ? parsed.value.reference.trim().toLowerCase()
    : '';
  if (!REFERENCE_PATTERN.test(reference)) {
    return json({ items: [], total: 0, page: 1, limit: 1 });
  }

  const result = await env.DB.prepare(
    `SELECT id, reference, content, app_version, is_read, created_at
     FROM feedback WHERE reference = ? LIMIT 1`
  ).bind(reference).all();
  const items = result.results || [];
  return json({ items, total: items.length, page: 1, limit: 1 });
}

// ── 标记已读 ──

async function handleRead(request, env) {
  const parsed = await readJsonBody(request, 4_000);
  if (!parsed.ok) return json({ error: 'invalid request' }, 400);
  const ids = Array.isArray(parsed.value.ids)
    ? parsed.value.ids.filter(id => Number.isSafeInteger(id) && id > 0).slice(0, 100)
    : [];
  if (!ids.length) return json({ error: 'ids required' }, 400);

  const placeholders = ids.map(() => '?').join(',');
  await env.DB.prepare(`UPDATE feedback SET is_read = 1 WHERE id IN (${placeholders})`).bind(...ids).run();
  return json({ ok: true });
}

// ── 删除 ──

async function handleDelete(path, env) {
  const id = path.replace('/api/', '');
  if (!id || !/^\d+$/.test(id)) return json({ error: 'invalid id' }, 400);
  await env.DB.prepare('DELETE FROM feedback WHERE id = ?').bind(id).run();
  return json({ ok: true });
}

// ── 公开隐私政策 ──

function privacyRedirect(request) {
  const destination = prefersTraditionalChinese(request.headers.get('Accept-Language'))
    ? TRADITIONAL_PRIVACY_URL
    : SIMPLIFIED_PRIVACY_URL;
  return new Response(null, {
    status: 302,
    headers: {
      'Location': destination,
      'Cache-Control': 'no-store',
      'Vary': 'Accept-Language',
      'Referrer-Policy': 'no-referrer',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

function prefersTraditionalChinese(acceptLanguage) {
  if (typeof acceptLanguage !== 'string') return false;

  const candidates = [];
  for (const [index, entry] of acceptLanguage.split(',').entries()) {
    const [languageRange, ...parameters] = entry.trim().split(';');
    const tag = languageRange.trim().toLowerCase().replaceAll('_', '-');
    if (tag !== 'zh' && !tag.startsWith('zh-')) continue;

    let quality = 1;
    for (const parameter of parameters) {
      const match = /^\s*q\s*=\s*(0(?:\.\d{0,3})?|1(?:\.0{0,3})?)\s*$/i.exec(parameter);
      if (match) quality = Number(match[1]);
    }
    if (quality <= 0) continue;

    const subtags = tag.split('-').slice(1);
    let traditional;
    if (subtags.includes('hant')) traditional = true;
    else if (subtags.includes('hans')) traditional = false;
    else traditional = subtags.some(subtag => ['tw', 'hk', 'mo'].includes(subtag));
    candidates.push({ traditional, quality, index });
  }

  candidates.sort((left, right) => (
    right.quality - left.quality || left.index - right.index
  ));
  return candidates[0]?.traditional === true;
}

// ── 管理页面 ──

function adminPage() {
  const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>楞严经 · 反馈管理</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #FAF8F3; color: #33231A; min-height: 100vh; }
  .login { max-width: 360px; margin: 120px auto; text-align: center; }
  .login h1 { font-size: 20px; margin-bottom: 24px; font-weight: 400; letter-spacing: 2px; }
  .login input { width: 100%; padding: 12px 16px; border: 1px solid #C4A265; border-radius: 8px; font-size: 15px; outline: none; background: #fff; }
  .login input:focus { border-color: #228B22; }
  .login button { width: 100%; padding: 12px; background: #228B22; color: #fff; border: none; border-radius: 8px; font-size: 15px; margin-top: 12px; cursor: pointer; }
  .header { background: #FAF8F3; border-bottom: 1px solid #e8dfd0; padding: 16px 24px; display: flex; align-items: center; justify-content: space-between; position: sticky; top: 0; z-index: 10; }
  .header h1 { font-size: 17px; font-weight: 500; letter-spacing: 1px; }
  .header-meta { display: flex; align-items: center; gap: 14px; color: #999; font-size: 13px; }
  .logout { border: 0; padding: 4px 0; background: transparent; color: #756b63; cursor: pointer; }
  .filters { display: flex; gap: 8px; padding: 12px 24px; }
  .filters button { padding: 6px 14px; border: 1px solid #d4c5a9; border-radius: 16px; background: #fff; color: #4A3728; font-size: 13px; cursor: pointer; }
  .filters button.active { background: #228B22; color: #fff; border-color: #228B22; }
  .reference-search { display: flex; gap: 8px; padding: 0 24px 12px; }
  .reference-search input { flex: 1; max-width: 420px; padding: 8px 12px; border: 1px solid #d4c5a9; border-radius: 8px; background: #fff; }
  .reference-search button { padding: 8px 14px; border: 1px solid #d4c5a9; border-radius: 8px; background: #fff; cursor: pointer; }
  .list { padding: 0 24px; }
  .item { background: #fff; border-radius: 10px; padding: 16px; margin-bottom: 10px; border: 1px solid #e8dfd0; }
  .item.unread { border-left: 3px solid #C4A265; }
  .item-content { font-size: 15px; line-height: 1.7; white-space: pre-wrap; margin-bottom: 8px; }
  .item-meta { font-size: 12px; color: #999; display: flex; justify-content: space-between; align-items: center; }
  .item-meta span { background: #f5f0e8; padding: 2px 8px; border-radius: 10px; font-size: 11px; }
  .item-actions { margin-top: 8px; display: flex; gap: 8px; }
  .item-actions button { padding: 4px 10px; border: 1px solid #ddd; border-radius: 6px; background: #fff; font-size: 12px; cursor: pointer; color: #666; }
  .item-actions button:hover { border-color: #228B22; color: #228B22; }
  .item-actions .del:hover { border-color: #c00; color: #c00; }
  .empty { text-align: center; padding: 80px 0; color: #999; font-size: 14px; }
  .pager { text-align: center; padding: 20px; }
  .pager button { padding: 8px 20px; border: 1px solid #d4c5a9; border-radius: 8px; background: #fff; cursor: pointer; margin: 0 4px; }
  .hidden { display: none; }
</style>
</head>
<body>

<div id="loginView" class="login">
  <h1>🪷 反馈管理</h1>
  <input type="password" id="pw" placeholder="输入管理密码" onkeydown="if(event.key==='Enter')login()">
  <button onclick="login()">进入</button>
</div>

<div id="mainView" class="hidden">
  <div class="header">
    <h1>🪷 反馈管理</h1>
    <div class="header-meta"><span id="unreadCount"></span><button class="logout" onclick="logout()">退出</button></div>
  </div>
  <div class="filters">
    <button class="active" onclick="filter('all',this)">全部</button>
    <button onclick="filter('unread',this)">未读</button>
    <button onclick="filter('read',this)">已读</button>
  </div>
  <div class="reference-search">
    <input id="reference" maxlength="32" autocomplete="off" placeholder="按 32 位反馈编号精确查找" onkeydown="if(event.key==='Enter')searchReference()">
    <button onclick="searchReference()">查找</button>
    <button onclick="clearReference()">清除</button>
  </div>
  <div class="list" id="list"></div>
  <div class="pager" id="pager"></div>
</div>

<script>
let currentFilter='all', currentPage=1;
async function login(){
  const pw=document.getElementById('pw').value;
  const r=await fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({password:pw})});
  if(r.ok){document.getElementById('pw').value='';document.getElementById('loginView').classList.add('hidden');document.getElementById('mainView').classList.remove('hidden');load();}
  else{document.getElementById('pw').style.borderColor='red';}
}
async function logout(){
  const r=await fetch('/api/logout',{method:'POST'});
  if(!r.ok)return;
  document.getElementById('pw').value='';
  document.getElementById('reference').value='';
  document.getElementById('mainView').classList.add('hidden');
  document.getElementById('loginView').classList.remove('hidden');
}
async function load(){
  const reference=document.getElementById('reference').value.trim().toLowerCase();
  const url=reference?'/api/find':'/api/list?status='+currentFilter+'&page='+currentPage+'&limit=20';
  const options=reference?{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({reference})}:{};
  const r=await fetch(url,options);
  if(!r.ok){document.getElementById('mainView').classList.add('hidden');document.getElementById('loginView').classList.remove('hidden');return;}
  const d=await r.json();
  const list=document.getElementById('list');
  document.getElementById('unreadCount').textContent=d.total+' 条';
  if(!d.items.length){list.innerHTML='<div class="empty">暂无反馈</div>';document.getElementById('pager').innerHTML='';return;}
  list.innerHTML=d.items.map(i=>'<div class="item '+(i.is_read?'':'unread')+'"><div class="item-content">'+esc(i.content)+'</div><div class="item-meta"><div>编号 '+esc(i.reference)+' · '+diagnostics(i)+'</div><div>'+fmtTime(i.created_at)+'</div></div><div class="item-actions">'+(i.is_read?'':'<button onclick="markRead(['+i.id+'])">已读</button>')+'<button class="del" onclick="del('+i.id+')">删除</button></div></div>').join('');
  const totalPages=Math.ceil(d.total/20);
  document.getElementById('pager').innerHTML=totalPages>1?'<button '+(currentPage<=1?'disabled':'')+' onclick="currentPage--;load()">上一页</button> '+currentPage+'/'+totalPages+' <button '+(currentPage>=totalPages?'disabled':'')+' onclick="currentPage++;load()">下一页</button>':'';
}
function filter(s,btn){currentFilter=s;currentPage=1;document.querySelectorAll('.filters button').forEach(b=>b.classList.remove('active'));btn.classList.add('active');load();}
function searchReference(){currentPage=1;load();}
function clearReference(){document.getElementById('reference').value='';currentPage=1;load();}
async function markRead(ids){await fetch('/api/read',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({ids})});load();}
async function del(id){if(!confirm('确认删除？'))return;await fetch('/api/'+id,{method:'DELETE'});load();}
function esc(s){if(!s)return'';return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function diagnostics(i){return i.app_version?'v'+esc(i.app_version):'无版本信息';}
function fmtTime(s){const d=new Date(s);return d.toLocaleDateString('zh-CN')+' '+d.toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'});}
</script>
</body>
</html>`;
  return new Response(html, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
      'Content-Security-Policy': "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
      'Referrer-Policy': 'no-referrer',
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
    },
  });
}

// ── 工具函数 ──

function json(data, status = 200, additionalHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      ...additionalHeaders,
    },
  });
}

async function readJsonBody(request, maximumUTF8Bytes) {
  const contentLength = request.headers.get('Content-Length');
  const declaredLength = contentLength === null ? null : Number.parseInt(contentLength, 10);
  if (declaredLength !== null
    && Number.isFinite(declaredLength)
    && declaredLength > maximumUTF8Bytes) {
    return { ok: false, error: 'request is too large', status: 413 };
  }

  const reader = request.body?.getReader();
  const chunks = [];
  let totalBytes = 0;

  try {
    while (reader) {
      const { done, value } = await reader.read();
      if (done) break;

      totalBytes += value.byteLength;
      if (totalBytes > maximumUTF8Bytes) {
        try {
          await reader.cancel();
        } catch {
          // The response is already fixed at 413; cancellation failure is benign.
        }
        return { ok: false, error: 'request is too large', status: 413 };
      }
      chunks.push(value);
    }
  } catch {
    return { ok: false, error: 'invalid request', status: 400 };
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  let raw;
  try {
    raw = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch {
    return { ok: false, error: 'invalid request', status: 400 };
  }

  try {
    const value = JSON.parse(raw);
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      return { ok: false, error: 'invalid JSON object', status: 400 };
    }
    return { ok: true, value };
  } catch {
    return { ok: false, error: 'invalid JSON', status: 400 };
  }
}

function cleanMetadata(value, maximumLength) {
  if (typeof value !== 'string') return '';
  return Array.from(value.trim()).slice(0, maximumLength).join('');
}

function utf8ByteLength(value) {
  return new TextEncoder().encode(value).byteLength;
}

function graphemeCountExceeds(value, maximumCount) {
  // Intl.Segmenter uses Unicode grapheme clusters, matching Swift String.count
  // much more closely than JavaScript's UTF-16 String.length.
  if (typeof Intl?.Segmenter !== 'function') {
    // Current Workers support Segmenter. Fail closed if a future/runtime-local
    // environment does not, rather than silently accepting oversized content.
    return true;
  }

  const segmenter = new Intl.Segmenter('zh', { granularity: 'grapheme' });
  let count = 0;
  for (const _segment of segmenter.segment(value)) {
    count += 1;
    if (count > maximumCount) return true;
  }
  return false;
}

function createFeedbackReference() {
  return crypto.randomUUID().replaceAll('-', '').toLowerCase();
}

async function enforceRequestRateLimits(request, secret, actorLimiter, locationLimiter, scope) {
  if (typeof secret !== 'string' || secret.length < 32
    || !actorLimiter || typeof actorLimiter.limit !== 'function'
    || !locationLimiter || typeof locationLimiter.limit !== 'function') {
    console.error('Required rate limiter binding is unavailable');
    return json({ error: 'service unavailable' }, 503);
  }

  try {
    // Cloudflare already sees the connection address. Only an HMAC-derived,
    // route-scoped value enters the short-lived counter; raw IPs are never
    // logged by this Worker or stored in D1.
    const address = request.headers.get('CF-Connecting-IP') || 'unavailable';
    const actorKey = await signSessionPayload(`rate-limit:${scope}:${address}`, secret);
    const actorResult = await actorLimiter.limit({ key: actorKey });
    if (!actorResult?.success) {
      return json({ error: 'too many requests' }, 429, { 'Retry-After': '60' });
    }

    // Do not let an already-limited source consume the shared location budget.
    const locationResult = await locationLimiter.limit({ key: scope });
    if (!locationResult?.success) {
      return json({ error: 'too many requests' }, 429, { 'Retry-After': '60' });
    }
    return null;
  } catch {
    console.error('Rate limiter failed');
    return json({ error: 'service unavailable' }, 503);
  }
}

function adminConfigurationIsValid(env) {
  return typeof env.ADMIN_PASSWORD === 'string'
    && env.ADMIN_PASSWORD.length >= MIN_ADMIN_PASSWORD_LENGTH
    && typeof env.ADMIN_SESSION_SECRET === 'string'
    && env.ADMIN_SESSION_SECRET.length >= 32
    && env.ADMIN_PASSWORD !== env.ADMIN_SESSION_SECRET;
}

async function deleteExpiredFeedback(env) {
  const retentionMilliseconds = ACTIVE_DATABASE_RETENTION_DAYS * 24 * 60 * 60 * 1000;
  const cutoff = new Date(Date.now() - retentionMilliseconds).toISOString();
  await env.DB.prepare('DELETE FROM feedback WHERE created_at <= ?').bind(cutoff).run();
}

async function secretsMatch(provided, expected) {
  const encoder = new TextEncoder();
  const [providedHash, expectedHash] = await Promise.all([
    crypto.subtle.digest('SHA-256', encoder.encode(provided)),
    crypto.subtle.digest('SHA-256', encoder.encode(expected)),
  ]);
  return constantTimeBytesEqual(new Uint8Array(providedHash), new Uint8Array(expectedHash));
}

async function createAdminSession(secret) {
  const expiresAt = Math.floor(Date.now() / 1000) + ADMIN_SESSION_SECONDS;
  const nonce = crypto.randomUUID().replaceAll('-', '');
  const payload = String(expiresAt) + '.' + nonce;
  const signature = await signSessionPayload(payload, secret);
  return payload + '.' + signature;
}

async function verifyAdminSession(token, secret) {
  if (typeof token !== 'string' || token.length > 256) return false;

  const parts = token.split('.');
  if (parts.length !== 3) return false;
  const [expiresAtText, nonce, signature] = parts;
  if (!/^\d{10}$/.test(expiresAtText)
    || !/^[a-f0-9]{32}$/.test(nonce)
    || !/^[a-f0-9]{64}$/.test(signature)) {
    return false;
  }

  const expiresAt = Number.parseInt(expiresAtText, 10);
  const now = Math.floor(Date.now() / 1000);
  if (expiresAt <= now || expiresAt > now + ADMIN_SESSION_SECONDS) return false;

  const expected = await signSessionPayload(expiresAtText + '.' + nonce, secret);
  return constantTimeStringEqual(signature, expected);
}

async function signSessionPayload(payload, secret) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(payload));
  return Array.from(new Uint8Array(signature), byte => byte.toString(16).padStart(2, '0')).join('');
}

function constantTimeBytesEqual(left, right) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left[index] ^ right[index];
  }
  return difference === 0;
}

function constantTimeStringEqual(left, right) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

function cookieValue(request, name) {
  const cookieHeader = request.headers.get('Cookie') || '';
  for (const entry of cookieHeader.split(';')) {
    const separator = entry.indexOf('=');
    if (separator < 0) continue;
    if (entry.slice(0, separator).trim() === name) {
      return entry.slice(separator + 1).trim();
    }
  }
  return null;
}
