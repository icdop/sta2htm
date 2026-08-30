---
title: "STA2HTM 使用手冊"
author: "千問辦公 QwenWork 編譯整理"
date: "2026-08-28"
---

# STA2HTM 使用手冊

> **MMMC STA 時序報告 → HTML 摘要報表轉換工具｜完整使用與維護指南（v2021.02 / v2.0）**
>
> 依 Gitee 倉庫 `icdop/sta2htm` 原始碼逐檔研讀並實測後撰寫 · 千問辦公（QwenWork）· 2026-08

## 目錄

- 第 1 章 產品概覽與核心概念
- 第 2 章 安裝與環境設定
- 第 3 章 輸入資料：PrimeTime 報告準備
- 第 4 章 設定檔完整參考
- 第 5 章 命令參考
- 第 6 章 輸出檔案參考
- 第 7 章 HTML 報表導覽（含 13 張實測截圖）
- 第 8 章 實戰流程（完整重現）
- 第 9 章 團隊落地建議
- 第 10 章 疑難排解與已知限制
- 附錄 A 原始碼模組對照表 / 附錄 B 上線模板與檢查清單 / 附錄 C 一頁速查


## 關於本手冊

本手冊針對開源工具 **STA2HTM（STA MMMC Report Reviewer）** 撰寫，倉庫位址為 `https://gitee.com/icdop/sta2htm`（對應 GitHub 鏡像 `https://github.com/icdop/sta2htm`），授權為 MIT，原始作者 Albert Li（報表 banner 指向 lyg-semi.com），程式庫版本標識為 `LIB_STA ver.2021.2`。

手冊內容係**逐檔讀取原始碼**（`bin/`、`csh/`、`tcl/`、`etc/`、`run/`、`doc/` 共 4,188 行 Tcl 與 7 支驅動腳本）、並**在 Linux 環境實際執行 `run/01_sta` 與 `run/02_trend` 兩個範例**驗證之後寫成。因此書中所述之檔案清單、欄位順序、顏色圖例、報表數值，皆為真實執行結果，而非推測。

#### 適用對象

| 角色 | 建議閱讀章節 |
|---|---|
| 時序簽核工程師（Timing Signoff） | 第 1、3、5、7、8 章 |
| 專案 CAD / 流程維運人員 | 第 2、4、6、9 章 |
| 專案經理 / 主管（只看結果） | 第 1、7 章 |
| 二次開發者 | 全冊，重點為第 6、10 章與附錄 A |

#### 語法慣例

- `%` 開頭代表在 **csh/tcsh** 終端機輸入的命令。
- `$sta_mode`、`$sta_group` 等以 `$` 開頭者為工具使用的**變數佔位符**，非 Shell 展開。
- 「Runset」指一次被審查的一系列版本（例如 apr0 → eco1 → eco2），「Run」指其中單一版本目錄。
- 所有實際數值範例取自倉庫附帶的 demo 報告（GOLDEN-0122 ∼ 0125）。

> **快速上手（TL;DR）**
>
已解壓的發行版中，只要三分鐘即可看到報表：

```csh
% source setup.cshrc          # 設定 STA2HTM 與 PATH
% cd run/01_sta
% make run                    # 初始化 + 解析 + 產生 HTML
% firefox index.htm           # 或 make view
```

### 目錄

## 第 1 章 產品概覽與核心概念

### 1.1 它解決什麼問題

現代的 IC 設計以 **MMMC（Multi-Mode Multi-Corner，多模式多角落）** 進行時序簽核。以一個中等規模的 SoC 為例：

- 3 個工作模式（functional / dc_shift / ac_capture）
- 5 個角落（000_TT、151_ML、157_BC、231_WCL、258_WC）
- 2 個檢查項目（setup / hold）
- N 個版本（apr0、eco1、eco2…）

一次 signoff 就會產生 `3 × 5 × 2 × N` 份 PrimeTime 文字報告，動輒數千頁。工程師面臨的實際痛苦是：

1. **看不到全景**：單一 `RptConst.rpt` 只有該 corner 的違規，跨 corner 之後「同一個 endpoint 在哪個最差」需要人工比對。
2. **重複端點**：同一個 endpoint 在同一份報告中可能因為多個 path group 被列很多次，NVP（Negative Violation Point）計數被灌水。
3. **Waive 無法追溯**：豁免清單散落在各 corner，無人知道哪些違規是因為 waiver 而消失的。
4. **版本收斂無法量化**：ECO 前後到底改善了多少？文字 diff 無法回報給主管。

**STA2HTM 的定位**就是一個**離線、純文字、無資料庫**的報告後處理器：讀取既有 PrimeTime 報告，產出一套**可點選、可瀏覽、自帶圖表的靜態 HTML 報表**，並以 `.dqi` 純文字檔對外提供機器可讀的指標（Design Quality Indicator）。

> **它「不做」的事**
>
STA2HTM **不會**自己去跑 PrimeTime / Tempus，也**不解析** SDC、lib、SPF；它只需要「已產出的報告文字檔」。它是 review/reporting 層，不是 STA engine。原始碼中也完全沒有 PT 呼叫（`LIB_ECO.tcl`、`ECO_ICC2.tcl` 等屬同家族的其它 DOP 工具，與 sta2htm 主流程無關）。


### 1.2 系統架構與資料流

**STA2HTM 端到端資料流**
```mermaid
flowchart TD
  A["PrimeTime 報告<br/>STA_RPT/mode/corner/check.rpt(.gz)"] --> B[".sta 設定目錄<br/>sta2htm.cfg / .corner / .mode / .waive"]
  B --> C["sta_init_run<br/>建立 Run 目錄（Makefile / Makefile.group / STA 連結）"]
  C --> D["sta_uniq_end<br/>解析報告 + 跨 corner 去重 + waive 過濾"]
  D --> E["純文字產出<br/>.vio / .wns / .nvp / .sum / .uniq_end.rpt / .nvp_wns.dat"]
  D --> F[".dqi/520-STA/check/{NVP,WNS,TNS,NWP}<br/>機器可讀指標"]
  D --> G["HTML 產出<br/>.htm / .html / .js (Chart.js)"]
  E --> G
  F --> H["sta_index_group<br/>group 內 index/mode/check/corner.htm"]
  F --> I["sta_index_run<br/>單一 Run 的跨 group 趨勢頁"]
  H --> J["sta_index_runset<br/>讀 sta2htm.run，產 Runset 總 index 與跨版本趨勢圖"]
  I --> J
  J --> K["瀏覽器 index.htm<br/>(make view / firefox)"]
  G --> K


實作上以 `tcl/LIB_STA.tcl` 為中樞，每個命令都是「`parse_argv` → `read_sta_config` → 一個 `report_*` 程序」的三段式結構，詳見附錄 A。

### 1.3 核心名詞

理解這幾個詞，整套工具就通了。

| 變數名（程式內） | 中文 | 意義與範例 |
|---|---|---|
| `sta_runset` | 版本集 | 一批待審查版本。由 `sta2htm.run` 的 `[VERSION]` 定義 |
| `STA_RUN` | 版本 / Run | 單一版次，如 `GOLDEN-0122`；成為一個工作目錄名 |
| `STA_RUN_DIR` | 報告來源目錄 | 如 `reports/apr0-0122`，會被 symlink 成 Run 下的 `STA` |
| `sta_group` | 報告群 | 一類 path group 的報告集合，如 `uniq_end`、`reg2reg`；決定輸出子目錄 |
| `sta_mode` | 工作模式 | `func` / `scan01` / `scan02`；對應 SDC，也是目錄第一層 |
| `sta_corner` | corner 代號 | 3 位數字，如 `258`；目錄第二層以其 `corner_name`（`258_WC`）呈現 |
| `sta_check` | 檢查項目 | `setup` / `hold`（也可定義其它名稱，但只有這兩類會被真正解析，見 3.3） |
| `STA_CORNER(mode,check)` | 劇本矩陣 | 宣告「某 mode+check 要看哪幾 corner」，即一個 MMMC scenario |
| `NVP` | 違規端點數 | Number of Violated Point（slack < 0）。注意：mode 層 DQI 值仍含被豁免的點，真正淨數见 `NVP-W`（8.4） |
| `NWP` | 豁免端點數 | Number of Waived Point |
| `NMP` | 達標路徑數 | 解析中 slack ≥ 0 的計數（於 `.vio` 階段），僅內部使用 |
| `WNS` | 最差時序餘裕 | Worst Negative Slack，單位 ps |
| `TNS` | 總違規餘裕 | Total Negative Slack（該檔累積），單位 ps |
| `WCorner` | 最差 corner | 該 endpoint 出現 WNS 的 corner 代號 |
| `DQI` | 設計品質指標 | 寫在 `.dqi/520-STA/<check>/{NVP,WNS,TNS,NWP}` 的單值文字檔 |
| `Uniqify` | 端點去重 | 跨 corner 以 `(PathGroup, Endpoint)` 為 key 取最差 slack，見 6.6 |

### 1.4 版本與授權

| 項目標 | 內容 |
|---|---|
| 授權 | MIT（Copyright (c) 2020 Albert Li） |
| 最新發布 | 標籤 `v2.0`（分支 main，`LIB_STA ver.2021.2`），最後更新 README 於 2026-08 |
| 語言佔比 | JavaScript 76%（含內附的 Chart.js/jQuery/bootstrap 圖型庫）、Tcl 21%、HTML/Makefile/tcsh 其餘 |
| 文件 | `doc/pdf/210125_STA2HTM_User_Guide_v1.pdf`（公司內部培訓簡報，17 頁） |

#### v1.0 → v2.0 命令對照（升級必讀）

舊版（v1.0，`csh/*.csh`）的命令在 v2.0 全部改名且改寫為 Tcl。若你的 environment module 或 script 沿用舊名，需對應修改：

| v1.0 命令 | v2.0 命令 | 實作檔 | 備註 |
|---|---|---|---|
| `sta_init_dir` | `sta_init_run` | `csh/20_sta_init_run.csh` | 仍為 csh 腳本 |
| `sta_rpt_uniq_end` | `sta_uniq_end` | `csh/21_sta_uniq_end.tcl` | 加入 group 概念 |
| `sta_rpt_by_clock` | `sta_rpt_by_clock`（未掛進 `bin/`） | `csh/22_sta_rpt_by_clock.tcl` | v2.0 有已知錯誤，見 10.3 |
| `sta_rpt_by_group` | `sta_rpt_by_block`（未掛進 `bin/`） | `csh/23_sta_rpt_by_block.tcl` | 同上 |
| `sta_gen_index` | `sta_index_group` | `csh/28_sta_index_group.tcl` | 產 group 級索引 |
| —（新增） | `sta_index_run` | `csh/28_sta_index_run.tcl` | 單一 Run 趨勢頁 |
| —（新增） | `sta_index_runset` | `csh/29_sta_index_runset.tcl` | Runset 總索引 + 跨版本趨勢 |

同理，`doc/README_sta.txt` 與 PDF 簡報中的 `sta_rpt_uniq_end -sum_dir … -sta_check …` 為 **v1.0 語法**，v2.0 的選項已改為 `-sta_group`（見第 5 章）。這是閱讀原廠文件時最容易踩到的落差。

## 第 2 章 安裝與環境設定

### 2.1 系統需求

| 項目 | 需求 | 用途 | 缺少時的後果 |
|---|---|---|---|
| OS | Linux（實測於 glibc 系統） | — | Windows/macOS 需自行處理 `realpath`、`csh` |
| Tcl | `tclsh` 8.5+（實測 8.6.16） | 5 支主命令的直譯器 | 完全無法執行 |
| csh/tcsh | `/bin/csh` 或 `tcsh` | `sta_init_run` 是 csh 腳本 | 初始化命令失敗（見 10.3 的替代方案） |
| GNU make | 任何版本 | 驅動流程與相依 | 需手動逐條輸入命令 |
| `tree` | README 明列必裝 | `make tree` / `make diff` 產出目錄樹快照 | 僅 `make tree` 報錯 |
| `gnuplot` | 選擇性 | 產生 `.nvp_wns.png` 靜態圖 | **不影響 HTML 報表**（改用內建 Chart.js） |
| 瀏覽器 | Chrome / Firefox / Edge | 閱讀報表 | — |
| 磁碟 | 報告目錄大小 + 約 1∼3 倍 | HTML 與文字報表 | — |

README 只提到 `tree` 與 `gnuplot`，但真實必要條件是 **Tcl 與 csh**；`gnuplot` 反而是可選（頁面圖表由 `Chart.bundle.min.js` 本地渲染）。

### 2.2 取得與安裝

```csh
# 1) 取得原始碼（擇一）
% git clone https://gitee.com/icdop/sta2htm.git
% git clone https://github.com/icdop/sta2htm.git     # 鏡像
# 或 Download ZIP: https://gitee.com/icdop/sta2htm/repository/archive/main.zip

# 2) 安裝到共用區並產生命令
% cd sta2htm
% make bin

# 3) 載入環境（csh/tcsh）
% source setup.cshrc

# 4) 驗證
% which sta_uniq_end sta_index_runset sta_init_run
```

`make bin` 實際執行的動作（`etc/make/bin.make`）是在 `bin/` 下建立 5 個 symlink，指向 `csh/` 的腳本；因此**搬家或 `git pull` 後建議重跑一次 `make bin`**（symlink 為相對路徑 `../csh/...`，整個目錄一起搬是安全的）。

> **`make bin` 不會建立全部命令**
>
`csh/22_sta_rpt_by_clock.tcl` 與 `csh/23_sta_rpt_by_block.tcl` **沒有**被列入 `bin.make`，所以安裝後找不到 `sta_rpt_by_clock`。它們在 v2.0 也有已知錯誤（10.3）。若確需使用，請自行建立連結並參考 10.3 的修正。


### 2.3 環境變數

`setup.cshrc` 只做四件事：

```csh
setenv STA2HTM   <setup.cshrc 所在目錄>   # 所有 Tcl 腳本的 root，必要
set path = ($STA2HTM/bin $path)            # 命令路徑
setenv STA_PLUGIN $STA2HTM/plugin          # 指向不存在的 plugin/（佔位，v2.0 未使用）
setenv DOP_HOME  $STA2HTM:h                # 僅在尚未定義時設定（同家族工具共用 root）
```

- `STA2HTM` 是**關鍵變數**：各命令以 `file dirname [file dirname [info script]]` 自行推得，`sta_init_run` 則以 `$?STA2HTM` 判斷；原則上 `source setup.cshrc` 後不必理會。
- 若不想 `source`，直接把 `$STA2HTM/bin` 加進 `PATH` 亦可。
- 建議將此段寫進團隊共用的 environment module（`#%module` 檔案）或專案 `setup.csh`。

### 2.4 倉庫目錄結構

| 路徑 | 內容 |
|---|---|
| `bin/` | 5 支命令 symlink（`make bin` 產生，不建議手工修改） |
| `csh/` | 7 支驅動腳本，檔名前綴為執行順序編號（20 初始化、21 解析、28/29 索引） |
| `tcl/` | 14 個 Tcl 模組（共 4,188 行），`LIB_STA` namespace；附錄 A 有逐檔職責表 |
| `etc/make/` | `bin.make`、`sta2htm.make`（Run 層 Makefile 模板）、`runset.make`（Runset 層模板）、`test.make`（回歸測試框架） |
| `etc/sta/` | `sta2htm.cfg` / `.corner` / `.trend` / `.waive` 設定檔範本，供複製到專案 `.sta/` |
| `etc/html/` | 內附第三方圖型庫（Chart.js 2.9.4、jQuery 3.2.1、bootstrap 3）與 CSS、`dashboard.htm` |
| `etc/icon/` | `logo_banner.png`、`lyg_banner.png`（報頁右上角 banner） |
| `etc/eco/` | 同家族 ECO / SPEF 電容比對腳本，**與 sta2htm 主流程無關** |
| `run/01_sta/` | demo：單版本、多 path group |
| `run/02_trend/` | demo：4 個版本的 ECO 收斂趨勢 |
| `run/reports/` | demo 的假 PrimeTime 報告（`apr0-0122`、`eco1-0123`、`eco2-0124`、`eco3-0125`） |
| `doc/` | PDF 訓練簡報、README、`COMMAND.md` 模板、`help/sta_uniq_end.md` |

### 2.5 三分鐘驗證安裝

```csh
% cd run/01_sta
% make run
```

若安裝正確，終端機會依序列出（節錄實際輸出）：

```text
INFO: Loading 'LIB_STA.tcl'...
###########################################################
# STA2HTM LIBRARY ver.2021.2                             #
###########################################################
INFO: STA2HTM = /path/to/sta2htm
INFO: Reading corner table file '.sta/sta2htm.corner'...
CORNER:  000 => 000_TT
...
INFO: Generating STA GROUP(uniq_end) Index HTML Files ...
INFO: sta_index_run Done...
```

接著開啟 Runset 總頁：

```csh
% make view          # 相當於 firefox index.htm &
```

> **倉庫附帶 demo 的已知資料瑕疵**
>
真實執行 `run/01_sta` 時會看到：

```text
ERROR: STA_CORNER(scan02,setup) has undefined corner (251) !
INFO: 1 ERRORs found, please check the config file.
```

原因：`run/reports/apr0-0122/.sta/sta2htm.cfg` 內把 `258` 誤植為 `251`（`set STA_CORNER(scan02,setup) "000 - - 251 258"`）。此為**範例設定檔本身的錯字**，不影响安裝成敗，僅会使該 mode/check 的劇本被標記為錯誤。請把 `251` 改為 `231`（或刪除）後重跑，即可得到完全乾淨的輸出。第 10 章有其他排查提示。


## 第 3 章 輸入資料：PrimeTime 報告準備

STA2HTM 對輸入的**唯一要求**是：報告檔的「目錄位置」能被 `sta_report_path + filter` 的 glob 樣式命中，且「檔內文字」能被第 3.3 節的正則表達式命中。本章說明這兩件事。

### 3.1 建議的目錄結構

原廠建議（README 第 2 節）：

```text
$STA_RUN_DIR/
├── func                  ← $sta_mode
│   ├── 000_TT            ← $corner_name
│   │   ├── setup.rpt     ← $sta_check.rpt
│   │   └── hold.rpt
│   ├── 151_ML
│   │   └── hold.rpt
│   ├── 157_BC
│   │   ├── hold.rpt
│   │   └── setup.rpt
│   ├── 231_WCL
│   │   └── setup.rpt
│   └── 258_WC
│       ├── hold.rpt
│       └── setup.rpt
└── scan02
    ├── 000_TT
    │   ├── hold.rpt
    │   └── setup.rpt
    └── 157_BC
        └── hold.rpt
```

即 `$STA_RUN_DIR/$sta_mode/$corner_name/$sta_check.rpt`。要点：

1. **第一層 = mode 名**，**第二層 = `corner_name`（不是 corner 代號）**。二者的對應由 `sta2htm.corner` 決定（`258` → `258_WC`）。
2. 檔案不必每種組合都存在：缺檔該格會顯示 `Report Not Found!`（紅底），不會讓整個流程失敗。
3. 若某 mode/check 只需要部分 corner，由 `STA_CORNER(mode,check)` 控制，不需要建空目錄。
4. 檔名可為 `setup.rpt`、`setup.rpt.gz`，也可以是同一 glob 下的多個檔案（例如 `RptConst.rpt.1`、`RptConst.rpt.2`），全部會被**串接彙整**後再計數。

### 3.2 可被解析的三種報告格式

程式以檔內的 `Report : <類型>` 行切換解析器（`tcl/STA_PT.tcl`）。實測與閱讀碼得到的**支援清單**如下。

#### 格式 A：`report_constraint -all_violators -path slack_only`（建議，檔小）

```text
****************************************
Report : constraint
        -all_violators
        -path slack_only
Design : top
****************************************

   max_delay/setup ('VCLK_APB' group)

   Endpoint                                                  Slack
   -----------------------------------------------------------------
   pad_gpio_pa[0]                                         -0.05431  (VIOLATED)
   pad_gpio_pa[1]                                         -0.00600  (VIOLATED)
```

- 每個 `max_delay/setup ('G' group)` / `min_delay/hold ('G' group)` 標題決定 `sta_check` 與 Path Group。
- 端點行必須是「名稱 空格 slack 空格 (VIOLATED)」，且**行尾無其它文字**。
- 此格式最精簡，也是 demo 報告主流（`func/000_TT/setup.rpt` 即為此式）。

#### 格式 B：`report_constraint -all_violators -verbose`

```text
****************************************
Report : constraint
 -all_violators
 -verbose
 -min_delay
Design : top
****************************************

  Startpoint: u_core/u_ddr_ctrl_0/stat_reg_0_
               (rising edge-triggered flip-flop clocked by CLK_DDRC_0)
  Endpoint: u_ddr_phy (rising edge-triggered flip-flop clocked by CLK_DDR_PHY_pub_ctl_0)
  Path Group: CLK_DDR_PHY_pub_ctl_0
  Path Type: min
  ...
  slack (VIOLATED)                                                                                         -0.05081
```

- 會額外取得 `Startpoint` / `Endpoint` 的**時鐘名**（`clocked by X`）與其**實際 cell pin**，因此可做跨時鐘（cross-clock）與跨區塊（cross-block）統計，以及 `*nnn:LINE` 起點追蹤行。
- `Path Type: max → setup`、`min → hold`、其它 → `drv`。

#### 格式 C：`report_timing`（`Report : timing`）

解析邏輯與格式 B 相同（同一組規則），差別只在 `rpt_type` 為 `timing`。適用於只 dump `report_timing -path_delay full` 的專案。

> **只有這三種會被解析**
>
其它 `Report :` 類型（如 `clock`、`power`、`check_timing` 輸出）會被整段跳過。若在 `constraint` 報告中沒有 `-path slack_only` 也沒有 `-verbose`（例如只有 `-summary`），**不會有任何違規被讀取**，於是該 corner 顯示 `0` 而不是錯誤——這是容易被誤判為「乾淨」情境。請用 `grep -c VIOLATED 檔案` 自查。


### 3.3 欄位解析規則詳表（進階 / 除錯用）

#### 3.3.1 時間單位

```tcl
set slack [format "%.2f" [expr ($slack + $slack_offset) * 1000]]
```

工具假定 **PrimeTime 報告單位為 ns**，一律乘 1000 換算為 **ps** 後輸出（`.vio`、圖表、HTML 全部為 ps）。若你的 PT 以 `set time_unit ps` 輸出，數值會被再乘一次 1000，請改以 ns 輸出報告或於後處理修正。

#### 3.3.2 Path Group 特殊分類

| 報告內文字 | `sta_check` 歸屬 | Path Group 記為 |
|---|---|---|
| `max_delay/setup ('X' group)` | setup | `X`（`clock_gating_` 開頭者統一收斂為 `**clock_gating_default**`） |
| `min_delay/hold ('X' group)` | hold | `X`（同上） |
| `clock_gating_setup` / `clock_gating_hold` | setup / hold | `**clock_gating_default**` |
| `recovery` | setup | `**async**` |
| `removal` | hold | `**async**` |
| `sequential_clock_pulse_width` | pulse_width | `**clock_pin**`（並**結束此檔解析**） |
| `clock_tree_pulse_width` | pulse_width | `**clock_tree**`（同上） |
| `max_capacitance` / `min_capacitance` | capacitance | `**drv**`（同上） |
| `max_transition` / `min_transition` | transition | `**drv**`（同上） |
| `max_fanout` | fanout | `**drv**`（同上） |

> **重要限制：DRV / pulse-width 會被「中斷」而非「統計」**
>
上述 `pulse_width`、`capacitance`、`transition`、`fanout` 的處理路徑是設定 `rpt_check` 與 `egroup` 後立刻 `break` 離開該報告的迴圈，**沒有任何違規點被累計**。亦即：`sta_check` 實務上只有 `setup` 與 `hold` 有意義（`recovery/removal` 會被歸併進 setup/hold）。若 `STA_CHECK_LIST` 写了 `capture`、`noisewidth` 等-self-made 名稱，將永遠得到空結果。


#### 3.3.3 端點 / 起點的精細化

- 起迄點最初取 `Startpoint:` / `Endpoint:` 後的**實例名**。
- 進入路徑點表格後（`Point` 行之後），會逐行比對 `file dirname $instpin`：若等於 Startpoint 實例，則把 `spoint` 更新為該**腳位（pin）全名**；若等於 Endpoint 實例，則更新 `epoint`。
- 因此 `.vio` 中記錄的是 `u_ddr_phy/pub_ctl_clk` 這種 pin 等級名稱，去重與 block 統計的精度至腳位。
- 時鐘名由 `clocked by X` 取得（會剝除尾部 `)`）；分別記錄起點鐘 `sclock` 與終點鐘 `eclock`。
- `clock network delay`、`clock reconvergence pessimism` 被記錄以計算 `clock_skew`（僅內部使用，v2.0 未輸出到畫面）。

#### 3.3.4 corner 名稱的自動對應

對 glob 命中的每個檔名，由左至右拆出每個路徑元件，以 `_` 再拆一次；若**第一段等於目前 corner 代號**，則以該元件作為 `corner_name`：

```text
_reports/apr0-0122/func/258_WC/setup.rpt   → corner_name = 258_WC
reports/apr0-0122/func/258/setup.rpt       → corner_name = 258
```

這讓「平鋪式命名」（`000_TT_setup.rpt` 放在同一目錄）也能工作，只要把 filter 寫成 `{$sta_mode/$corner_name$sta_check.rpt*}` 形式。

### 3.4 gzip 與多檔

- glob 樣式中含 `*`（如 `$sta_check.rpt*`）即可同時命中 `setup.rpt` 與 `setup.rpt.gz`。
- `.gz` 檔會先以 `gunzip -c` 解到 `$sta_group/$sta_mode/$sta_corner/.unzip.rpt` 再解析；此暫存檔的清理路徑寫錯（清的是 `$sta_check/` 而非 `$sta_corner/`），會在 corner 目錄留下 `.unzip.rpt`，屬外观看遗留，不影響結果。

### 3.5 上線前檢查清單

| # | 檢查 | 方法 |
|---|---|---|
| 1 | 每份報告都有 `Report :` 行 | `grep -l "^Report :" *.rpt` |
| 2 | 違規行能被命中 | `grep -c "(VIOLATED)" setup.rpt` 與 HTML 顯示數是否一致 |
| 3 | 單位為 ns | 檔頭 `Design :` 附近或 PT `report_units` |
| 4 | 目錄第二層與 `sta2htm.corner` 的 `corner_name` 完全相同 | `ls`＋`diff` |
| 5 | mode 目錄名與 `STA_MODE_LIST` 一致 | 同上 |
| 6 | Path Group 名稱未含空白 | 含空白時 `regexp` 只吃第一段，會錯切 |
| 7 | 報告檔名不含空白 | glob/lsort 處理可能異常 |

## 第 4 章 設定檔完整參考

### 4.1 設定檔一覽與載入順序

| 檔案 | 格式 | 角色 | 是否必要 |
|---|---|---|---|
| `sta2htm.run` | INI 區塊式 | Runset 定義（版本清單、group、mode/corner/check、劇本） | 跑 `sta_index_runset` 時必要 |
| `Makefile.run` | GNU Make | 同上的 Make 側定義（`sta_init_run` 的參數來源） | 用 Makefile 流程時必要 |
| `.sta/sta2htm.corner` | 兩欄文字 | corner 代號 ↔ corner 名稱 ↔ 定義 | 必要（否則 corner_name 等於代號） |
| `.sta/sta2htm.cfg` | **Tcl** | mode / check 清單與 `STA_CORNER(mode,check)` 矩陣 | 必要 |
| `.sta/all.waive` | 欄位式文字 | **全域豁免清單**（名稱必須是 `all`，見 4.5） | 選擇性 |
| `.sta/<mode>.waive`、`.sta/<corner>.waive` | 同上 | 各 mode／角落專屬豁免，與 `all` 疊加 | 選擇性 |
| `.sta/sta2htm.mode` | 兩欄文字 | demo 中存在，但 v2.0 程式**未讀取**（mode 名稱改由 `sta2htm.run [MODE]` 提供） | 非必要 |
| `etc/sta/sta2htm.trend` | Makefile 片段 | gnuplot 趨勢圖的替代小流程（獨立於主流程） | 非必要 |

**載入順序**（`read_sta_config`）：依序 `source` 以下存在的 `sta2htm.cfg`，後載入者覆蓋先前設定：

```text
① STA/.sta/sta2htm.cfg      ← symlink 指向的原始報告區
② .sta/sta2htm.cfg          ← Run 目錄內（初始化時由 ① 複製而來）
③ ./sta2htm.cfg             ← 當前工作目錄
```

`sta2htm.corner` 由 `read_sta_corner` 單獨讀取，優先級為 `./sta2htm.corner` → `.sta/sta2htm.corner`（找不到則略過，不報錯）。waive 檔搜尋 `./<name>.waive` → `.sta/<name>.waive`。

> **實務建議**
>
把 `sta2htm.cfg`、`sta2htm.corner`、`all.waive` 統一放在**報告區**的 `.sta/` 下（即 `$STA_RUN_DIR/.sta/`），使其與報告一起版本化管理；`sta_init_run` 會自動複製進 Run 目錄，而 `.dqi` 與 HTML 則落在 Run 目錄，可安全重複清除重跑。


### 4.2 `sta2htm.run`（Runset 定義檔）

行語法通則：

- `#` 開頭為整行註解；`;` 之後為行尾註解（會先被 `regsub` 剝除）。
- 空行與 `#` 開頭的表頭行會被跳過。
- 欄位以**空白或 Tab** 分隔（Tcl `lindex`），因此欄位內不可含空白。
- 區塊以 `[NAME]` 開頭，共 7 個區塊：`VERSION`、`GROUP`、`BLOCK`、`CHECK`、`MODE`、`CORNER`、`SCENARIO`。
- 未在 `MODE`／`CHECK`／`CORNER` 中宣告而被 `SCENARIO` 使用之名稱，會自動補上並印出 `WARNING: ... is not defined`。

#### `[VERSION]` — 版本清單

```text
#STA_RUN      STA_RUN_DIR           STA_RUN_GROUPS
GOLDEN-0122   reports/apr0-0122     uniq_end reg2reg
GOLDEN-0123   reports/eco1-0123     uniq_end
;GOLDEN-0127  reports/eco3-0127     uniq_end        ← 以 ; 註解掉，暫不參與
```

| 欄 | 意義 | 備註 |
|---|---|---|
| `STA_RUN` | 版本目錄名 | 同時是輸出目錄與趨勢圖 x 軸標籤 |
| `STA_RUN_DIR` | 報告目錄路徑 | 通常以 `reports/<date>` 命名 |
| `STA_RUN_GROUPS` | 此版次要跑哪些 group | 省略時 `sta_init_run` 預設為 `uniq_end` |

#### `[GROUP]` — 報告群（path group 分類）

```text
uniq_end    $sta_mode/$corner_name/$sta_check/RptConst.rpt
reg2reg     $sta_mode/$corner_name/$sta_check/RptConst_reg2reg.rpt
```

第一欄為 group 名（=輸出子目錄名），第二欄是**報告檔 glob 樣式**，可用變數 `$sta_mode`、`$corner_name`、`$sta_check`、`$sta_postfix`。用途是把「reg2reg」「in2reg」「reg2out」等**不同報告集**各自成為獨立的 HTML 儀表板，互不乾擾。

#### `[CHECK]` — 檢查項目及其代表指標（DQI）

```text
setup    WNS
hold     NVP
```

第二欄是該 check 在**趨勢表的 corner 欄**要顯示的指標（`NVP` / `WNS` / `TNS`）。規則為 `STA_CHECK_DEF` 的第一個 token（`lindex ... 0`）。其餘 token現行版本未使用。

#### `[MODE]` — 工作模式

```text
func      functional     func_0210.sdc
scan01    dc_shift       scan_0211.sdc
scan02    ac_capture     scan_0221.sdc
```

三欄依序為：目錄用的 mode 代稱、**顯示用全名**（`STA_MODE_NAME`，出現在報表標題與連結）、SDC/定義檔（`STA_MODE_DEF`，僅在 `[MODE]` 區塊顯示與 `output_sta2htm_runset` 回寫時使用，不影響解析）。

#### `[CORNER]` — 角落定義

```text
000    000_TT     TTT:0.80V:025C  RCtyp
151    151_ML     FFG:0.88V:125C  Cmax
258    258_WC     SSG:0.72V:125C  Cmax
```

| 欄 | 意義 |
|---|---|
| `STA_CORNER` | 3 位數字代號（趨勢表欄位、目錄鍵值） |
| `STA_CORNER_NAME` | **報告目錄的實際名稱**（對應 3.1 節第二層） |
| `STA_CORNER_DEF` | 其餘欄位，純文件用途（lib corner / RC corner / lib 檔） |

#### `[SCENARIO]` — MMMC 劇本矩陣

```text
#SID    CHECK   MODE     CORNERS
S001    setup   func     000 -   157 231 258
S002    setup   scan02   000 -   -   -   258
H001    hold    func     000 151 157 -   258
H002    hold    scan01   000 -   157 -   258
```

以 **CORNER 區塊的欄序**對齊，`-` 表示該 corner 不参與此劇本。每一行等於設定：

```tcl
set STA_CORNER($MODE,$CHECK) { 該列非 '-' 的 corner 代號 }
```

`SID`（S001/H001…）只是文件用識別號；真正供索引頁判斷欄位底色的是內部 `STA_SCENARIO_MAP(check,mode,corner)`。

#### `[BLOCK]` — 區塊彙整（選用）

```text
cpu     ^cpu/.*
ddr     u_ddr_phy
```

提供 `STA_BLOCK_DEF` 列表。**注意**：`get_block_name` 使用的是一個名為 `STA_BLOCK` 的變數（非 `STA_BLOCK_DEF` 陣列），v2.0 無任何程式碼設定它，因此實務上 block 名稱一律**退回「instance 的第一層目錄名」**。詳見 10.4。

#### 由 `sta2htm.run` 反寫

`output_sta2htm_runset`（`STA_CONFIG.tcl` 內）可把記憶體中的設定回寫成一份完整 `sta2htm.run`（含 `[BLOCK]` 與對齊的 `[SCENARIO]` 矩陣），目前在 `read_sta_config` 中被註解掉（`# output_sta2htm_runset sta2htm.config`）。若想用它產生範本，在 tclsh 中手動執行：

```csh
% tclsh
> source $STA2HTM/tcl/LIB_STA.tcl
> ::LIB_STA::read_sta_runset sta2htm.run
> ::LIB_STA::output_sta2htm_runset sta2htm.run.new
```

### 4.3 `.sta/sta2htm.cfg`（Tcl 設定）

這是**被 `source` 的 Tcl 腳本**，故可寫變數、`if`、`foreach` 等邏輯（但請留意 4.3.2）。

```tcl
# 報告路徑樣式（v2.0 僅供文件參考，實際樣式由 -sta_group_report / Makefile 決定）
set STA_RPT_PATH {$sta_mode/$corner_name}
set STA_RPT_FILE {$sta_check$sta_postfix.rpt*}

# mode / check 清單
set STA_MODE_LIST  "func scan01 scan02"
set STA_CHECK_LIST "setup hold"

# 劇本矩陣：(mode,check) => corner 清單
set STA_CORNER(func,setup)    "000 157 231 258"
set STA_CORNER(func,hold)     "000 151 157 231 258"
set STA_CORNER(scan01,hold)   "000 - 157 258"
set STA_CORNER(scan02,setup)  "000 - - 231 258"
```

#### 4.3.1 變數速查

| 變數 | 型別 | 作用 | 預設 |
|---|---|---|---|
| `STA_MODE_LIST` | 清單 | 要處理的 mode（順序即報表順序） | 由 `-sta_mode_list` 或 runset 提供 |
| `STA_CHECK_LIST` | 清單 | 要處理的 check | `setup hold`（由 runset 或此檔） |
| `STA_CORNER(m,c)` | 陣列 | 該 (mode,check) 的 corner 清單；**未定義者直接跳過不處理** | 無 |
| `STA_RPT_PATH` | 字串 | 報告搜尋根目錄。在 **Run 目錄內執行時必須保持 `STA`**（預設值，指向 symlink） | `STA` |
| `STA_RPT_FILE` | 字串 | 僅 demo 設定檔殘留；v2.0 主流程使用 `STA_CURR_REPORT`（由 `-sta_group_report` 傳入） | — |
| `STA_POSTFIX` | 字串 | 被 `report_check_summary` 宣告但無來源；用於自訂副檔名時請改走 `-sta_group_report` | — |

> **不要把 STA_RPT_PATH 寫進 cfg**
>
`sync_sta_config` 會以 `STA_RPT_PATH` 推產出 Run 目錄的 `STA_RUN_DIR`。在 Run 目錄內執行時它是 `STA`（symlink）。若在 cfg 中把它改成 `{$sta_mode/$corner_name}`，會同時（a）令 glob 根路徑失效而找不到報告，與（b）讓 `index.htm` 顯示錯誤的來源路徑。`etc/sta/sta2htm.cfg` 與部分 demo 檔中的這一行是**歷史残留，請刪除或註解**。


#### 4.3.2 `'` 與 `{}` 的陷阱

`set STA_RPT_FILE {$sta_mode/$corner_name/$sta_check.rpt*}` 使用大括號，故 `$sta_mode` **不會**在 source 時展開；真正展開發生在 `parse_primetime_report` 內的 `eval glob`。因此：

- 樣式中只能使用 `$sta_mode`、`$corner_name`、`sta_check`、`$sta_postfix` 這幾個**解析階段才存在**的變數；寫入其它變數會被 `eval` 成空字串。
- 樣式中若要含空格，請改用 `-sta_group_report` 傳多個 glob（以空白分隔多個樣式，逐樣式累加）。

### 4.4 `.sta/sta2htm.corner`

```text
000    000_TT     TTT:0.80V:025C  RCtyp
151    151_ML     FFG:0.88V:125C  Cmax
```

`read_sta_corner` 接受三種行式（其餘靜默跳過）：

| 行式 | 結果 |
|---|---|
| `#Mode <name> …` | 僅印出 `STA MODE = <name>`，供同一檔內分 mode 定義 |
| `<id>_<postfix> …`（例 `157_BC`） | 以 `_` 前綴數字為代號 |
| `<id> <name> …`（例 `157 157_BC`） | 標準兩欄式 |
| 其它（含空行） | 跳過（不報錯，容易被忽略而導致 corner 未定義） |

### 4.5 all.waive 與各 mode／corner 的豁免清單

#### 欄位語法

`read_waive_list` 對每行做由寬到窄的正則比對，可寫成 1∼4 欄：

```text
#  slack    PathGroup(endpoint 或 group)    Endpoint(pin)    Corner
   -2.99    -                               -              -        # 全域豁免 slack ≥ -2.99
   -        clk1                            -                        # 名稱為 clk1 者豁免（不比較 slack）
   -        -                               top/u_cpu/data_1         # 特定 endpoint 豁免
   -5.00    VCLK_APB                        pad_gpio_pa[0]   231     # 僅在 corner 231 生效
*  -3.00    u_core/x_reg                    top/y_reg        258     # 行首 * = 含起點的模式（此檔僅解析、不入庫）
```

| 欄 | 說明 |
|---|---|
| 1 `slack` | 豁免門檻。**寫 `-` 代表無條件豁免**；寫數值則違規 slack ≥ 此值時豁免（數值為 ps，與報告同單位） |
| 2 `egroup` | Path Group 或（verbose 報告時）終點時鐘名 |
| 3 `epoint` | 終點 pin / 實例腳位 |
| 4 `corner` | 角落代號；省略等同 `-`（全域角落） |

#### 比對優先順序

`check_waive_slack` 依下列順序尋找第一筆命中（`:` 左邊為起點、右邊為終點；`-` 為萬用字元）：

1. `(egroup,epoint,corner)`
2. `(-:egroup,-:epoint,corner)`
3. `(egroup,epoint,-)`
4. `(-:egroup,-:epoint,-)`
5. `(egroup,-:-,-)`
6. `(-:egroup,-:-,-)`
7. `(-:-,epoint,-)`
8. `(-:-,-:epoint,-)`
9. `(-:-,-:-,-)` — 全域豁免

命中後若門檻為 `-` → 直接豁免；否則 `slack ≥ 門檻` 才豁免。**每份報告都會先 `read_waive_list all` 再 `read_waive_list <corner>`**（於 `parse_primetime_report`），而產生文字報表階段則改讀 `all` 與 `<mode>`。

#### 實務寫法建議

> **waive 治理**
>
1. 盡量用**第 1 欄填 `-`（無條件豁免）+ 明細 endpoint**，避免用 slack 門檻造成「剛好變好就被算乾淨」的誤判。
2. 為每一條 waive 保留註解行說明理由與核准人／日期（`#` 開頭不會被吃入清單，但會保留在檔內）。
3. 把 `all.waive` 作為跨 mode 共通豁免，`func.waive` / `scan01.waive` 放專屬項目；檔名就是 `read_waive_list` 的參數。
4. 豁免結果會單獨出現在 `<check>.waive_end.rpt` / `.waive_end.htm`，請在簽核會議中和未豁免清單一起審查。
5. 修改 `.waive` 後**務必 `make clean` 重跑**（或至少刪除 group 目錄），否則會沿用舊的 `.vio` 快取。


### 4.6 Makefile 三件套

#### `.sta` 層（Runset 目錄）：`etc/make/runset.make` → 你的 `Makefile`

```make
include Makefile.run

$(STA_RUN):
	sta_init_run $@ $(STA_RUN_DIR.$@) $(STA_RUN_GROUPS.$@)
init: $(STA_RUN)
run: init
	@for i in $(STA_RUN); do ( \
	  (cd $$i; make run) | tee run.$$i.log ; \
	) ; done
	sta_index_runset
index: run
	@for i in $(STA_RUN); do ( cd $$i; make index ; ) ; done
	sta_index_runset
view:  firefox index.htm &
clean: rm -fr $(STA_RUN) *.log *.tree index.* .trendchart .javascript .icon
```

`run` 與 `index` 的差別只在 `index` 會對各 Run 重跑 `sta_index_group`（僅重建 group 索引頁，速度極快，適合只改了 `.waive` 或只想刷新連結時使用）。

#### Run 層：`etc/make/sta2htm.make` → `$STA_RUN/Makefile`（由 `sta_init_run` 複製）

```make
include Makefile.group
$(STA_GROUP):
	mkdir -p $@
	sta_uniq_end -sta_group $@ -sta_group_report $(STA_GROUP_REPORT.$@) | tee $@/sta2htm.log
	sta_index_group -sta_group $@
run: $(STA_GROUP)
	sta_index_run -sta_group_list '$(STA_GROUP)' | tee sta2htm.log
```

`$(STA_GROUP)` 是**多目標規則**（對每個 group 各建一條規則），因此一個 Run 可同時跑 `uniq_end reg2reg in2reg reg2out`。

#### `Makefile.group`（由 `sta_init_run` 產生，請不要手寫）

```make
# STA_RUN := GOLDEN-0122
# STA_RPT := /path/to/run/reports/apr0-0122
STA_GROUP += uniq_end
```

`sta_init_run` **不會**寫入 `STA_GROUP_REPORT.<group>`，故 Run 層的 `-sta_group_report` 通常為空，`sta_uniq_end` 退回內定樣式 `$sta_mode/$corner_name/$sta_check.rpt*`。若要為不同 group 使用不同報告樣式，請在 `Makefile.group` 補一行（這是在現有架構下唯一可行的管道）：

```make
STA_GROUP_REPORT.reg2reg := $sta_mode/$corner_name/$sta_check/RptConst_reg2reg.rpt
```

## 第 5 章 命令參考

### 5.1 通用選項

5 支 Tcl 命令共用 `LIB_STA::parse_argv`，因此選項一致（`sta_init_run` 為 csh，另有自己的位置參數）。**選項需要值，寫錯不會報錯**，只會印出 `INFO: Unused parameter 'N'`。

| 選項 | 意義 | 對應內部變數 |
|---|---|---|
| `-runset <file>` | 讀 Runset 定義檔（預設 `sta2htm.run`） | `read_sta_runset` |
| `-config <file>` | 讀指定的 Tcl 設定檔（預設 `sta2htm.cfg`） | `read_sta_config` |
| `-sta_run <name>` | 指定目前版本名（頁面標題用） | `STA_CURR_RUN`（會被 `sync_sta_config` 以 `$PWD` 目錄名覆蓋） |
| `-sta_group <name>` | 指定報告群 | `STA_CURR_GROUP` |
| `-sta_group_report <pattern…>` | 指定報告 glob 樣式（可多個，空格分隔） | `STA_CURR_REPORT` |
| `-sta_group_list <list>` | 一次指定多個 group（`sta_index_run` 使用） | `STA_GROUP_LIST` |
| `-sta_mode_list <list>` | 覆蓋 mode 清單 | `STA_MODE_LIST` |
| `-sta_check_list <list>` | 覆蓋 check 清單 | `STA_CHECK_LIST` |
| `-sta_corner_list <list>` | 覆蓋 corner 清單 | `STA_CORNER_LIST` |
| `-slack_offset <value>` | **v2.0 未實作**（`read_slack_offset` 不存在，會直接當） | 見 10.5 |

執行順序固定為 `parse_argv` → `read_sta_config`（`sta_index_runset` 則為 `read_sta_runset`）→ 一個 `report_*` 程序。`read_sta_config` 會先讀 `.sta/sta2htm.corner`，再 source cfg，最後 `sync_sta_config` 完成清單補齊與劇本重建。

> **-sta_group_list 會覆盖 -sta_group**
>
`sync_sta_config` 只在 `STA_CURR_GROUP` 非空時才寫 `STA_GROUP_REPORT`。若傳了 `-sta_group 'a b'`（多 group 塞一個引數），第一個會被當成整體名稱而產生怪異目錄。多 group 請一律使用 `-sta_group_list`。


### 5.2 `sta_init_run` — 建立 Run 工作目錄

```text
Usage: sta_init_run [options] <STA_RUN> <STA_RUN_DIR> <sta_group>...
       options:
          --STA_DIR <sta_report_dir>
```

| 參數 | 預設 | 說明 |
|---|---|---|
| `--STA_DIR <dir>` | `STA` | Run 目錄內指向報告區的 symlink 名稱 |
| `<STA_RUN>` | `.` | 欲建立的 Run 目錄名 |
| `<STA_RUN_DIR>` | 同 `<STA_RUN>` | 報告區路徑（會先 `realpath`） |
| `<sta_group>...` | `uniq_end` | 此 Run 要處理的報告群，可多個 |

執行動作（等同下列手工操作，可作為無 csh 環境的替代方案）：

1. `mkdir -p $STA_RUN`，並複製 `etc/make/sta2htm.make` → `$STA_RUN/Makefile`
2. 產生 `$STA_RUN/Makefile.group`（寫入 `STA_RUN`、`STA_RPT`、`STA_GROUP`）
3. 複製 `etc/icon/*` → `$STA_RUN/.icon/`；`Chart.bundle.min.js` → `$STA_RUN/.javascript/`
4. 複製 `<報告區>/.sta/sta2htm.*` → `$STA_RUN/.sta/`
5. `ln -s <報告區 realpath> $STA_RUN/STA`（若已存在先移除）

```csh
% sta_init_run GOLDEN-0122 reports/apr0-0122 uniq_end reg2reg
# 自訂 group 報告樣式（手工補 Makefile.group）
% echo 'STA_GROUP_REPORT.reg2reg := $sta_mode/$corner_name/$sta_check/RptConst_reg2reg.rpt' >> GOLDEN-0122/Makefile.group
```

README 中的 `sta_init_dir GOLDEN-0122 reports/GOLDEN-0122 uniq_end reg2reg` 為 v1.0 命令名，v2.0 請改用 `sta_init_run`。

### 5.3 `sta_uniq_end` — 解析報告並產生群內報表（核心）

```csh
% sta_uniq_end -sta_group uniq_end [-sta_group_report <pattern...>]
```

內部對 **每個 `sta_check` × 每個 `sta_mode`**（僅處理有定義 `STA_CORNER(mode,check)` 的組合）依序執行：

1. `parse_primetime_report`：glob 命中所有報告 → 逐檔解析 → 逐點判定 waive / met / violation → 寫 `corner/<check>.vio`、corner 級 `.dqi`、`<check>.nvp_wns.dat`
2. `unique_vio_endpoint`：跨 corner 去重合併，寫 mode 級 `.dqi`
3. `report_endpoint_text` → `<check>.uniq_end.rpt`、`<check>.waive_end.rpt`
4. `report_endpoint_html` / `report_wavpoint_html` → `.uniq_end.htm` / `.waive_end.htm`
5. `report_index_clock` / `report_index_block` → `<check>.clk.htm` / `<check>.blk.htm`
6. `report_vio_histogram` → `<check>.uniq_end.{wns,nvp,sum}`
7. `report_scenario_summary` → `<check>.htm`（單頁儀表板）、`<check>.nvp_wns.{htm,js,plt,png}`

> **增量執行**
>
`parse_primetime_report` 對每個角落先檢查 `$sta_group/$sta_mode/$sta_corner/$sta_check.vio`，**已存在則 `continue` 跳過**。因此：
- 只想新增一個 corner：直接重跑，舊 corner 不會重新解析（速度快）。
- 改了 `.waive` 或報告內容：**務必先清除舊 `.vio`**，否則不會生效。
```csh
% rm -rf uniq_end/<mode>/<corner>/<check>.vio     # 或直接 rm -rf uniq_end
```
（`make clean` 會整個移除 group 目錄，是最安全的重跑方式。）


### 5.4 `sta_index_group` — 重建群級索引

```csh
% sta_index_group -sta_group uniq_end
```

產出／更新 4 頁：`$sta_group/index.htm`（主儀表板）、`mode.htm`、`check.htm`、`corner.htm`，並連帶產生各 mode 的 `<mode>/index.htm` 與 `<check>.htm` 摘要頁。**不重新解析報告**，只讀 `.vio`，因此幾秒即可完成，適合修改設定後刷新頁面。

### 5.5 `sta_index_run` — 單一 Run 的跨 group 趨勢頁

```csh
% sta_index_run -sta_group_list 'uniq_end reg2reg'
```

在 **Run 目錄**執行，產出 `$PWD/index.htm`（列為 group × corner 的矩陣）與 `.trendchart/<mode>/<check>.nvp_wns.*` 圖檔。注意兩點：

1. 它依據 `.dqi` 檔案組表，因此 group 必須已跑過 `sta_uniq_end`。
2. 它需要 Run 目錄下存在 `.icon/` 與 `.javascript/`（`sta_init_run` 已複製）。

### 5.6 `sta_index_runset` — Runset 總索引與跨版本趨勢

```csh
% cd run/02_trend
% sta_index_runset                  # 讀 ./sta2htm.run
% sta_index_runset -runset my.run    # 指定其它檔名
```

產出：

- `index.htm`：上方內嵌 `sta2htm.run` 原文（iframe），中間為 **GROUP 表**（連結到 `.trendchart/<group>/index.htm`），下方為 **VERSION 表**（連結到各 `<run>/index.htm`）。
- `.trendchart/<group>/index.htm`：**跨版本收斂趨勢表**（列 = 版本，欄 = NVP/WNS/TNS + 各 corner），並對每個 (group,mode,check) 產生 `.nvp_wns.dat/.htm/.js/.plt` 曲線資料。

> **Runset 層需要自己備好 .javascript 與 .icon**
>
`.trendchart/<group>/<mode>/<check>.nvp_wns.htm` 以 `../../../.javascript/Chart.bundle.min.js` 參考腳本，解算後落在 **Runset 目錄**；`sta_init_run` 只把資源複製到各 Run 目錄。因此正式站點建議在 Runset 目錄多放一份：
```csh
% cp -r $STA2HTM/etc/html/chartjs/Chart.bundle.min.js . 2>/dev/null; mkdir -p .javascript .icon
% cp $STA2HTM/etc/html/chartjs/Chart.bundle.min.js .javascript/
% cp $STA2HTM/etc/icon/lyg_banner.png .icon/logo_banner.png
```
缺少時趨勢表中的圖會變成空白（資料表仍然正確）。


### 5.7 未掛載的輔助命令

`csh/22_sta_rpt_by_clock.tcl` 與 `csh/23_sta_rpt_by_block.tcl` 意在單獨重建「跨時鐘矩陣」與「跨區塊矩陣」，v2.0 未建立 symlink 且**無法直接執行**（見 10.3）。功能已被 `sta_uniq_end` 內部的 `report_index_clock` / `report_index_block` 覆蓋，實務上不需要它們。

### 5.8 Make 目標速查

| 層級 | 目標 | 動作 |
|---|---|---|
| Runset | `make init` | 對每個 `$(STA_RUN)` 呼叫 `sta_init_run` |
| Runset | `make run` | 逐 Run `make run`，最後 `sta_index_runset` |
| Runset | `make index` | 逐 Run `make index` + `sta_index_runset` |
| Runset | `make view` | `firefox index.htm &` |
| Runset | `make tree` / `make diff` | 以 `tree` 產生目錄樹快照，並與 `logs/tree.log` 比對（ regression 用，故 README 要求裝 `tree`） |
| Runset | `make clean` | 移除所有 Run 輸出、`index.*`、`.trendchart`、`.javascript`、`.icon` |
| Run | `make run` | 逐 group `sta_uniq_end` + `sta_index_group`，最後 `sta_index_run`（輸出 tee 至 `sta2htm.log`） |
| Run | `make index` | 僅逐 group `sta_index_group` |
| Run | `make clean` | `rm -fr $(STA_GROUP)` |
| 測試 | `test.make` | 以 `TEST.target/golden/check` 回傳 PASS/FAIL、`.status` 紀錄、`waive` 比對（可用於把 sta2htm 納入 CI 回歸，見 9.3） |

## 第 6 章 輸出檔案參考

### 6.1 完整輸出樹（實測）

以 `run/01_sta`（GOLDEN-0122）+ `run/02_trend`（4 個版本）實際產出為例：

```text
02_trend/                              ← Runset 目錄
├── index.htm                          ← 【起點】總索引（GROUP 表 + VERSION 表）
├── sta2htm.run                        ← 設定檔（被 index.htm 以 iframe 內嵌）
├── .trendchart/
│   └── uniq_end/
│       ├── index.htm                  ← 跨版本收斂趨勢頁（最推荐给主管看）
│       └── <mode>/<check>.nvp_wns.{dat,htm,js,plt,png}
└── GOLDEN-0122/                       ← Run 目錄
    ├── index.htm                      ← 此版本跨 group 摘要
    ├── Makefile / Makefile.group
    ├── sta2htm.log                    ← make run 的完整 log（被頁面 iframe 引用）
    ├── .sta/                          ← cfg / corner / waive 複本
    ├── .icon/logo_banner.png  .javascript/Chart.bundle.min.js
    ├── STA -> ../reports/apr0-0122    ← symlink（報告區）
    └── uniq_end/                      ← group 目錄
        ├── index.htm                  ← 群主儀表板（mode × check × corner）
        ├── mode.htm  check.htm  corner.htm
        ├── <check>.htm                ← 【單頁多 corner 摘要】func/setup.htm
        ├── <check>.nvp_wns.dat        ← 圖表資料（每 corner 一列）
        ├── <check>.nvp_wns.htm/.js/.plt/.png
        ├── <check>.uniq_end.rpt       ← 去重後違規端點表（文字）
        ├── <check>.uniq_end.htm       ← 同上（HTML，可點選）
        ├── <check>.waive_end.rpt/.htm ← 被豁免端點表
        ├── <check>.clk.htm  <check>.blk.htm   ← 跨時鐘 / 跨區塊矩陣
        ├── .dqi/520-STA/<check>/{NVP,WNS,TNS}                ← mode 層合成值
        ├── <corner>/                                          ← corner 層（000、151…）
        │   ├── <check>.vio            ← 該 corner 原始違規點（slack group epoint）
        │   ├── <check>.wns            ← 依 Path Group 統計 NVP/WAIVED/NVP-W/WNS
        │   ├── <check>.nvp            ← slack 分佈（區間 / 計數 / 累積）
        │   ├── <check>.sum            ← 同上的區間式（Max~Min 表達）
        │   ├── <check>.clk.htm  <check>.blk.htm
        │   └── .dqi/520-STA/<check>/{NVP,WNS,TNS,NWP}
        └── <mode>/                                            ← mode 層（func、scan01…）
            └── index.htm              ← mode 摘要（各 check 圖表＋WNS 表）
```

### 6.2 文字報表格式與實例

#### 角落層 check.vio — 原始違規清單（解析的第一手產物）

```text
# File : /path/reports/apr0-0122/func/000_TT/setup.rpt
# Report : constraint -path slack_only (Line# 2)
    -54.31 VCLK_APB                       pad_gpio_pa[0]
     -6.00 VCLK_APB                       pad_gpio_pa[1]
     -5.00 VCLK_APB                       pad_gpio_pa[2]
     -4.06 VCLK_MCU08                     pad_gpio_pb[15]
```

| 欄 | 意義 |
|---|---|
| `# File :` | 來源報告絕對路徑（一個 corner 有多份報告時會有多個此標頭）；索引頁的「STA Report」連結即取此值 |
| 1 | slack（ps，已乘 1000） |
| 2 | 格式 A：Path Group；格式 B/C：**終點時鐘名** |
| 3 | 終點 pin（verbose 格式時，前一行會有 `*路徑序:行號 起點鐘 起點pin` 追蹤行） |

`<check>.vio` 是整套工具的「中間快取」：去重、圖表、時鐘/區塊矩陣、corner 級索引全部由它二次運算（也因此 5.3 節的增量行為圍繞它）。

#### 模式層 check.uniq_end.rpt — 去重後端點表（最重要的一份）

```text
      No|     000      157      231      258 |      WNS |  WCorner | PathGroup                                | InstancePin
--------+--------+--------+--------+---------+----------+----------+------------------------------------------+----------------------------------------
       1|  -54.31       .    -44.00   -84.05 |   -84.05 |      258 | VCLK_APB                                 : pad_gpio_pa[0]
       2|      .        .    -14.02    -4.05 |   -14.02 |      231 | VCLK_APB                                 : pad_gpio_pa[10]
      15|      .        .   -114.56   -14.56 |  -114.56 |      231 | VCLK_CAN                                 : pad_can_txd
```

- 行首 `No`：按 Path Group＋Endpoint 排序後的序號。
- 中間各欄：該 endpoint 在**各 corner 的 slack（ps）**；`.` = 該 corner 未出現此違規。
- `WNS`：跨 corner 最差值；`WCorner`：最差值發生的 corner 代號（修 corner 時的優先依據）。
- 直欄標頭中的 `xxxxxxxx`（分隔線取代 `--------`）代表該 corner 無報告檔，可一眼辨識缺檔角落。

#### 模式層 check.uniq_end.wns — 依 Path Group 統計

```text
# Mode : func/setup.uniq_end
#       NVP     WAIVED      NVP-W        WNS PathGroup
         13          0         13     -84.05  VCLK_APB
          2          0          2    -114.56  VCLK_CAN
          9          0          9      -9.43  VCLK_DO
#        28          0         28    -114.56 5      ← 合計列（末欄為 group 數）
```

| 欄 | 意義 |
|---|---|
| `NVP` | 該 group 去重後違規端點數（含被豁免者） |
| `WAIVED` | 其中已被豁免的數量 |
| `NVP-W` | 淨違規數（真正需要修的） |
| `WNS` | 該 group 最差 slack（ps） |

#### 模式層 check.uniq_end.nvp 與 .sum — slack 直方圖

```text
# func/setup.uniq_end                 #    Max -    Min | :        NVP      Accmu
#  Slack |        NVP      Accum      (      0 ~     -1 ] :          1         28
       0            1         28      (     -1 ~     -2 ] :          0         27
      -1            0         27      ...
      -4            2         26      (-1000 ~    -100 ] :          0          1
```

分佈門檻由 `LIB_STA.tcl` 的 `WNS_HRANGE` 決定（內定 `0 -1 -2 -3 -4 -5 -10 -15 -20 -30 -40 -50 -100 -200 -300 -500 -1000`，可自行修改後重跑）。`.nvp` 的首欄是**區間上界**，NVP 為落在 `(上界, 下界]` 的筆數，`Accum` 為「比上界更差（含）」的累積數，適合判斷「Waive -5ps 以上可消除多少違規」；`.sum` 則是同一資料的區間式寫法。

#### 模式層 check.nvp_wns.dat — 圖表資料（Chart.js 與 gnuplot 共用）

```text
# GOLDEN-0122/uniq_end
#ID          NVP        WNS
000            8      57.43
157            0      -0.00
231           28     114.56
*231           0       0.00
```

> **WNS 欄是「取負後」的正值**
>
第 3 欄寫入的是 `-WNS`（`expr -$wns`），因此**數值越大代表越差**，以配合圖表 y2 軸向上延伸的視覺直覺。讀圖或自取資料做二次分析時請記得還原正負號；HTML 表格中的 WNS 欄仍為原本的負值。
第 1 欄行首的 `*`（如 `*231`）代表該 corner **找不到報告檔**（內部 nvp 仍為 `-`），圖表上會顯示為 0，容易被誤解為「乾淨」。


#### .dqi 目錄 — 機器可讀指標

| 層級 | 檔案 | 內容（以 demo GOLDEN-0122 func/setup 為例） |
|---|---|---|
| mode 層 | `NVP` `WNS` `TNS` | `28` / `-114.56` / `-1274.25`（去重合併後的值） |
| corner 層 | `NVP` `WNS` `TNS` `NWP` | `8` / `-57.43` / `-194.64` / `0`（該 corner 單檔累計） |

`520-STA` 是同家族 DQI 系統的阶段编号（DQR/DOP 框架），便於被其它腳本 `cat` 取用。跨趨勢頁的所有數值即來自這些檔案。

### 6.3 名詞與 uniqify 邏輯

1. **單檔內**：同一報告裡每個 `(egroup, epoint)` 的違規都會進 `.vio`（不去重）；corner 級 `.dqi/NVP` 是「該 corner 所有報告檔案的違規筆數」。
2. **跨 corner 去重**（`unique_vio_endpoint`）：key 為 `(PathGroup, Endpoint)`；取各 corner **最差** slack，記錄該值出現的 `WCorner`。去重後筆數 = mode 級 `.dqi/NVP` = 報表上的 NVP。
3. 排序探 `lsort -unique` 再 `lsort -index 0`（以 group+endpoint 字串序），**非依 slack 排序**；要按難易排序請用 `.wns`（依 group 的 WNS）或直接對 `.uniq_end.rpt` 做 sort。
4. **同一 key 的「一個 endpoint」被視為一個問題**，因此 NVP 通常明顯小於各 corner 違規數之和：demo 中 000+157+231+258 = 8+0+28+28 = 64 筆，去重後為 28 個端點。

## 第 7 章 HTML 報表導覽

以下截圖全部為本手冊撰寫時於 demo（`run/01_sta`、`run/02_trend`）實跑產出，可直接比對。所有頁面共用四格導覽列：

```text
[@Index]   [@Mode]   [@Check]   [@Corner]        ← group 內四種切 viewpoint
[@RUNSET]  [uniq_end]                             ← Run 層：回總索引 / 各 group
```

頁面套用一個 `#sta_tbl` CSS（`tcl/STA_HTML.tcl` 內嵌）：綠色表頭、斑馬紋、滑鼠懸停變灰。右上角圖檔為 `etc/icon/logo_banner.png`（可在該檔統一改為公司 banner 與連結 `STA_HTML::LINK(logo_banner)`）。

### 7.1 三層入口

| 頁面 | 路徑 | 用途 |
|---|---|---|
| Runset 總索引 | `index.htm` | 進入點；GROUP 趨勢連結 + 各版本連結 + 設定原文 |
| 群級儀表板 | `<run>/<group>/index.htm` | 單版本的 mode×check×corner 全貌 |
| 單頁摘要 | `<run>/<group>/<mode>/<check>.htm` | 工程師修問題時的主戰場 |

![圖 7-1 Runset 總索引（index.htm）：上方 iframe 為 sta2htm.run 原文，中段為 GROUP 表（連到跨版本趨勢），下段為 VERSION 表（連到各版本）。](截圖/01_runset_index.png)

![圖 7-2 群級儀表板（uniq_end/index.htm）：左上是 make run 的 log（sta2htm.log），每個 check 一個區塊，逐 corner 列出 NVP / WNS / TNS 與原始報告連結。](截圖/04_group_index.png)

### 7.2 跨版本收斂趨勢（本工具價值最高的一頁）

![圖 7-3 .trendchart/uniq_end/index.htm：列 = 版本（GOLDEN-0122→0125），欄 = NVP/WNS/TNS ＋ 每個 corner 一個狀態格。setup 區塊的 corner 欄顯示 WNS、hold 區塊顯示 NVP（由 [CHECK] 區塊的第一欄决定）。](截圖/02_trend_group.png)

讀法（以實測數值為例）：

| 視角 | 判斷 |
|---|---|
| 收斂性 | NVP `28 → 22 → 18 → 8`、TNS `-1274 → -419 → -338 → -101`，ECO 明顯有效 |
| 惡化警訊 | `GOLDEN-0124` 的 157 欄從 `.`（0）變成 `-2.06` → 該版在 157_BC 新增了違規（demo 資料即為此情境） |
| 缺檔警訊 | 紅底 `*` = 該 corner 沒有 `.dqi`（報告缺或沒跑）；請先查 3.5 檢查清單 |

![圖 7-4 單一版本頁（GOLDEN-0125/index.htm）：欄位同樣是 corner，但列 = 該版本的各 group，角落格顯示的是該 corner 的 NVP。](截圖/03_run_index.png)

> **兩個 index 頁的 corner 欄指標不同（易混淆）**
>
- `.trendchart/<group>/index.htm`（Runset 層）：會先讀 `sta2htm.run` 的 `[CHECK]` 定義，所以 setup 列的 corner 格是 **WNS**（如 `-57.43`）。
- `<run>/index.htm`（Run 層）：`sta_index_run` **不讀 runset 檔**（只讀 `.sta/sta2htm.cfg`），`STA_CHECK_DEF` 未定義時 `sync_sta_config` 一律補 `NVP`，所以同一格顯示的是 **NVP 計數**（如 `2`、`5`、`3`）。
這是原始碼層次的不對稱，不是設定錯誤。若需一致，請在 `.sta/sta2htm.cfg` 內自行補上：`set STA_CHECK_DEF(setup) WNS`、`set STA_CHECK_DEF(hold) NVP`。


![圖 7-5 trend 圖表頁（Chart.js）：長條 = NVP（左軸），折線 = |WNS|（右軸），x 軸為版本。無 gnuplot 時 .png 不存在，但本頁照常渲染。](截圖/02b_trend_chart.png)

### 7.3 四種切入 viewpoint

![圖 7-6 mode.htm：以「模式」為主軸，每列一個 mode，跨欄比較各 check 的 corner 分布圖。適合回答「scan 模式有沒有比 func 差」。](截圖/05_mode.png)

![圖 7-7 check.htm：以「檢查項目」為主軸，每個 mode 一格 NVP/WNS 圖。適合 setup / hold 分工追蹤。](截圖/07_check.png)

![圖 7-8 corner.htm：corner 為列、(check,mode) 為欄的 MMMC 劇本矩陣，附 corner 定義全文。綠點 = 乾淨，數字 = 該 corner 違規筆數，紅星 = 缺報告。這是「哪個 corner 拖後腿」最快的答案。](截圖/06_corner.png)

![圖 7-9 <mode>/index.htm（本例 func）：該模式下各 check 的圖表與 WNS 表堆疊頁。](截圖/12_modepage.png)

### 7.4 單頁摘要（工程師主戰場）

![圖 7-10 func/setup.htm 單頁摘要：左上為 corner 分布圖、右上為 NVP 分布（setup.uniq_end.nvp）、中間是逐 corner 資料表（可點 NVP/WNS/TNS/Clock/Block 連結）、下方大區塊為選取項目的原始報告內容（iframe sta_output）。](截圖/08_onesummary.png)

表頭每個連結的意義：

| 連結 | 開啟 |
|---|---|
| `#` | `setup.uniq_end.rpt`（文字，去重後全表） |
| `Waive` | `setup.waive_end.rpt`（被豁免的清單） |
| `NVP` / `WNS` / `TNS` | 同 group 的分布檔（依 slack 區間） |
| `Clock` / `Block` | 跨時鐘 / 跨區塊矩陣 |
| `Unique Endpoint` | 同資料的 HTML 表格版 |
| 某 corner 的 NVP 數字 | 該 corner 的 `index.htm`（corner 細分頁） |
| 右側檔名 | 原始 PrimeTime 報告絕對路徑（新視窗開啟） |

![圖 7-11 setup.uniq_end.htm：跨 corner 去重後端點表（與 .uniq_end.rpt 同資料）。已在解析階段被豁免的項目不會出現在這張表。](截圖/09_uniqend.png)

### 7.5 跨時鐘 / 跨區塊矩陣

![圖 7-12 func/setup.clk.htm：以終點時鐘為列、角落為欄，值為該時鐘的 WNS；表頭 `#N Clocks` 為涉及時鐘數。mode 層為跨 corner 總覽，corner 層的 `000/setup.clk.htm` 則是起點鐘 × 終點鐘的 NVP 矩陣。](截圖/10_clk.png)

![圖 7-13 setup.blk.htm：以實例第一層目錄作為 block（見 10.4 關於自訂 block 的限制）。](截圖/11_blk.png)

### 7.6 顏色圖例總整理

| 顏色 | 記號 | 意義 |
|---|---|---|
| 綠 `#80f080` | `.` | 該項指標為 0（乾淨） |
| 紅 `#f08080` | `*` | 找不到報告 / `.dqi`（缺檔或沒跑） |
| 粉紅 `#f0c0c0` | `*` ＋ `Report Not Found!` | 群級索引中該 corner 無 `.vio` |
| 橄欖 `#c0c080` / 紅 `#f00000` | `Corner Undefined!` | 劇本引用了未在 corner 檔中定義的代號 |
| 灰 `#c0c0c0` | `-`（空白） | 該 corner **不屬於**此 (mode,check) 劇本 |
| 黃 `#f0f080` | corner 代號 | 可點擊的 corner 標識 |
| 青 `#80c0c0` | mode / check 標签 | 頁面内切換用 |

## 第 8 章 實戰流程（完整重現）

本章的指令與輸出皆為本次撰寫時在 Linux（Tcl 8.6.16）真實執行所得。

### 8.1 案例一：單版本 MMMC 審查（`run/01_sta`）

情境：拿到 `apr0-0122` 的簽核報告，要快速產出可點選的審查頁面。

```csh
% source ../setup.cshrc            # DOP_HOME / STA2HTM / PATH 就緒
% cd run/01_sta
% cat Makefile.run
STA_RUN     := GOLDEN-0122
STA_RUN_DIR.GOLDEN-0122    := reports/apr0-0122
STA_RUN_GROUPS.GOLDEN-0122 := uniq_end reg2reg in2reg reg2out
% make run                         ← 一條到底
```

`make run` 實際發生的事（依序）：

| 步驟 | 命令 | 產物 |
|---|---|---|
| 1 | `sta_init_run GOLDEN-0122 reports/apr0-0122 uniq_end …` | `GOLDEN-0122/{Makefile,Makefile.group,.sta,.icon,.javascript,STA}` |
| 2 | （進入 Run 目錄）`make run` → 逐 group `sta_uniq_end` | `uniq_end/**`、`reg2reg/**` … 全部文字與 HTML |
| 3 | 逐 group `sta_index_group` | `<group>/{index,mode,check,corner}.htm` |
| 4 | `sta_index_run -sta_group_list '…'` | `GOLDEN-0122/index.htm`＋`.trendchart` |
| 5 | `sta_index_runset` | `run/01_sta/index.htm` |

結果驗證（demo 報告共 4 個 mode×check 劇本）：

```csh
% cat GOLDEN-0122/uniq_end/func/setup.nvp_wns.dat
# GOLDEN-0122/uniq_end
#ID          NVP        WNS
000            8      57.43
157            0      -0.00
231           28     114.56
258           28      84.05

% cat GOLDEN-0122/uniq_end/func/.dqi/520-STA/setup/NVP   # 去重後端點數
28
% head -4 GOLDEN-0122/uniq_end/func/setup.uniq_end.wns   # 依 Path Group 統計
#       NVP     WAIVED      NVP-W        WNS PathGroup
         13          0         13     -84.05  VCLK_APB
          2          0          2    -114.56  VCLK_CAN
```

開啟瀏覽器（或用任何靜態檔伺服器／`python3 -m http.server` 之後_urls）：

```csh
% make view          # firefox index.htm &
```

> **只想看某個 mode/check？**
>
不需要改設定，直接限定範圍，速度最快（其餘組合會因 `STA_CORNER(mode,check)` 未定義而跳過）：

```csh
% cd GOLDEN-0122
% sta_uniq_end -sta_group uniq_end -sta_mode_list func -sta_check_list hold
% sta_index_group -sta_group uniq_end -sta_mode_list func -sta_check_list hold
```

也可只跑部分 corner：`-sta_corner_list "000 258"`。注意 `sta_uniq_end` 的角落清單實際取自 `STA_CORNER(mode,check)`，`-sta_corner_list` 主要影響索引頁的欄位順序與 corner 頁清單。


### 8.2 案例二：ECO 收斂趨勢（`run/02_trend`）

情境：apr0 → eco1 → eco2 → eco3 四個版本要做收斂追蹤。

```csh
% cd run/02_trend
% cat Makefile.run
STA_RUN += GOLDEN-0122
STA_RUN_DIR.GOLDEN-0122 := reports/apr0-0122
STA_RUN += GOLDEN-0123
STA_RUN_DIR.GOLDEN-0123 = reports/eco1-0123
STA_RUN += GOLDEN-0124
STA_RUN_DIR.GOLDEN-0124 = reports/eco2-0124
STA_RUN += GOLDEN-0125
STA_RUN_DIR.GOLDEN-0125 = reports/eco3-0125

% make run
```

若 `sta2htm.run` 的 `[VERSION]` 中某版以 `;` 註解（如 `;GOLDEN-0127`），它不會被 `sta_index_runset` 列入趨勢表，但對應目錄仍留存——這是做 A/B 對照時的常用手法。

收斂曲線資料（`% cat .trendchart/uniq_end/func/setup.nvp_wns.dat`）：

```text
# func/setup
#VERSION           NVP        WNS
GOLDEN-0122         28     114.56
GOLDEN-0123         22      42.14
GOLDEN-0124         18      57.43
GOLDEN-0125          8      22.15
```

**日常增量流程**：新版報告到位後，只需（a）在 `[VERSION]` 與 `Makefile.run` 加一列、（b）`make init`（僅新建的 Run 會被初始化）、（c）`make run`。已解析過的舊 Run 因 `.vio` 存在會跳過逐檔解析（5.3），但 `make clean` 之後就全部重算。

### 8.3 案例三：新增一個 path group（reg2reg 獨立儀表板）

1. 報告端：依 3.1 結構把 reg2reg 報告放成 `$sta_mode/$corner_name/$sta_check/RptConst_reg2reg.rpt`。
2. 定義端：在 `sta2htm.run` 補兩處。

```text
[GROUP]
reg2reg      $sta_mode/$corner_name/$sta_check/RptConst_reg2reg.rpt

[VERSION]
GOLDEN-0122  reports/apr0-0122   uniq_end reg2reg
```

3. Make 端：`Makefile.run` 的 `STA_RUN_GROUPS.GOLDEN-0122` 加 `reg2reg`；並在 `GOLDEN-0122/Makefile.group` 補上該 group 的報告樣式（4.8 節說明的唯一可行管道，`sta_init_run` 不會自動寫這一行）：

```make
STA_GROUP += reg2reg
STA_GROUP_REPORT.reg2reg := $sta_mode/$corner_name/$sta_check/RptConst_reg2reg.rpt
```

4. 執行（於 Run 目錄）：

```csh
% cd GOLDEN-0122
% make reg2reg            # sta2htm.make 對每個 group 都有規則：uniq_end / reg2reg
% sta_index_run -sta_group_list 'uniq_end reg2reg'
% cd .. ; sta_index_runset
```

完成後 Runset `index.htm` 的 GROUP 表會多出 `reg2reg` 一條趨勢線，Run 層 `index.htm` 也會多一列。

### 8.4 案例四：Waiver 上線

> **豁免檔的檔名不是 sta2htm.waive**
>
`read_waive_list` 只按「`<名稱>.waive`」組合檔名去尋找，而傳入的名稱只會是 `all`、`<sta_mode>`、`<sta_corner>` 三種。因此 `etc/sta/sta2htm.waive`（以及 demo `.sta/sta2htm.waive`）**永遠不會被讀取**——它只是內容範本，使用時務必改名：

```text
.sta/all.waive        ← 全域豁免（會被所有模式/角落讀取）
.sta/func.waive       ← 僅 func 模式
.sta/231.waive        ← 僅 231 角落（corner 級，於解析階段載入）
```

（`read_waive_list` 另有「傳入名稱本身就是存在的檔案則直接使用」的分支，所以取名為 `.sta/all` 這種無副檔名的路徑也有效，但不建議。）


```csh
% cd GOLDEN-0122/.sta
% cat >> all.waive <<'WVF'
# 2026-08-28 核決：IO 電容 mismatch，暫不修
-        VCLK_CAN                        -
WVF
# 必須清除既有解析／輸出，才會完整重算（見 5.3 快取行為）
% cd .. ; make clean ; make run
```

前後對照（demo 實測，`uniq_end/func/setup.uniq_end.wns`）：

| Path Group |  waive 前 NVP / WAIVED / NVP-W |  waive 後 NVP / WAIVED / NVP-W |
|---|---|---|
| VCLK_CAN | 2 / 0 / 2 | 2 / **2** / **0** |
| VCLK_APB | 13 / 0 / 13 | 13 / 0 / 13 |
| 合計（實際） | 28 / 0 / 28 | 28 / **2** / **26** |

被豁免的兩筆會改出現在 `func/setup.waive_end.rpt`（行尾帶 `@` 標記），仍列在原始清單中以便審查。

> **合計列欄序錯位（實測）**
>
`.wns` 的**明細列**欄序為 `NVP WAIVED NVP-W WNS PathGroup`，但**合計列**實際寫出的是 `26 2 28 -114.56 5`，即依序為「NVP-W、WAIVED、NVP、WNS、group 數」（原始碼輸出順序為 `$V $W $T $S`），與表頭順序相反。若照表頭解讀會得到 NVP=26、NVP-W=28 的錯誤結論。若要做自動擷取，請改用明細列自行加總（或直接讀各欄的 `NVP-W`）。


> **豁免不會改善趨勢圖與 index 頁的 NVP/WNS/TNS（重點）**
>
mode 層的 `.dqi/520-STA/<check>/{NVP,WNS,TNS}` 在去重階段寫出，**晚於**它的豁免判定只發生於報表產出階段，所以三值皆**含已豁免點**。實測加入上述豁免後：`NVP=28`、`WNS=-114.56`、`TNS=-1274.25` 完全沒變（真實數值應為 26），因此：
- `<run>/index.htm`、`.trendchart/<group>/index.htm`、corner 格、以及所有 NVP/WNS 圖表 **不会因豁免而下降**。
- 唯一反映豁免後現況的資料是 `<check>.uniq_end.wns` 的 `NVP-W`（無豁免後 WNS/TNS 可用）。
簽核會議上請以 `.wns` 為準，或依 10.6 的做法調整。


## 第 9 章 團隊落地建議

### 9.1 專案目錄與命名慣例

本工具對命名無硬性要求（全部由設定檔決定），但配合其設計，建議採以下慣例：

```text
<project>/frontend/stasi/reports/
├── apr0-0122/         ← $STA_RUN_DIR：日期後綴（-MMDD）
│   ├── .sta/          ← cfg / corner / all.waive（與報告一起版控管）
│   ├── func/  scan01/  scan02/
├── eco1-0123/
└── eco2-0124/

<workarea>/review/     ← Runset 目錄（可獨立於報告區，避免污染資料庫）
├── Makefile           ← 內容取自 etc/make/runset.make
├── Makefile.run
├── sta2htm.run
├── logs/              ← 留存每次 make run 的 log 與 tree.log
├── index.htm          ← 對外唯一入口
└── GOLDEN-0122/  …    ← 由 sta_init_run 產出，可隨時 clean
```

命名要點：

1. **版本名前綴帶狀態**（`GOLDEN-`／`TRY-`／`ECO-`）；趨勢圖 x 軸會直接顯示這個名字。
2. 報告子目錄第二層必須與 `corner_name` **完全一致**（含大小寫與底線）。
3. mode 目錄名用短代號（`func`／`scan01`），全名寫在 `[MODE]` 第二欄供畫面顯示。
4. 暫時不想參與統計的版本，在 `[VERSION]` 行首加 `;` 即可（不必刪檔、不必 `clean`）。

### 9.2 報告產出端（PrimeTime）配合

在 PT 簽核腳本中，以模式／角落迴圈輸出到建議結構，並保留 `Report :` 標頭（STA2HTM 依賴它）：

```tcl
foreach corner_name $signoff_corners {
  update_timing -full
  foreach chk {setup hold} {
    set of "reports/${mode}/${corner_name}/${chk}.rpt"
    if {$chk eq "setup"} {
      report_constraint -all_violators -max_delay -path slack_only > $of
    } else {
      report_constraint -all_violators -min_delay -path slack_only > $of
    }
  }
}
```

需要跨時鐘／跨區塊矩陣精度時，改（或額外）產 `-verbose` 格式；兩者可放同一 glob（例如 `setup.rpt` 與 `setup_verbose.rpt` 都會被 `$sta_check.rpt*` 命中並累加）。

> **只保留 slack_only 即可滿足多數需求**
>
`-verbose` 報告體積可達數十倍（逐 pin 路徑），而 STA2HTM 對 slack_only 已能完成去重、Waive、histogram 與 Path Group 統計。只有在確實需要 cross-clock／cross-block 分析時才加 `-verbose`；此時 `.vio` 中第 2 欄會是**時鐘名**而非 Path Group（3.3.3），兩者混用時判讀請留意。


### 9.3 納入 CI / 每日回歸

| 強度 | 做法 |
|---|---|
| 手動 | 工程師拿到報告後自行 `make run`（demo 流程） |
| 排程 | crontab／CI job 於每日報告落地後跑 `make run`，並用 `make tree` 留 `logs/tree.log`；`make diff` 檢查輸出結構變化 |
| 卡關 | 直接讀 `.dqi` 做閾值檢查，超過門檻即讓 build fail |

```sh
# 例：以 .dqi 做 CI 卡關（NVP 上限 10）
NVP=$(cat $RUN/uniq_end/func/.dqi/520-STA/setup/NVP)
[ "$NVP" -le 10 ] || { echo "setup NVP $NVP > 10"; exit 1; }
```

請記得 `.dqi` 的 NVP **含已豁免點**（8.4），若要卡「真違規數」請改抓 `<check>.uniq_end.wns` 的 `NVP-W`。

`etc/make/test.make` 提供 PASS/FAIL、`.status`、waive 比對等通用回歸骨架，可把「各 group 的 `.vio` 行數」當 target 與 golden 比對，作為 sta2htm 自身的回歸測試。

### 9.4 對外發佈

STA2HTM 產物是**相對連結的靜態站**，發佈時（a）保持 Runset 目錄結構完整、（b）連 `.icon/`、`.javascript/` 一起打包（`sta_init_run` 是以 `cp` 複製的實體檔，可安全打包）。

```csh
% make run
% tar czf review-0122.tgz index.htm .trendchart .javascript .icon sta2htm.run GOLDEN-0122/
```

內網網站發佈：在 Runset 目錄起一個靜態服務即可（`python3 -m http.server`、nginx autoindex，或同步到專案共用 web 區）。**不要**只複製某個 `.htm` 單一檔案——頁面大量使用 `iframe` 與相對路徑，必須整棵樹複製。

> **部分頁面內容會被當成下載檔**
>
索引頁大量以 `<iframe src=sta2htm.log>`、`<iframe src=sta2htm.run>` 引用無副檔名的文字檔。部分瀏覽器或嚴格伺服器會把 `.log`／`.run` 判為下載（實測以 headless Chromium 瀏覽時即觸發下載，該區塊顯示為空）。屬外觀問題，不影響分析數據；必要時於伺服器強制 `Content-Type: text/plain`。


### 9.5 品牌與樣式客製

| 目標 | 修改處 |
|---|---|
| 右上角 logo 圖檔 | 替換 `etc/icon/lyg_banner.png`，或改 `tcl/STA_HTML.tcl` 的 `ICON(logo_banner)` |
| logo 超連結 | `STA_HTML::LINK(logo_banner)`（預設連到公司關於頁） |
| 表格樣式 | `STA_HTML::TABLE_CSS(sta_tbl)` 內嵌 CSS（表頭色 `#4CAF50`）；另參考 `etc/html/sta/table_sta_tbl.css` |
| Runset 頁標題 | `tcl/STA_INDEX.tcl` 中 `report_index_runset` 的 `"STA2HTM MMMC Timing Report Reviewer V2021.02"` |
| histogram 門檻 | `tcl/LIB_STA.tcl` 的 `WNS_HRANGE` |
| 自訂 block 分組 | 在 `.sta/sta2htm.cfg` 加 `set ::LIB_STA::STA_BLOCK {ddr u_ddr_phy core u_core}`（平鋪 list：鍵、樣式交錯） |

`get_block_name` 使用的正則為 `^<樣式>/.*`，即**錨定在實例路徑開頭**，故樣式需能從頂層開始匹配（例：`top/u_cpu`）。一旦 `STA_BLOCK` 非空，未匹配的腳位一律歸為 `-`（不再退回「第一層目錄名」），因此樣式清單應盡量涵蓋所有頂層實例。（本次實測驗證，見 10.4。）

### 9.6 二次開發地圖

| 想加什麼 | 要改哪裡 |
|---|---|
| 新的輸出頁面 | 在 `tcl/` 新增 `report_xxx`（`LIB_STA` namespace），並於 `report_uniq_end` 的 mode 迴圈中呼叫 |
| 新的命令 | 仿 `csh/21_sta_uniq_end.tcl`（source LIB_STA → `parse_argv` → 一個 `report_*`），並在 `etc/make/bin.make` 加 symlink |
| 新的報告格式 | `tcl/STA_PT.tcl` 增加 `rpt_type` 分支或 `rpt_style` 正則 |
| 支援 Tempus 等其它工具 | 只需新寫一個 `parse_<tool>_report`，其下去重、HTML、DQI、趨勢頁全部可 reuse |
| 讓趨勢圖反映豁免 | 在 `unique_vio_endpoint` 寫 `.dqi` 之前套用 `check_waive_slack` 過濾（改善 10.7） |

## 第 10 章 疑難排解與已知限制

以下每一項都在本次實測中被重現或驗證。編號對應前文引用位置。

### 10.1 自診三步：先看這三處

| # | 檢查 | 指令／方法 | 判讀 |
|---|---|---|---|
| 1 | 解析有沒有吃到檔 | `head -2 <run>/<group>/<mode>/<corner>/<check>.vio` | 有 `# File :` 表有吃到；缺此檔＝路徑/glob 問題（10.2、10.10） |
| 2 | 吃到幾筆 | `grep -c '^\s*-' <check>.vio` 或 `cat <corner>/.dqi/520-STA/<check>/NVP` | 與 `grep -c "(VIOLATED)" 報告檔` 對照 |
| 3 | 執行 log | `cat <run>/<group>/sta2htm.log`、`cat <run>/sta2htm.log` | 搜尋 `ERROR:`、`WARNING:`、`Report Not Found` |

### 10.2 情境對照表

| 症狀 | 最可能原因 | 處方 |
|---|---|---|
| `sta_uniq_end: Command not found` | 未 `source setup.cshrc` 或 `make bin` 未跑 | `cd sta2htm && make bin && source setup.cshrc` |
| `sta_init_run` 沒反應／`/bin/csh: No such file` | 系統無 csh（多數 container/devbox 預設只有 bash） | 走「手工初始化」，見 10.3 |
| 頁面出現 `ERROR: STA_CORNER(...) has undefined corner (NNN)` | 劇本引用了 `sta2htm.corner` 裡沒有的代號 | 補 corner 定義或修正代號（demo 的 `251` 即此例） |
| 所有角落都是紅 `*` | `STA_RPT_PATH`／glob 樣式沒命中（路徑大小寫、第二層目錄名不符） | 檢查 3.1、3.5；確認 `STA` symlink 有效：`ls -l <run>/STA` |
| NVP 為 0 但報告確實有違規 | 報告只有 `-summary`（無 `-path slack_only` 也無 `-verbose`） | PT 重新輸出，或於 `.vio` 用 10.1 確認 |
| NVP 為 `.`（綠）但實際有違規 | 同上；或 `sta_check` 名稱與 `Path Type` 對應不上（3.3.2） | 用 `setup`／`hold` 兩個標準名稱 |
| 數值比預期大 1000 倍 | PT 輸出單位不是 ns | 統一用 ns 輸出（3.3.1） |
| 改了 `.waive` 沒效果 | 檔名不是 `all.waive`／`<mode>.waive`；或 `.vio` 快取未清 | 見 8.4；`make clean` 重跑 |
| 趨勢圖某版缺一整列 | 該 Run 沒跑過或 `.dqi` 缺失 | 進該 Run `make run`；確認 `sta2htm.run` 的 `[VERSION]` 未以 `;` 註解 |
| 趨勢圖某版對齊錯乱 | 版本名含空白 | `STA_RUN` 不可含空白（4.2） |
| 圖表區空白 | 該層缺 `.javascript/Chart.bundle.min.js`（Chart.js 404） | 依 5.6 的提醒補檔 |
| 只有 `.plt` 沒有 `.png` | 無 gnuplot（正常） | 不影響 HTML；需 png 才裝 gnuplot |
| 右上角 logo 破圖 | 缺 `.icon/logo_banner.png` 或上溯層數不對 | 依 5.6 補 `.icon/`（Run 與 Runset 兩層都要） |
| 頁面 iframe 變成下載 | `.log`／`.run` 的 Content-Type | 本地開啟或伺服器端設定（9.4） |

### 10.3 沒有 csh 環境如何初始化（實測可行）

`sta_init_run` 是 csh 腳本。在無 csh 的機器（容器、CI image）上，可用等價的 bash 段落取代——以下為本次撰写手冊實際使用的替代腳本，行為與 `csh/20_sta_init_run.csh` 一致：

```bash
#!/bin/bash
# sta_init_run.sh <STA_RUN> <STA_RUN_DIR> [group...]
: ${STA2HTM:?must source setup.cshrc or export STA2HTM}
STA_DIR=STA
[ "$1" = "--STA_DIR" ] && { STA_DIR=$2; shift 2; }
STA_RUN=${1:-.}; [ $# -gt 0 ] && shift
STA_RPT=${1:-$STA_RUN}; [ $# -gt 0 ] && shift
mkdir -p "$STA_RUN/.sta" "$STA_RUN/.icon" "$STA_RUN/.javascript"
cp -f  $STA2HTM/etc/make/sta2htm.make      "$STA_RUN/Makefile"
cp -fr $STA2HTM/etc/icon/*                 "$STA_RUN/.icon/"
cp -f  $STA2HTM/etc/html/chartjs/Chart.bundle.min.js "$STA_RUN/.javascript/"
STA_RPT=$(realpath "$STA_RPT")
{ echo "# STA_RUN := $STA_RUN"; echo "# STA_RPT := $STA_RPT"; } > "$STA_RUN/Makefile.group"
cp -f  "$STA_RPT/.sta/sta2htm."* "$STA_RUN/.sta/" 2>/dev/null
rm -f  "$STA_RUN/$STA_DIR"; ln -s "$STA_RPT" "$STA_RUN/$STA_DIR"
if [ $# -eq 0 ]; then echo "STA_GROUP := uniq_end" >> "$STA_RUN/Makefile.group"
else for g in "$@"; do echo "STA_GROUP += $g" >> "$STA_RUN/Makefile.group"; done; fi
```

其餘 4 支命令是 `#!/usr/bin/tclsh`，只需要 Tcl，不需 csh。

### 10.4 【限制】Block 報表永遠只有一列 `- : -`

實測：`<check>.blk.htm` 輸出為 `#0 Blocks`、單列 `- : -`。原因是 `tcl/STA_BLOCK.tcl` 的 `get_block_name` 判斷 `[info exist STA_BLOCK]`，而 `variable STA_BLOCK` 一經宣告即永遠為真（值為空字串），使 `elseif` 的「退回第一層目錄名」分支**永遠不會執行**。

**解方**：在 `.sta/sta2htm.cfg` 內顯式指定（本次驗證有效，`#2 Blocks` 正確認出 `ddr`、`core`）：

```tcl
set ::LIB_STA::STA_BLOCK {ddr u_ddr_phy core u_core}
```

或打一行補丁，把該判斷改為「非空才算存在」：

```diff
-  if {[info exist STA_BLOCK]} {
+  if {[info exist STA_BLOCK] && $STA_BLOCK!=""} {
```

補丁後未匹配的腳位會退回「第一層目錄名」，即原廠說明預期的行為。

### 10.5 【限制】`-slack_offset` 選項不可用

`parse_argv` 呼叫 `read_slack_offset`，但該程序**在整個 codebase 中並不存在**，因此使用 `-slack_offset` 必定結束執行：

```text
invalid command name "read_slack_offset"
```

同理 `SLACK_OFFSET(...)` 陣列無任何來源，`get_slack_offset` 恆返回 0。若確需對特定 group 加 margin（例如 derate），請在 PT 端用 `set_multicycle_path`／margin 選項處理，或自行於 `.sta/sta2htm.cfg` 內以 Tcl 設定：

```tcl
set ::LIB_STA::SLACK_OFFSET(func,setup) 0.001   ;# 需確認此處單位為 ns（會再乘 1000）
```

（注意 `get_slack_offset` 使用的是 `variable SLACK_OFFSET`，從 proc 內 `source` 的 cfg 需以 `::LIB_STA::` 全限定名稱才能寫入該 namespace。此為變通做法，正式使用請先以對照組驗證數值符號。）

### 10.6 【限制】`sta_rpt_by_clock` / `sta_rpt_by_block` 無法執行

兩支腳本以無參數呼叫需要 2 個參數的程序：

```text
wrong # args: should be "::LIB_STA::report_clock_end sta_group sta_check"
```

且 `make bin` 未建立它們的 symlink。功能已由 `sta_uniq_end` 內部的 `report_index_clock`/`report_index_block` 勝任（5.7），**不需使用**。若確需獨立重建，請改用：

```csh
% sta_index_group -sta_group uniq_end          # 重建索引與矩陣頁（不重新解析）
```

### 10.7 【限制】豁免不影響 DQI、索引頁與趨勢圖

實測（8.4）：加入豁免後 `NVP=28`、`WNS=-114.56`、`TNS=-1274.25` 不變，僅 `.wns` 的 `NVP-W` 降為 26。根因：豁免的二次判定發生在報表產出階段，而 mode 級 `.dqi` 在去重階段已寫出。若組織以趨勢圖作為 ECO 成效指標，請：

- 以 `<check>.uniq_end.wns` 的 `NVP-W` 合計（自行加總明細列，避开 10.8）為對外交付數字；或
- 依 9.6 最後一列打補丁；或
- 把豁免直接從報告源頭處理（PT 端 mask），使 STA2HTM 看到的即是淨違規。

### 10.8 【限制】`.wns` 合計列欄序錯置

明細列為 `NVP WAIVED NVP-W WNS PathGroup`，合計列卻依序輸出「`NVP-W  WAIVED  NVP  WNS  group 數`」（原始碼 `[format ... $V $W $T $S ...]`），即第 1 格與第 3 格互換。以 demo 為例合計列印成 `26 2 28 -114.56 5`。自動擷取請只讀明細列自行加總。

### 10.9 【限制】比較（diff）功能未接線

`STA_PLOT.tcl::create_comp_nvp_wns_plot`（產生 `nvp_wns.diff.png/.rpt`）與 `STA_COMP.tcl::report_comp_sta_html`（產生 `<check>.diff.htm`）在 v2.0 **無任何呼叫者**，也無命令列入口。兩版對照請改用 `sta_index_runset` 的趨勢頁（跨版本矩陣）。若需要真的 diff 圖，可在 tclsh 中手動執行：

```csh
% tclsh
> source $STA2HTM/tcl/LIB_STA.tcl
> ::LIB_STA::read_sta_config
> ::LIB_STA::create_comp_nvp_wns_plot func/setup <newRun>/.trendchart <oldRun>/.trendchart diff
```

（需 gnuplot，且兩側都要有同名 `.nvp_wns.dat`。）

### 10.10 【限制】其它實作細節（不影響正確性，但會影響使用體感）

| 項目 | 現象 | 備註 |
|---|---|---|
| corner 級 `.dqi/NWP` | 幾乎恆為 0 | 解析階段的 `check_waive_slack` 參數順序與報表階段不同（見 10.7 根因） |
| `.waive_end.rpt` 分隔線 | corner 欄恆為 `xxxxxxxx` | 檢查的是未存在的 `WAV_FILE` 陣列（應為 `VIO_FILE`），無功能影響 |
| `.unzip.rpt` 殘留 | 解析 `.gz` 後清理路徑寫錯，corner 目錄可能留檔 | 殘留垃圾，可定期 `find . -name .unzip.rpt -delete` |
| `sta_postfix` 變數 | 模板 `sta2htm.cfg` 引用但從未賦值 | 需後綴區分時請改用多個 glob |
| `sta2htm.mode` | demo `.sta/` 內存在但不會被讀取 | mode 全名請寫進 `sta2htm.run` 的 `[MODE]` |
| 未使用的選項值 | 錯誤選項會被靜默忽略，僅印 `INFO: Unused parameter 'N'` | 參數拼錯時務必回看 log |
| `report_sta_report_directory`（STA_INDEX.tcl 尾） | 引用未宣告的 `$fo`，呼叫即錯 | v2.0 無呼叫者，請不要使用 |
| `mode_name`（STA_PT.tcl 開頭） | `set mode_name $sta_mnode` 為錯字，但該分支只在 mode 未定義時進入 | 會導致 mode 未定義時多一個錯，請確保 `[MODE]` 完整 |
| 效能 | 每份報告逐行正則比對，單檔 10 萬行約十秒級 | 大設計建議用 `-path slack_only`（格式 A）而非 `-verbose`，可省一至兩個數量級 |

## 附錄 A 原始碼模組對照表

`tcl/LIB_STA.tcl` 為中樞，`init` 依序 source 下列模組（皆於 `LIB_STA` namespace 內）。

| 模組 | 行數 | 職責 | 關鍵程序 |
|---|---|---|---|
| `LIB_STA.tcl` | 830 | CLI 解析、主流程、去重後報表、mode/check 摘要頁 | `parse_argv`、`report_uniq_end`、`report_scenario_summary`、`report_mode_summary`、`report_check_summary`、`report_endpoint_text/html`、`report_wavpoint_html` |
| `STA_CONFIG.tcl` | 459 | `sta2htm.run` 解析、cfg source、設定同步與回寫 | `read_sta_runset`、`parse_runset_line`、`read_sta_config`、`sync_sta_config`、`output_sta2htm_runset` |
| `STA_INDEX.tcl` | 846 | Runset／Run／Group 三層索引與跨版本趨勢表 | `report_index_runset`、`report_index_run`、`report_index_group{,_main,_mode,_check,_corner}`、`report_trend_group` |
| `STA_PT.tcl` | 476 | PrimeTime 報告解析（核心） | `parse_primetime_report` |
| `STA_MERGE.tcl` | 97 | 跨 corner 端點去重、mode 級 DQI | `unique_vio_endpoint` |
| `STA_WAIVE.tcl` | 148 | 豁免清單載入與比對、slack offset | `read_waive_list`、`check_waive_slack`、`get_slack_offset` |
| `STA_CORNER.tcl` | 91 | `sta2htm.corner` 讀取與 id↔name 換算 | `read_sta_corner`、`get_corner_name`、`get_corner_id` |
| `STA_CLOCK.tcl` | 336 | 跨時鐘 NVP/WNS 矩陣 | `sort_slack_by_clock`、`output_clock_table`、`report_index_clock` |
| `STA_BLOCK.tcl` | 352 | 跨區塊（實例前綴）矩陣 | `get_block_name`、`sort_slack_by_block`、`output_block_table`、`report_index_block` |
| `STA_HISTOGRAM.tcl` | 133 | slack 分佈與 group 統計 | `report_vio_histogram` |
| `STA_PLOT.tcl` | 127 | gnuplot 腳本生成與呼叫 | `create_nvp_wns_plot`、`create_comp_nvp_wns_plot`、`get_nvp_ymax` |
| `STA_CHART.tcl` | 177 | Chart.js（HTML）圖表生成 | `create_nvp_wns_chart` |
| `STA_HTML.tcl` | 47 | CSS／logo／連結常數 | `STA_HTML::TABLE_CSS`、`ICON`、`LINK` |
| `STA_COMP.tcl` | 69 | 兩版差異頁（未接線） | `report_comp_sta_html` |

驅動腳本（`csh/`，`bin/` 為其 symlink）：

| 腳本 | 命令 | 呼叫的核心程序 |
|---|---|---|
| `20_sta_init_run.csh` | `sta_init_run` | —（shell 複製／連結） |
| `21_sta_uniq_end.tcl` | `sta_uniq_end` | `report_uniq_end` + `report_index_group` |
| `22_sta_rpt_by_clock.tcl` | （無 symlink） | `report_clock_end`（見 10.6） |
| `23_sta_rpt_by_block.tcl` | （無 symlink） | `report_block_end`（見 10.6） |
| `28_sta_index_group.tcl` | `sta_index_group` | `report_index_group` |
| `28_sta_index_run.tcl` | `sta_index_run` | `report_index_run` |
| `29_sta_index_runset.tcl` | `sta_index_runset` | `read_sta_runset` + `report_index_runset` |

## 附錄 B 上線模板與檢查清單

### B.1 `sta2htm.run` 完整模板

```text
# ============================================================
#  STA2HTM Runset : <project>_<block> _signoff
#  Owner : <engineer>     Last update : <YYYY-MM-DD>
# ============================================================
[VERSION]
#STA_RUN       STA_RUN_DIR                 STA_RUN_GROUPS
#------------- --------------------------- --------------------------------
GOLDEN-0122    reports/apr0-0122           uniq_end reg2reg
GOLDEN-0123    reports/eco1-0123           uniq_end reg2reg
;GOLDEN-0127   reports/eco3-0127           uniq_end          # 暫不參與

[GROUP]
#STA_GROUP     STA_GROUP_REPORT
#------------  ------------------------------------------------------------
uniq_end       $sta_mode/$corner_name/$sta_check.rpt*
reg2reg        $sta_mode/$corner_name/$sta_check/RptConst_reg2reg.rpt

[BLOCK]
#STA_BLOCK     STA_BLOCK_DEF（實例路徑前綴，見 9.5／10.4）
cpu            top/u_cpu
ddr            top/u_ddr_phy

[CHECK]
#STA_CHECK     STA_CHECK_DQI（趨勢表角落欄要顯示的指標）
setup          WNS
hold           NVP

[MODE]
#STA_MODE      STA_MODE_NAME     STA_MODE_DEF（SDC）
#------------  ----------------  --------------------------------
func           functional        func_0210.sdc
scan01         dc_shift          scan_0211.sdc
scan02         ac_capture        scan_0221.sdc

[CORNER]
#STA_CORNER    STA_CORNER_NAME   STA_CORNER_DEF（lib:volt:temp  RC）
#------------  ----------------  --------------------------------
000             000_TT            TTT:0.80V:025C   RCtyp
151             151_ML            FFG:0.88V:125C   Cmax
157             157_BC            FFF:0.88V:-40C   Cmin
231             231_WCL           SSG:0.72V:-40C   Cmax
258             258_WC            SSG:0.72V:125C   Cmax

[SCENARIO]
#SID    CHECK    MODE      <依 [CORNER] 欄序填 corner 或 ->
#-----  -------  --------  ------------------------------------
S001    setup    func      000 -   157 231 258
S002    setup    scan02    000 -   -   -   258
H001    hold     func      000 151 157 -   258
H002    hold     scan01    000 -   157 -   258
```

### B.2 `Makefile.run` 模板

```make
STA_RUN     := GOLDEN-0122
STA_RUN_DIR.GOLDEN-0122    := reports/apr0-0122
STA_RUN_GROUPS.GOLDEN-0122 := uniq_end reg2reg

STA_RUN    += GOLDEN-0123
STA_RUN_DIR.GOLDEN-0123    := reports/eco1-0123
STA_RUN_GROUPS.GOLDEN-0123 := uniq_end reg2reg
```

### B.3 上線前檢查清單

| # | 項目 | 驗證指令 |
|---|---|---|
| 1 | 環境載入 | `which sta_uniq_end sta_index_runset` |
| 2 | 報告結構 | `tree -d -L 2 <STA_RUN_DIR>` 對照 `[MODE]`/`[CORNER]` |
| 3 | corner 名稱一致 | 比對 `<run>/.sta/sta2htm.corner` 第二欄與實際目錄名 |
| 4 | 劇本無未定義 corner | `make run 2>&1 \| grep -E "ERROR\|WARNING"` 為空 |
| 5 | 每角落都有吃到違規 | `find <run> -name "*.vio" \| xargs -I{} sh -c 'echo -n "{}: "; grep -c "^ " {}'` |
| 6 | 豁免生效 | `grep -c @ <run>/<group>/<mode>/<check>.waive_end.rpt` |
| 7 | 單位正確（ps） | 數值應為個位～三位數，非 `-0.05` 這種 tiny 值 |
| 8 | 連結完整 | 瀏覽器無 404（F12 Network），`.javascript`、`.icon` 有載入 |
| 9 | 與前一版可比 | `.dqi` 於各 Run 皆存在，趨勢表無紅 `*` |

## 附錄 C 一頁速查

| 我想… | 做什麼 |
|---|---|
| 第一次安裝 | `git clone …; cd sta2htm; make bin; source setup.cshrc` |
| 看範例 | `cd run/01_sta; make run; firefox index.htm` |
| 新增一個版本 | `sta2htm.run [VERSION]` + `Makefile.run` 各加一列 → `make run` |
| 只重刷頁面（不重解析） | `sta_index_group -sta_group uniq_end; sta_index_runset` |
| 完全重算 | `make clean; make run` |
| 加一個報告群 | `[GROUP]`＋`STA_RUN_GROUPS`＋`STA_GROUP_REPORT.<g>` → `make <g>` |
| 豁免某個違規 | 編輯 `.sta/all.waive`（`-  <pathgroup>  <pin>`）→ `make clean; make run` |
| 查真違規數 | `cat <group>/<mode>/<check>.uniq_end.wns`（`NVP-W` 明細列） |
| 查最差 corner | 群級 `corner.htm` 或 `.uniq_end.rpt` 的 `WCorner` 欄 |
| 取指標給腳本 | `cat <mode>/<corner>/.dqi/520-STA/<check>/NVP\|WNS\|TNS\|NWP` |
| 發佈給主管 | 打包 Runset 目錄（含 `index.htm`、`.trendchart`、`.javascript`、`.icon`） |

---

## 參考資料

1. `icdop/sta2htm`，Gitee 倉庫：[https://gitee.com/icdop/sta2htm](https://gitee.com/icdop/sta2htm)（README、`etc/make/*`、`tcl/*`、`csh/*` 全檔）
2. `icdop/sta2htm`，GitHub 鏡像：[https://github.com/icdop/sta2htm](https://github.com/icdop/sta2htm)
3. 原廠訓練簡報：`doc/pdf/210125_STA2HTM_User_Guide_v1.pdf`（Albert Li，2021-01-25；內容為 **v1.0 命令語法**）
4. 範例資料與輸出：`run/01_sta/`、`run/02_trend/`、`run/reports/{apr0-0122,eco1-0123,eco2-0124,eco3-0125}/`
5. 授權：MIT License，Copyright (c) 2020 Albert Li

*本手冊由千問辦公（QwenWork）於 2026-08-28 依上述來源研讀並實測後撰寫；書中所有數值與錯誤訊息皆取自真實執行結果。工具本身的既有瑕疵在第 10 章逐項標注，使用時請以該章為準。*
