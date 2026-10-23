/* sta2htm.run 引擎（瀏覽器 / Node 共用）
 * 與 bin/sta2htm_run_json.tcl 同語法、同輸出格式（docs/grammar.md）
 */
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.S2H = factory();
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

  /* ---------- 詞法：lindex 語意切詞（tcl list：空白/Tab 分隔，"…" 與 {…} 為單元）---------- */
  function tokens(str) {
    const out = [];
    let i = 0, cur, mode;
    while (i < str.length) {
      while (i < str.length && /\s/.test(str[i])) i++;
      if (i >= str.length) break;
      const c = str[i];
      if (c === '"' || c === "{") {
        const close = c === '"' ? '"' : "}";
        let depth = 1, j = i + 1, raw = "", inner = "";
        while (j < str.length && depth > 0) {
          const ch = str[j];
          if (ch === "\\") { raw += "\\" + (str[j+1] || ""); j += 2; continue; }
          if (c !== close && ch === c) depth++;
          else if (ch === close) { depth--; if (depth === 0) break; }
          raw += ch; j++;
        }
        // 取出包裹內文（不展開轉義：$ 開頭等仍保持與 tcl lindex 相同的純文本行為）
        out.push(raw);
        i = j + 1;
      } else {
        let j = i;
        while (j < str.length && !/\s/.test(str[j])) j++;
        out.push(str.slice(i, j));
        i = j;
      }
    }
    return out;
  }

  function newModel() {
    return { schema: "sta2htm.run/1", sectionOrder: [], sections: {}, preamble: [], ignored: [], source: "" };
  }

  /* ---------- 解析 .run ---------- */
  function parseRun(text) {
    const model = newModel();
    const warnings = [];
    let sec = "";
    const lines = String(text).split(/\r?\n/);
    lines.forEach((raw, idx) => {
      const ln = idx + 1;
      // 停用列：';' 於行首 → 保留為 disabled 條目
      const dm = raw.match(/^(\s*);(.*)$/);
      if (dm) {
        const body = dm[2].trim();
        if (body === "" || body.startsWith("#")) {
          if (sec === "" && body.startsWith("#")) model.preamble.push(raw);
          return;
        }
        const toks = tokens(body);
        if (toks.length < 2) return;               // 單詞元 ';xxx' 視作行註解
        if (!sec || SECS.indexOf(sec) < 0) {
          model.ignored.push({ section: sec || "", line: raw });
          return;
        }
        const e = entryFromTokens(sec, toks, warnings);
        if (e) { e.disabled = true; pushEntry(model, sec, e); }
        return;
      }
      // 原 regsub：';' 行內切尾
      let line = raw.replace(/;[\s\S]*$/, "");
      if (/^\s*$/.test(line)) {
        if (sec === "" && raw !== "") model.preamble.push(raw);
        return;
      }
      if (line[0] === "#") {
        if (sec === "") model.preamble.push(raw);
        return;
      }
      if (/^\s+#/.test(line)) {
        warnings.push(`WARN  L${ln}: '#' 前有空白——原始解析器會把它當資料列；本器視為註解`);
        return;
      }
      let m = line.match(/^\s*\[([A-Z]+)\]/);
      if (m) {
        sec = m[1];
        if (SECS.indexOf(sec) >= 0 && model.sectionOrder.indexOf(sec) < 0) model.sectionOrder.push(sec);
        if (!(sec in model.sections)) model.sections[sec] = [];
        return;
      }
      if (!sec) {
        warnings.push(`WARN  L${ln}: 任何區塊之前出現資料列，原始解析器忽略——保留於 ignored`);
        model.ignored.push({ section: "", line: raw });
        return;
      }
      if (SECS.indexOf(sec) < 0) {
        warnings.push(`WARN  L${ln}: 未知區塊 [${sec}] 的資料列，原始解析器忽略`);
        model.ignored.push({ section: sec, line: raw });
        return;
      }
      const e = entryFromTokens(sec, tokens(line), warnings);
      if (e) pushEntry(model, sec, e);
    });
    return { model, warnings };
  }

  function pushEntry(model, sec, e) {
    if (!(sec in model.sections)) { model.sections[sec] = []; }
    if (model.sectionOrder.indexOf(sec) < 0) model.sectionOrder.push(sec);
    model.sections[sec].push(e);
  }

  function entryFromTokens(sec, toks, warnings) {
    const n = toks.length;
    const e = {};
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

  /* ---------- 輸出 .run ---------- */
  const ljust = (s, w) => (s.length >= w ? s : s + " ".repeat(w - s.length));
  function fmtTok(t) {
    t = String(t);
    if (/\s/.test(t)) return "{" + t + "}";
    return t;
  }
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
  function renderRun(model) {
    const out = [];
    (model.preamble || []).forEach(l => out.push(l));
    const final = [];
    (model.sectionOrder || []).forEach(s => { if (SECS.includes(s) && !final.includes(s)) final.push(s); });
    SECS.forEach(s => { if (model.sections[s] && !final.includes(s)) final.push(s); });
    final.forEach(sec => {
      const rows = model.sections[sec] || [];
      if (out.length) out.push("");
      out.push("[" + sec + "]");
      HEAD[sec].forEach(h => out.push(h));
      rows.forEach(e => out.push(renderEntry(sec, e)));
    });
    if ((model.ignored || []).length) {
      if (out.length) out.push("");
      out.push("# --- unrecognized lines (kept verbatim; parsers ignore) ---");
      model.ignored.forEach(g => {
        out.push("# !! " + (g.section ? "[" + g.section + "] " : "") + g.line);
      });
    }
    return out.join("\n");
  }

  /* ---------- 模型 ⇄ JSON ---------- */
  function modelToJson(model) {
    const o = {
      "$schema": "sta2htm.run/1",
      "generator": "engine.js/1.0 (browser parity of sta2htm_run_json.tcl)",
    };
    if (model.source) o.source = model.source;
    const final = [];
    (model.sectionOrder || []).forEach(s => { if (SECS.includes(s) && !final.includes(s)) final.push(s); });
    SECS.forEach(s => { if ((model.sections[s] || []).length && !final.includes(s)) final.push(s); });
    o.sectionOrder = final;
    o.preamble = model.preamble || [];
    const secs = {};
    final.forEach(sec => {
      const rows = (model.sections[sec] || []);
      if (!rows.length) return;
      secs[sec] = rows.map(e => {
        const r = {};
        SPEC[sec].forEach(([k, ty]) => {
          r[k] = ty === "str" ? (e[k] || "") : (e[k] || []);
        });
        if (e.disabled) r.disabled = true;
        return r;
      });
    });
    o.sections = secs;
    if ((model.ignored || []).length) o.ignored = model.ignored;
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

  /* ---------- 語義 lint（與 tcl lint_model 同規則）---------- */
  function lintModel(model) {
    const w = [];
    const corners = (model.sections.CORNER || []).map(e => e.corner);
    const modes = (model.sections.MODE || []).map(e => e.mode);
    const checks = (model.sections.CHECK || []).map(e => e.check);
    SECS.forEach(sec => {
      const rows = model.sections[sec] || [];
      const key = FIELDS(sec)[0];
      const seen = new Set();
      rows.forEach(e => {
        const nm = e[key];
        if (seen.has(nm)) w.push(`WARN  [${sec}] 名稱重複：${key}=${nm}`);
        seen.add(nm);
        if (String(nm).match(/\s/)) w.push(`ERROR [${sec}] ${key}='${nm}' 含空白——會破壞 lindex 欄序（請改底線）`);
      });
    });
    const pairs = new Set();
    (model.sections.SCENARIO || []).forEach(e => {
      if (e.mode && !modes.includes(e.mode)) w.push(`WARN  Scenario ${e.id}: mode '${e.mode}' 未在 [MODE] 定義（原始解析器會自動補空定義）`);
      if (e.check && !checks.includes(e.check)) w.push(`WARN  Scenario ${e.id}: check '${e.check}' 未在 [CHECK] 定義`);
      const key = e.mode + "," + e.check;
      if (pairs.has(key)) w.push(`WARN  [SCENARIO] ${key} 被多列使用——後列覆蓋 STA_CORNER[${key}]`);
      pairs.add(key);
      if (corners.length) {
        (e.corners || []).forEach(c => {
          if (c !== "-" && !corners.includes(c)) w.push(`WARN  Scenario ${e.id} 引用未定義角落 '${c}'（原始解析器會自動補定義並印 WARNING）`);
        });
        if ((e.corners || []).length !== corners.length) w.push(`WARN  Scenario ${e.id} corners 欄數 ${(e.corners||[]).length} ≠ [CORNER] 筆數 ${corners.length}（欄序以 [CORNER] 定義為準）`);
      }
    });
    (model.sections.VERSION || []).forEach(e => {
      if (/\s/.test(e.dir || "")) w.push(`ERROR VERSION ${e.run}: dir='${e.dir}' 含空白（會破壞 lindex 欄序）`);
    });
    return w;
  }

  function norm(model) {           // 語義指紋（與 tcl model_norm 對等格式）
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
    parts.push(`preamble=${(model.preamble||[]).length}`);
    return parts.join("\n") + "\n";
  }

  return { SECS, SPEC, FIELDS, HEAD, tokens, parseRun, renderRun, modelToJson,
           jsonToModelObj, lintModel, norm, newModel, entryFromTokens };
});
