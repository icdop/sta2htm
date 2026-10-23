# sta2htm-run-editor

`sta2htm.run` ⇄ `sta2htm.json` 轉換器 + Node.js 網頁編輯器。
語法由 STA2HTM V3.0 官方解析器（`tcl/STA_CONFIG.tcl :: read_sta_runset / parse_runset_line`）
與三個 demo runset 逆向推導，完整文件見 **[docs/grammar.md](docs/grammar.md)**。

## 目錄

```
bin/sta2htm_run_json.tcl   權威轉換器（Tcl 8.5+，零依賴）
docs/grammar.md            速查（EBNF 濃縮）
docs/grammar_manual.md     ★ sta2htm.run 語法說明書（mode/corner/scenario 圖解版）
docs/editor_manual.md      ★ 編輯器使用說明書
../sta2htm.run 語法與編輯器訓練教材.pptx  ★ 50 頁訓練簡報（本工具的課程教材）
app/public/                網頁編輯器（index.html / app.js / engine.js / style.css）
server.js                  Node.js 服務（靜態 + /api 代理 tcl 轉換）
examples/                  demo 01_sta / 02_trend / 03_tempus 的 .run 與 .json
test/                      nasty.run 邊界測試 + diff_harness.js（JS⇄Tcl 差分）
```

## 快速開始

```bash
node server.js 3000          # 打開 http://localhost:3000
```

命令行轉換（不需要 Node；只要 tclsh）：

```bash
tclsh bin/sta2htm_run_json.tcl run2json run/01_sta/sta2htm.run -o out.json
tclsh bin/sta2htm_run_json.tcl json2run out.json -o new.run
tclsh bin/sta2htm_run_json.tcl verify run/01_sta/sta2htm.run   # 雙向往返自檢
tclsh bin/sta2htm_run_json.tcl lint   sta2htm.run              # WARN/ERROR → stderr
```

## 語義保證（已執行）

1. `verify`：`run→run`、`run→json→run` 模型指紋一致 —— 3 個 demo + nasty **全 PASS**。
2. **真實解析器對拍**：以倉庫內 `LIB_STA::read_sta_runset` 分別載入「原檔」與「json2run 再生檔」，
   比對 16 個陣列（`STA_RUN_LIST / STA_CORNER / STA_SCENARIO_MAP …`）→ **逐位元組相同**。
3. JS（瀏覽器引擎）與 Tcl 差分：語義指紋、**渲染逐位元組**、警示條目數三項比對 —— **4 fixtures 全 PASS**。

## 網頁編輯器功能

* **四視圖**：表格編輯（七區塊逐列、停用微信框、行列增刪/排序）｜SCENARIO 角落矩陣（勾選＝`corner`、未勾＝`-`）｜Run 原文｜JSON 即時同步。
* **驗證**：即時語義 lint（名稱重複、未定義角落/劇本欄序錯位、空白欄名、`;`/`#` 坑位）；右下角问题面板。
* **伺服器端 Tcl 驗證**：一鍵比對客戶端轉換 vs 權威 tcl 結果（含往返封閉性）。
* **匯入/匯出**：`.run`/`.json` 拖檔、下載、內建 3 個 demo 與邊界範例。
* **語法頁**：語法圖 + Schema + 坑位速查。

## 與原始解析器的行為差異（有意為之，詳見 grammar.md）

| 情境 | 原始工具 | 本工具 |
|---|---|---|
| 行首 `;` 停用列 | 整列丟棄後**消失** | JSON 保留 `"disabled":true`；.run 寫回 `;` |
| `#` 前有空白 | 當成資料列（印 WARNING） | 視為註解 + WARN 提示修正 |
| 未知區塊 `[FOO]` | 內部列逐行 WARNING 丟棄 | JSON `ignored[]` 保留；.run 以 `# !!` 註解保留 |
| SCENARIO 引用未定義角落 | 自動補定義 + WARNING | 語義 lint 提示（不擅自改資料） |

## 測試

```bash
node test/diff_harness.js     # 需 tclsh；比對 JS/Tcl 語義、渲染、警示
```
