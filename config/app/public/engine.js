/* STA Config Editor — 引擎 v2
 * 在 v1（sta2htm.run ⇄ JSON）基礎上新增：
 *   • 三檔拆分：sta_runset.ini (VERSION, GROUP)
 *               sta_mmmc.ini  (CHECK, MODE, CORNER, SCENARIO)
 *               sta_block.ini (BLOCK)
 *   • 子集渲染/解析（renderIni / parseIni）
 *   • mergeModels()：三檔 → 完整 sta2htm.run / sta2htm.json
 * 與 bin/sta2htm_run_json.tcl 逐位元組差分對齊（沿用 v1 diff harness）
 */
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.S2C = factory();
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  const SECS = ["VERSION", "GROUP", "BLOCK", "CHECK", "MODE", "CORNER", "SCENARIO"];
  const SPEC = {
    VERSION:  [["run","str"],["dir","str"],["groups","list"]],
    GROUP:    [["group","str"],["pattern","list"]],
    BLOCK:    [["block","str"],["pattern","list"]],
    CHECK:    [["check","str"],["def","list"]],
    MODE:     [["mode","str"],["name","str"],["def","list"]],
    CORNER:   [["corner","str"],["name","str"],["def","list"]],
    SCENARIO: [["id","str"],["check","str"],["mode","str"],["corners","list"]],
  };
  const HEAD = {
    VERSION:  ["#STA_RUN       STA_RUN_DIR            STA_RUN_GROUPS",
               "#------------- ---------------------  ------------------------------"],
    GROUP:    ["#STA_GROUP     STA_GROUP_REPORT (glob patterns)",
               "#-----------  --------------------------------------------"],
    BLOCK:    ["#BLOCK         PATTERN(S)",
               "#-----------  ----------------------------"],
    CHECK:    ["#STA_CHECK     CHECK_DEF (trend metric of corner column: WNS|TNS|NVP)",
               "#-----------  ---------------------------------"],
    MODE:     ["#STA_MODE      MODE_NAME         MODE_DEF (SDC...)",
               "#-----------  ----------------  ---------------------------"],
    CORNER:   ["#STA_CORNER    CORNER_NAME       CORNER_DEF (lib:V:T RC ...)",
               "#------------  ----------------  ----------------------------------"],
    SCENARIO: ["#SID    CHECK   MODE      CORNERS  (columns follow [CORNER] order; - = absent)",
               "#------   ------  --------  ---------------------------------------"],
  };
  const FIELDS = sec => SPEC[sec].map(([k]) => k);

  /* 三檔拆分定義（本編輯器核心概念） */
  const FILES = {
    "sta_runset.ini": { label: "RUNSET", secs: ["VERSION", "GROUP"],
      desc: "版本登記表：要上趨勢的每個 GOLDEN 版本（dir/群組）" },
    "sta_mmmc.ini":   { label: "MMMC",  secs: ["CHECK", "MODE", "CORNER", "SCENARIO"],
      desc: "MMMC 劇本：每個製程節點可重複使用；Foundry 可提供參考檔" },
    "sta_block.ini":  { label: "BLOCK", secs: ["BLOCK"],
      desc: "Design Block 別名：跨區塊分析頁（可選）" },
  };
  const CANON = ["VERSION", "GROUP", "BLOCK", "CHECK", "MODE", "CORNER", "SCENARIO"];
  const fileOfSec = {}; CANON.forEach(s => {
    for (const [fn, def] of Object.entries(FILES)) if (def.secs.includes(s)) fileOfSec[s] = fn;
  });

  /* ---------- 詞法：與 tcl lindex 語意一致 ---------- */
  function tokens(str) {
    const out = [];
    let i = 0;
    while (i < str.length) {
      while (i < str.length && /\s/.test(str[i])) i++;
      if (i >= str.length) break;
      const c = str[i];
      if (c === '"' || c === "{") {
        const close = c === '"' ? '"' : "}";
        let depth = 1, j = i + 1, raw = "";
        while (j < str.length && depth > 0) {
          const ch = str[j];
          if (ch === "\\") { raw += "\\" + (str[j+1] || ""); j += 2; continue; }
          if (c !== close && ch === c) depth++;
          else if (ch === close) { depth--; if (depth === 0) break; }
          raw += ch; j++;
        }
        out.push(raw); i = j + 1;
      } else {
        let j = i;
        while (j < str.length && !/\s/.test(str[j])) j++;
        out.push(str.slice(i, j)); i = j;
      }
    }
    return out;
  }

  function newModel() {
    return { schema: "sta2htm.run/1", sectionOrder: [], sections: {}, sectionComments: {}, preamble: [], ignored: [], source: "" };
  }

  /* ---------- 解析 .run / .ini（；停用、# 第 0 欄、[SEC] 標記） ---------- */
  function parseRun(text) {
    const model = newModel();
    const warnings = [];
    let sec = "";
    String(text).split(/\r?\n/).forEach((raw, idx) => {
      const ln = idx + 1;
      const dm = raw.match(/^(\s*);(.*)$/);
      if (dm) {
        const body = dm[2].trim();
        if (body === "" || body.startsWith("#")) {
          if (sec === "" && body.startsWith("#")) model.preamble.push(raw);
          return;
        }
        const toks = tokens(body);
        if (toks.length < 2) return;
        if (!sec || SECS.indexOf(sec) < 0) { model.ignored.push({ section: sec || "", line: raw }); return; }
        const e = entryFromTokens(sec, toks, warnings);
        if (e) { e.disabled = true; pushEntry(model, sec, e); }
        return;
      }
      let line = raw.replace(/;[\s\S]*$/, "");
      if (/^\s*$/.test(line)) { if (sec === "" && raw !== "") model.preamble.push(raw); return; }
      if (line[0] === "#") {
        if (sec === "") model.preamble.push(raw);
        else { if (!model.sectionComments[sec]) model.sectionComments[sec] = []; model.sectionComments[sec].push(raw); }
        return;
      }
      if (/^\s+#/.test(line)) {
        warnings.push(`WARN  L${ln}: '#' 前有空白——原始解析器會把它當資料列；本器視為註解`);
        return;
      }
      const m = line.match(/^\s*\[([A-Z]+)\]/);
      if (m) {
        sec = m[1];
        if (SECS.indexOf(sec) >= 0 && model.sectionOrder.indexOf(sec) < 0) model.sectionOrder.push(sec);
        if (!(sec in model.sections)) model.sections[sec] = [];
        return;
      }
      if (!sec) { model.ignored.push({ section: "", line: raw }); return; }
      if (SECS.indexOf(sec) < 0) { model.ignored.push({ section: sec, line: raw }); return; }
      const e = entryFromTokens(sec, tokens(line), warnings);
      if (e) pushEntry(model, sec, e);
    });
    return { model, warnings };
  }

  function pushEntry(model, sec, e) {
    if (!(sec in model.sections)) model.sections[sec] = [];
    if (model.sectionOrder.indexOf(sec) < 0) model.sectionOrder.push(sec);
    model.sections[sec].push(e);
  }

  function entryFromTokens(sec, toks, warnings) {
    const n = toks.length, e = {};
    switch (sec) {
      case "VERSION":
        if (n < 1) return null;
        e.run = toks[0]; e.dir = n >= 2 ? toks[1] : "";
        if (n < 2) warnings.push(`WARN  [VERSION] 缺 STA_RUN_DIR 欄：${toks.join(" ")}`);
        e.groups = toks.slice(2); break;
      case "GROUP":
        if (n < 1) return null; e.group = toks[0]; e.pattern = toks.slice(1); break;
      case "BLOCK":
        if (n < 1) return null; e.block = toks[0]; e.pattern = toks.slice(1); break;
      case "CHECK":
        if (n < 1) return null; e.check = toks[0]; e.def = toks.slice(1); break;
      case "MODE":
        if (n < 1) return null; e.mode = toks[0]; e.name = n >= 2 ? toks[1] : toks[0]; e.def = toks.slice(2); break;
      case "CORNER":
        if (n < 1) return null; e.corner = toks[0]; e.name = n >= 2 ? toks[1] : toks[0]; e.def = toks.slice(2); break;
      case "SCENARIO":
        if (n < 3) { warnings.push(`WARN  [SCENARIO] 詞元不足（需 id check mode）：${toks.join(" ")}`); return null; }
        e.id = toks[0]; e.check = toks[1]; e.mode = toks[2]; e.corners = toks.slice(3); break;
      default: return null;
    }
    return e;
  }

  /* ---------- 輸出 .run / .ini ---------- */
  const ljust = (s, w) => (s.length >= w ? s : s + " ".repeat(w - s.length));
  function fmtTok(t) { t = String(t); return /\s/.test(t) ? "{" + t + "}" : t; }
  const jf = arr => (arr || []).map(fmtTok).join(" ");
  function renderEntry(sec, e) {
    const dis = e.disabled ? ";" : "";
    switch (sec) {
      case "VERSION":  return (dis + ljust(e.run,14) + " " + ljust(e.dir,22) + " " + jf(e.groups)).trimEnd();
      case "GROUP":    return (dis + ljust(e.group,14) + " " + jf(e.pattern)).trimEnd();
      case "BLOCK":    return (dis + ljust(e.block,14) + " " + jf(e.pattern)).trimEnd();
      case "CHECK":    return (dis + ljust(e.check,14) + " " + jf(e.def)).trimEnd();
      case "MODE":     return (dis + ljust(e.mode,14) + " " + ljust(e.name,16) + " " + jf(e.def)).trimEnd();
      case "CORNER":   return (dis + ljust(e.corner,14) + " " + ljust(e.name,16) + " " + jf(e.def)).trimEnd();
      case "SCENARIO": {
        let l = dis + ljust(e.id,7) + " " + ljust(e.check,7) + " " + ljust(e.mode,9);
        (e.corners || []).forEach(c => { l += " " + ljust(fmtTok(c),4); });
        return l.trimEnd();
      }
    }
    return "";
  }
  /* 渲染：secs 為空＝全部（canonical 順序）；否則僅輸出指定區塊（.ini 模式） */
  function renderRun(model, secs) {
    const out = [];
    (model.preamble || []).forEach(l => out.push(l));
    const wanted = secs && secs.length ? secs : null;
    const final = [];
    (model.sectionOrder || []).forEach(s => {
      if (SECS.includes(s) && (!wanted || wanted.includes(s)) && !final.includes(s)) final.push(s);
    });
    (wanted ? wanted : SECS).forEach(s => {
      if (model.sections[s] && !final.includes(s)) final.push(s);
    });
    final.forEach(sec => {
      const rows = model.sections[sec] || [];
      if (!rows.length && wanted) return;
      if (out.length) out.push("");
      out.push("[" + sec + "]");
      HEAD[sec].forEach(h => out.push(h));
      if (wanted && model.sectionComments && model.sectionComments[sec])
        model.sectionComments[sec].forEach(c => out.push(c));
      rows.forEach(e => out.push(renderEntry(sec, e)));
    });
    if (!wanted && (model.ignored || []).length) {
      if (out.length) out.push("");
      out.push("# --- unrecognized lines (kept verbatim; parsers ignore) ---");
      model.ignored.forEach(g => out.push("# !! " + (g.section ? "[" + g.section + "] " : "") + g.line));
    }
    return out.join("\n");
  }

  /* ---------- 模型 ⇄ JSON ---------- */
  function modelToJson(model, secs) {
    const wanted = secs && secs.length ? secs : null;
    const o = { "$schema": "sta2htm.run/1", "generator": "STA Config Editor engine.js/2.0" };
    if (model.source) o.source = model.source;
    const final = [];
    const order = wanted ? wanted : [];
    (model.sectionOrder || []).forEach(s => {
      if (SECS.includes(s) && (!wanted || wanted.includes(s)) && !order.includes(s)) order.push(s);
    });
    if (!wanted) SECS.forEach(s => { if ((model.sections[s] || []).length && !order.includes(s)) order.push(s); });
    o.sectionOrder = order;
    o.preamble = model.preamble || [];
    const cm = {};
    Object.keys(model.sectionComments || {}).forEach(k => { if ((model.sectionComments[k] || []).length) cm[k] = model.sectionComments[k]; });
    if (Object.keys(cm).length) o.comments = cm;
    const secsObj = {};
    order.forEach(sec => {
      const rows = (model.sections[sec] || []);
      if (!rows.length) return;
      secsObj[sec] = rows.map(e => {
        const r = {};
        SPEC[sec].forEach(([k, ty]) => { r[k] = ty === "str" ? (e[k] || "") : (e[k] || []); });
        if (e.disabled) r.disabled = true;
        return r;
      });
    });
    o.sections = secsObj;
    if (!wanted && (model.ignored || []).length) o.ignored = model.ignored;
    return JSON.stringify(o, null, 2);
  }

  function jsonToModelObj(j) {
    const model = newModel();
    const warnings = [];
    if (typeof j === "string") j = JSON.parse(j);
    if (j["$schema"] && j["$schema"] !== "sta2htm.run/1")
      warnings.push(`WARN  $schema=${j["$schema"]}（預期 sta2htm.run/1），仍嘗試解析`);
    model.source = j.source || "";
    (j.sectionOrder || []).forEach(s => { if (SECS.includes(s) && !model.sectionOrder.includes(s)) model.sectionOrder.push(s); });
    model.preamble = (j.preamble || []).map(String);
    Object.keys(j.comments || {}).forEach(k => {
      if (SECS.includes(k) && Array.isArray(j.comments[k])) model.sectionComments[k] = j.comments[k].map(String);
    });
    const secs = j.sections || {};
    Object.keys(secs).forEach(sec => {
      if (!SECS.includes(sec)) { warnings.push(`WARN  忽略未知區塊 "sections.${sec}"`); return; }
      if (!Array.isArray(secs[sec])) { warnings.push(`WARN  sections.${sec} 必須是陣列，跳過`); return; }
      model.sections[sec] = [];
      if (!model.sectionOrder.includes(sec)) model.sectionOrder.push(sec);
      secs[sec].forEach(row => {
        const e = {};
        SPEC[sec].forEach(([k, ty]) => {
          const v = row[k];
          if (ty === "str") e[k] = (v === undefined || v === null) ? "" : String(v);
          else e[k] = Array.isArray(v) ? v.map(String) : (v === undefined || v === null || v === "" ? [] : [String(v)]);
        });
        if (row.disabled === true || row.disabled === "true") e.disabled = true;
        model.sections[sec].push(e);
      });
    });
    (j.ignored || []).forEach(g => model.ignored.push({ section: String(g.section || ""), line: String(g.line || "") }));
    return { model, warnings };
  }

  /* ---------- 三檔拆分 / 合併 ---------- */
  function subset(model, secs, withPreamble) {
    const m = newModel();
    m.schema = model.schema;
    secs.forEach(s => { m.sections[s] = (model.sections[s] || []).map(e => Object.assign({}, e)); });
    m.sectionOrder = secs.filter(s => (m.sections[s] || []).length);
    if (withPreamble) { m.preamble = (model.preamble || []).slice(); m.ignored = (model.ignored || []).slice(); }
    secs.forEach(s => { if (model.sectionComments && model.sectionComments[s]) m.sectionComments[s] = model.sectionComments[s].slice(); });
    m.source = model.source;
    return m;
  }
  function splitModel(model) {
    return {
      runset: subset(model, FILES["sta_runset.ini"].secs, true),
      mmmc:   subset(model, FILES["sta_mmmc.ini"].secs,  false),
      block:  subset(model, FILES["sta_block.ini"].secs, false),
    };
  }
  function mergeModels(parts) {
    const m = newModel();
    m.schema = "sta2htm.run/1";
    m.source = parts.runset.source || "";
    m.preamble = (parts.runset.preamble || []).slice();
    m.ignored = (parts.runset.ignored || []).slice();
    CANON.forEach(sec => {
      const src = (parts.runset.sections[sec] || parts.mmmc.sections[sec] || parts.block.sections[sec]);
      if (src && src.length) {
        m.sections[sec] = src.map(e => Object.assign({}, e));
        m.sectionOrder.push(sec);
      }
      [parts.runset, parts.mmmc, parts.block].forEach(p => {
        if (p.sectionComments && p.sectionComments[sec]) m.sectionComments[sec] = p.sectionComments[sec].slice();
      });
    });
    return m;
  }
  /* 從任意檔案只擷取指定 sections（其餘進 ignored 註記） */
  function parseIni(text, secs, keepPreamble) {
    const { model, warnings } = parseRun(text);
    const kept = subset(model, secs, keepPreamble === undefined ? secs.includes("VERSION") : keepPreamble);
    model.sectionOrder.forEach(s => {
      if (!secs.includes(s)) warnings.push(`INFO  跳過區塊 [${s}]（不屬於本檔：${secs.join("/")}）`);
    });
    return { model: kept, warnings };
  }

  /* ---------- lint（沿用 v1 規則） ---------- */
  function lintModel(model, secs) {
    const w = [];
    const scope = secs && secs.length ? secs : SECS;
    const corners = (model.sections.CORNER || []).map(e => e.corner);
    const modes = (model.sections.MODE || []).map(e => e.mode);
    const checks = (model.sections.CHECK || []).map(e => e.check);
    scope.forEach(sec => {
      const rows = model.sections[sec] || [];
      const key = FIELDS(sec)[0];
      const seen = new Set();
      rows.forEach(e => {
        const nm = e[key];
        if (seen.has(nm)) w.push(`WARN  [${sec}] 名稱重複：${key}=${nm}`);
        seen.add(nm);
        if (String(nm).match(/\s/)) w.push(`ERROR [${sec}] ${key}='${nm}' 含空白——會破壞 lindex 欄序`);
      });
    });
    if (scope.includes("SCENARIO")) {
      const pairs = new Set();
      (model.sections.SCENARIO || []).forEach(e => {
        if (e.mode && !modes.includes(e.mode)) w.push(`WARN  Scenario ${e.id}: mode '${e.mode}' 未在 [MODE] 定義`);
        if (e.check && !checks.includes(e.check)) w.push(`WARN  Scenario ${e.id}: check '${e.check}' 未在 [CHECK] 定義`);
        const key = e.mode + "," + e.check;
        if (pairs.has(key)) w.push(`WARN  [SCENARIO] ${key} 被多列使用——後列覆蓋`);
        pairs.add(key);
        if (corners.length) {
          (e.corners || []).forEach(c => {
            if (c !== "-" && !corners.includes(c)) w.push(`WARN  Scenario ${e.id} 引用未定義角落 '${c}'`);
          });
          if ((e.corners || []).length !== corners.length)
            w.push(`WARN  Scenario ${e.id} corners 欄數 ${(e.corners||[]).length} ≠ [CORNER] 筆數 ${corners.length}`);
        }
      });
    }
    if (scope.includes("VERSION")) {
      (model.sections.VERSION || []).forEach(e => {
        if (/\s/.test(e.dir || "")) w.push(`ERROR VERSION ${e.run}: dir='${e.dir}' 含空白`);
        if (!e.dir) w.push(`WARN  [VERSION] 缺 STA_RUN_DIR 欄：${e.run}`);
      });
    }
    return w;
  }

  function norm(model) {
    const parts = [];
    SECS.forEach(sec => {
      (model.sections[sec] || []).forEach(e => {
        let r = sec;
        FIELDS(sec).forEach(k => {
          const v = e[k];
          r += "|" + k + "=" + (Array.isArray(v) ? v.join("\u0001") : v);
        });
        if (e.disabled) r += "|DISABLED";
        parts.push(r);
      });
    });
    parts.push(`preamble=${(model.preamble || []).length}`);
    return parts.join("\n") + "\n";
  }

  /* ---------- Makefile / run_sta.tcl 模板（依 demo run/01_sta 與 etc/make/*） ---------- */
  function genMakefileRun(versions) {
    const L = ["# Makefile.run — generated by STA Config Editor",
               "# 由 sta_runset.ini 的 [VERSION] 逐列展開；手改後請與 sta_runset.ini 同步"];
    versions.forEach((v, i) => {
      L.push("");
      L.push(`${i === 0 ? "STA_RUN     :=" : "STA_RUN     +="} ${v.run}`);
      L.push(`STA_RUN_DIR.${v.run} := ${v.dir || "reports/" + v.run.toLowerCase()}`);
      if ((v.groups || []).length) L.push(`STA_RUN_GROUPS.${v.run} := ${v.groups.join(" ")}`);
    });
    return L.join("\n") + "\n";
  }
  function genRunsetMakefile() {
    return [
      "# Makefile — runset 層（對應 STA2HTM etc/make/runset.make 的 demo 用法）",
      "include Makefile.run",
      "",
      "help:",
      "\t@echo\t\"Usage:\"",
      "\t@echo\t\"  make run    # run all : $(STA_RUN)\"",
      "\t@echo\t\"  make <ver>  # run one version\"",
      "\t@echo\t\"  make index  # create index.htm + runset index\"",
      "\t@echo\t\"  make view   # firefox index.htm\"",
      "\t@echo\t\"  make clean\"",
      "\t@echo",
      "",
      "$(STA_RUN):",
      "\tsta_init_run $@ $(STA_RUN_DIR.$@) $(STA_RUN_GROUPS.$@)",
      "",
      "init: $(STA_RUN)",
      "\tmkdir -p logs",
      "",
      "run: init",
      "\t@for i in $(STA_RUN); do ( \\",
      "\t  (cd $$i; make run) | tee logs/run.$$i.log ; \\",
      "\t) ; done",
      "\tsta_index_runset",
      "",
      "index: run",
      "\t@for i in $(STA_RUN); do ( \\",
      "\t  cd $$i; make index ; \\",
      "\t) ; done",
      "\tsta_index_runset",
      "",
      "view:",
      "\tfirefox index.htm &",
      "",
      "clean:",
      "\trm -fr $(STA_RUN) logs *.log index.* .trendchart .javascript .icon",
    ].join("\n") + "\n";
  }
  function dirName(mode, corner, check) { return `${mode}_${corner}_${check}`; }
  function genMmmcTopMakefile(mmmc) {
    const modes = (mmmc.sections.MODE || []).map(e => e.mode);
    const checks = (mmmc.sections.CHECK || []).map(e => e.check);
    const corners = (mmmc.sections.CORNER || []).map(e => e.name);
    const dirs = [];
    (mmmc.sections.SCENARIO || []).forEach(sc => {
      const cn = (mmmc.sections.CORNER || []).find(c => c.corner === (sc.corners || ["-"])[0]);
      corners.forEach(cname => {
        if ((sc.corners || [])[corners.indexOf(cname)] === "-") return;
        dirs.push(dirName(sc.mode, cname, sc.check));
      });
    });
    const uniq = [...new Set(dirs)];
    return [
      "# Makefile — MMMC 上層（STA Config Editor build 產生）",
      "# 語意：make run ⇒ 依 SCENARIO 進入每個 <mode>_<corner>_<check>/ 子目錄跑 STA",
      "",
      `MODE_LIST   := ${modes.join(" ")}`,
      `CORNER_LIST := ${corners.join(" ")}`,
      `CHECK_LIST  := ${checks.join(" ")}`,
      `SUBDIRS     := ${uniq.join(" ")}`,
      "",
      "help:",
      "\t@echo \"make run    # 逐子目錄執行 run_sta.tcl $(MODE_LIST)\"",
      "\t@echo \"make clean  # 刪除各子目錄 reports\"",
      "",
      "run:",
      "\t@for d in $(SUBDIRS); do ( \\",
      "\t  echo \"==== MMMC $$d ====\" ; \\",
      "\t  $(MAKE) -C $$d run || exit 1 ; \\",
      "\t) ; done",
      "",
      "clean:",
      "\t@for d in $(SUBDIRS); do ( $(MAKE) -C $$d clean ) ; done",
    ].join("\n") + "\n";
  }
  function genMmmcSubMakefile(mode, corner, check, sdc) {
    return [
      "# <mode>_<corner>_<check>/Makefile — generated by STA Config Editor",
      `MODE   := ${mode}`,
      `CORNER := ${corner}`,
      `CHECK  := ${check}`,
      `SDC    := ${sdc || mode + ".sdc"}`,
      "",
      "run:",
      "\t@echo \"[STA] $(MODE) $(CORNER) $(CHECK) (SDC=$(SDC))\"",
      "\t@tclsh run_sta.tcl $(MODE) $(CORNER) $(CHECK)",
      "",
      "clean:",
      "\trm -rf reports",
    ].join("\n") + "\n";
  }
  function genRunStaTcl(mode, corner, check, sdc) {
    return [
      "#!/usr/bin/env tclsh",
      "# run_sta.tcl — STA 執行樣板（STA Config Editor / MMMC build 產生）",
      "# 用法：tclsh run_sta.tcl <mode> <corner> <check>",
      "# 職責：讀 lib/網表/SDC → 跑簽核工具 → 把報告寫到 sta2htm 約定路徑：",
      "#       ../../reports/<mode>/<corner>/<check>.rpt   (相對本檔＝mmmc/<dir>/)",
      "# 之後由 runset 層sta2htm 命令解析成 HTML 儀表板。",
      "",
      "if {[llength $argv] < 3} { puts \"usage: run_sta.tcl <mode> <corner> <check>\"; exit 1 }",
      "lassign $argv MODE CORNER CHECK",
      "set SDC [expr {[info exists env(SDC)] ? $env(SDC) : \"${MODE}.sdc\"}]",
      "set OUTDIR [file join .. .. reports $MODE $CORNER]",
      "file mkdir $OUTDIR",
      "set rpt [file join $OUTDIR $CHECK.rpt]",
      "",
      "# ── demo 模式：STA_DEMO=1 時產生極簡範例報告（教學/管線驗證用）──────────",
      "if {[info exists env(STA_DEMO)]} {",
      "    set fh [open $rpt w]",
      "    puts $fh \"  Report : $CHECK\"",
      "    puts $fh \"  Path Type : max\"",
      "    puts $fh \"  Corner : $CORNER\"",
      "    puts $fh \"  Mode : $MODE (SDC=$SDC)\"",
      "    puts $fh \"\"",
      "    puts $fh \"slack (VIOLATED)\"; puts $fh \"   -0.0421\"",
      "    puts $fh \"slack (VIOLATED)\"; puts $fh \"   -0.0180\"",
      "    puts $fh \"slack (MET)\";      puts $fh \"    0.1234\"",
      "    close $fh",
      "    puts \"DEMO: wrote $rpt\"; exit 0",
      "}",
      "",
      "# ── 正式模式：把下面換成你的簽核工具呼叫 ─────────────────────────────",
      "# 例（PrimeTime）：",
      "#   exec pt_shell -file pt_main.tcl -mode $MODE -corner $CORNER -check $CHECK \\",
      "#        -output $rpt",
      "# 例（Tempus）：",
      "#   exec tempus -files tm_main.tcl ...",
      "puts \"ERROR: STA_DEMO 未設定且尚未接入簽核工具（見本檔尾部註解）\"",
      "exit 2",
    ].join("\n") + "\n";
  }

  return { SECS, SPEC, FIELDS, HEAD, FILES, CANON, fileOfSec,
           tokens, parseRun, parseIni, renderRun, modelToJson, jsonToModelObj,
           splitModel, mergeModels, subset, lintModel, norm, newModel, entryFromTokens,
           genMakefileRun, genRunsetMakefile, genMmmcTopMakefile,
           genMmmcSubMakefile, genRunStaTcl, dirName };
});
