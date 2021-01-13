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
PREV_RUN := GOLDEN_0623
CURR_RUN := GOLDEN_0624
STA_RPT  := /projects/xxxx/sta/report
</pre>

## 2) Initialize working directory environment

+ <code> % sta_init GOLDEN_0624 --PREV GOLDEN_0623 --STA /projects/xxxx/sta/report</code>

<pre>
Usage: sta_init [$CURR_RUN]
    --PREV $PREV_RUN
    --STA  $STA_RPT
</pre>

<pre>
# mkdir GOLDEN_0624 
# cd GOLDEN_0623
# cp -fr  $ETC_DIR/sta/ .sta
# ln -s   .sta/Makefile.sta Makefile
# ln -s   $PREV_RUN PREV
# ln -s   $STA_RPT  STA
</pre>

## 3) Modify timing signoff corner definition table

+ <code> % vi GOLDEN_0624/.sta/sta.corner </code>

<pre>
000_TT
111_LT
121_BC
151_ML
213_WCL
253_WC
</pre>

## 4) Modify sta report filtering configuration file

+ <code> % vi GOLDEN_0624/.sta/sta.cfg </code>

<pre>
# STA report filename filter : $STA_RPT_PATH/$STA_RPT_FILE
set STA_RPT_PATH {$sta_mode/$corner_name}
set STA_RPT_FILE {$sta_check$sta_postfix.rpt*}

# STA mode name list
set STA_MODE_LIST "func dc_shift ac_capture"

# STA scenario table ($sta_mode,$sta_check) => "$sta_corner ...."
set STA_CORNER(func,setup) "000 121 253"
set STA_CORNER(scan,setup) "000 121"
set STA_CORNER(func,hold)  "000 111 121 151 213 253"
set STA_CORNER(scan,hold)  "000 111 121 151"
</pre>

## 5) Extract quality factor from sta timing report

+ <code> % cd GOLDEN_0624 </code>
+ <code> % sta_uniq_end -sta_check setup </code>

<pre>
$STA_RPT_PATH/$STA_RPT_FILE (setup.rpt) : PT timing report
=> generate_vio_endpoint
=> parse_timing_report
# $STA_SUM_DIR/$sta_mode/$sta_check.htm
# $STA_SUM_DIR/$sta_mode/$sta_check.nvp_wns.dat
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.vio
#
=> report_slack_summary $sta_mode $sta_check/$corner_name
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.clk
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.nvp
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.sum
</pre>

## 6) Review STA summary report through browser

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
