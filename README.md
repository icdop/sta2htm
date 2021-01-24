# Static Timing Analysis HTML Report Reviewer
## 0) Pre-requirement

+ install <code>tree</code> packages.
+ install <code>gnuplot</code> packages.
+ geneate STA reports from PrimeTime: 
  <code>$STA_RPT/$sta_mode/$sta_corner/$sta_check/all_violation.rpt</code>

## 1) Specify HTML report dir name and STA report path

+ <code> % cd run/01-sta/ </code>
+ <code> % vi Makefile </code>

<pre>
CURR_RUN := GOLDEN_0122
STA_RPT  := /projects/xxxx/sta/report
</pre>

## 2) Initialize working directory environment

+ <code> % sta_init GOLDEN_0122 /projects/xxxx/sta/report</code>

<pre>
Usage: sta_init [$STA_RUN] [STA_RPT]
</pre>

<pre>
# mkdir GOLDEN_0122
# cd GOLDEN_0122
# cp -fr  $(STA_RPT)/.sta .sta
# cp $(ETC_DIR)/sta/Makefile Makefile
# ln -s   $(STA_RPT)  STA
</pre>

## 3) Modify timing signoff corner definition table

+ <code> % vi GOLDEN_0122/.sta/sta.corner </code>

<pre>
000	000_TT
151	151_ML
157	157_BC
231	231_WCL
258	258_WC
</pre>

## 4) Modify sta report filtering configuration file

+ <code> % vi GOLDEN_0122/.sta/sta.cfg </code>

<pre>
# STA report filename filter : $STA_RPT_PATH/$STA_RPT_FILE
set STA_RPT_PATH {$sta_mode/$corner_name}
set STA_RPT_FILE {$sta_check$sta_postfix.rpt*}

# STA mode name list
set STA_MODE_LIST "func scan"

# STA scenario table ($sta_mode,$sta_check) => "$sta_corner ...."
set STA_CORNER(func,setup) "000 157 231 258"
set STA_CORNER(func,hold)  "000 151 157 258"
set STA_CORNER(scan,setup) "000 157"
set STA_CORNER(scan,hold)  "000 157 258"
</pre>

## 5) Extract quality factor from sta timing report

+ <code> % cd GOLDEN_0122 </code>
+ <code> % sta_rpt_uniq_end -sta_check setup </code>

<pre>
$STA_RPT_PATH/$STA_RPT_FILE (setup.rpt) : PT timing report

# $STA_SUM_DIR/$sta_check.htm
# $STA_SUM_DIR/$sta_mode/$sta_check.htm
# $STA_SUM_DIR/$sta_mode/$sta_check.nvp_wns.dat
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.vio
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.clk
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.nvp
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.sum
</pre>

+ <code> % sta_rpt_uniq_end -sta_check hold </code>

<pre>
...
</pre>

## 6) Review STA report index.htm
+ <code> % sta_gen_index </code>

## 7) Review STA summary report through browser

+ <code> % make view </code>

<pre>
uniq_end/
├── func
│   ├── setup
│   │   ├── 000_TT.blk.htm
│   │   ├── 000_TT.clk.htm
│   │   ├── 121_BC.blk.htm
│   │   ├── 121_BC.clk.htm
│   │   ├── 253_WC.blk.htm
│   │   └── 253_WC.clk.htm
│   ├── index.htm
│   ├── setup.blk.htm
│   ├── setup.clk.htm
│   ├── setup.htm
│   └── setup.uniq_end.htm
├── scan
│   ├── setup
│   │   ├── 000_TT.blk.htm
│   │   ├── 000_TT.clk.htm
│   │   ├── 121_BC.blk.htm
│   │   └── 121_BC.clk.htm
│   ├── index.htm
│   ├── setup.blk.htm
│   ├── setup.clk.htm
│   ├── setup.htm
│   └── setup.uniq_end.htm
├── corner.htm
├── index.htm                   <-- (Summary Report Home Page)
├── mode.htm
├── setup.diff.htm
├── setup.full.htm
└── setup.htm
</prev>
