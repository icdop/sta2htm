#!/usr/bin/env tclsh
#=============================================================================
# sta2htm_run_json.tcl  v1.0  (2026)
#
# sta2htm.run  <->  sta2htm.json  雙向往回轉換器（零依賴，Tcl 8.5+）
#
# 語法依據：STA2HTM V3.0 tcl/STA_CONFIG.tcl :: read_sta_runset / parse_runset_line
# 文件：docs/grammar.md
#
# 用法：
#   tclsh sta2htm_run_json.tcl run2json <in.run>   [-o <out.json>]
#   tclsh sta2htm_run_json.tcl json2run <in.json>  [-o <out.run>]
#   tclsh sta2htm_run_json.tcl lint     <in.run>          # 驗證，WARN/ERR 列於 stderr
#   tclsh sta2htm_run_json.tcl verify   <in.run>          # 往返自洽性檢查
#
#   <in> 為 "-" 時讀 stdin；無 -o 時結果寫 stdout（WARN 走 stderr，便於管線）。
#
# 設計要點（與原始解析器的差異）：
#   * 原始解析器遇到行首 ';' 直接把該列整個丟棄；本轉換器將之保留為
#     "disabled": true 的條目，json2run 再以 ';' 寫回 —— 語義等價、資訊無損。
#   * 區塊內的註解行（第 0 欄 '#'）由工具重新生成標準欄位標頭；
#     首個區塊之前的檔案級註解（preamble）逐行原樣保留。
#=============================================================================
package require Tcl 8.5

namespace eval ::s2h {

    # ---- 七區塊的欄位定義 -------------------------------------------------
    # 每个 entry: dict {k1 v1 k2 v2 ...}；list 欄位存 Tcl list
    variable SPEC {
        VERSION  {run:str           dir:str           groups:list}
        GROUP    {group:str         pattern:list}
        BLOCK    {block:str         pattern:list}
        CHECK    {check:str         def:list}
        MODE     {mode:str          name:str          def:list}
        CORNER   {corner:str        name:str          def:list}
        SCENARIO {id:str check:str mode:str corners:list}
    }
    variable SECS [dict keys $SPEC]

    variable HEAD {
        VERSION  {#STA_RUN       STA_RUN_DIR            STA_RUN_GROUPS\n#------------- ---------------------  ------------------------------}
        GROUP    {#STA_GROUP     STA_GROUP_REPORT (glob patterns)\n#-----------  --------------------------------------------}
        BLOCK    {#BLOCK         PATTERN(S)\n#-----------  ----------------------------}
        CHECK    {#STA_CHECK     CHECK_DEF (trend metric of corner column: WNS|TNS|NVP)\n#-----------  ---------------------------------}
        MODE     {#STA_MODE      MODE_NAME         MODE_DEF (SDC...)\n#-----------  ----------------  ---------------------------}
        CORNER   {#STA_CORNER    CORNER_NAME       CORNER_DEF (lib:V:T RC ...)\n#------------  ----------------  ----------------------------------}
        SCENARIO {#SID    CHECK   MODE      CORNERS  (columns follow [CORNER] order; - = absent)\n#------   ------  --------  ---------------------------------------}
    }
    variable WARNINGS {}
    #-- JSON ------------------------------------------------------------
    proc jesc {s}    {}
    proc jstr  {s}   {}
    proc jarr  {l}   {}
    proc jread {txt} {}; # tagged: {S str} {A {v...}} {O {k v k v}} {B 0|1} {Z {}} {N num}
    #-- RUN parsing -----------------------------------------------------
    proc parse_run  {txt}      {}; # -> model dict
    proc model_norm {model}    {}  ; # canonical string for equality checks
    #-- RUN render ------------------------------------------------------
    proc render_run {model}    {}
    #-- JSON render / import -------------------------------------------
    proc render_json {model}   {}
    proc json_to_model {jtag}  {}
    #-- lint -------------------------------------------------------------
    proc lint_model {model}    {}
    #-- CLI --------------------------------------------------------------
    proc main {argv} {}
}
#=============================================================================
# JSON 極簡實作（tagged value：{S ..}/{A ..}/{O ..}/{B ..}/{Z}/{N ..}）
#=============================================================================
proc ::s2h::jstr {s} {
    regsub -all {\\} $s {\\\\} t
    regsub -all {"}  $t {\"}   t
    regsub -all {\n} $t {\\n}  t
    regsub -all {\r} $t {\\r}  t
    regsub -all {\t} $t {\\t}  t
    return "\"$t\""
}
proc ::s2h::jarr {items} {
    if {$items eq ""} {return "\[\]"}
    return "\[[join $items ", "]\]"
}
proc ::s2h::jp_skip {txtVar posVar} {
    upvar 1 $txtVar txt $posVar pos
    set n [string length $txt]
    while {$pos < $n} {
        set c [string index $txt $pos]
        if {$c eq " " || $c eq "\t" || $c eq "\n" || $c eq "\r"} {incr pos} else break
    }
}
proc ::s2h::jp_string {txtVar posVar} {
    upvar 1 $txtVar txt $posVar pos
    incr pos            ; # 跳過開頭 "
    set out "" ; set n [string length $txt]
    while {$pos < $n} {
        set c [string index $txt $pos]
        if {$c eq "\""} {incr pos; break}
        if {$c eq "\\"} {
            set e [string index $txt [expr {$pos+1}]]
            switch -exact -- $e {
                n {append out "\n"} r {append out "\r"} t {append out "\t"}
                b {append out "\b"} f {append out "\f"}
                / {append out "/"}  \" {append out "\""} \\ {append out "\\"}
                u {
                    set hex [string range $txt [expr {$pos+2}] [expr {$pos+5}]]
                    append out [format %c 0x$hex] ; incr pos 4
                }
                default {append out $e}
            }
            incr pos 2
        } else {append out $c; incr pos}
    }
    return [list S $out]
}
proc ::s2h::jp_value {txtVar posVar} {
    upvar 1 $txtVar txt
    upvar 1 $posVar pos
    jp_skip txt pos
    set n [string length $txt]
    if {$pos >= $n} {
        error "JSON: unexpected end"
    }
    set c [string index $txt $pos]
    if {$c eq "\{"} {
        return [jp_object txt pos]
    }
    if {$c eq "\["} {
        return [jp_array txt pos]
    }
    if {$c eq "\""} {
        return [jp_string txt pos]
    }
    if {[string match true* [string range $txt $pos end]]} {
        incr pos 4
        return [list B 1]
    }
    if {[string match false* [string range $txt $pos end]]} {
        incr pos 5
        return [list B 0]
    }
    if {[string match null* [string range $txt $pos end]]} {
        incr pos 4
        return [list Z {}]
    }
    set m [string range $txt $pos end]
    if {[regexp {^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?} $m -> num]} {
        incr pos [string length $num]
        return [list N $num]
    }
    error "JSON: unexpected char at offset $pos"
}
proc ::s2h::jp_object {txtVar posVar} {
    upvar 1 $txtVar txt
    upvar 1 $posVar pos
    incr pos
    set pairs {}
    jp_skip txt pos
    if {[string index $txt $pos] eq "\}"} {
        incr pos
        return [list O $pairs]
    }
    while {1} {
        jp_skip txt pos
        if {[string index $txt $pos] ne "\""} {
            error "JSON: key must be string at offset $pos"
        }
        set k [lindex [jp_string txt pos] 1]
        jp_skip txt pos
        if {[string index $txt $pos] ne ":"} {
            error "JSON: colon expected after key at offset $pos"
        }
        incr pos
        lappend pairs $k [jp_value txt pos]
        jp_skip txt pos
        set d [string index $txt $pos]
        if {$d eq ","} {
            incr pos
            continue
        }
        if {$d eq "\}"} {
            incr pos
            break
        }
        error "JSON: comma or close-brace expected at offset $pos"
    }
    return [list O $pairs]
}
proc ::s2h::jp_array {txtVar posVar} {
    upvar 1 $txtVar txt
    upvar 1 $posVar pos
    incr pos
    set items {}
    jp_skip txt pos
    if {[string index $txt $pos] eq "\]"} {
        incr pos
        return [list A $items]
    }
    while {1} {
        lappend items [jp_value txt pos]
        jp_skip txt pos
        set d [string index $txt $pos]
        if {$d eq ","} {
            incr pos
            continue
        }
        if {$d eq "\]"} {
            incr pos
            break
        }
        error "JSON: comma or close-bracket expected at offset $pos"
    }
    return [list A $items]
}
proc ::s2h::jread {txt} {
    set pos 0
    set v [jp_value txt pos]
    jp_skip txt pos
    if {$pos < [string length $txt]} {error "JSON: trailing garbage at offset $pos"}
    return $v
}

#=============================================================================
# .run 解析（鏡像 read_sta_runset/parse_runset_line，另存 disabled/未知區塊）
#=============================================================================
proc ::s2h::warn {msg} {
    variable WARNINGS
    lappend WARNINGS $msg
}
# 以 lindex 語意切詞（tcl list）；不平衡引號/大括號時退回正則切分
proc ::s2h::tokens {line} {
    if {![catch {llength $line} n]} {
        return [lrange $line 0 end]
    }
    set out {}
    set cur "" ; set mode 0; # 0 none 1 dq 2 brace
    foreach ch [split $line ""] {
        switch -exact -- $ch {
            "\\"" { if {$mode==0} {set mode 1} elseif {$mode==1} {set mode 0} else {append ch} }
            "\}"  { if {$mode==2} {set mode 0} ; append cur $ch }
            "\{"  { if {$mode==0} {set mode 2} ; append cur $ch }
            " " - "\t" {
                if {$mode == 0} { if {$cur ne ""} {lappend out $cur; set cur ""} } else {append cur $ch}
            }
            default { append cur $ch }
        }
    }
    if {$cur ne ""} {lappend out $cur}
    return $out
}
proc ::s2h::parse_run {txt} {
    variable SECS
    set model [dict create preamble {} order {} sections {} ignored {} source {}]
    set sec ""
    set lines [split $txt "\n"]
    set ln 0
    foreach raw $lines {
        incr ln
        # 1) 停用列：行首（允許縮排）';' → 原始解析器丟棄整列；我們保留為 disabled 條目
        if {[regexp {^(\s*);(.*)$} $raw -> ind rest]} {
            set body [string trim $rest]
            if {$body eq "" || [string match "#*" $body]} {
                if {$sec eq "" && $body ne "" && [string match "#*" $body]} {
                    dict lappend model preamble $raw
                }
                continue
            }
            set toks [tokens $body]
            if {[llength $toks] < 2} {
                # 僅一個詞元的 ';xxx' 視為行級註解（與原工具丟棄行為等價）
                continue
            }
            if {$sec eq ""} {
                dict lappend model ignored [dict create section "" line $raw ln $ln]
                continue
            }
            if {[lsearch -exact $SECS $sec] < 0} {
                dict lappend model ignored [dict create section $sec line $raw ln $ln]
                continue
            }
            set e [entry_from_tokens $sec $toks]
            if {$e eq ""} {dict lappend model ignored [dict create section $sec line $raw ln $ln]; continue}
            dict set e disabled 1
            append_entry model $sec $e
            continue
        }
        # 2) 原 regsub：行內 ';' 起切尾
        set line $raw
        regsub {\;.*$} $line {} line
        # 3) 空行
        if {[regexp {^\s*$} $line]} {
            if {$sec eq "" && $raw ne ""} {dict lappend model preamble $raw}
            continue
        }
        # 4) 第 0 欄註解
        if {[string match "#*" $line]} {
            if {$sec eq ""} {dict lappend model preamble $raw}
            continue
        }
        if {[regexp {^\s+#} $line]} {
            warn "WARN  L$ln: '#' 前有空白——原始解析器會把它當資料列；本器視為註解（建議 # 置第 0 欄）"
            continue
        }
        # 5) 區塊標記
        if {[regexp {^\s*\[([A-Z]+)\]} $line -> s]} {
            set sec $s
            if {[lsearch -exact [dict get $model order] $sec] < 0 && [lsearch -exact $SECS $sec] >= 0} {
                dict lappend model order $sec
            }
            if {![dict exists $model sections $sec]} {dict set model sections $sec {}}
            continue
        }
        # 6) 資料列
        if {$sec eq ""} {
            warn "WARN  L$ln: 任何區塊之前出現資料列，原始解析器忽略——保留於 ignored"
            dict lappend model ignored [dict create section "" line $raw ln $ln]
            continue
        }
        if {[lsearch -exact $SECS $sec] < 0} {
            warn "WARN  L$ln: 未知區塊 \[$sec\] 的資料列，原始解析器忽略"
            dict lappend model ignored [dict create section $sec line $raw ln $ln]
            define_missing_section_block $model $sec $ln
            continue
        }
        set toks [tokens $line]
        set e [entry_from_tokens $sec $toks]
        if {$e ne ""} {append_entry model $sec $e}
    }
    return $model
}
proc ::s2h::append_entry {modelVar sec e} {
    upvar 1 $modelVar model
    dict set model sections $sec [concat [dict get $model sections $sec] [list $e]]
}
# 未定義區塊名（如 [EXTRA]）：於 order 保留佔位，資料列進 ignored
proc ::s2h::define_missing_section_block {modelVar sec ln} {}
#=============================================================================
# lint / 正規化 / run 輸出
#=============================================================================
proc ::s2h::secfields {sec} {
    variable SPEC
    set out {}
    foreach kv [dict get $SPEC $sec] { lappend out [lindex [split $kv ":"] 0] }
    return $out
}
proc ::s2h::entry_from_tokens {sec toks} {
    set n [llength $toks]
    set e [dict create]
    switch -exact -- $sec {
        VERSION {
            if {$n < 1} {return ""}
            dict set e run [lindex $toks 0]
            dict set e dir [expr {$n >= 2 ? [lindex $toks 1] : ""}]
            if {$n < 2} {warn "WARN  \[VERSION\] 缺 STA_RUN_DIR 欄：$toks"}
            dict set e groups [lrange $toks 2 end]
        }
        GROUP    { if {$n < 1} {return ""}
                   dict set e group [lindex $toks 0]; dict set e pattern [lrange $toks 1 end] }
        BLOCK    { if {$n < 1} {return ""}
                   dict set e block [lindex $toks 0]; dict set e pattern [lrange $toks 1 end] }
        CHECK    { if {$n < 1} {return ""}
                   dict set e check [lindex $toks 0]; dict set e def [lrange $toks 1 end] }
        MODE     { if {$n < 1} {return ""}
                   dict set e mode [lindex $toks 0]
                   dict set e name [expr {$n >= 2 ? [lindex $toks 1] : [lindex $toks 0]}]
                   dict set e def [lrange $toks 2 end] }
        CORNER   { if {$n < 1} {return ""}
                   dict set e corner [lindex $toks 0]
                   dict set e name [expr {$n >= 2 ? [lindex $toks 1] : [lindex $toks 0]}]
                   dict set e def [lrange $toks 2 end] }
        SCENARIO {
            if {$n < 3} {warn "WARN  \[SCENARIO\] 詞元不足（需 id check mode）：$toks"; return ""}
            dict set e id [lindex $toks 0]; dict set e check [lindex $toks 1]
            dict set e mode [lindex $toks 2]; dict set e corners [lrange $toks 3 end]
        }
        default { return "" }
    }
    return $e
}
#=============================================================================
# 語義 lint（與轉換共用；結果走 stderr）
#=============================================================================
proc ::s2h::lint_model {model} {
    variable SECS
    set corners {}
    if {[dict exists $model sections CORNER]} {
        foreach e [dict get $model sections CORNER] {lappend corners [dict get $e corner]}
    }
    set modes {} ; set checks {}
    if {[dict exists $model sections MODE]}  {foreach e [dict get $model sections MODE]  {lappend modes  [dict get $e mode]}}
    if {[dict exists $model sections CHECK]} {foreach e [dict get $model sections CHECK] {lappend checks [dict get $e check]}}
    foreach sec $SECS {
        if {![dict exists $model sections $sec]} continue
        set key [lindex [secfields $sec] 0]
        set names {}
        foreach e [dict get $model sections $sec] {
            set nm [dict get $e $key]
            if {[lsearch -exact $names $nm] >= 0} {
                warn "WARN  \[$sec\] 名稱重複：$key=$nm"
            }
            lappend names $nm
        }
    }
    if {[dict exists $model sections SCENARIO]} {
        set pairs {}
        foreach e [dict get $model sections SCENARIO] {
            set id [dict get $e id]; set m [dict get $e mode]; set c1 [dict get $e check]
            if {$m ne "" && [lsearch -exact $modes $m] < 0} {
                warn "WARN  Scenario $id: mode '$m' 未在 \[MODE\] 定義（原始解析器會自動補空定義）"
            }
            if {$c1 ne "" && [lsearch -exact $checks $c1] < 0} {
                warn "WARN  Scenario $id: check '$c1' 未在 \[CHECK\] 定義"
            }
            set key "$m,$c1"
            if {[lsearch -exact $pairs $key] >= 0} {
                warn "WARN  \[SCENARIO\] $key 被多列使用——後列覆蓋 STA_CORNER\[$key\]"
            }
            lappend pairs $key
            foreach cc [dict get $e corners] {
                if {$cc ne "-" && [llength $corners] > 0 && [lsearch -exact $corners $cc] < 0} {
                    warn "WARN  Scenario $id 引用未定義角落 '$cc'（原始解析器會自動補定義並印 WARNING）"
                }
            }
            if {[llength $corners] > 0 && [llength [dict get $e corners]] != [llength $corners]} {
                warn "WARN  Scenario $id corners 欄數 [llength [dict get $e corners]] ≠ \[CORNER\] 筆數 [llength $corners]（欄序以 \[CORNER\] 定義為準）"
            }
        }
    }
    return ""
}
#=============================================================================
# 模型正規化 / render .run
#=============================================================================
proc ::s2h::norm_entry {sec e} {
    set r $sec
    foreach k [secfields $sec] {append r "|$k=[join [dict get $e $k] \x01]"}
    if {[dict exists $e disabled] && [dict get $e disabled]} {append r "|DISABLED"}
    return $r
}
proc ::s2h::model_norm {model} {
    variable SECS
    set s ""
    foreach sec $SECS {
        if {![dict exists $model sections $sec]} continue
        foreach e [dict get $model sections $sec] {append s "[norm_entry $sec $e]\n"}
    }
    append s "preamble=[llength [dict get $model preamble]]"
    return $s
}
proc ::s2h::fmt_tok {t} {
    if {![regexp {\s} $t]} {return $t}
    return "\{$t\}"
}
proc ::s2h::join_fmt {lst} {
    set o {}
    foreach t $lst {lappend o [fmt_tok $t]}
    return [join $o " "]
}
proc ::s2h::render_entry {sec e} {
    set dis ""
    if {[dict exists $e disabled] && [dict get $e disabled]} {set dis ";"}
    switch -exact -- $sec {
        VERSION  {set l [format {%-14s %-22s %s} [dict get $e run] [dict get $e dir] [join_fmt [dict get $e groups]]]}
        GROUP    {set l [format {%-14s %s}  [dict get $e group] [join_fmt [dict get $e pattern]]]}
        BLOCK    {set l [format {%-14s %s}  [dict get $e block] [join_fmt [dict get $e pattern]]]}
        CHECK    {set l [format {%-14s %s}  [dict get $e check] [join_fmt [dict get $e def]]]}
        MODE     {set l [format {%-14s %-16s %s} [dict get $e mode] [dict get $e name] [join_fmt [dict get $e def]]]}
        CORNER   {set l [format {%-14s %-16s %s} [dict get $e corner] [dict get $e name] [join_fmt [dict get $e def]]]}
        SCENARIO {set l [format {%-7s %-7s %-9s} [dict get $e id] [dict get $e check] [dict get $e mode]]
                   foreach cc [dict get $e corners] { append l " [format {%-4s} [fmt_tok $cc]]" } }
        default  {set l ""}
    }
    return [string trimright "$dis$l"]
}
proc ::s2h::render_run {model} {
    variable HEAD
    variable SECS
    set out {}
    foreach l [dict get $model preamble] {lappend out $l}
    set order [dict get $model order]
    set final {}
    foreach s $order {if {[lsearch -exact $SECS $s] >= 0 && [lsearch -exact $final $s] < 0} {lappend final $s}}
    foreach s $SECS {if {[dict exists $model sections $s] && [lsearch -exact $final $s] < 0} {lappend final $s}}
    foreach sec $final {
        set rows [dict get $model sections $sec]
        if {$out ne ""} {lappend out ""}
        lappend out "\[$sec\]"
        foreach h [split [string map [list {\n} "\n"] [dict get $HEAD $sec]] "\n"] {lappend out $h}
        foreach e $rows {lappend out [render_entry $sec $e]}
    }
    set ig [dict get $model ignored]
    if {$ig ne "" && [llength $ig]} {
        if {$out ne ""} {lappend out ""}
        lappend out "# --- unrecognized lines (kept verbatim; parsers ignore) ---"
        foreach g $ig {
            set sec [dict get $g section]
            lappend out "# !! [expr {$sec ne "" ? "\[$sec\] " : ""}][dict get $g line]"
        }
    }
    return [join $out "\n"]
}
#=============================================================================
# render JSON / parse JSON -> model
#=============================================================================
proc ::s2h::field_types {sec} {
    variable SPEC
    set d {}
    foreach kv [dict get $SPEC $sec] {
        lassign [split $kv ":"] k t
        lappend d $k $t
    }
    return $d
}
proc ::s2h::json_entry {sec e} {
    set types [field_types $sec]
    set parts {}
    dict for {k ty} $types {
        if {![dict exists $e $k]} continue
        set v [dict get $e $k]
        if {$ty eq "str"} {
            lappend parts "\"$k\": [jstr $v]"
        } else {
            set items {}
            foreach t $v { lappend items [jstr $t] }
            lappend parts "\"$k\": \[[join $items ", "]\]"
        }
    }
    if {[dict exists $e disabled] && [dict get $e disabled]} {
        lappend parts "\"disabled\": true"
    }
    return "{ [join $parts ", "] }"
}
proc ::s2h::render_json {model} {
    variable SECS
    set final {}
    foreach s [dict get $model order] {
        if {[lsearch -exact $SECS $s] >= 0 && [lsearch -exact $final $s] < 0} {lappend final $s}
    }
    foreach s $SECS {
        if {[dict exists $model sections $s] && [lsearch -exact $final $s] < 0} {lappend final $s}
    }
    set t "\{\n"
    append t "  \"\$schema\": \"sta2htm.run/1\",\n"
    append t "  \"generator\": \"sta2htm_run_json.tcl/1.0\",\n"
    set src [dict get $model source]
    if {$src ne ""} { append t "  \"source\": [jstr $src],\n" }
    set os {} ; foreach s $final { lappend os [jstr $s] }
    append t "  \"sectionOrder\": \[[join $os ", "]\],\n"
    set ps {} ; foreach l [dict get $model preamble] { lappend ps [jstr $l] }
    append t "  \"preamble\": \[[join $ps ", "]\],\n"
    append t "  \"sections\": "
    set blocks {}
    foreach sec $final {
        set rows [dict get $model sections $sec]
        if {[llength $rows] == 0} { continue }
        set elines {}
        foreach e $rows { lappend elines "      [json_entry $sec $e]" }
        lappend blocks "  [jstr $sec]: \[\n[join $elines ",\n"]\n    \]"
    }
    if {[llength $blocks] == 0} {
        append t "\{\}\n"
    } else {
        append t "\{\n"
        append t [join $blocks ",\n"]
        append t "\n  \}"
    }
    set ig [dict get $model ignored]
    if {[llength $ig]} {
        append t ",\n  \"ignored\": \[\n"
        set glines {}
        foreach g $ig {
            lappend glines "    { \"section\": [jstr [dict get $g section]], \"line\": [jstr [dict get $g line]] }"
        }
        append t [join $glines ",\n"]
        append t "\n  \]"
    }
    append t "\n\}"
    return $t
}
# tagged value helpers
proc ::s2h::v_str {tv} {
    lassign $tv t v
    if {$t eq "S" || $t eq "N"} {return $v}
    if {$t eq "Z"} {return ""}
    error "expected string, got $t"
}
proc ::s2h::json_to_model {tag} {
    variable SECS
    if {[lindex $tag 0] ne "O"} {error "top-level JSON must be an object"}
    set d [lindex $tag 1]
    if {[dict exists $d \$schema]} {
        set sch [v_str [dict get $d \$schema]]
        if {$sch ne "sta2htm.run/1"} {warn "WARN  \$schema=$sch（預期 sta2htm.run/1），仍嘗試解析"}
    }
    set model [dict create preamble {} order {} sections {} ignored {} source {}]
    if {[dict exists $d source]} {dict set model source [v_str [dict get $d source]]}
    if {[dict exists $d sectionOrder]} {
        foreach tv [lindex [dict get $d sectionOrder] 1] {
            set s [v_str $tv]
            if {[lsearch -exact $SECS $s] >= 0 && [lsearch -exact [dict get $model order] $s] < 0} {
                dict lappend model order $s
            }
        }
    }
    if {[dict exists $d preamble]} {
        if {[lindex [dict get $d preamble] 0] ne "A"} {error "preamble must be array"}
        foreach tv [lindex [dict get $d preamble] 1] {dict lappend model preamble [v_str $tv]}
    }
    if {![dict exists $d sections]} {error "missing \"sections\""}
    if {[lindex [dict get $d sections] 0] ne "O"} {error "\"sections\" must be object"}
    set sd [lindex [dict get $d sections] 1]
    dict for {sec rowsTag} $sd {
        if {[lsearch -exact $SECS $sec] < 0} {
            warn "WARN  忽略未知區塊 \"sections.$sec\""
            continue
        }
        if {[lindex $rowsTag 0] ne "A"} {error "sections.$sec must be array"}
        dict set model sections $sec {}
        if {[lsearch -exact [dict get $model order] $sec] < 0} {dict lappend model order $sec}
        set types [field_types $sec]
        foreach eTag [lindex $rowsTag 1] {
            if {[lindex $eTag 0] ne "O"} {error "sections.$sec row must be object"}
            set ed [lindex $eTag 1]
            set e [dict create]
            dict for {k ty} $types {
                if {![dict exists $ed $k]} {
                    if {$ty eq "str"} { dict set e $k "" } else { dict set e $k {} }
                    continue
                }
                set tv [dict get $ed $k]
                if {$ty eq "str"} {
                    dict set e $k [v_str $tv]
                } else {
                    if {[lindex $tv 0] ne "A"} {error "sections.$sec.$k must be array"}
                    set items {}
                    foreach itv [lindex $tv 1] { lappend items [v_str $itv] }
                    dict set e $k $items
                }
            }
            if {[dict exists $ed disabled]} {
                set b [lindex [dict get $ed disabled] 1]
                if {$b} {dict set e disabled 1}
            }
            dict set model sections $sec [concat [dict get $model sections $sec] [list $e]]
        }
    }
    if {[dict exists $d ignored]} {
        if {[lindex [dict get $d ignored] 0] eq "A"} {
            foreach gTag [lindex [dict get $d ignored] 1] {
                if {[lindex $gTag 0] ne "O"} continue
                set gd [lindex $gTag 1]
                dict lappend model ignored [dict create section [v_str [dict get $gd section]] line [v_str [dict get $gd line]]]
            }
        }
    }
    return $model
}
#=============================================================================
# CLI
#=============================================================================
proc ::s2h::usage {{code 2}} {
    puts stderr "usage: tclsh sta2htm_run_json.tcl \\
        { run2json <in.run|->  [-o out.json] | \\
          json2run <in.json|-> [-o out.run]  | \\
          lint <in.run> | verify <in.run> }"
    exit $code
}
proc ::s2h::read_any {f} {
    if {$f eq "-"} {
        fconfigure stdin -encoding utf-8 -translation lf
        return [read stdin]
    }
    if {![file exists $f]} { puts stderr "ERROR: no such file: $f"; exit 2 }
    set fh [open $f r]; fconfigure $fh -encoding utf-8 -translation lf
    set t [read $fh]; close $fh
    return $t
}
proc ::s2h::write_out {out text} {
    if {$out eq ""} { puts $text; return }
    set fh [open $out w]; fconfigure $fh -encoding utf-8 -translation lf
    puts $fh $text; close $fh
    puts stderr "INFO: wrote $out"
}
proc ::s2h::flush_warn {} {
    variable WARNINGS
    foreach w $WARNINGS { puts stderr $w }
}
proc ::s2h::main {argv} {
    variable WARNINGS
    set WARNINGS {}
    if {[llength $argv] < 2} {usage}
    set mode [lindex $argv 0]
    set in ""; set out ""
    set args [lrange $argv 1 end]
    while {[llength $args]} {
        set a [lindex $args 0]
        if {$a in [list "-o" "--out"]} {
            if {[llength $args] < 2} {usage}
            set out [lindex $args 1]; set args [lrange $args 2 end]
        } elseif {$in eq ""} {
            set in $a; set args [lrange $args 1 end]
        } else { usage }
    }
    if {$in eq ""} {usage}
    if {$mode eq "run2json"} {
        set m [parse_run [read_any $in]]
        dict set m source [file tail [expr {$in eq "-" ? "stdin" : $in}]]
        lint_model $m
        write_out $out [render_json $m]
        flush_warn
    } elseif {$mode eq "json2run"} {
        set m [json_to_model [jread [read_any $in]]]
        lint_model $m
        write_out $out [render_run $m]
        flush_warn
    } elseif {$mode eq "lint"} {
        set m [parse_run [read_any $in]]
        lint_model $m
        flush_warn
        variable WARNINGS
        exit [expr {[llength $WARNINGS] ? 1 : 0}]
    } elseif {$mode eq "verify"} {
        set txt [read_any $in]
        set m1 [parse_run $txt]
        set firstWarn [expr {[llength $::s2h::WARNINGS] ? $::s2h::WARNINGS : {}}]
        set r1 [render_run $m1]
        set m2 [parse_run $r1]
        set ok1 [expr {[model_norm $m1] eq [model_norm $m2]}]
        set m3 [json_to_model [jread [render_json $m1]]]
        set ok2 [expr {[model_norm $m1] eq [model_norm $m3]}]
        puts stderr "verify run->run    : [expr {$ok1 ? "PASS" : "FAIL"}]"
        puts stderr "verify run->json->run: [expr {$ok2 ? "PASS" : "FAIL"}]"
        set ::s2h::WARNINGS $firstWarn
        flush_warn
        exit [expr {($ok1 && $ok2) ? 0 : 3}]
    } else { usage }
}
::s2h::main $argv
