# Static Timing Report Reviewer

## 1) Specify database dir name and STA report path

<code> % vi Makefile </code>

<pre>
ORIG := GOLDEN_0623
CURR := GOLDEN_0624
STA  := /projects/xxxx/FrontendDb/.../stasi/
</pre>

## 2) Initialize current working directory environment

<code> % $(STA_HOME)/bin/sta_init GOLDEN_0624</code>

<pre>
# mkdir GOLDEN_0624 
# cd GOLDEN_0624/
# cp -fr  $(STA_HOME)/etc/sta/ .sta
# ln -s   .sta/Makefile.sta Makefile
</pre>

<code> % cd GOLDEN_0624 </code>

## 3) Modify timing signoff corner definition table

<code> % vi .sta/sta.corner </code>

<pre>
000_TT_typical_85
111_LT_Cbest
121_BC_Cbest
151_ML_Cbest
213_WCL_Cworst
253_WC_Cworst
349_TT_derate_85
</pre>

## 4) Modify sta report filtering configuration file

<code> % vi .sta/sta.cfg </code>

<pre>
# STA report filename filter : $STA_RPT_PATH/$STA_RPT_FILE
set STA_RPT_PATH {$sta_mode/$corner_name}
set STA_RPT_FILE {$sta_check$sta_postfix.rpt*}

# STA mode name list
set STA_MODE_LIST "func dc_shift ac_capture"

# STA scenario table ($sta_mode,$sta_check) => "$sta_corner ...."
set STA_CORNER(func,setup) "000 111 253 349"
set STA_CORNER(ac_capture,setup) "000 111 253 349"
set STA_CORNER(func,hold) "000 111 253 349"
set STA_CORNER(dc_shift,hold) "000 111 253 349"
</pre>

## 5) Extract quality factor from sta timing report

<code> % sta_uniq_end -sta_check setup </code>

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
