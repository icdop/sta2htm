# STA Config Editor 使用說明書（online editor v2）

> Node.js 網頁編輯器，把 `sta2htm.run` 拆成 `sta_runset.ini / sta_mmmc.ini /
> sta_block.ini` 三檔分頁維護，並直接串接 STA2HTM 主程序產生 HTML 報告。
> 文法細節見 [config_grammar_manual.md](config_grammar_manual.md)。

---

## 1. 啟動

```bash
cd sta-config-editor
node server.js 3000          # 瀏覽器開 http://localhost:3000
```

* `SCE_WORKSPACE=/path/to/proj node server.js` 可把 workspace 指到專案目錄。
* 需要伺服器端 Tcl 驗證與 make 執行：機器需有 `tclsh`、`make`、`zip` 與
  STA2HTM 環境（`STA2HTM` 變數 + bin 在 PATH）。
* 純瀏覽器（不開 server）仍可編輯與下載三檔，但 run/build/viewer 不可用。

## 2. 介面總覽

```
┌ 綠色標題列：STA Config Editor｜開啟檔案｜下載 sta2htm.run/.json｜Tcl badge
├ 分頁：RUNSET ｜ MMMC ｜ BLOCK ｜ VIEWER
├ 各設定分頁 = 工具列(init/load/save/build…) + 左(區塊卡片表格) + 右(.ini 文字)
├ 右下角：驗證面板（WARN 琥珀 / ERROR 紅 / ✔ 綠）
└ VIEWER 分頁 = 內嵌 iframe 檢視 sta2htm HTML 報告
```

字體規範：設定檔文字、表格欄頭、範例標題一律**系統固定寬度字體**
（Consolas/Menlo/Courier New），並與範本欄位標頭**逐欄對齊**；
配色取自 sta2htm HTML 報告（表頭綠 `#4CAF50`、斑馬列 `#f2f2f2`、框線 `#ddd`、
UI 字體 Trebuchet MS/Arial）。

## 3. 三分頁功能對照

| 功能 | RUNSET | MMMC | BLOCK |
|---|---|---|---|
| **init** | 空白＋`#` 範例（VERSION/GROUP） | 空白＋`#` 範例（CHECK/MODE/CORNER/SCENARIO） | 空白＋`#` 範例 |
| **load** | 讀任意檔，只擷取 VERSION+GROUP | 只擷取 CHECK/MODE/CORNER/SCENARIO | 只擷取 BLOCK |
| **save** | 下載 `sta_runset.ini`（含 `#` 內容） | 下載 `sta_mmmc.ini` | 下載 `sta_block.ini` |
| **build** | 寫出 `sta2htm.run`＋`Makefile.run`＋`Makefile`（+三 ini 快照） | 產生 `mmmc/` 目錄樹：每子目錄 Makefile＋`run_sta.tcl`，上層 Makefile 有 `run` target | — |
| **run** | 彈窗勾選版本→`make <ver>`＋`cd <ver> && make run`；或 run all=`make run` | —（請在終端 `cd mmmc && make run`） | — |
| **viewer** | 跳 VIEWER 分頁（/viewer/ 伺服 workspace） | — | — |
| **release** | 打包所有 `<ver>/index.htm` 成 `release_YYYYMMDD.zip` 下載 | — | — |

**自動拆分**：頂部「開啟 .run / .json」讀入完整檔後，內容自動分派到三分頁
（`splitModel`：VERSION+GROUP→RUNSET、CHECK/MODE/CORNER/SCENARIO→MMMC、BLOCK→BLOCK）。

## 4. 標準工作流（第一次使用）

1. **MMMC 分頁 → init**：以 Foundry 參考檔覆蓋（load），只改 [MODE] 與各 mode 的
   SDC 綁定 → **save sta_mmmc.ini**。
2. **RUNSET 分頁 → init**：填 [VERSION]（每個 GOLDEN 一列）與 [GROUP]。
3. **RUNSET → build**：產生 `workspace/{sta2htm.run, Makefile.run, Makefile}`。
4. **RUNSET → run…**：勾版本（或 run all；教學環境勾 `STA_DEMO=1` 免簽核工具）。
5. **VIEWER**：點開 `<ver>/index.htm` 或 runset 總索引（跨版趨勢）。
6. **release**：戰情室打包發送。

## 5. run 彈窗細節

* 清單來自 RUNSET 分頁 [VERSION]；每項顯示 `make <ver> → dir（groups）`。
* 執行序列＝`make <ver>`（sta_init_run 建 Run 目錄）→ `cd <ver> && make run`
  （sta_uniq_end 解析＋sta_index_run）。
* **STA_DEMO=1**：子目錄 `run_sta.tcl` 產生極簡報告（無需 PrimeTime/Tempus），
  供管線與教學驗證；正式使用時取消勾選。
* log 區即時顯示 make 輸出；結束後一鍵開 VIEWER。

## 6. 驗證面板

* 即時（客戶端）：三檔各自的語義 lint（重複名/未定義角落/欄數不符/空白欄名/`#` 位置）。
* 「開啟完整 sta2htm.run」後建議按 **下載 sta2htm.run** 前先確認面板全綠；
  伺服器端可用 `POST /api/verify`（tcl 權威 run2json）做二次確認。

## 7. HTTP API（CI/腳本）

```bash
curl -s localhost:3000/api/health
curl -s -X POST localhost:3000/api/ws/write -H 'content-type: application/json' \
     -d '{"path":"sta_runset.ini","content":"..."}'
curl -s -X POST localhost:3000/api/run -H 'content-type: application/json' \
     -d '{"dir":".","targets":["run"]}'                 # runset 層全部
curl -s -X POST localhost:3000/api/run -H 'content-type: application/json' \
     -d '{"dir":"mmmc/func_000_TT_setup","targets":["run"],"demo":true}'
curl -s -X POST localhost:3000/api/release              # → {zip, download}
# 檢視：http://localhost:3000/viewer/<ver>/index.htm
```

## 8. 疑難排解

| 狀況 | 處置 |
|---|---|
| run 失敗：`sta_init_run: command not found` | 環境沒設 `STA2HTM`/PATH；或無 csh → 用 `tools/sta_init_run.sh`（放進 PATH 改名 sta_init_run） |
| make 抓不到版本 | RUNSET [VERSION] 改完要重按 **build**（Makefile.run 是 build 產物） |
| viewer 空清單 | workspace 內沒有任何 `<ver>/index.htm`：先 run 成功，或確認 dir 是否指到有報告的目錄 |
| MMMC build 少了某些角落 | SCENARIO 該欄是 `-`（設計上不建）；要跑請回矩陣打勾 |
| run_sta.tcl exit 2 | 未設 `STA_DEMO` 且尚未接入簽核工具——見該檔尾部註解換成 pt_shell/tempus 呼叫 |
| 停用列變沒了 | 停用＝行首 `;`；分頁表格用「停」欄勾選，save 會寫回 `;` |
| 兩人同改 | 無併發鎖：三 ini 進 git；build 產物（sta2htm.run/Makefile*）提交前先跑 verify |

## 9. 限制

1. 編輯器管「設定檔」；STA 引擎本體（PrimeTime/Tempus）呼叫由 `run_sta.tcl` 樣板承載。
2. build 不改寫 `.sta/sta2htm.cfg`（解析層劇本）；雙劇本同步請循 SOP。
3. release 只收 `<ver>/index.htm` 所在樹（排除 `*/STA/*` symlink 內容）；趨勢圖 png/js 一併打包。
4. workspace API 不做多人鎖；單一 workspace 單一 owner 為前提。

---
*交付：`sta-config-editor/`（本目錄）— server.js · app/ · bin/ · docs/ · examples/ ·
test/smoke.js · tools/sta_init_run.sh。*
