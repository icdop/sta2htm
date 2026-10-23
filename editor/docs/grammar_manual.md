# sta2htm.run 語法說明書

版本：sta2htm.run/1 ｜ 適用 STA2HTM **V3.0**（`etc/DOP_VERSION = 2026_0830a`）
權威依據：`tcl/STA_CONFIG.tcl` 之 `read_sta_runset` / `parse_runset_line`（253–378 行）
配套：`bin/sta2htm_run_json.tcl`（轉換器）、`app/`（網頁編輯器）、`docs/grammar.md`（速查）

---

## 1. sta2htm.run 是什麼、誰在讀它

`sta2htm.run` 是 STA2HTM 的 **Runset 設定檔（版本集登記表 + MMMC 劇本）**，放在每個
run 專案根目錄（`sta2htm.run`），描述：

1. **比對哪些資料庫版本**（`[VERSION]`，一行＝一個 GOLDEN 版本）；
2. **每個版本如何解析報告**（`[GROUP]` 報告樣式、`[CHECK]` 趨勢指標）；
3. **MMMC 劇本本體**（`[MODE] / [CORNER] / [SCENARIO]`：在什麼模式、哪個角落、跑 setup 還是 hold）。

```
產線流程                 誰讀哪支檔
─────────────────────────────────────────────────────────────
PT/Tempus 產報告  ──►  reports/<日期版本>/<mode>/<corner_name>/<check>.rpt*
                                             │
sta_init_run (讀 Makefile.run) ──► 建立 Run 目錄 + 複製 .sta/
sta_uniq_end / sta_index_*      ──► 讀 .sta/sta2htm.cfg（解析層劇本）
sta_index_runset                ──► 讀 ./sta2htm.run（彙總層：Runset 索引＋趨勢）
```

> ⚠ **兩個劇本、一份事實**：解析層用 `.sta/sta2htm.cfg`（`STA_CORNER(...)`），
> 彙總層用 `sta2htm.run`（`[SCENARIO]`）。兩邊必須語意一致，否則單版頁與趨勢頁
> 數字打架——這是最常見的「對不上」根因。

## 2. MMMC 三元素：mode、corner、scenario（含圖示）

STA 簽核從不只看一個「環境」：同一份 netlist，在不同工作模式、不同製程/電壓/溫度
角落下，會得到完全不同的時序結論。MMMC = Multi-Mode Multi-Corner。

### 2.1 MODE（工作模式）＝ 「電路在幹麼」

功能 (functional)、掃描移位 (dc_shift)、捕獲 (ac_capture)…——由 **SDC 時序限制檔**
定義的「場景視角」。同一路徑在 func 下是資料路徑、在 scan 下是時鐘馈通路徑。

```
[MODE]   ＃ 欄位：代號  全名            SDC
func     functional      func_0210.sdc      ← 功能模式
scan01   dc_shift        scan_0211.sdc      ← 掃描移位
scan02   ac_capture      scan_0221.sdc      ← 掃描捕獲
```

圖示——報告落檔的第一層目錄就是 mode：

```
reports/apr0-0122/
├── func/     ← mode 000 全名 functional 的報告群
├── scan01/   ← mode scan01 的報告群
└── scan02/
```

### 2.2 CHECK（檢查類型）＝ 「在問什麼問題」

只有兩種：`setup`（最大延遲收斂）與 `hold`（最小延遲/时鐘馈通）。
`[CHECK]` 區塊第二欄規定 **Runset 趨勢矩陣中「角落欄」顯示哪個指標**：

```
[CHECK]
setup   WNS     ← 趨勢表 setup 角落欄顯示 Worst Negative Slack
hold    NVP     ← hold 欄顯示違規端點數
```

> 注意層級差異：單版 index 頁一律以 **NVP** 著色；Runset 趨勢頁依 `[CHECK]` 規定指標。
> 同一格兩頁數字不同屬正常（口徑不同源）。

### 2.3 CORNER（製程角落）＝ 「晶片在哪個物理環境」

一個角落 = **製程角 (process/lib corner) × 電壓 × 溫度 × RC 互連角** 的組合。
lib 全名形如 `SSG:0.72V:125C`（Liberty 角:電壓:溫度）。

```
[CORNER] ＃代號  ＃目錄名(corner_name) ＃lib:V:T       ＃RC角
000      000_TT     TTT:0.80V:025C   RCtyp      ← 標稱角（typical）
151      151_ML     FFG:0.88V:125C   Cmax       ← 快角高壓高溫（min leakage 側）
157      157_BC     FFF:0.88V:-40C   Cmin       ← 最快角（hold 兇手）
237      237_WCL    SSG:0.72V:-40C   Cmax       ← 慢角低溫高 RC（setup 兇手）
231      231_WC     SSG:0.72V:125C   Cmax       ← 慢角高溫
```

圖示——四維物理空間投影成一個「角落」：

```
        process:  FF ◄─── TT ───►  SS            RC corner: RCmin ← TT → RCmax
        電壓:     0.88V ← 0.80V → 0.72V           溫度:    -40C ← 25C → 125C
                    └────────── 一個 (lib×V×T×RC) 取樣點 = 一個 CORNER ──────────┘
```

`corner_name`（第二欄，例 `000_TT`）是**報告目錄名**，也是儀表板角落欄顯示名——
它必須與實際落檔目錄**完全一致**；代號（第一欄 `000`）才是 SCENARIO 引用用的鍵。

### 2.4 SCENARIO（劇本）＝ mode × check × corner 的三元綁定

一列 SCENARIO 宣告：「<check> 在 <mode> 下，要跑這些 <corner>」。它同時翻譯成
解析層的 `STA_CORNER(<mode>,<check>)` 清單。

```
[SCENARIO] #SID  CHECK  MODE     角落矩陣（欄序＝上面 [CORNER] 的列出順序）
S001       setup  func     000  -   157 237 231
S002       setup  scan02   000  -   -   -   231
H001       hold   func     000 151  157  -  231
H002       hold   scan01   000  -   157  -  231
```

畫成 MMMC 劇本矩陣（demo 01_sta 原樣）：

```
              │ func·setup │ func·hold │ scan01·hold │ scan02·setup
──────────────┼────────────┼───────────┼─────────────┼─────────────
 000 000_TT   │     ●      │     ●     │      ●      │      ●
 151 151_ML   │     —      │     ●     │      —      │      —
 157 157_BC   │     ●      │     ●     │      ●      │      —
 237 237_WCL  │     ●      │     ●     │      —      │      ●
 231 231_WC   │     ●      │     ●     │      ●      │      ●
   ●＝在劇本內必產報告    —＝打 -（或根本沒排），頁面該角不顯示指標
```

三條鐵律：
1. **欄序即 [CORNER] 順序**：矩陣第 k 欄永遠對應 [CORNER] 第 k 行列的代號。
2. **`-` 是佔位符**，代表「這個 (mode,check) 不跑這個角落」，不是錯誤；少了 `-` 補位
   （詞元數 ≠ 角落數）會把後面所有欄位往左挤——最陰險的錯法。
3. SCENARIO 引用未定義的 mode/check/corner 時，原始解析器只印 WARNING 並**自動補
   空定義**（不會擋你）——所以名字打錯不會報錯，只會「那格永遠沒資料」。

### 2.5 VERSION（版本集）＝ 趨勢圖的時序軸

```
[VERSION]
#STA_RUN      STA_RUN_DIR          STA_RUN_GROUPS
GOLDEN-0122   reports/apr0-0122    uniq_end
GOLDEN-0123   reports/eco1-0123    uniq_end
GOLDEN-0124   reports/eco2-0124    uniq_end
;GOLDEN-0127  reports/eco3-0127    uniq_end
```

* 行序 = 時序（後＝新），決定趨勢曲線 x 軸。
* 一行可掛多個 group（`uniq_end reg2reg`）。
* 行首 `;` = **暫除名**（檔留、名單上消失；換版前確認是策略不是事故）。
* `STA_RUN` 名称 = Run 輸出目錄名 = 趨勢標籤；慣例 `GOLDEN-[階段]-[晉級日]`。

## 3. 詞法規則（與 lindex 語意完全一致）

| 規則 | 說明 |
|---|---|
| 欄位分隔 | 空白或 Tab，連續空白視為一個；欄位內不得含空白 |
| 區塊標記 | 行首可縮排，`[NAME]`，NAME **僅大寫字母**；其後文字忽略 |
| 作用範圍 | 資料列歸給「最近一次區塊標記」；重複區塊標記＝同一區塊可分散多處 |
| 註解 | `#` 開頭——**必須在第 0 欄**；`   #...` 不算註解（會被當資料列） |
| 停用作業 | `;` 出現在**行內任何位置**即切掉其後全部內容（含引號內！）；行首 `;` ＝停用整列 |
| 詞元引用 | 支援 tcl list 引用：`"a b"` 與 `{a b}` 各為單一詞元（轉換器輸出以 `{}` 包裹含空白詞元） |
| 空行 | 跳過（在首個區塊之前出現的非註解空行仍原樣保留於 .run／JSON.preamble） |

## 4. 七區塊欄位規格（本器 JSON 欄名 ≡ 工具顯示欄名）

| 區塊 | 詞元順序 | JSON 欄 | 必填 | 語意 |
|---|---|---|---|---|
| `[VERSION]` | run dir group+ | run, dir, groups[] | run, dir, ≥1 group | 版本登記；dir 僅顯示用（執行看 Makefile.run） |
| `[GROUP]` | group glob+ | group, pattern[] | group | 報告樣式：`$sta_mode/$corner_name/$sta_check.rpt*`；一個 group＝一套儀表板 |
| `[BLOCK]` | alias pattern+ | block, pattern[] | alias | 跨區塊群；匹配 `^pattern/.*`（可選） |
| `[CHECK]` | check metric+ | check, def[] | check | 趨勢角落欄指標 WNS/TNS/NVP；慣例 setup→WNS、hold→NVP |
| `[MODE]` | mode name sdc* | mode, name, def[] | mode, name | 全名僅顯示；def 常為 SDC 檔名 |
| `[CORNER]` | corner name lib… | corner, name, def[] | corner, name | name＝報告目錄名；def 通常 [lib:V:T, RC角] |
| `[SCENARIO]` | sid check mode corner\|-+ | id, check, mode, corners[] | 前三 + ≥1 欄 | MMMC 劇本列；corners 為**依 [CORNER] 欄序**的陣列 |

全區塊通用：`disabled`（JSON）⇄ 行首 `;`（.run）。

## 5. JSON（sta2htm.json）表示

```jsonc
{
  "$schema": "sta2htm.run/1",
  "sectionOrder": ["VERSION","GROUP","CHECK","MODE","CORNER","SCENARIO"],
  "preamble": ["#"],                      // 第一個區塊前的原始行逐條保留
  "sections": {
    "VERSION": [ {"run":"GOLDEN-0122","dir":"reports/apr0-0122","groups":["uniq_end"]},
                 {"run":"GOLDEN-0127","dir":"reports/eco3-0127","groups":["uniq_end"],"disabled":true} ],
    "CORNER":  [ {"corner":"000","name":"000_TT","def":["TTT:0.80V:025C","RCtyp"]}, ... ],
    "SCENARIO":[ {"id":"S001","check":"setup","mode":"func","corners":["000","-","157","237","231"]} ]
  },
  "ignored": [ {"section":"FOO","line":"…"} ]   // 原工具忽略之未知區塊行，保留資訊
}
```

還原原則：`json2run` 輸出**標準欄位標頭 + 確定性欄寬**，再經同一文法解讀必與原
語意**完全相等**（转换器 `verify` 模式自我保證；本專案並已用真實 `read_sta_runset`
對拍 16 個內部陣列逐位元組相同）。

## 6. lint 檢查清單（編輯器/轉換器共用）

| 等級 | 條件 |
|---|---|
| ERROR | 主鍵欄（run/group/…）含空白；(mode,check,corner) 欄序超出 [CORNER] 筆數且非 `-` |
| WARN | 名稱重複；SCENARIO 引用未定義 mode/check/corner；(mode,check) 重複掛劇本；`#` 前有空白；VERSION 缺 dir；corners 欄數≠角落數；未知區塊 |
| INFO | `;` 停用列保留為 disabled；preamble/ignored 逐條保留 |

## 7. 範例：demo 02_trend（含停用列）完整語意

1. `GOLDEN-0122..0125` 四版依序上趨勢軸；`GOLDEN-0127` 被 `;` 暫除（資料仍在
   `reports/eco3-0127`，戰情室需恢復時去掉 `;` 重跑 `sta_index_runset` 即可）。
2. `demo 內 dir 有兩筆顯示性錯字`（apr0-0120 / eco2-0125）：僅影響總索引 VERSION
   表顯示，執行以 `Makefile.run` 為準——**兩檔必須同步修訂**（本表第 1 大痛點）。
3. `setup→WNS、hold→NVP` 使角落格同時具「時間損失」與「違規個數」兩種判讀。

## 8. FAQ（新手最常問的五件事）

* **Q: 改了 runset 沒生效？** A: 只有 `sta_index_runset`（Runset 索引/趨勢頁）讀
  `sta2htm.run`；單版解析讀 `.sta/sta2htm.cfg`。兩邊同改、或全部重跑。
* **Q: 趨勢圖順序亂跳？** A: `[VERSION]` 行序被改動；以晉級日為唯一時序來源。
* **Q: SCENARIO 加了一個角落整列位移？** A: 缺 `-` 補位；用編輯器矩陣勾選即自動補齊。
* **Q: 角落頁面出現紅 \*？** A: 劇本排了但 `.rpt` 缺席（比 `-` 嚴重：報告要補 or 劇本要改）。
* **Q: 檔名可以自取嗎？** A: 路徑由 `sta_index_runset` 參數決定，一般維持 `sta2htm.run`
  （同目錄只能有一份生效）。

---
*本文件與 `bin/sta2htm_run_json.tcl`、`app/public/engine.js` 同步；三者以
`test/diff_harness.js` / `verify` 模式保持位元組級一致。*
