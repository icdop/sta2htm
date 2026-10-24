# STA Config Editor — 設定檔文法與相關檔案說明書

> 對象：使用 STA Config Editor（本工具）維護 sta2htm 設定檔、並串接 STA2HTM 主程序
> 產生 HTML 報告的工程師。語法規格與 STA2HTM V3.0 官方解析器逐條對齊。

---

## 1. 為什麼把 sta2htm.run 拆成三個 .ini

原始 `sta2htm.run` 一檔混三種「生命週期」不同的內容：

| 檔案 | 區塊 | 生命週期 | 誰維護 |
|---|---|---|---|
| `sta_runset.ini` | [VERSION] [GROUP] | **每次收斂都在長**（新版本就加一行） | 專案 STA owner |
| `sta_mmmc.ini` | [CHECK] [MODE] [CORNER] [SCENARIO] | **製程級資產**，同一工藝節點幾乎不動 | Foundry 提供參考檔＋專案微調 |
| `sta_block.ini` | [BLOCK] | 網表結構變了才動 | 設計負責人 |

拆開之後：

```
sta_runset.ini ─┐
sta_mmmc.ini  ──┼─► STA Config Editor ──► sta2htm.run ＋ sta2htm.json（完整檔）
sta_block.ini ──┘         （build）
```

* 三檔都是 **sta2htm.run/1 文法**的子集（同一套詞法/區塊規則）；
* 編輯器讀入完整 `sta2htm.run` 或 `sta2htm.json` 時，依區塊**自動拆回三檔**；
* RUNSET 分頁的 **build** 按鈕負責把三檔**合併還原**成完整檔並寫入 workspace。

## 2. 共通詞法（三檔通用，與 sta2htm.run 完全一致）

1. 欄位以**空白/Tab** 分隔；欄位內不得含空白。
2. 區塊標記 `^[空格]*[大寫名稱]`；資料列歸屬「最近一次」標記。
3. 註解＝**第 0 欄 `#`**；`#` 前有空格會被原工具當資料列（編輯器會擋）。
4. `;` 出現於行內任何位置即切尾；**行首 `;` ＝停用整列**（JSON 對應 `"disabled": true`）。
5. 引用詞元 `"a b"` / `{a b}` 各為單欄（tcl lindex 語意）。
6. 編輯器 **init** 產生的範例皆以 `#` 開頭（不生效），**save 會原樣保留**——
   拿掉行首 `#` 即為正式設定。

## 3. sta_runset.ini（RUNSET 分頁）

```
# ==============================================
# sta_runset.ini — RUNSET（VERSION ＋ GROUP）
# ==============================================
[VERSION]
#STA_RUN       STA_RUN_DIR            STA_RUN_GROUPS
GOLDEN-0122    reports/apr0-0122      uniq_end reg2reg
GOLDEN-0123    reports/eco1-0123      uniq_end
;GOLDEN-0127   reports/eco3-0127      uniq_end        ← 停用（暫除名）

[GROUP]
#STA_GROUP     STA_GROUP_REPORT (glob patterns)
uniq_end       $sta_mode/$corner_name/$sta_check.rpt
reg2reg        $sta_mode/$corner_name/$sta_check/RptConst_reg2reg.rpt
```

* **[VERSION]**：`run`（唯一鍵＝趨勢標籤）、`dir`（報告區，僅顯示用）、`groups…`。
  行序＝趨勢時序。
* **[GROUP]**：`group`（唯一鍵）＋ glob 樣式；一個 group＝一套儀表板。
  可用變數：`$sta_mode / $corner_name / $sta_check / $sta_postfix / $tool`。

## 4. sta_mmmc.ini（MMMC 分頁）—— 製程級參考檔

```
[CHECK]
setup   WNS          ← Runset 趨勢角落欄指標
hold    NVP

[MODE]
#MODE   NAME         SDC（請改成你的場景；檔名慣例 $mode.sdc）
func    functional   func.sdc
scan01  dc_shift     scan_shift.sdc

[CORNER]
#CORNER CORNER_NAME  LIB:V:T          RC
000     000_TT       TTT:0.80V:025C   RCtyp
157     157_BC       FFF:0.88V:-40C   Cmin
231     231_WC       SSG:0.72V:125C   Cmax

[SCENARIO]
#SID    CHECK  MODE    （欄序＝[CORNER]）
S001    setup  func    000  -    231
H001    hold   scan01  000  157  231
```

### 4.1 Foundry 參考檔工作法（重要）

1. Foundry/平台端提供一份該製程節點的 **sta_mmmc.ini 參考檔**（含完整 CORNER 矩陣）。
2. 專案端只需：
   * 改 **[MODE]** 區塊——增減自己的工作場景；
   * 把每個 mode 綁定自己的 SDC（欄三 `$mode.sdc`）；
   * 視專案取捨增減 **[SCENARIO]** 列（`-`＝該組合不跑）。
3. `[CORNER]` 的物理定義（lib:V:T / RC）**原則上整段沿用**——這正是「製程可重用」的價值。

## 5. sta_block.ini（BLOCK 分頁，選配）

```
[BLOCK]
core    {^core/.*}
u_core  {^u_core/.*}
```

別名 → 實例路徑前綴；供 sta2htm 跨區塊 `.blk` 頁歸群。未匹配的實例歸 `-`。

## 6. build 會產生哪些檔（相關檔案說明）

### 6.1 RUNSET 分頁 build（寫入 workspace/）

| 檔案 | 來源 | 內容 |
|---|---|---|
| `sta2htm.run` | 三檔合併 | 完整七區塊（canonical 順序：VERSION GROUP BLOCK CHECK MODE CORNER SCENARIO） |
| `Makefile.run` | [VERSION] 逐列展開 | `STA_RUN := / +=`、`STA_RUN_DIR.<ver> :=`、`STA_RUN_GROUPS.<ver> :=` |
| `Makefile` | 模板（=demo `runset.make` 慣例） | `include Makefile.run` + targets：help / `$(STA_RUN)` / init / **run** / index / view / clean |
| `sta_runset.ini` 等三檔 | 目前分頁內容 | 供版本控制與回編輯 |

**Makefile（runset 層）變數/target 對照**：

| 變數 | 意義 | target | 動作 |
|---|---|---|---|
| `STA_RUN` | 版本名清單（趨勢軸） | `make <ver>` | `sta_init_run <ver> <dir> <groups>` 建 Run 目錄 |
| `STA_RUN_DIR.<ver>` | 該版報告區路徑 | `make init` | 依序建立所有 Run |
| `STA_RUN_GROUPS.<ver>` | 該版要解析的群 | `make run` | 逐版進入 `make run`（STA 解析）後 `sta_index_runset` 生趨勢 |
| `logs/` | `tee` 保存逐版 log | `make index` | run ＋ 每版 `make index` ＋ runset 索引 |
| — | — | `make view` | `firefox index.htm` |
| — | — | `make clean` | 刪 Run 目錄與圖表快取 |

### 6.2 MMMC 分頁 build（寫入 workspace/mmmc/）

```
mmmc/
├── Makefile                     ← 上層：MODE_LIST/CORNER_LIST/CHECK_LIST/SUBDIRS + run/clean
├── func_000_TT_setup/
│   ├── Makefile                 ← MODE/CORNER/CHECK/SDC 變數；target run
│   └── run_sta.tcl              ← tclsh run_sta.tcl $mode $corner $check
├── func_157_BC_setup/ …（依 SCENARIO 矩陣展開，'- ' 的組合不建）
```

* 上層 `make run` ⇒ 逐子目錄 `$(MAKE) -C <dir> run`；
* 子目錄 `make run` ⇒ `tclsh run_sta.tcl $(MODE) $(CORNER) $(CHECK)`；
* `run_sta.tcl` 是**樣板**：`STA_DEMO=1` 時自動寫出極簡範例報告
  （`../../reports/<mode>/<corner>/<check>.rpt`，即 sta2htm 約定路徑）供管線驗證；
  正式模式把檔尾註解換成你的 PrimeTime/Tempus 呼叫即可。

## 7. 如何連結 STA2HTM 主程序產生 HTML 報告（六步）

```
① build（RUNSET 分頁）      → workspace/{sta2htm.run, Makefile, Makefile.run}
② make <ver>                → sta_init_run 建 Run 目錄（含 .sta、STA symlink）
③ make run（runset 層）     → 逐版 cd <ver> && make run
④ <ver>/make run            → sta_uniq_end 解析 .rpt → .vio/.wns/.dqi
                             → sta_index_group / sta_index_run
⑤ make index（runset 層）   → sta_index_runset → 跨版趨勢 index.htm
⑥ 編輯器 VIEWER 分頁        → /viewer/ 直接點開 HTML 報告
```

環境前置（你的機器）：`setenv STA2HTM <安裝根>`、`set path=($STA2HTM/bin $path)`；
無 csh 的環境可用附帶 `tools/sta_init_run.sh`（bash 版 init）替代第一刀，
`sta_uniq_end` 等解析命令請在 tclsh 內直接呼叫 `LIB_STA` 程序（見 README §測試）。

### 7.1 run 分頁按鈕與 make 的對應

| 編輯器按鈕 | 等效 shell |
|---|---|
| run…→勾選版本→執行 | `make <ver>` ＋ `cd <ver> && make run`（逐版串接） |
| run…→run all | `make run`（runset 層：全部版本＋趨勢索引） |
| build 後 viewer | `http://<host>:3000/viewer/`（伺服 workspace 靜態檔） |
| release | `zip -r release_YYYYMMDD.zip <ver1>/… <verN>/…`（排除 STA symlink 內容） |

## 8. 一致性契約（三檔 ⇄ 完整檔）

* 編輯器任何分頁的修改，**build 時**才合併寫出 `sta2htm.run`；
* 合併後檔案經 `bin/sta2htm_run_json.tcl verify` 必須 PASS（run→run、run→json→run）；
* 與 `.sta/sta2htm.cfg` 的雙劇本同步仍由使用者負責（cfg=解析層、runset=彙總層），
  建議以同一份 SCENARIO 為單一真相，由腳本反寫 cfg。

---
*本手冊與 `app/public/engine.js`（拆分/合併/模板）及 `server.js`（workspace API）同步；
測試：`node test/smoke.js`。*
