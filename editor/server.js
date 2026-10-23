#!/usr/bin/env node
/**
 * STA2HTM Run Editor — Node.js server
 *   • 靜態服務 public/
 *   • /api/run2json | /api/json2run | /api/verify  → 以 tclsh 呼叫權威轉換器
 *   • /examples/*   → 示範 runset 與 JSON
 * 啟動：node server.js [port]   （預設 3000）
 */
const http = require("http"), fs = require("fs"), path = require("path");
const { spawnSync } = require("child_process");

const ROOT = __dirname;
const BIN = path.join(ROOT, "bin", "sta2htm_run_json.tcl");
const PUB = path.join(ROOT, "app", "public");
const EXA = path.join(ROOT, "examples");
const PORT = Number(process.argv[2] || 3000);

const MIME = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8", ".json": "application/json; charset=utf-8",
  ".run": "text/plain; charset=utf-8", ".md": "text/plain; charset=utf-8", ".svg": "image/svg+xml" };

function send(res, code, body, type) {
  res.writeHead(code, { "Content-Type": type || "text/plain; charset=utf-8" });
  res.end(body);
}
function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", c => { data += c; if (data.length > 4e6) { reject(new Error("too large")); req.destroy(); } });
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });
}

/** 以 tclsh 執行權威轉換器；mode: run2json|json2run|lint；input 為檔案內容 */
function tcl(mode, input) {
  const r = spawnSync("tclsh", [BIN, mode, "-"], { input, encoding: "utf8", maxBuffer: 16e6 });
  if (r.error && r.error.code === "ENOENT") return { ok: false, err: "tclsh not found on server — use client-side engine" };
  return { ok: r.status === 0 || r.status === 1, out: r.stdout || "", warn: r.stderr || "", code: r.status };
}

const server = http.createServer(async (req, res) => {
  const u = new URL(req.url, "http://x");
  const p = u.pathname;

  if (req.method === "POST" && (p === "/api/run2json" || p === "/api/json2run" || p === "/api/lint")) {
    let body; try { body = await readBody(req); } catch (e) { return send(res, 413, "payload too large"); }
    let mode = p.slice(5);
    const inp = String(body);
    const r = tcl(mode, inp);
    if (!r.ok) return send(res, 503, JSON.stringify({ error: r.err || "tcl failed" }) , "application/json; charset=utf-8");
    const warnings = (r.warn.match(/(WARN|ERROR).*$/gm) || []);
    return send(res, 200, JSON.stringify({ result: r.out, warnings }), "application/json; charset=utf-8");
  }

  if (req.method === "GET" && p === "/api/health") {
    const probe = spawnSync("tclsh", [BIN, "lint", "-"], { input: "[VERSION]\nG1 reports/v1 uniq_end\n", encoding: "utf8" });
    const tclsh = !probe.error && [0, 1, 3].includes(probe.status);
    return send(res, 200, JSON.stringify({ ok: true, tclsh }), "application/json; charset=utf-8");
  }

  if (p.startsWith("/examples/")) {
    const f = path.join(EXA, path.normalize(p.slice(10)));
    if (!f.startsWith(EXA) || !fs.existsSync(f)) return send(res, 404, "not found");
    return send(res, 200, fs.readFileSync(f), MIME[path.extname(f)] || "application/octet-stream");
  }
  if (p === "/docs/grammar.md") {
    const f = path.join(ROOT, "docs", "grammar.md");
    if (fs.existsSync(f)) return send(res, 200, fs.readFileSync(f), "text/markdown; charset=utf-8");
  }

  let f = p === "/" ? "index.html" : p.slice(1);
  f = path.normalize(f);
  if (f.startsWith("..")) return send(res, 403, "forbidden");
  const full = path.join(PUB, f);
  if (!full.startsWith(PUB) || !fs.existsSync(full) || fs.statSync(full).isDirectory()) {
    // SPA fallback
    const idx = path.join(PUB, "index.html");
    if (fs.existsSync(idx)) return send(res, 200, fs.readFileSync(idx), MIME[".html"]);
    return send(res, 404, "not found");
  }
  send(res, 200, fs.readFileSync(full), MIME[path.extname(full)] || "text/plain; charset=utf-8");
});

server.listen(PORT, () => {
  console.log(`STA2HTM Run Editor on http://localhost:${PORT}  (converter: ${BIN})`);
});
