# STA2HTM Run Editor 使用說明書

對象：需建立/維護 `sta2htm.run` 的 IC 設計與 STA 收斂工程師。
語法細節請先讀 [grammar_manual.md](grammar_manual.md)。

---

## 1. 是什麼

一個瀏覽器裡的 **sta2htm.run ⇄ JSON 雙向往返編輯器**：

* **五個視圖**同步同一份模型：`表格編輯`（含 **MMMC 劇本矩陣**）、`Run 文字`、
  `JSON`、`語法/Schema`，外加常駐 **驗證面板**。
* **客戶端引擎**（engine.js）與 **權威轉換器**（`bin/sta2htm_run_json.tcl`）經
  `test/diff_harness.js` 做過**語義指紋 + 渲染逐位元組 + 警示條目數**三級對拍。
* 匯入/匯出、範例載入、一行 `curl` 也可用的 HTTP API。

## 2. 安裝與啟動

需求：僅 Node.js ≥ 18（瀏覽器引擎連 tclsh 都不需要）。

```bash
cd sta2htm-run-editor
node server.js 3000
# 瀏覽器開 http://localhost:3000
```

沒有 Node 時，可直接用 `tclsh bin/sta2htm_run_json.tcl` 做命令列轉換（見 §7）；
完全沒開伺服器時，`index.html` 的客戶端功能亦可離線使用（僅「Tcl 驗證」按鈕會提示
伺服器不可用）。

## 3. 介面總覽

```
┌ header: 標題｜載入範例▾｜開啟檔案｜下載 .run｜下載 .json｜伺服器端 Tcl 驗證｜Tcl 狀態 badge
├ tabs:   表格編輯 ／ Run 文字 ／ JSON ／ 語法 · Schema
├ 主區:   （依分頁）
└ aside:  驗證面板（右下浮窗，WARN 琥珀 / ERROR 紅 / ✔ 綠）
```

* **Tcl badge**：`上線`＝伺服器可執行權威轉換；`不可用`＝仍可編輯，僅少伺服器端驗證。

## 4. 典型工作流

### 4.1 新建一份 runset
1. 顶部 `✕ 清空為新檔` → 依序按「新增區塊」 chips：`VERSION → GROUP → CHECK →
   MODE → CORNER → SCENARIO`（建議順序；工具實際解析順序無條件依賴，但欄序/劇本引用會更直覺）。
2. 先填 `[CORNER]`（代號、corner_name=報告目錄名、lib:V:T、RC 角各一欄，
   多詞以空白分隔——即 .run 裡的實際詞元）。
3. 到 SCENARIO：**每列自動出現角落矩陣**（欄位＝CORNER 顺序）；`勾選＝在劇本內`、
   `未勾＝-`。
4. 切到 `Run 文字` 檢視成品 → 下載 `.run`。

### 4.2 維護既有檔案
`開啟 .run / .json`（或範例下拉）→ 表格改 → 驗證面板全綠（或只剩你接受的 WARN）
→ 按 **伺服器端 Tcl 驗證** → 下載。

### 4.3 暫除一個版本
找該 VERSION 列 → 左侧 ☑ **停用** → .run 出現 `;GOLDEN-0127 …`、JSON 得到
`"disabled": true`。要回來取消勾選即可（**不要刪列**；刪了就等於趨勢缺軸）。

### 4.4 修改角落順序
調整 CORNER 列順序 → 工具自動 **realign 每列 Scenario**：以舊欄序值逐欄搬到新欄序，
超出部分被丟除並出現 WARN——檢查一次矩陣勾選無誤再存檔。

## 5. 各視圖細節

| 視圖 | 能用什麼 | 注意 |
|---|---|---|
| 表格編輯 | 增列/複製/↑↓/✕、☑停用、清單欄（groups/def/pattern/corners）以空白分隔＝多個詞元 | SCENARIO 的 mode/check 為下拉+可自由輸入；自由輸入未定義值會被 lint 點名 |
| Run 文字 | 手改原始檔；`套用到表格`（或欄位失焦）即重解析 | 手打內容與原工具語法一致；`;` 開頭自動還原為「停用」條目 |
| JSON | 直接編 model；`套用到表格` 生效 | 欄名必須用 schema 詞（run/dir/groups…）；錯欄名會被 lint 提示或忽略 |
| 語法/Schema | 語法圖 railroad、欄位表、坑位速查 | 與 docs/grammar.md 同內容之網頁版 |

## 6. 驗證面板在說什麼

* **即時（客戶端）**：重複名稱、未定義角落引用、`(mode,check)` 重複掛列、
  corners 欄數 ≠ 角落數、`#` 前有空白、停用列保留提示……
* **伺服器端 Tcl 驗證**（按鈕）：把目前 .run 丟給 `tclsh bin/… run2json`，
  比對 ①tcl warnings ≡ 客戶端 warnings、② `run→json→run` 語義封閉
  （`norm PASS` + `往返 PASS` 兩條綠）。若兩邊結論不同会出现 ERROR，請附
  `node test/diff_harness.js` 輸出回報。

## 7. HTTP API（供 CI/腳本）

```bash
curl -s localhost:3000/api/run2json  --data-binary @sta2htm.run      # → {result: "<json>", warnings:[…]}
curl -s localhost:3000/api/json2run  --data-binary @sta2htm.run.json # → {result: "<run text>", warnings:[…]}
curl -s localhost:3000/api/lint      --data-binary @sta2htm.run      # → 僅 warnings
curl -s localhost:3000/api/health    # → {ok:true, tclsh:true|false}
```

命令列等價：`tclsh bin/sta2htm_run_json.tcl {run2json|json2run|lint|verify} <in> [-o out]`
（`-` 讀 stdin）。

## 8. 疑難排解（Editor FAQ）

| 狀況 | 含義／處置 |
|---|---|
| 下載的 .run 與原檔欄寬不同 | 正常：輸出是「標準欄位標頭＋確定性欄寬」canonical 版；**語義等價**已由 verify 證明。要 diff 請用 `tclsh bin/… verify` 而非比字節 |
| 貼上 Run 文字後表格沒變 | 按 `套用到表格`（textarea 失焦即自動套用）；解析失敗時旧模型保留、面板印 WARN/ERROR |
| 矩陣消失 | 尚未建立 [CORNER] 列（無欄序來源）——補角落即出現 |
| corners 有 `x` 不在欄上 | 引用了未定義角落（原工具也只會 WARNING）——回表格改成代號或 `-` |
| badge 顯示 Tcl 不可用 | 伺服器端沒裝 tclsh／路徑不對；純客戶端功能不受影響 |
| 未知區塊內容 | 自動進 `ignored[]` 並在 .run 尾以 `# !!` 保留；原工具直接忽略，語義無異 |
| 多人同時改同一檔 | 編輯器無併發鎖：以 git 管 `sta2htm.run`（並同步 `.sta/sta2htm.cfg`） |

## 9. 限制（誠實清單）

1. 區塊內自訂註解不進 JSON（首行 preamble 保留）；輸出採 canonical 區塊標頭。
2. 不校验 `dir` 是否存在（那是 `Makefile.run` 的職責）、也不讀 cfg/Makefile 做
   三方一致性檢查——編輯器只管 `sta2htm.run`⇄JSON「單一檔案內」的正確性。
3. 欄序超過 [CORNER] 筆數的 SCENARIO 屬**原工具合法但本器 lint 必 WARN** 的灰色區。
4. 停用條目以 JSON 為準；若你手改 .run 又沒重跑 `run2json`，以「Run 文字 → 套用」
   同步一次為準。

---
*交付物：`sta2htm-run-editor/`（本目錄）— bin/Tcl 转换器 · app/ 前端 · server.js ·
examples/（含 02_trend 停用列與 nasty 邊界範例）· test/（差分 harness）。*
