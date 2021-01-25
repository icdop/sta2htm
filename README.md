# Static Timing Analysis Report Reviewer

## 0) Pre-requirement

+ install <code>tree</code> packages.
+ install <code>gnuplot</code> packages.
+ geneate STA reports from PrimeTime: 
  <code>$STA_RPT/$sta_mode/$sta_corner/$sta_check/violation.rpt</code>

## 1) Specify HTML report dir name and STA report path

+ <code> % cd 01-sta </code>
<pre>
01_sta
├── Makefile
├── README.md
└── reports -> ../reports
</pre>
<pre>
reports
├── apr0-0122
├── eco1-0123
└── eco2-0124
</pre>

+ <code> % vi Makefile </code>
<pre>
STA_RUN  := GOLDEN-0122
STA_RPT  := ../reports/apr0-0122
</pre>

The followin directory structure is recommeded for MMMC STA reports
<pre>
apr0-0122/
├── func
│   ├── 000_TT
│   │   ├── hold.rpt
│   │   └── setup.rpt
│   ├── 151_ML
│   │   └── hold.rpt
│   ├── 157_BC
│   │   ├── hold.rpt
│   │   └── setup.rpt
│   ├── 231_WCL
│   │   └── setup.rpt
│   └── 258_WC
│       ├── hold.rpt
│       └── setup.rpt
└── scan
    ├── 000_TT
    │   ├── hold.rpt
    │   └── setup.rpt
    └── 157_BC
        └── hold.rpt
</pre>

## 2) Initialize working directory environment

+ <code> % sta_init GOLDEN-0122 ../reports/GOLDEN-0122</code>

<pre>
Usage: sta_init_dir [$STA_RUN] [$STA_RPT]
</pre>

The follow csh commands will be executed by stat_init_dir
<pre>
# mkdir GOLDEN-0122
# cd GOLDEN-0122
# cp -fr  $(STA_RPT)/.sta .sta
# cp $(ETC_DIR)/sta/Makefile Makefile
# ln -s   $(STA_RPT)  STA
</pre>

## 3) Modify timing signoff corner definition table

+ <code> % vi GOLDEN-0122/.sta/sta2htm.corner </code>

<pre>
000	000_TT
151	151_ML
157	157_BC
231	231_WCL
258	258_WC
</pre>

## 4) Modify sta report filtering configuration file

+ <code> % vi GOLDEN_0122/.sta/sta2htm.cfg </code>

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

## 5) Generate HTML reports from Pretime STA timing reports

+ <code> % cd GOLDEN-0122 </code>
+ <code> % sta_rpt_uniq_end -sta_check setup </code>
+ <code> % sta_rpt_uniq_end -sta_check hold </code>

<pre>
$STA_RPT_PATH/$STA_RPT_FILE (violation.rpt) : Primetime report

# $STA_SUM_DIR/$sta_check.htm
# $STA_SUM_DIR/$sta_mode/$sta_check.htm
# $STA_SUM_DIR/$sta_mode/$sta_check.nvp_wns.dat
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.vio
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.clk
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.nvp
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.sum
</pre>

## 6) Geneare STA2HM home page index file
+ <code> % sta_gen_index </code>

<pre>
# $STA_SUM_DIR/index.htm
# $STA_SUM_DIR/$sta_mode/index.htm
# $STA_SUM_DIR/$sta_mode/mode.htm
# $STA_SUM_DIR/$sta_mode/check.htm
# $STA_SUM_DIR/$sta_mode/corner.htm
...
</pre>

## 7) Review STA summary report through browser

+ <code> % make view </code>
+ <code> % firefox $(STA_RUN)/index.htm </code>

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
