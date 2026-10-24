# STA Config Editor

`sta2htm.run` 三檔式 online editor（Node.js）：把設定檔拆成
`sta_runset.ini`（VERSION/GROUP）、`sta_mmmc.ini`（MMMC 劇本）、`sta_block.ini`（BLOCK）
三個分頁維護，build 時合併還原 `sta2htm.run`＋Makefile，並串接 STA2HTM 主程序
產生/檢視 HTML 報告（viewer/release）。

## 快速開始

```bash
node server.js 3000            # http://localhost:3000
node test/smoke.js             # 引擎/模板/權威轉換 一致性（需 tclsh）
```

| 分頁 | 檔案 | 功能鍵 |
|---|---|---|
| RUNSET | sta_runset.ini | init/load/save/**build**/**run**/**viewer**/**release** |
| MMMC | sta_mmmc.ini | init/load/save/**build**（產生 mmmc/ 目錄樹＋run_sta.tcl） |
| BLOCK | sta_block.ini | init/load/save |
| VIEWER | （workspace 靜態） | 內嵌檢視 sta2htm HTML 報告 |

連結主程序六步（詳 docs/config_grammar_manual.md §7）：
build → `make <ver>` → `make run` → `<ver>/make run`（uniq_end/index）→ `make index` → VIEWER。

## 目錄

```
server.js              workspace API（寫檔/make/release/viewer）
app/public/            index.html · app.js · engine.js(v2 拆分/合併/模板) · style.css
bin/sta2htm_run_json.tcl  權威轉換器（沿用 run editor v1）
docs/config_grammar_manual.md  三 ini 文法＋Makefile 變數/target＋六步串接
docs/editor_manual.md  本編輯器使用說明書
examples/              demo run 檔
tools/sta_init_run.sh  bash 版 sta_init_run（無 csh 環境）
test/smoke.js          冒煙測試（拆分守恆/模板/與 tcl 一致）
```

## 環境變數

* `SCE_WORKSPACE` — workspace 根目錄（預設 `<本目錄>/workspace`）
* `STA_DEMO=1` — run_sta.tcl 產生示範報告（免簽核工具）
