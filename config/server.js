#!/usr/bin/env node
/**
 * STA Config Editor — server v2
 *   • static app/public
 *   • /api/health /api/verify（tcl 權威轉換）
 *   • workspace（預設 <root>/workspace，可用 env SCE_WORKSPACE 指定）：
 *       GET  /api/ws/list            目錄樹（二層）
 *       POST /api/ws/write           {path, content} 寫檔
 *       GET  /api/ws/read?path=      讀檔
 *       POST /api/run                {dir, target|targets} → make -C
 *       POST /api/release            打包各 run/index.htm → workspace/release-*.zip
 *       GET  /viewer/*               靜態伺服 workspace（供 iframe 檢視 sta2htm HTML 報告）
 *       GET  /api/download?path=     下載 workspace 內檔案
 */
const http = require("http"), fs = require("fs"), path = require("path");
const { spawnSync } = require("child_process");

const ROOT = __dirname;
const BIN = path.join(ROOT, "bin", "sta2htm_run_json.tcl");
const PUB = path.join(ROOT, "app", "public");
const WS = path.normalize(process.env.SCE_WORKSPACE || path.join(ROOT, "workspace"));
const PORT = Number(process.argv[2] || 3000);
fs.mkdirSync(WS, { recursive: true });

const MIME = { ".html": "text/html; charset=utf-8", ".htm": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8", ".ini": "text/plain; charset=utf-8",
  ".run": "text/plain; charset=utf-8", ".tcl": "text/plain; charset=utf-8",
  ".png": "image/png", ".jpg": "image/jpeg", ".gif": "image/gif",
  ".zip": "application/zip", ".log": "text/plain; charset=utf-8", ".txt": "text/plain; charset=utf-8" };

function send(res, code, body, type) {
  res.writeHead(code, { "Content-Type": type || "text/plain; charset=utf-8" });
  res.end(body);
}
const jsend = (res, obj, code = 200) => send(res, code, JSON.stringify(obj), "application/json; charset=utf-8");
function readBody(req) {
  return new Promise((res, rej) => {
    let d = ""; req.on("data", c => { d += c; if (d.length > 8e6) { rej(new Error("too large")); req.destroy(); } });
    req.on("end", () => res(d)); req.on("error", rej);
  });
}
function safeJoin(rel) {                       // 防 traversal：必須落在 WS 內
  const p = path.normalize(path.join(WS, rel || "."));
  return p.startsWith(WS) ? p : null;
}
function tcl(mode, input) {
  const r = spawnSync("tclsh", [BIN, mode, "-"], { input, encoding: "utf8", maxBuffer: 16e6 });
  if (r.error) return { ok: false, err: String(r.error) };
  return { ok: true, out: r.stdout || "", warn: r.stderr || "", code: r.status };
}
function sh(cmd, args, opts) {
  const r = spawnSync(cmd, args, Object.assign({ encoding: "utf8", maxBuffer: 32e6, timeout: 600000 }, opts || {}));
  return { code: r.status, out: (r.stdout || "") + (r.stderr || ""), err: r.error ? String(r.error) : null };
}

const server = http.createServer(async (req, res) => {
  const u = new URL(req.url, "http://x");
  const p = u.pathname;

  /* ---------- 靜態 ---------- */
  if (req.method === "GET" && !p.startsWith("/api/") && !p.startsWith("/viewer")) {
    let f = p === "/" ? "index.html" : p.slice(1);
    const full = path.normalize(path.join(PUB, f));
    if (full.startsWith(PUB) && fs.existsSync(full) && fs.statSync(full).isFile())
      return send(res, 200, fs.readFileSync(full), MIME[path.extname(full)] || "text/plain; charset=utf-8");
  }

  /* ---------- 健康與權威轉換 ---------- */
  if (p === "/api/health") {
    const probe = spawnSync("tclsh", [BIN, "lint", "-"], { input: "[VERSION]\nG1 reports/v1 uniq_end\n", encoding: "utf8" });
    return jsend(res, { ok: true, tclsh: !probe.error && [0, 1, 3].includes(probe.status), workspace: WS });
  }
  if (req.method === "POST" && p === "/api/verify") {
    const r = tcl("run2json", await readBody(req));
    return jsend(res, { result: r.out, warnings: (r.warn.match(/(WARN|ERROR).*$/gm) || []), ok: r.ok });
  }

  /* ---------- workspace 檔案 ---------- */
  if (p === "/api/ws/list" && req.method === "GET") {
    const walk = (d, depth) => {
      if (depth > 2) return [];
      return fs.readdirSync(d, { withFileTypes: true }).sort((a, b) =>
        (b.isDirectory() - a.isDirectory()) || a.name.localeCompare(b.name)).map(e => ({
        name: e.name, dir: e.isDirectory(),
        children: e.isDirectory() ? walk(path.join(d, e.name), depth + 1) : undefined,
        size: e.isFile() ? fs.statSync(path.join(d, e.name)).size : undefined,
      }));
    };
    return jsend(res, { root: path.basename(WS), tree: walk(WS, 0) });
  }
  if (p === "/api/ws/write" && req.method === "POST") {
    const { path: rel, content } = JSON.parse(await readBody(req));
    const full = safeJoin(rel);
    if (!full) return jsend(res, { error: "path escapes workspace" }, 400);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, content);
    return jsend(res, { ok: true, path: rel, bytes: Buffer.byteLength(content) });
  }
  if (p === "/api/ws/read" && req.method === "GET") {
    const full = safeJoin(u.searchParams.get("path"));
    if (!full || !fs.existsSync(full) || fs.statSync(full).isDirectory())
      return jsend(res, { error: "not found" }, 404);
    return send(res, 200, fs.readFileSync(full), MIME[path.extname(full)] || "text/plain; charset=utf-8");
  }
  if (p === "/api/download" && req.method === "GET") {
    const full = safeJoin(u.searchParams.get("path"));
    if (!full || !fs.existsSync(full)) return send(res, 404, "not found");
    res.writeHead(200, { "Content-Type": "application/octet-stream",
      "Content-Disposition": `attachment; filename="${path.basename(full)}"` });
    return res.end(fs.readFileSync(full));
  }

  /* ---------- 執行 make（runset 層 / mmmc 子目錄） ---------- */
  if (p === "/api/run" && req.method === "POST") {
    const body = JSON.parse(await readBody(req));
    const dir = safeJoin(body.dir || ".");
    if (!dir) return jsend(res, { error: "bad dir" }, 400);
    const targets = body.all ? ["run"] : (body.targets || []);
    if (!targets.length) return jsend(res, { error: "no target" }, 400);
    const env = Object.assign({}, process.env);
    if (body.demo) env.STA_DEMO = "1";
    let log = `$ cd ${path.relative(WS, dir) || "."} && make ${targets.join(" ")}\n`;
    for (const t of targets) {
      const r = sh("make", ["-C", dir, t], { env, timeout: 900000 });
      log += r.out + `\n[exit ${r.code}] ${r.err || ""}\n`;
      if (r.code !== 0) break;
    }
    return jsend(res, { log });
  }

  /* ---------- release：打包所有版本 index.htm 報告 ---------- */
  if (p === "/api/release" && req.method === "POST") {
    const runs = fs.readdirSync(WS).filter(n =>
      fs.existsSync(path.join(WS, n, "index.htm")) && fs.statSync(path.join(WS, n)).isDirectory());
    if (!runs.length) return jsend(res, { error: "workspace 內沒有含 index.htm 的 Run 目錄" }, 400);
    const stamp = new Date().toISOString().slice(0, 10).replace(/-/g, "");
    const zipName = `release_${stamp}.zip`;
    const args = ["-rq", zipName, ...runs.map(r => `${r}/.`), "-x", "*/STA/*"];
    // 讓 zip 內有版本目錄感：先做一層 staging
    const stage = path.join(WS, `.release_${stamp}`);
    fs.rmSync(stage, { recursive: true, force: true });
    fs.mkdirSync(stage, { recursive: true });
    runs.forEach(r => fs.cpSync(path.join(WS, r), path.join(stage, r), { recursive: true }));
    const r = sh("zip", ["-rq", path.join(WS, zipName), "."], { cwd: stage, timeout: 300000 });
    fs.rmSync(stage, { recursive: true, force: true });
    if (r.code !== 0) return jsend(res, { error: "zip failed: " + r.out }, 500);
    return jsend(res, { ok: true, zip: zipName, versions: runs,
      download: `/api/download?path=${encodeURIComponent(zipName)}` });
  }

  /* ---------- viewer：靜態伺服 workspace（sta2htm HTML 報告） ---------- */
  if (req.method === "GET" && p.startsWith("/viewer")) {
    let rel = decodeURIComponent(p.replace(/^\/viewer\/?/, ""));
    let full = safeJoin(rel);
    if (!full) return send(res, 403, "forbidden");
    if (rel === "" || !fs.existsSync(full)) {
      // 預設頁：列出各 Run 的 index.htm
      const runs = fs.readdirSync(WS).filter(n =>
        fs.existsSync(path.join(WS, n, "index.htm")) && fs.statSync(path.join(WS, n)).isDirectory());
      const runsetIdx = fs.existsSync(path.join(WS, "index.htm"));
      const lis = (runsetIdx ? [`<li><a href="/viewer/index.htm">▸ Runset 總索引 index.htm（全版本趨勢）</a></li>`] : [])
        .concat(runs.map(r => `<li><a href="/viewer/${encodeURIComponent(r)}/index.htm">▸ ${r}/index.htm</a></li>`));
      return send(res, 200, `<!DOCTYPE html><meta charset="utf-8"><title>STA Report Viewer</title>
        <body style="font:14px 'Trebuchet MS',Arial;background:#fafafa">
        <h2 style="color:#2e7d32">STA2HTM Report Viewer</h2>
        <p style="color:#666">workspace：${WS}</p>
        <ul style="font-size:15px;line-height:1.9">${lis.join("") || "<li style='color:#c00'>尚無 index.htm —— 先 RUNSET→build→run，或檢查 make 是否成功</li>"}</ul>`,
        "text/html; charset=utf-8");
    }
    if (fs.statSync(full).isDirectory()) full = path.join(full, "index.htm");
    if (!fs.existsSync(full)) return send(res, 404, "not found");
    return send(res, 200, fs.readFileSync(full), MIME[path.extname(full)] || "application/octet-stream");
  }

  send(res, 404, "not found");
});

server.listen(PORT, () => {
  console.log(`STA Config Editor  →  http://localhost:${PORT}`);
  console.log(`workspace = ${WS}`);
});
