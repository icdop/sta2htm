/* STA Config Editor — UI 邏輯（依賴 engine.js 之 S2C） */
"use strict";
const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
const S2C = window.S2C;

const TABDEF = {
  runset: { secs: ["VERSION", "GROUP"], file: "sta_runset.ini", ta: "#ta-runset", cards: "#cards-runset", lbl: "#fl-runset" },
  mmmc:   { secs: ["CHECK", "MODE", "CORNER", "SCENARIO"], file: "sta_mmmc.ini", ta: "#ta-mmmc", cards: "#cards-mmmc", lbl: "#fl-mmmc" },
  block:  { secs: ["BLOCK"], file: "sta_block.ini", ta: "#ta-block", cards: "#cards-block", lbl: "#fl-block" },
};
const ST = {};   // tab → {model, warns, fileName}
Object.keys(TABDEF).forEach(k => { ST[k] = { model: S2C.newModel(), warns: [], fileName: "" }; });
let EXTRA = [];   // 伺服器端訊息
let WS = "";

/* ---------- init 範本（全 # 註解；拿掉 # 即生效） ---------- */
const SAMPLES = {
runset: `# ==============================================================
# sta_runset.ini — RUNSET（VERSION ＋ GROUP）
# 由 STA Config Editor init 產生；以下範例皆以 # 開頭（未生效）
# 拿掉行首 # 即成為有效設定
# --------------------------------------------------------------
#[VERSION]
#GOLDEN-0122   reports/apr0-0122    uniq_end reg2reg
#GOLDEN-0123   reports/eco1-0123    uniq_end
#
#[GROUP]
#uniq_end   $sta_mode/$corner_name/$sta_check.rpt
#reg2reg    $sta_mode/$corner_name/$sta_check/RptConst_reg2reg.rpt
`,
mmmc: `# ==============================================================
# sta_mmmc.ini — MMMC 劇本（CHECK/MODE/CORNER/SCENARIO）
# 製程級資產：同一製程工藝基本重複使用；Foundry 可提供參考檔，
# 使用者僅需修改 MODE section 及各 mode 綁定的 SDC（$mode.sdc）
# 以下範例皆以 # 開頭；拿掉行首 # 即生效
# --------------------------------------------------------------
#[CHECK]
#setup   WNS
#hold    NVP
#
#[MODE]
#func    functional    func.sdc
#scan01  dc_shift      scan_shift.sdc
#
#[CORNER]
#000     000_TT    TTT:0.80V:025C   RCtyp
#157     157_BC    FFF:0.88V:-40C   Cmin
#231     231_WC    SSG:0.72V:125C   Cmax
#
#[SCENARIO]
#S001    setup   func    000  -   231
#H001    hold    scan01  000  157  231
`,
block: `# ==============================================================
# sta_block.ini — Design Block 別名（選配）
# 供 sta2htm 跨區塊分析頁（.blk）歸群；匹配鍵為 ^pattern/.*
# 以下範例以 # 開頭；拿掉行首 # 即生效
# --------------------------------------------------------------
#[BLOCK]
#core    {^core/.*}
#ddr     {^ddr/.*}
#u_core  {^u_core/.*}
`,
};

/* ---------- 基礎工具 ---------- */
function toast(msg, warn) {
  const t = $("#toast"); t.textContent = msg;
  t.className = "toast" + (warn ? " warn" : "");
  clearTimeout(t._h); t._h = setTimeout(() => t.classList.add("hidden"), 4200);
}
function dl(name, text, mime) {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([text], { type: mime || "text/plain" }));
  a.download = name; a.click(); URL.revokeObjectURL(a.href);
}
function cornerIds(model) { return (model.sections.CORNER || []).map(e => e.corner); }
function cornerNames(model) { return (model.sections.CORNER || []).map(e => e.name || e.corner); }
function realignCorners(model) {
  const ids = cornerIds(model);
  (model.sections.SCENARIO || []).forEach(e => {
    const next = new Array(ids.length).fill("-");
    for (let i = 0; i < Math.min((e.corners || []).length, ids.length); i++) next[i] = e.corners[i];
    e.corners = next.map(c => (c === "-" || ids.includes(c)) ? c : "-");
  });
}

/* ---------- 同步：model → 文字 / 面板 ---------- */
function syncTab(tab) {
  const def = TABDEF[tab], st = ST[tab];
  const ta = $(def.ta);
  if (document.activeElement !== ta) ta.value = S2C.renderRun(st.model, def.secs);
  $(def.lbl).textContent = st.fileName ? `（${st.fileName}）` : "";
  refreshProblems();
  const n = def.secs.reduce((a, s) => a + (st.model.sections[s] || []).length, 0);
  $("#meta").textContent = `RUNSET ${cnt("runset")} · MMMC ${cnt("mmmc")} · BLOCK ${cnt("block")}`
    + (WS ? ` · workspace=${WS}` : "");
}
const cnt = tab => TABDEF[tab].secs.reduce((a, s) => a + (ST[tab].model.sections[s] || []).length, 0);
function refreshProblems() {
  const box = $("#plist"); if (!box) return;
  box.innerHTML = "";
  const w = EXTRA.concat(...Object.keys(TABDEF).map(k => ST[k].warns.concat(S2C.lintModel(ST[k].model, TABDEF[k].secs))));
  let errs = 0;
  w.forEach(m => { const li = document.createElement("li"); if (/^ERROR/.test(m)) { li.className = "err"; errs++; } li.textContent = m; box.appendChild(li); });
  if (!w.length) { const li = document.createElement("li"); li.className = "ok"; li.textContent = "✔ 三檔皆無警告"; box.appendChild(li); }
  const p = $("#pcount"); p.textContent = w.length; p.classList.toggle("zero", w.length === 0);
}

/* ---------- 表格卡片 ---------- */
function renderCards(tab) {
  const host = $(TABDEF[tab].cards); host.innerHTML = "";
  const st = ST[tab], def = TABDEF[tab];
  const shown = def.secs.filter(s => (st.model.sections[s] || []).length || st.model.sectionComments[s]);
  shown.forEach(sec => host.appendChild(card(tab, sec)));
  const miss = def.secs.filter(s => !shown.includes(s));
  if (miss.length) {
    const b = document.createElement("div"); b.className = "addrow";
    miss.forEach(s => {
      const btn = document.createElement("button"); btn.className = "btn"; btn.textContent = "+ [" + s + "]";
      btn.onclick = () => { st.model.sections[s] = []; st.model.sectionOrder.push(s); st.model.sectionComments[s] = S2C.HEAD[s].slice(); syncTab(tab); renderCards(tab); };
      b.appendChild(btn);
    });
    host.appendChild(b);
  }
}
function card(tab, sec) {
  const st = ST[tab];
  const el = document.createElement("div"); el.className = "sheet";
  const h = document.createElement("h3");
  h.innerHTML = `[${sec}] <span class="cnt">${(st.model.sections[sec] || []).length} 列</span><span class="rm" title="移除區塊">✕</span>`;
  h.querySelector(".rm").onclick = () => {
    if (!confirm(`移除 [${sec}]？`)) return;
    delete st.model.sections[sec]; delete st.model.sectionComments[sec];
    st.model.sectionOrder = st.model.sectionOrder.filter(x => x !== sec);
    syncTab(tab); renderCards(tab);
  };
  el.appendChild(h);
  const tbl = document.createElement("table"); tbl.className = "grid";
  const hr = document.createElement("tr");
  hr.innerHTML = `<th style="width:30px">停</th>` + S2C.SPEC[sec].map(([k, ty]) => `<th>${k}${ty === "list" ? " <small>(空白分隔)</small>" : ""}</th>`).join("") + `<th style="width:92px"></th>`;
  tbl.appendChild(hr);
  const body = document.createElement("tbody");
  (st.model.sections[sec] || []).forEach((e, i) => body.appendChild(row(tab, sec, e, i)));
  tbl.appendChild(body); el.appendChild(tbl);
  if (sec === "SCENARIO" && cornerIds(st.model).length) el.appendChild(matrixTable(st.model));
  const add = document.createElement("div"); add.className = "addrow";
  const b = document.createElement("button"); b.className = "btn"; b.textContent = "+ 新增列";
  b.onclick = () => { st.model.sections[sec].push(defaults(tab, sec)); syncTab(tab); renderCards(tab); };
  add.appendChild(b); el.appendChild(add);
  return el;
}
function defaults(tab, sec) {
  const st = ST[tab], e = {};
  S2C.SPEC[sec].forEach(([k, ty]) => { e[k] = ty === "str" ? "" : []; });
  if (sec === "CHECK") { e.check = "setup"; e.def = ["WNS"]; }
  if (sec === "SCENARIO") { e.check = "setup"; e.mode = (st.model.sections.MODE || [])[0]?.mode || ""; e.corners = cornerIds(st.model).map(() => "-"); }
  return e;
}
function row(tab, sec, e, idx) {
  const st = ST[tab];
  const tr = document.createElement("tr"); if (e.disabled) tr.className = "dis";
  const td0 = document.createElement("td"); td0.className = "op";
  const ck = document.createElement("input"); ck.type = "checkbox"; ck.className = "ck"; ck.checked = !!e.disabled;
  ck.onchange = () => { e.disabled = ck.checked; syncTab(tab); renderCards(tab); };
  td0.appendChild(ck); tr.appendChild(td0);
  S2C.SPEC[sec].forEach(([k, ty]) => {
    const td = document.createElement("td"); td.colSpan = ty === "list" ? 5 : 3;
    if (sec === "SCENARIO" && (k === "mode" || k === "check")) {
      const opts = k === "mode" ? (st.model.sections.MODE || []).map(x => x.mode)
                                : ["setup", "hold", ...(st.model.sections.CHECK || []).map(x => x.check)].filter((v, i, a) => a.indexOf(v) === i);
      const sel = document.createElement("select");
      sel.innerHTML = `<option value="">--</option>` + opts.map(o => `<option${o === e[k] ? " selected" : ""}>${o}</option>`).join("");
      if (e[k] && !opts.includes(e[k])) sel.innerHTML += `<option selected>${e[k]}</option>`;
      sel.onchange = () => { e[k] = sel.value; syncTab(tab); renderCards(tab); };
      const txt = document.createElement("input"); txt.type = "text"; txt.value = e[k]; txt.style.maxWidth = "90px";
      txt.onchange = () => { e[k] = txt.value; syncTab(tab); };
      td.appendChild(sel); td.appendChild(txt);
    } else {
      const inp = document.createElement("input"); inp.type = "text";
      inp.value = ty === "list" ? (e[k] || []).join(" ") : (e[k] ?? "");
      if (ty === "list") inp.placeholder = "（空白分隔多詞元）";
      inp.onchange = () => {
        st.model.sections[sec][idx][k] = ty === "list" ? inp.value.trim().split(/\s+/).filter(x => x !== "") : inp.value;
        if (sec === "CORNER") realignCorners(st.model);
        syncTab(tab); renderCards(tab);
      };
      td.appendChild(inp);
    }
    tr.appendChild(td);
  });
  const op = document.createElement("td"); op.className = "op";
  op.innerHTML = `<a title="上移">▲</a><a title="下移">▼</a><a title="複製">⧉</a><a title="刪除">✕</a>`;
  const [up, dn, cp, del] = [...op.querySelectorAll("a")];
  const a = st.model.sections[sec];
  up.onclick = () => { if (idx > 0) { [a[idx - 1], a[idx]] = [a[idx], a[idx - 1]]; syncTab(tab); renderCards(tab); } };
  dn.onclick = () => { if (idx < a.length - 1) { [a[idx + 1], a[idx]] = [a[idx], a[idx + 1]]; syncTab(tab); renderCards(tab); } };
  cp.onclick = () => { a.splice(idx + 1, 0, JSON.parse(JSON.stringify(e))); syncTab(tab); renderCards(tab); };
  del.onclick = () => { a.splice(idx, 1); syncTab(tab); renderCards(tab); };
  tr.appendChild(op);
  return tr;
}
function matrixTable(model) {
  const ids = cornerIds(model);
  const box = document.createElement("div"); box.style.padding = "0 8px 8px";
  const t = document.createElement("table"); t.className = "grid";
  const hr = document.createElement("tr");
  hr.innerHTML = `<th>SID</th><th>check</th><th>mode</th>` + ids.map(i => `<th>${i}</th>`).join("") + `<th>☑</th>`;
  t.appendChild(hr);
  (model.sections.SCENARIO || []).forEach((e, si) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `<td style="font:11.5px var(--mono);color:#555">${e.id}</td><td style="font:11.5px var(--mono)">${e.check}</td><td style="font:11.5px var(--mono)">${e.mode}</td>`;
    ids.forEach((cid, col) => {
      const td = document.createElement("td");
      const cb = document.createElement("input"); cb.type = "checkbox"; cb.className = "ck";
      cb.checked = (e.corners[col] || "-") === cid;
      cb.onchange = () => {
        while (e.corners.length < ids.length) e.corners.push("-");
        e.corners[col] = cb.checked ? cid : "-";
        syncTab("mmmc"); renderCards("mmmc");
      };
      td.appendChild(cb); tr.appendChild(td);
    });
    const tdc = document.createElement("td");
    tdc.innerHTML = `<input type="checkbox" class="ck"${e.disabled ? " checked" : ""}>`;
    tdc.querySelector("input").onchange = ev => { e.disabled = ev.target.checked; syncTab("mmmc"); renderCards("mmmc"); };
    tr.appendChild(tdc); t.appendChild(tr);
  });
  box.appendChild(t); return box;
}

/* ---------- 載入 / 拆分 ---------- */
function setTabModel(tab, model, warns, name) {
  ST[tab] = { model, warns: warns || [], fileName: name || ST[tab].fileName };
  syncTab(tab); renderCards(tab);
}
function ingest(text, name) {          // 開啟 .run/.json/.ini → 自動拆 3 檔
  let model;
  if (/^\s*\{/.test(text) || /\.json$/i.test(name)) model = S2C.jsonToModelObj(text).model;
  else model = S2C.parseRun(text).model;
  const parts = S2C.splitModel(model);
  setTabModel("runset", parts.runset, [], name);
  setTabModel("mmmc", parts.mmmc, [], name);
  setTabModel("block", parts.block, [], name);
  toast(`已載入 ${name}，並自動拆分為 sta_runset.ini / sta_mmmc.ini / sta_block.ini`);
}
function loadInto(tab, text, name) {   // 單一 tab：只擷取該檔 sections
  const def = TABDEF[tab];
  let model, warns;
  if (/^\s*\{/.test(text)) {
    const r = S2C.jsonToModelObj(text); model = r.model; warns = r.warnings;
    model = S2C.subset(model, def.secs, true);
  } else {
    const r = S2C.parseIni(text, def.secs, true); model = r.model; warns = r.warnings;
  }
  model.source = name;
  setTabModel(tab, model, warns, name);
  toast(`${def.file}：已擷取 [${def.secs.join("｜")}]${warns.some(w => /跳過區塊/.test(w)) ? "（其他區塊已略過）" : ""}`);
}

/* ---------- RUNSET build / run / release ---------- */
function mergedModel() { return S2C.mergeModels({ runset: ST.runset.model, mmmc: ST.mmmc.model, block: ST.block.model }); }
async function wsWrite(path, content) {
  const r = await fetch("/api/ws/write", { method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ path, content }) });
  const j = await r.json(); if (j.error) throw new Error(j.error); return j;
}
async function buildRunset() {
  const merged = mergedModel();
  const runText = S2C.renderRun(merged) + "\n";
  const mkRun = S2C.genMakefileRun((merged.sections.VERSION || []).map(v => ({ run: v.run, dir: v.dir, groups: v.groups })));
  const mkTop = S2C.genRunsetMakefile();
  try {
    await wsWrite("sta2htm.run", runText);
    await wsWrite("Makefile.run", mkRun);
    await wsWrite("Makefile", mkTop);
    await wsWrite("sta_runset.ini", S2C.renderRun(ST.runset.model, TABDEF.runset.secs) + "\n");
    await wsWrite("sta_mmmc.ini", S2C.renderRun(ST.mmmc.model, TABDEF.mmmc.secs) + "\n");
    await wsWrite("sta_block.ini", S2C.renderRun(ST.block.model, TABDEF.block.secs) + "\n");
    const n = (merged.sections.VERSION || []).length;
    toast(`build 完成：sta2htm.run + Makefile.run + Makefile 已寫入 workspace（${n} 個版本）——接著按 run…`);
    EXTRA = [`✔ build：workspace/{sta2htm.run, Makefile.run, Makefile, sta_*.ini}（${n} 版）`];
    refreshProblems();
  } catch (e) { toast("build 失敗：" + e.message, true); }
}
function openRunModal() {
  const v = (mergedModel().sections.VERSION || []);
  const list = $("#runList");
  list.innerHTML = v.length ? v.map(x =>
    `<label><input type="checkbox" class="ck rv" value="${x.run}"> make ${x.run} &nbsp;<span style="color:#888">→ ${x.dir}（${(x.groups || []).join(", ")}）</span></label>`).join("")
    : `<span style="color:#c00">無 [VERSION] —— 請先於 RUNSET 建立並 build</span>`;
  $("#runLog").textContent = "尚未執行。"; $("#runModal").classList.remove("hidden");
}
async function runSeq(steps, demo) {
  const log = $("#runLog");
  for (const stp of steps) {
    log.textContent += `\n$ cd ${stp.dir || "."} && make ${stp.targets.join(" ")}\n`;
    log.scrollTop = log.scrollHeight;
    try {
      const r = await fetch("/api/run", { method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ dir: stp.dir, targets: stp.targets, demo: !!demo }) });
      const j = await r.json();
      log.textContent += (j.log || j.error || "") + "\n";
    } catch (e) { log.textContent += "ERROR " + e.message + "\n"; }
    log.scrollTop = log.scrollHeight;
  }
  toast("run 結束 — 可開 VIEWER 檢查 HTML 報告");
}
async function doRelease() {
  try {
    const r = await fetch("/api/release", { method: "POST" });
    const j = await r.json();
    if (j.error) return toast("release 失敗：" + j.error, true);
    toast(`release 完成：${j.zip}（${(j.versions || []).length} 個版本）`);
    location.href = j.download;
  } catch (e) { toast("release 失敗：" + e.message, true); }
}

/* ---------- MMMC build ---------- */
async function buildMmmc() {
  const m = ST.mmmc.model;
  const corners = cornerNames(m);
  const modes = {}; (m.sections.MODE || []).forEach(e => modes[e.mode] = (e.def || [])[0] || e.mode + ".sdc");
  const jobs = [];
  const dirs = new Set();
  (m.sections.SCENARIO || []).forEach(sc => {
    corners.forEach((cname, ci) => {
      if ((sc.corners || [])[ci] === "-" || !cname) return;
      const dir = S2C.dirName(sc.mode, cname, sc.check);
      if (dirs.has(dir)) return; dirs.add(dir);
      jobs.push({ path: `mmmc/${dir}/Makefile`,
        content: S2C.genMmmcSubMakefile(sc.mode, cname, sc.check, modes[sc.mode]) });
      jobs.push({ path: `mmmc/${dir}/run_sta.tcl`,
        content: S2C.genRunStaTcl(sc.mode, cname, sc.check, modes[sc.mode]) });
    });
  });
  if (!jobs.length) return toast("MMMC 為空：請先建立 CORNER/SCENARIO", true);
  jobs.push({ path: "mmmc/Makefile", content: S2C.genMmmcTopMakefile(m) });
  jobs.push({ path: "sta_mmmc.ini", content: S2C.renderRun(m, TABDEF.mmmc.secs) + "\n" });
  try {
    for (const j of jobs) await wsWrite(j.path, j.content);
    toast(`MMMC build 完成：${dirs.size} 個子目錄（Makefile + run_sta.tcl）＋ mmmc/Makefile`);
    EXTRA = [`✔ MMMC build：workspace/mmmc/ 共 ${dirs.size} 子目錄；上層 make run 逐目錄呼叫 run_sta.tcl`];
    refreshProblems();
  } catch (e) { toast("MMMC build 失敗：" + e.message, true); }
}

/* ---------- 事件接裝 ---------- */
$$(".tabs button").forEach(b => b.onclick = () => {
  $$(".tabs button").forEach(x => x.classList.remove("on")); b.classList.add("on");
  $$(".tab").forEach(x => x.classList.remove("on"));
  $("#tab-" + b.dataset.tab).classList.add("on");
  if (b.dataset.tab === "viewer") $("#vFrame").src = "/viewer/?t=" + Date.now();
});
Object.keys(TABDEF).forEach(tab => {
  $(TABDEF[tab].ta).addEventListener("change", () => {
    const txt = $(TABDEF[tab].ta).value;
    const r = S2C.parseIni(txt, TABDEF[tab].secs, true);
    setTabModel(tab, r.model, r.warns, ST[tab].fileName);
  });
  $("#tb-" + tab).addEventListener("click", async ev => {
    const act = ev.target.dataset.act; if (!act) return;
    if (act === "init") {
      const r = S2C.parseIni(SAMPLES[tab], TABDEF[tab].secs, true);
      setTabModel(tab, r.model, [], "");
      toast(`${TABDEF[tab].file}：已重置為 # 範例模板`);
    }
    if (act === "load") {
      const inp = document.createElement("input"); inp.type = "file"; inp.accept = ".run,.json,.ini,.txt";
      inp.onchange = () => { const f = inp.files[0]; if (!f) return;
        const rd = new FileReader(); rd.onload = () => loadInto(tab, rd.result, f.name); rd.readAsText(f); };
      inp.click();
    }
    if (act === "save") {
      dl(TABDEF[tab].file, S2C.renderRun(ST[tab].model, TABDEF[tab].secs) + "\n");
      toast(`已下載 ${TABDEF[tab].file}`);
    }
    if (act === "build" && tab === "runset") buildRunset();
    if (act === "run") openRunModal();
    if (act === "viewer") $$(".tabs button")[3].click();
    if (act === "release") doRelease();
    if (act === "build" && tab === "mmmc") buildMmmc();
  });
});
$("#file").onchange = ev => {
  const f = ev.target.files[0]; if (!f) return;
  const rd = new FileReader(); rd.onload = () => ingest(rd.result, f.name); rd.readAsText(f);
};
$("#dlRun").onclick = () => dl("sta2htm.run", S2C.renderRun(mergedModel()) + "\n");
$("#dlJson").onclick = () => dl("sta2htm.json", S2C.modelToJson(mergedModel()) + "\n");
$("#runClose").onclick = () => $("#runModal").classList.add("hidden");
$("#runAll").onclick = () => { $("#runLog").textContent = ""; runSeq([{ dir: ".", targets: ["run"] }], $("#demoCk")?.checked); };
$("#runSel").onclick = () => {
  const sel = $$("#runList .rv").filter(c => c.checked).map(c => c.value);
  if (!sel.length) return toast("尚未勾選任何版本", true);
  $("#runLog").textContent = "";
  const steps = sel.flatMap(v => [{ dir: ".", targets: [v] }, { dir: v, targets: ["run"] }]);
  runSeq(steps, $("#demoCk")?.checked);
};
$("#vReload").onclick = () => { $("#vFrame").src = "/viewer/?t=" + Date.now(); };
$("#ptoggle") && ($("#ptoggle").onclick = () => $("#problems").classList.toggle("min"));

/* ---------- 啟動 ---------- */
(async () => {
  Object.keys(TABDEF).forEach(tab => {
    const r = S2C.parseIni(SAMPLES[tab], TABDEF[tab].secs, true);
    ST[tab] = { model: r.model, warns: [], fileName: "" };
    syncTab(tab); renderCards(tab);
  });
  try {
    const h = await (await fetch("/api/health")).json();
    WS = h.workspace || "";
    $("#health").textContent = h.tclsh ? "Tcl ✓" : "Tcl ✕（僅客戶端）";
  } catch (e) { $("#health").textContent = "未連線 server"; }
  syncTab("runset");
})();
