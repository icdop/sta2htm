/* STA Config Editor — 冒煙測試（不需瀏覽器）
 *   node test/smoke.js
 * 驗證：三檔拆分/合併往返、Makefile/run_sta.tcl 產生器、與 tcl 權威轉換的語義一致性
 */
const fs = require("fs"), path = require("path"), cp = require("child_process");
const S2C = require(path.join(__dirname, "..", "app", "public", "engine.js"));
const BIN = path.join(__dirname, "..", "bin", "sta2htm_run_json.tcl");
const EX = path.join(__dirname, "..", "examples");
let fail = 0;
const ok = (cond, msg) => { console.log((cond ? "✔ " : "✘ ") + msg); if (!cond) fail++; };

for (const f of ["01_sta.run", "02_trend.run", "03_tempus.run"]) {
  const txt = fs.readFileSync(path.join(EX, f), "utf8");
  const model = S2C.parseRun(txt).model;
  const parts = S2C.splitModel(model);
  // 1) 拆分：sec 總數不變
  const n0 = S2C.SECS.reduce((a, s) => a + (model.sections[s] || []).length, 0);
  const n1 = ["runset", "mmmc", "block"].reduce((a, k) =>
    a + S2C.CANON.reduce((b, s) => b + (parts[k].sections[s] || []).length, 0), 0);
  ok(n0 === n1, `${f}: 拆分後條目數守恆 (${n0})`);
  // 2) 合併往返
  const back = S2C.mergeModels(parts);
  ok(S2C.norm(back) === S2C.norm(model), `${f}: split→merge 語義指紋不變`);
  // 3) 子集渲染 → 再解析等價
  for (const [fn, def] of Object.entries(S2C.FILES)) {
    const t = S2C.renderRun(parts[fn === "sta_runset.ini" ? "runset" : fn === "sta_mmmc.ini" ? "mmmc" : "block"], def.secs);
    const r = S2C.parseIni(t, def.secs, true);
    ok(S2C.norm(r.model) === S2C.norm(parts[fn === "sta_runset.ini" ? "runset" : fn === "sta_mmmc.ini" ? "mmmc" : "block"]),
       `${f}: ${fn} 渲染→解析 封閉`);
  }
  // 4) 與 tcl 權威轉換語義一致
  const tj = cp.spawnSync("tclsh", [BIN, "run2json", path.join(EX, f)], { encoding: "utf8" });
  const tm = S2C.jsonToModelObj(JSON.parse(tj.stdout)).model;
  ok(S2C.norm(tm) === S2C.norm(model), `${f}: 引擎 ⇄ tcl run2json 語義一致`);
}

/* Makefile 產生器抽檢 */
const model = S2C.parseRun(fs.readFileSync(path.join(EX, "02_trend.run"), "utf8")).model;
const mk = S2C.genMakefileRun(model.sections.VERSION.map(v => ({ run: v.run, dir: v.dir, groups: v.groups })));
ok(/STA_RUN     := GOLDEN-0122/.test(mk) && /STA_RUN_DIR\.GOLDEN-0123 := reports\/eco1-0123/.test(mk),
   "genMakefileRun：首版 :=、版本 DIR 展開");
const mkTop = S2C.genRunsetMakefile();
ok(/include Makefile\.run/.test(mkTop) && /sta_init_run \$@ \$\(STA_RUN_DIR\.\$@\)/.test(mkTop),
   "genRunsetMakefile：對齊 demo runset.make 慣例");
const mmmc = S2C.splitModel(model).mmmc;
const top = S2C.genMmmcTopMakefile(mmmc);
ok(/\$\(MAKE\) -C \$\$d run/.test(top), "genMmmcTopMakefile：run 逐子目錄");
const sub = S2C.genMmmcSubMakefile("func", "000_TT", "setup", "func.sdc");
ok(/tclsh run_sta\.tcl \$\(MODE\) \$\(CORNER\) \$\(CHECK\)/.test(sub), "genMmmcSubMakefile：target run ⇒ run_sta.tcl");
ok(/STA_DEMO/.test(S2C.genRunStaTcl("func", "000_TT", "setup")), "genRunStaTcl：含 STA_DEMO 示範模式");

console.log(fail ? `\nFAILURES: ${fail}` : "\nSMOKE ALL PASS");
process.exit(fail ? 1 : 0);
