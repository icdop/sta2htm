// 差分測試：engine.js vs sta2htm_run_json.tcl（三個 demo + nasty）
const fs = require("fs"), cp = require("child_process"), path = require("path");
const S2H = require(path.join(__dirname, "..", "app", "public", "engine.js"));
const BIN = path.join(__dirname, "..", "bin", "sta2htm_run_json.tcl");
const REPO = "/workspace/f61d058e-b808-4cf6-a2e6-4c15ebf8f0fd/work/ref/repo";
const files = [
  path.join(REPO, "run/01_sta/sta2htm.run"),
  path.join(REPO, "run/02_trend/sta2htm.run"),
  path.join(REPO, "run/03_tempus/sta2htm.run"),
  path.join(__dirname, "nasty.run"),
];
let fail = 0;
for (const f of files) {
  const txt = fs.readFileSync(f, "utf8");
  const js = S2H.parseRun(txt);
  const tJson = cp.execFileSync("tclsh", [BIN, "run2json", f], {encoding: "utf8"});
  const tModel = S2H.jsonToModelObj(JSON.parse(tJson)).model;
  const jsJsonModel = js.model;
  // 1) 語義指紋（model 內容）一致
  if (S2H.norm(jsJsonModel) !== S2H.norm(tModel)) { console.log("NORM DIFF", f); fail++; continue; }
  // 2) JS render == TCL render（字節級）
  const jsRun = S2H.renderRun(jsJsonModel);
  const tRun = cp.execFileSync("tclsh", [BIN, "json2run", "-"], {input: tJson, encoding: "utf8"});
  if (jsRun.trimEnd() !== tRun.trimEnd()) {
    console.log("RENDER DIFF", f);
    const a = jsRun.split("\n"), b = tRun.split("\n");
    for (let i = 0; i < Math.max(a.length, b.length); i++)
      if (a[i] !== b[i]) { console.log("  js :", JSON.stringify(a[i])); console.log("  tcl:", JSON.stringify(b[i])); break; }
    fail++;
  } else console.log("✔", path.basename(path.dirname(f)) + "/" + path.basename(f));
  // 3) 各自對再生結果再解析 → 指紋仍一致（往返封閉）
  if (S2H.norm(S2H.parseRun(jsRun).model) !== S2H.norm(jsJsonModel)) { console.log("RT DIFF", f); fail++; }
  // 4) lint 條目數一致
  const sp = cp.spawnSync("tclsh", [BIN, "run2json", f], {encoding: "utf8"});
  const tWarn = (sp.stderr || "");
  const jsW = js.warnings.concat(S2H.lintModel(jsJsonModel));
  const nT = (tWarn.match(/WARN |ERROR/g) || []).length;
  if (nT !== jsW.length) { console.log(`LINT COUNT tcl=${nT} js=${jsW.length}`, f);
    if (process.env.LINTD) { console.log(tWarn); console.log(jsW.join("\n")); }
    fail++; }
}
console.log(fail ? `\nFAILURES: ${fail}` : "\nALL DIFF-TESTS PASS");
process.exit(fail ? 1 : 0);
