# sta2htm.run 語法規範（Grammar / Schema）v1

> 依據 STA2HTM V3.0 官方解析器 `LIB_STA::read_sta_runset` + `parse_runset_line`
> （tcl/STA_CONFIG.tcl:253-378）與三個 demo runset（run/01_sta、02_trend、03_tempus）推導。
> 配套工具：`bin/sta2htm_run_json.tcl`（run ⇄ json 轉換）與 `app/`（Node.js 網頁編輯器）。

---

## 1. 詞法（Lexical）

| 詞 | 規則 | 備註 |
|---|---|---|
| 空白 | 空格/Tab 均可，連續視作一個分隔 | 欄位內**不得**含空白 |
| 區塊標記 | `^\s*\[NAME\]`，NAME 只接受大寫 A–Z | 行首允許縮排 |
| 註解行 | `#` 開頭（**必須在第 0 欄**，前面有空格的 `#` 會被當作資料行） | |
| 停用字元 | 行內任一 `;` 起，其後整段被原始解析器**丟棄**；`;NAME ...`＝把該列「註解掉但不刪檔」 | demo：`;GOLDEN-0127 …` |
| 資料行 | `^\s*\[` 以外、非空、非 `#0` 欄開頭之行，全部交給「目前區塊」解析 | |
| 空行 | `^\s*$` 跳過 | |
| 詞元(token) | 以 `lindex` 語意切分：空白分隔；`"…" `與 `{…}` 視爲單一詞元 | `$sta_mode/...` 等 `$` 字元於 lindex 階段**不展開**，安全 |

> ⚠ 與實作完全一致的三個「坑位」：
> 1. `#` 前有空格 → 不是註解（會進 `parse_runset_line` 落入未知區塊、印 WARNING）。
> 2. `;` 可出現在**行中任何位置**，一律切尾（含引號內）。
> 3. 區塊標記後若有多餘文字不影響（正則只取 `[A-Z]+`）。

## 2. 語法圖（Syntax Diagram，EBNF）

```ebnf
file        ::= line { line }
line        ::= blank | comment | section | datum | disabled | raw_junk
blank       ::= ws newline
comment     ::= "#" anychar* newline          (* '#' 必須第 0 欄 *)
section     ::= ws "[" SECT "]" anychar* newline
SECT        ::= "VERSION" | "GROUP" | "BLOCK" | "CHECK"
              | "MODE" | "CORNER" | "SCENARIO"
disabled    ::= ws ";" tokens newline          (* 原始工具直接丟棄；本converter 保留成 enabled:false *)
datum       ::= tokens newline                 (* 以「目前 SECT」的字彙規則解析 *)
raw_junk    ::= line 於 SECT="" 時            (* 尚未出現任何 section 前的資料行 → WARNING *)

tokens      ::= token { ws token }             (* lindex 語意；"…" {…} 為單元 *)
```

各區塊 `datum` 的字彙（field）規則：

```
VERSION  ::= name dir groups+            ; 詞元0=run, 1=dir, 2..=groups
GROUP    ::= name pattern+               ; 0=群名, 1..=報告 glob
BLOCK    ::= alias pattern+              ; 0=區塊別名, 1..=匹配樣式
CHECK    ::= metric def+                 ; 0=setup|hold, 1..=趨勢指標(WNS/TNS/NVP)
MODE     ::= mode name sdc*              ; 0=代號, 1=全名, 2..=SDC 檔
CORNER   ::= corner name lib rc*         ; 0=代號, 1=corner_name(=報告目錄), 2..=lib/RC
SCENARIO ::= sid check mode cell+        ; 0=SID, 1=check, 2=mode, 3..=角落矩陣列
cell     ::= corner代號 | "-"            ; "-"＝該角落於此劇本不存在
```

**順序語意（重要）**

* `[CORNER]` 的**列出順序**＝ `[SCENARIO]` 矩陣的欄順序。
* `[VERSION]` 的行序＝趨勢圖 x 軸時序（後定義者為新）。
* `[SCENARIO]` 的 mode/check 必須已於 `[CHECK]`/`[MODE]` 定義，否則印 WARNING 並自動补一個空定義。
* 同一 `(mode,check)` 被兩列 SCENARIO 使用 → 後者覆蓋 STA_CORNER；SCENARIO_MAP 則兩列皆保留。

## 3. demo 對照（節選自 run/01_sta/sta2htm.run）

```
GOLDEN-0122	reports/apr0-0120      uniq_end reg2reg in2reg reg2out
     │              │                     └── groups（1..n 個）
     │              └── dir（STA 報告所在目錄）
     └── run name（輸出目錄名／唯一鍵）

S001    setup   func	000 -   157 237 231
  │      │      │    └── 依 [CORNER] 順序 5 欄，"-"＝该角落不跑
  │      │      └ mode（需已定義）
  │      └ check
  └ SID（僅供追蹤/顯示鍵）
```

## 4. JSON 表示（sta2htm.json）

```jsonc
{
  "$schema": "sta2htm.run/1",
  "source": "01_sta/sta2htm.run",       // 自由文字；json2run 僅記錄
  "sectionOrder": ["VERSION","GROUP","CHECK","MODE","CORNER","SCENARIO"],
  "preamble": ["#"],                     // 首個 section 前的原始行，按序保留
  "sections": {
    "VERSION": [ { "run":"GOLDEN-0122", "dir":"reports/apr0-0120",
                  "groups":["uniq_end","reg2reg","in2reg","reg2out"],
                  "enabled": true } ],
    "GROUP":   [ { "group":"uniq_end",
                  "pattern":"$sta_mode/$corner_name/$sta_check.rpt" } ],
    "BLOCK":   [ { "block":"cpu", "pattern":"^cpu/.*" } ],
    "CHECK":   [ { "check":"setup", "def":["WNS"] } ],
    "MODE":    [ { "mode":"func", "name":"functional", "def":["func_0210.sdc"] } ],
    "CORNER":  [ { "corner":"000", "name":"000_TT",
                  "def":["TTT:0.80V:025C","RCtyp"] } ],
    "SCENARIO":[ { "id":"S001", "check":"setup", "mode":"func",
                  "corners":["000","-","157","237","231"] } ]
  }
}
```

欄位規則：

| JSON | runset | 說明 |
|---|---|---|
| `"$schema"` | — | 固定 `"sta2htm.run/1"` |
| `sections.<SECT>` | 各區塊之資料列（**陣列順序保持**） | 缺失的區塊＝該段完全沒有資料行 |
| `enabled:false` | 行首 `;` | 轉換器**保留**被 `;` 停用的列（原始解析器會直接丟棄） |
| `preamble` | 區塊外註解/亂行 | 逐行原樣保留（含第 0 欄 `#`、`#` 前有空白者） |
| 多詞欄（groups/def/corners/pattern） | 行內第 N 個詞元起 | 詞元含空白時，文字版以 `{…}` 包裹 |

### 4.1 json2run 還原文字規則（確定性）

1. 依 `sectionOrder`（缺省→標準序）輸出區塊；每區塊前置**原解析器同款**欄位標頭註解（即 `output_sta2htm_runset` 之 `#STA_RUN…` 三行式）。
2. 欄寬對齊：`%-12s %-20s %s`（VERSION/SCENARIO 為 `%-8s %-10s %-10s %-4s…`），純視覺、不影響語意。
3. `enabled:false` → 行首補 `;`。
4. 多詞欄以單空格串接；詞元內含空白時以 `{}` 包裹（lindex 反切時還原）。
5. json2run 輸出**經同一文法重新解讀後必與原語意相等**（工具並附 `verify` 模式做自我保證）。

### 4.2 語義驗證規則（編輯器/轉換器共用 checklist）

* 區塊內名稱唯一（run/group/alias/check/mode/corner id）。
* SCENARIO.mode ∈ MODE；SCENARIO.check ∈ CHECK；cell（非 `-`）∈ CORNER。
* `corners` 長度 == CORNER 筆數（不等→WARNING：欄序對不齊 [CORNER]）。
* VERSION.dir 建議存在（編輯器僅給提示，不擋檔）。
* `(mode,check)` 被多列 Scenario 使用 → WARNING（後列覆蓋 STA_CORNER）。
* `#` 前有空白、`;` 位於引號內 → 編輯器以「行尾註解」正當化重排輸出。

## 5. 工具與範例

| 檔案 | 用途 |
|---|---|
| `bin/sta2htm_run_json.tcl` | run ⇄ json 轉換器（tclsh 8.5+，零依賴）；含 `verify` 雙向往返自檢 |
| `examples/*.json` | 三個 demo runset 之 JSON 產物 |
| `app/` | Node.js 網頁編輯器（表格/文字/JSON 三視圖＋即時驗證） |

用法：

```
tclsh bin/sta2htm_run_json.tcl run2json <檔.run>  -o <檔.json>
tclsh bin/sta2htm_run_json.tcl json2run <檔.json> -o <檔.run>
tclsh bin/sta2htm_run_json.tcl verify   <檔.run>
```
