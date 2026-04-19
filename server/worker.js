//
//  Cloudflare Worker — 楞严经 App 反馈收集服务
//
//  POST /           →  App 提交反馈（存 D1）
//  GET  /admin      →  管理页面（HTML）
//  GET  /api/list   →  查询反馈列表（JSON）
//  POST /api/read   →  标记已读
//  DELETE /api/:id  →  删除反馈
//
//  环境变量（wrangler secret put）:
//    FEEDBACK_API_KEY   — App 端请求头 X-API-Key
//    ADMIN_PASSWORD     — 管理页面密码
//

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders() });
    }

    // ── App 提交反馈 ──
    if (path === '/' && request.method === 'POST') {
      return handleSubmit(request, env);
    }

    // ── 管理页面 ──
    if (path === '/admin' && request.method === 'GET') {
      return adminPage(env);
    }

    // ── 管理员登录验证 ──
    if (path === '/api/login' && request.method === 'POST') {
      return handleLogin(request, env);
    }

    // ── 以下 API 需要管理员 cookie ──
    const adminCookie = request.headers.get('Cookie') || '';
    if (!adminCookie.includes(`admin_token=${env.ADMIN_PASSWORD || 'admin'}`)) {
      return json({ error: 'unauthorized' }, 401);
    }

    if (path === '/api/list' && request.method === 'GET') {
      return handleList(url, env);
    }
    if (path === '/api/read' && request.method === 'POST') {
      return handleRead(request, env);
    }
    if (path.startsWith('/api/') && request.method === 'DELETE') {
      return handleDelete(path, env);
    }

    return json({ error: 'not found' }, 404);
  },
};

// ── 提交反馈 ──

async function handleSubmit(request, env) {
  const apiKey = request.headers.get('X-API-Key');
  if (!apiKey || apiKey !== env.FEEDBACK_API_KEY) {
    return json({ error: 'unauthorized' }, 401);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'invalid json' }, 400);
  }

  const { content, type } = body;
  if (!content || !content.trim()) {
    return json({ error: 'content is required' }, 400);
  }

  const now = new Date();
  const device = body.device || '';
  const os = body.os || '';
  const appVersion = body.appVersion || '';
  const deviceId = body.deviceId || '';

  // 存入 D1
  try {
    await env.DB.prepare(
      'INSERT INTO feedback (content, type, device, os, app_version, device_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(content.trim(), type || 'feedback', device, os, appVersion, deviceId, now.toISOString()).run();
  } catch (e) {
    console.error('D1 insert error:', e);
    return json({ error: 'storage failed' }, 500);
  }

  return json({ ok: true });
}

// ── 登录 ──

async function handleLogin(request, env) {
  let body;
  try { body = await request.json(); } catch { return json({ error: 'invalid' }, 400); }
  if (body.password !== (env.ADMIN_PASSWORD || 'admin')) {
    return json({ error: 'wrong password' }, 401);
  }
  return new Response(JSON.stringify({ ok: true }), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Set-Cookie': `admin_token=${env.ADMIN_PASSWORD || 'admin'}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=86400`,
    },
  });
}

// ── 列表查询 ──

async function handleList(url, env) {
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = parseInt(url.searchParams.get('limit') || '20');
  const status = url.searchParams.get('status'); // unread | read | all
  const deviceId = url.searchParams.get('device_id') || '';
  const offset = (page - 1) * limit;

  const conds = [];
  const params = [];
  if (status === 'unread') { conds.push('is_read = 0'); }
  else if (status === 'read') { conds.push('is_read = 1'); }
  if (deviceId) { conds.push('device_id = ?'); params.push(deviceId); }
  const where = conds.length ? 'WHERE ' + conds.join(' AND ') : '';

  const [items, countResult] = await Promise.all([
    env.DB.prepare(`SELECT * FROM feedback ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`).bind(...params, limit, offset).all(),
    env.DB.prepare(`SELECT COUNT(*) as total FROM feedback ${where}`).bind(...params).first(),
  ]);

  return json({
    items: items.results,
    total: countResult.total,
    page,
    limit,
  });
}

// ── 标记已读 ──

async function handleRead(request, env) {
  let body;
  try { body = await request.json(); } catch { return json({ error: 'invalid' }, 400); }
  const { ids } = body;
  if (!ids || !ids.length) return json({ error: 'ids required' }, 400);

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

// ── 管理页面 ──

function adminPage(env) {
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
  .filters { display: flex; gap: 8px; padding: 12px 24px; }
  .filters button { padding: 6px 14px; border: 1px solid #d4c5a9; border-radius: 16px; background: #fff; color: #4A3728; font-size: 13px; cursor: pointer; }
  .filters button.active { background: #228B22; color: #fff; border-color: #228B22; }
  .list { padding: 0 24px; }
  .item { background: #fff; border-radius: 10px; padding: 16px; margin-bottom: 10px; border: 1px solid #e8dfd0; }
  .item.unread { border-left: 3px solid #C4A265; }
  .item-content { font-size: 15px; line-height: 1.7; white-space: pre-wrap; margin-bottom: 8px; }
  .item-meta { font-size: 12px; color: #999; display: flex; justify-content: space-between; align-items: center; }
  .item-meta span { background: #f5f0e8; padding: 2px 8px; border-radius: 10px; font-size: 11px; }
  .did { cursor: pointer; color: #999; margin-left: 6px; }
  .did:hover { color: #228B22; }
  #deviceFilter { display: none; background: #fff; margin: 0 24px; padding: 8px 14px; border-radius: 8px; font-size: 13px; color: #228B22; cursor: pointer; border: 1px dashed #C4A265; }
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
    <div id="unreadCount" style="font-size:13px;color:#999"></div>
  </div>
  <div class="filters">
    <button class="active" onclick="filter('all',this)">全部</button>
    <button onclick="filter('unread',this)">未读</button>
    <button onclick="filter('read',this)">已读</button>
  </div>
  <div id="deviceFilter" onclick="clearDevice()"></div>
  <div class="list" id="list"></div>
  <div class="pager" id="pager"></div>
</div>

<script>
let currentFilter='all', currentPage=1, currentDeviceId='';
async function login(){
  const pw=document.getElementById('pw').value;
  const r=await fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({password:pw})});
  if(r.ok){document.getElementById('loginView').classList.add('hidden');document.getElementById('mainView').classList.remove('hidden');load();}
  else{document.getElementById('pw').style.borderColor='red';}
}
async function load(){
  let url='/api/list?status='+currentFilter+'&page='+currentPage+'&limit=20';
  if(currentDeviceId)url+='&device_id='+encodeURIComponent(currentDeviceId);
  const r=await fetch(url);
  if(!r.ok)return document.getElementById('loginView').classList.remove('hidden');
  const d=await r.json();
  const list=document.getElementById('list');
  if(currentDeviceId){document.getElementById('deviceFilter').textContent='设备 '+currentDeviceId.substring(0,8)+'… 的反馈 (点击清除)';document.getElementById('deviceFilter').classList.remove('hidden');}
  else{document.getElementById('deviceFilter').classList.add('hidden');}
  if(!d.items.length){list.innerHTML='<div class="empty">暂无反馈</div>';document.getElementById('pager').innerHTML='';return;}
  list.innerHTML=d.items.map(i=>'<div class="item '+(i.is_read?'':'unread')+'"><div class="item-content">'+esc(i.content)+'</div><div class="item-meta"><div>'+typeBadge(i.type)+' · 📱 '+esc(i.device||'未知')+' · '+esc(i.os||'')+' · v'+esc(i.app_version||'?')+'<span class="did" onclick="filterDevice(\\''+esc(i.device_id)+'\\')" title="查看此设备所有反馈">🔑'+(i.device_id?i.device_id.substring(0,8)+'…':'无')+'</span></div><div>'+fmtTime(i.created_at)+'</div></div><div class="item-actions">'+(i.is_read?'':'<button onclick="markRead(['+i.id+'])">已读</button>')+'<button class="del" onclick="del('+i.id+')">删除</button></div></div>').join('');
  document.getElementById('unreadCount').textContent=d.total+' 条';
  const totalPages=Math.ceil(d.total/20);
  document.getElementById('pager').innerHTML=totalPages>1?'<button '+(currentPage<=1?'disabled':'')+' onclick="currentPage--;load()">上一页</button> '+currentPage+'/'+totalPages+' <button '+(currentPage>=totalPages?'disabled':'')+' onclick="currentPage++;load()">下一页</button>':'';
}
function filter(s,btn){currentFilter=s;currentPage=1;currentDeviceId='';document.querySelectorAll('.filters button').forEach(b=>b.classList.remove('active'));btn.classList.add('active');load();}
function filterDevice(did){currentDeviceId=did;currentPage=1;load();}
function clearDevice(){currentDeviceId='';currentPage=1;load();}
async function markRead(ids){await fetch('/api/read',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({ids})});load();}
async function del(id){if(!confirm('确认删除？'))return;await fetch('/api/'+id,{method:'DELETE'});load();}
function esc(s){if(!s)return'';return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
function typeBadge(t){const m={bug:'🐛 Bug',suggestion:'💡 建议',feedback:'🪷 反馈'};return '<span>'+(m[t]||'🪷 反馈')+'</span>';}
function fmtTime(s){const d=new Date(s);return d.toLocaleDateString('zh-CN')+' '+d.toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'});}
</script>
</body>
</html>`;
  return new Response(html, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
}

// ── 工具函数 ──

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders() },
  });
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-API-Key',
  };
}

function typeLabel(type) {
  return { bug: 'Bug', suggestion: '建议', feedback: '反馈' }[type] || '反馈';
}
