/* STA2HTM Run Editor — UI 邏輯（依賴 engine.js 之 S2H） */
"use strict";
const $ = s => document.querySelector(s);
const S = { model: S2H.newModel(), warnings: [], fileName: "" };

/* ================= 工具 ================= */
function cornerIds() { return (S.model.sections.CORNER || []).map(e => e.corner); }
function esc(s) { return String(s ?? "").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/"/g,"&quot;"); }
function fieldSpec(sec) { return S2H.SPEC[sec]; }

function defaults(sec) {
  const e = {};
  fieldSpec(sec).forEach(([k, ty]) => { e[k] = ty === "str" ? "" : []; });
  if (sec === "CHECK") { e.check = "setup"; e.def = ["WNS"]; }
  if (sec === "SCENARIO") { e.id = "", e.check = "setup", e.mode = (S.model.sections.MODE||[])[0]?.mode || ""; e.corners = cornerIds().map(() => "-"); }
  return e;
}
/* corners 對齊 CORNER id 順序；保留舊欄位值 */
function realignCorners() {
  const ids = cornerIds();
  (S.model.sections.SCENARIO || []).forEach(e => {
    const old = {}; (e.corners || []).forEach((c, i) => { if (c !== "-") old[idForCol(e.corners, i)] = c; });
    function idForCol(cs, i) { return cs[i]; }
    /* 保守做法：依【欄序 = 舊 CORNER 順序】轉存舊值再映射 */
    const mapped = ids.map(id => ((e.corners || []).includes(id)) ? id : "-");
    const keep = e.corners.slice();
    const cols = ids.length;
    const next = new Array(cols).fill("-");
    for (let i = 0; i < Math.min(keep.length, cols); i++) next[i] = keep[i];
    e.corners = next.map(c => (c === "-" || ids.includes(c)) ? c : "-");
  });
}

/* ================= 同步：model → run/json 文字 ================= */
function syncText(onlyIfHidden) {
  const runTA = $("#runText"), jsonTA = $("#jsonText");
  if (!(onlyIfHidden && document.activeElement === runTA)) runTA.value = S2H.renderRun(S.model);
  if (!(onlyIfHidden && document.activeElement === jsonTA)) jsonTA.value = S2H.modelToJson(S.model);
  refreshProblems();
  updateMeta();
}
function updateMeta() {
  const m = S.model;
  const n = S2H.SECS.reduce((a, s) => a + (m.sections[s] || []).length, 0);
  $("#meta").textContent = `${S.fileName || "未命名"} · ${n} 條目 · 區塊 [${m.sectionOrder.join(" ")||"—"}]`
    + ((m.ignored||[]).length ? ` · 未識別行 ${(m.ignored||[]).length}` : "");
}

/* ================= 驗證面板 ================= */
const EXTRA = [];           // 伺服器端回傳之訊息
function refreshProblems() {
  const w = S.warnings.concat(S2H.lintModel(S.model), EXTRA);
  const box = $("#plist"); box.innerHTML = "";
  let errs = 0;
  w.forEach(msg => {
    const li = document.createElement("li");
    if (/^ERROR/.test(msg)) { li.className = "err"; errs++; }
    li.textContent = msg;
    box.appendChild(li);
  });
  if (!w.length) {
    const li = document.createElement("li"); li.className = "ok";
    li.textContent = "✔ 無警告 — 符合 sta2htm.run/1 文法（建議仍跑一次伺服器端 Tcl 驗證）";
    box.appendChild(li);
  }
  const pill = $("#pcount"); pill.textContent = w.length;
  pill.classList.toggle("zero", w.length === 0);
}

/* ================= 表格渲染 ================= */
const COLW = { run:"150px", dir:"230px", groups:"", check:"110px", mode:"120px", name:"150px", def:"", corner:"110px", block:"", group:"140px", pattern:"", id:"90px" };

function makeInput(v, sec, key, i, list) {
  const el = document.createElement(list ? "input" : "input");
  if (list) { el.type = "text"; el.value = (v || []).join(" "); el.placeholder = "（空白分隔多詞）"; }
  else { el.type = "text"; el.value = v ?? ""; }
  const w = COLW[key]; if (w) el.style.maxWidth = w;
  el.addEventListener("change", () => {
    let val = list ? el.value.trim().split(/\s+/).filter(x => x !== "") : el.value;
    S.model.sections[sec][i][key] = val;
    if (sec === "CORNER") realignCorners();
    syncText(true); renderSheets();
  });
  return el;
}
function makeSel(val, opts, cb) {
  const el = document.createElement("select");
  el.innerHTML = `<option value="">--</option>` + opts.map(o => `<option${o===val?" selected":""}>${esc(o)}</option>`).join("");
  if (!opts.includes(val) && val) el.innerHTML += `<option selected>${esc(val)}</option>`;
  el.addEventListener("change", () => cb(el.value));
  return el;
}

function renderSheets() {
  const host = $("#sheets"); host.innerHTML = "";
  const shown = []; S.model.sectionOrder.forEach(s => { if (S2H.SECS.includes(s) && !shown.includes(s)) shown.push(s); });
  S2H.SECS.forEach(s => { if ((S.model.sections[s] || []).length && !shown.includes(s)) shown.push(s); });
  shown.forEach(sec => host.appendChild(renderSheet(sec)));
  const addHost = $("#addSecBtns"); addHost.innerHTML = "";
  S2H.SECS.filter(s => !shown.includes(s)).forEach(s => {
    const b = document.createElement("button"); b.className = "btn tiny"; b.textContent = "+" + s;
    b.onclick = () => { S.model.sections[s] = []; S.model.sectionOrder.push(s); syncText(); renderSheets(); };
    addHost.appendChild(b);
  });
}

function renderSheet(sec) {
  const card = document.createElement("div"); card.className = "sheet";
  const h = document.createElement("h3");
  h.innerHTML = `[${sec}] <span class="cnt">${S.model.sections[sec].length} 列</span> <span class="rm" title="移除區塊">✕ 移除</span>`;
  h.querySelector(".rm").onclick = () => {
    if (!confirm(`移除 [${sec}] 區塊及其所有條目？`)) return;
    delete S.model.sections[sec];
    S.model.sectionOrder = S.model.sectionOrder.filter(x => x !== sec);
    syncText(); renderSheets();
  };
  card.appendChild(h);

  const tbl = document.createElement("table"); tbl.className = "grid";
  const fs = fieldSpec(sec);
  const head = document.createElement("tr");
  head.innerHTML = `<th style="width:34px">停</th>` + fs.map(([k, ty]) => `<th>${k}${ty==="list"?" <small>(list)</small>":""}</th>`).join("") + `<th style="width:96px"></th>`;
  tbl.appendChild(head);
  const body = document.createElement("tbody");
  S.model.sections[sec].forEach((e, i) => body.appendChild(renderRow(sec, e, i)));
  tbl.appendChild(body);
  card.appendChild(tbl);

  if (sec === "SCENARIO" && cornerIds().length) card.appendChild(renderMatrixTable());

  const add = document.createElement("div"); add.className = "addrow";
  const b = document.createElement("button"); b.className = "btn tiny"; b.textContent = "+ 新增列";
  b.onclick = () => { S.model.sections[sec].push(defaults(sec)); syncText(); renderSheets(); };
  add.appendChild(b); card.appendChild(add);
  return card;
}

function renderRow(sec, e, idx) {
  const tr = document.createElement("tr");
  if (e.disabled) tr.className = "dis";
  const td0 = document.createElement("td"); td0.className = "op";
  const ck = document.createElement("input"); ck.type = "checkbox"; ck.className = "ck"; ck.checked = !!e.disabled;
  ck.title = "勾選＝停用（於 .run 以行首 ; 表達）";
  ck.onchange = () => { e.disabled = ck.checked; syncText(); renderSheets(); };
  td0.appendChild(ck); tr.appendChild(td0);

  fieldSpec(sec).forEach(([k, ty]) => {
    const td = document.createElement("td"); td.colSpan = 1 + (ty === "list" ? 4 : 2);
    if (sec === "SCENARIO" && (k === "mode" || k === "check")) {
      const opts = k === "mode" ? (S.model.sections.MODE || []).map(x => x.mode) : ["setup", "hold", ...(S.model.sections.CHECK||[]).map(x=>x.check)].filter((v,i,a)=>a.indexOf(v)===i);
      const sel = makeSel(e[k], opts, v => { e[k] = v; syncText(); renderSheets(); });
      const txt = document.createElement("input"); txt.type = "text"; txt.value = e[k]; txt.size = 8; txt.title = "或自由輸入";
      txt.onchange = () => { e[k] = txt.value; sel.value = txt.value; syncText(true); };
      td.appendChild(sel); td.appendChild(txt);
    } else if (sec === "SCENARIO" && k === "corners") {
      td.appendChild(cornerChipsCell(e));
    } else {
      td.appendChild(makeInput(e[k], sec, k, idx, ty === "list"));
    }
    tr.appendChild(td);
  });

  const op = document.createElement("td"); op.className = "op";
  op.innerHTML = `<a title="上移">▲</a><a title="下移">▼</a><a title="複製">⧉</a><a title="刪除">✕</a>`;
  const [up, dn, cp, del] = [...op.querySelectorAll("a")];
  up.onclick = () => move(sec, idx, -1); dn.onclick = () => move(sec, idx, 1);
  cp.onclick = () => { S.model.sections[sec].splice(idx + 1, 0, JSON.parse(JSON.stringify(e))); syncText(); renderSheets(); };
  del.onclick = () => { S.model.sections[sec].splice(idx, 1); syncText(); renderSheets(); };
  tr.appendChild(op);
  return tr;
}
function move(sec, i, d) {
  const a = S.model.sections[sec], j = i + d;
  if (j < 0 || j >= a.length) return;
  [a[i], a[j]] = [a[j], a[i]]; syncText(); renderSheets();
}

/* corners：以 ✓ / – 文字呈現於欄位清單內（快速鍵用矩陣） */
function cornerChipsCell(e) {
  const wrap = document.createElement("span");
  (e.corners || []).forEach((c, i) => {
    const b = document.createElement("button");
    b.className = "btn tiny " + (c === "-" ? "ghost" : "");
    b.textContent = c === "-" ? "–" : c;
    b.onclick = () => { syncText(); renderSheets(); };
    wrap.appendChild(b); wrap.append(" ");
  });
  if (!(e.corners || []).length) wrap.innerHTML = `<i style="color:var(--mut)">（先建立 [CORNER]，或使用 Run 文字頁直接編輯）</i>`;
  return wrap;
}

function renderMatrixTable() {
  const box = document.createElement("div"); box.style.padding = "0 10px 8px";
  const t = document.createElement("table"); t.className = "grid matrix";
  const ids = cornerIds();
  const hr = document.createElement("tr");
  hr.innerHTML = `<th>SID</th><th>check</th><th>mode</th>` + ids.map(i => `<th>${esc(i)}</th>`).join("") + `<th>☑</th>`;
  t.appendChild(hr);
  (S.model.sections.SCENARIO || []).forEach((e, si) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `<td style="font-family:var(--mono);font-size:11.5px;color:var(--mut)">${esc(e.id)}</td><td style="font-family:var(--mono);font-size:11.5px">${esc(e.check)}</td><td style="font-family:var(--mono);font-size:11.5px">${esc(e.mode)}</td>`;
    ids.forEach((cid, col) => {
      const td = document.createElement("td");
      const cb = document.createElement("input"); cb.type = "checkbox"; cb.className = "ck";
      cb.checked = (e.corners[col] || "-") === cid || (e.corners[col] !== undefined && e.corners[col] !== "-" && e.corners[col] === cid);
      cb.onchange = () => {
        while (e.corners.length < ids.length) e.corners.push("-");
        e.corners[col] = cb.checked ? cid : "-";
        syncText(true); renderSheets();
      };
      td.appendChild(cb); tr.appendChild(td);
    });
    const tdc = document.createElement("td");
    tdc.innerHTML = `<input type="checkbox" class="ck"${e.disabled ? " checked" : ""}>`;
    tdc.querySelector("input").onchange = ev => { e.disabled = ev.target.checked; syncText(); renderSheets(); };
    tr.appendChild(tdc);
    t.appendChild(tr);
  });
  box.appendChild(t);
  return box;
}

/* ================= 匯入 / 匯出 ================= */
function loadRunText(text, name) {
  const r = S2H.parseRun(text);
  S.model = r.model; S.warnings = r.warnings; S.fileName = name || "";
  EXTRA.length = 0;
  syncText(); renderSheets();
}
function loadJsonText(text, name) {
  try {
    const r = S2H.jsonToModelObj(text);
    S.model = r.model; S.warnings = r.warnings; S.fileName = name || "";
    EXTRA.length = 0; syncText(); renderSheets();
  } catch (e) { alert("JSON 解析失敗：" + e.message); }
}
function download(name, text, mime) {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([text], { type: mime }));
  a.download = name; a.click(); URL.revokeObjectURL(a.href);
}

/* ================= 伺服器端（Tcl 權威）驗證 ================= */
async function api(path_, body) {
  const r = await fetch(path_, { method: "POST", headers: { "content-type": "text/plain" }, body });
  if (!r.ok) throw new Error((await r.text()) || r.status);
  return r.json();
}
async function srvCheck() {
  const text = S2H.renderRun(S.model);
  try {
    const a = await api("/api/run2json", text);
    EXTRA.length = 0;
    a.warnings.filter(w => /^WARN|^ERROR/.test(w)).forEach(w => EXTRA.push("server·" + w));
    const rA = S2H.jsonToModelObj(a.result);
    if (S2H.norm(rA.model) !== S2H.norm(S.model)) {
      EXTRA.push("ERROR 客戶端 model 與伺服器 Tcl 結果「不同步」（norm diff）— 請貼 test/diff_harness 反應");
    } else {
      EXTRA.push("✔ 伺服器端 tcl run2json 與客戶端引擎一致（norm PASS）");
    }
    const b = await api("/api/json2run", JSON.stringify(JSON.parse(a.result)));
    const back = S2H.parseRun(b.result);
    if (S2H.norm(back.model) !== S2H.norm(S.model))
      EXTRA.push("ERROR 伺服器 json2run 往返後語義漂移");
    else EXTRA.push("✔ 伺服器 tcl json2run 往返 PASS（run↔json 封閉）");
    refreshProblems();
  } catch (e) { EXTRA.length = 0; EXTRA.push("WARN  無法使用伺服器 tclsh（" + e.message + "）"); refreshProblems(); }
}

/* ================= 語法頁 ================= */
function rail(lbl, toks) {
  return `<div class="rail"><span class="lbl">${lbl}</span>` +
    toks.map(([t, cls]) => `<span class="tok ${cls||""}">${t}</span><i>▸</i>`).join("").replace(/<i>▸<\/i>\s*$/, "") +
    `</div>`;
}
function renderGrammar() {
  const R = (sec, items) => rail("[" + sec + "]", items);
  $("#gramDoc").innerHTML = `
  <h2>sta2htm.run 語法（sta2htm.run/1）</h2>
  <p>詞法：<b>空白/Tab</b> 分隔欄位（tcl <code>lindex</code> 語意）；區塊標記 <code>^[ws]*[A-Z]+</code>；
  第 0 欄 <code>#</code>＝註解；行內 <code>;</code> 起＝切尾（<code>;NAME…</code> 停用整列）。</p>
  ${R("VERSION", [[ "&lt;run&gt;", "" ],[ "&lt;dir&gt;", "" ],[ "&lt;groups&gt;…", "rep opt" ]])}
  ${R("GROUP", [[ "&lt;group&gt;", "" ],[ "&lt;glob pattern&gt;…", "rep opt" ]])}
  ${R("BLOCK", [[ "&lt;alias&gt;", "" ],[ "&lt;pattern&gt;…", "rep opt" ]])}
  ${R("CHECK", [[ "&lt;check&gt;", "" ],[ "&lt;metric&gt;…", "rep opt" ]])}
  ${R("MODE", [[ "&lt;mode&gt;", "" ],[ "&lt;name&gt;", "" ],[ "&lt;sdc…&gt;", "opt" ]])}
  ${R("CORNER", [[ "&lt;corner&gt;", "" ],[ "&lt;corner_name&gt;", "" ],[ "&lt;lib:V:T&gt;", "" ],[ "&lt;RC&gt;…", "opt" ]])}
  ${R("SCENARIO", [[ "&lt;SID&gt;", "" ],[ "&lt;check&gt;", "" ],[ "&lt;mode&gt;", "" ],[ "&lt;corner|−&gt;…（欄序＝[CORNER]）", "rep" ]])}
  <h3>JSON Schema（摘要）</h3>
  <pre>{ "\$schema": "sta2htm.run/1",
  "sectionOrder": [ "VERSION", "GROUP", "BLOCK", "CHECK", "MODE", "CORNER", "SCENARIO" ],
  "preamble":     [ "# 檔頭註解原行保留" ],
  "sections": {
    "VERSION": [ { "run": "GOLDEN-0122", "dir": "reports/apr0-0120",
                   "groups": [ "uniq_end", "reg2reg" ], "disabled": false } ],
    "GROUP":   [ { "group": "uniq_end", "pattern": [ "$sta_mode/$corner_name/$sta_check.rpt" ] } ],
    "BLOCK":   [ { "block": "cpu", "pattern": [ "^cpu/.*" ] } ],
    "CHECK":   [ { "check": "setup", "def": [ "WNS" ] } ],
    "MODE":    [ { "mode": "func", "name": "functional", "def": [ "func.sdc" ] } ],
    "CORNER":  [ { "corner": "000", "name": "000_TT", "def": [ "TTT:0.80V:025C", "RCtyp" ] } ],
    "SCENARIO":[ { "id": "S001", "check": "setup", "mode": "func",
                   "corners": [ "000", "-", "157", "237", "231" ] } ] },
  "ignored":   [ { "section": "FOO", "line": "…" } ] }</pre>
  <h3>順序語意</h3>
  <ul>
    <li><b>[CORNER]</b> 的列出順序＝SCENARIO 矩陣欄順序；<code>-</code>＝該角落不跑。</li>
    <li><b>[VERSION]</b> 行序＝趨勢圖時序；<code>;NAME</code> 暫除（本編輯器 ☑停用）。</li>
    <li>SCENARIO 引用未定義之 mode/check/corner → 原始解析器自動補定義並印 WARNING。</li>
    <li>同一 (mode,check) 出現多列 SCENARIO → 後列覆蓋。</li>
  </ul>
  <h3>四個坑（本課簡報同步收錄）</h3>
  <table><tr><th>坑</th><th>症狀</th><th>防呆</th></tr>
  <tr><td>「<code>#</code>」前有空白</td><td>不被視為註解</td><td>編輯器自動標記並重排</td></tr>
  <tr><td>欄位內含空白</td><td>lindex 欄序錯切</td><td>名稱用底線；清單欄以空白分隔＝多個詞元</td></tr>
  <tr><td><code>;</code> 在引號內</td><td>整段切尾</td><td>避免內嵌分號</td></tr>
  <tr><td>runset 與 .cfg 雙劇本</td><td>單版/趨勢頁數字打架</td><td>兩檔同步改（見 grammar.md §4.2）</td></tr></table>`;
}

/* ================= 事件接裝 ================= */
document.querySelectorAll(".tabs button").forEach(b => b.onclick = () => {
  document.querySelectorAll(".tabs button").forEach(x => x.classList.remove("on"));
  b.classList.add("on");
  document.querySelectorAll(".tab").forEach(x => x.classList.remove("on"));
  $("#tab-" + b.dataset.tab).classList.add("on");
});
$("#applyRun").onclick = () => loadRunText($("#runText").value, S.fileName);
$("#applyJson").onclick = () => {
  const t = $("#jsonText").value.trim();
  try { loadJsonText(JSON.parse(t), S.fileName); } catch (e) { loadRunText(t, S.fileName); }
};
$("#runText").addEventListener("change", () => loadRunText($("#runText").value, S.fileName));
$("#jsonText").addEventListener("change", () => { try { loadJsonText($("#jsonText").value, S.fileName); } catch (e) {} });
$("#file").onchange = ev => {
  const f = ev.target.files[0]; if (!f) return;
  const rd = new FileReader();
  rd.onload = () => { (/\.json$/i.test(f.name) || rd.result.trim().startsWith("{")) ? loadJsonText(rd.result, f.name) : loadRunText(rd.result, f.name); };
  rd.readAsText(f);
};
$("#dlRun").onclick = () => download(S.fileName && !/\.json$/i.test(S.fileName) ? S.fileName : "sta2htm.run", S2H.renderRun(S.model) + "\n", "text/plain");
$("#dlJson").onclick = () => download((S.fileName || "sta2htm").replace(/\.run$/, "") + ".json", S2H.modelToJson(S.model) + "\n", "application/json");
$("#srvCheck").onclick = srvCheck;
$("#newFile").onclick = () => { if (confirm("清空目前內容？")) { S.model = S2H.newModel(); S.warnings = []; S.fileName=""; EXTRA.length=0; syncText(); renderSheets(); } };
$("#ptoggle").onclick = () => $("#problems").classList.toggle("min");
$("#examples").onchange = async ev => {
  const v = ev.target.value; if (!v) return;
  try {
    const r = await fetch("/examples/" + v); if (!r.ok) throw new Error(r.status);
    loadRunText(await r.text(), v);
  } catch (e) { alert("無法載入範例：" + e.message); }
  ev.target.value = "";
};

/* 起始：內建小範本 */
S.model = S2H.parseRun(
`# STA2HTM runset（編輯器內建範本 — 由 [表格編輯] 改起）
[VERSION]
GOLDEN-0101  reports/apr0-0101  uniq_end
GOLDEN-0102  reports/eco0-0102  uniq_end
;GOLDEN-0103  reports/eco1-0103  uniq_end
[CHECK]
setup   WNS
hold    NVP
[MODE]
func    functional   func.sdc
sc01    dc_shift     scan.sdc
[CORNER]
000     000_TT       TTT:0.80V:025C  RCtyp
231     231_WC       SSG:0.72V:125C  Cmax
[GROUP]
uniq_end  $sta_mode/$corner_name/$sta_check.rpt
[SCENARIO]
S001  setup  func  000 231
H001  hold   sc01  -   231
`).model;
S.fileName = "untitled.run";
renderSheets(); syncText(); renderGrammar();
fetch("/api/health").then(r => r.json()).then(h => {
  const b = $("#health");
  b.textContent = h.tclsh ? "Tcl 轉換器：上線" : "Tcl 轉換器：不可用（僅客戶端引擎）";
  b.className = "badge " + (h.tclsh ? "ok" : "no");
}).catch(() => { $("#health").textContent = "伺服器模式未啟動"; $("#health").className = "badge no"; });
