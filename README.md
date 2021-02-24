# Static Timing Analysis HTML Reviewer

## 0) System Requirements

+ install <code>tree</code> packages.
+ install <code>gnuplot</code> packages.

## 1) Edit Runset defintion file [sta2htm.run]
<pre>
#
[VERSION]
#STA_RUN	STA_RUN_DIR            STA_RUN_GROUPS
#-------------	---------------------  ----------------
GOLDEN-0122	reports/apr0-0120      uniq_end
GOLDEN-0123	reports/eco1-0123      uniq_end
GOLDEN-0124	reports/eco2-0124      uniq_end
GOLDEN-0125	reports/eco2-0125      uniq_end
;GOLDEN-0127	reports/eco3-0127      uniq_end

[GROUP]
#STA_GROUP   STA_GROUP_FILES
#---------   -----------------------------------------------
uniq_end     $sta_mode/$corner_name/$sta_check.rpt

[CHECK]
#STA_CHECK   STA_CHECK_DEF
#----------- -------------------
setup		WNS        
hold            NVP

[MODE]
#STA_MODE     STA_MODE_NAME     STA_MODE_DEF
#-----------  ----------------- -------------------
func          functional        func_0210.sdc
scan01        dc_shift          scan_0211.sdc
scan02        ac_capture        scan_0221.sdc

[CORNER]
#STA_CORNER    STA_CORNER_NAME    STA_CORNER_DEF
#------------  ---------------    ------------------------ ----------
000            000_TT             TTT:0.80V:025C  RCtyp
151            151_ML             FFG:0.88V:125C  Cmax
157            157_BC             FFF:0.88V:-40C  Cmin
231            231_WCL            SSG:0.72V:-40C  Cmax
258            258_WC             SSG:0.72V:125C  Cmax

[SCENARIO]
#SID    CHECK   MODE	CORNERS
#-----	------	------- --------------------
S001    setup   func	000 -   157 231 258
S002    setup	scan02	000 -   -   -   258
H001    hold	func	000 151 157 -   258
H002    hold	scan01	000 -   157 -   258
</pre>

![run/02_trend/screenshot/sta2htm_runset.jpeg](./run/02_trend/screenshot/sta2htm_runset.jpeg?raw=true)


## 2) Specify STA report path

+ geneate STA reports from PrimeTime: 

The followin directory structure is recommeded for MMMC STA reports
  <code>$STA_RPT/$sta_mode/$sta_corner/$sta_check/violation.rpt</code>
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

## 3) Initialize working directory environment

<pre>
Usage: sta_init_run [STA_RUN] [STA_RUN_DIR] [STA_RUN_GROUPS]...
</pre>

Example:
+ <code> % sta_init_dir GOLDEN-0122 reports/GOLDEN-0122  uniq_end reg2reg</code>

[Makefile.run]
<pre>
STA_RUN     := GOLDEN-0122
STA_RUN_DIR.GOLDEN-0122 := reports/apr0-0122
STA_RUN_GROUPS.GOLDEN-0122 := detail uniq_end
</pre>

[Makefile]
<pre>
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
	@for i in $(STA_RUN); do ( \
	  cd $$i; make index ; \
	) ; done
	sta_index_runset
	
</pre>

## 4) Review sta2htm configuration file

+ <code> % vi GOLDEN_0122/.sta/sta2htm.cfg </code>

<pre>
set STA_RPT_FILE {$sta_mode/$corner_name/$sta_check.rpt*}

# STA mode name list
set STA_MODE_LIST "func scan"

# STA scenario table ($sta_mode,$sta_check) => "$sta_corner ...."
set STA_CORNER(func,setup) "000 157 231 258"
set STA_CORNER(func,hold)  "000 151 157 258"
set STA_CORNER(scan,setup) "000 157"
set STA_CORNER(scan,hold)  "000 157 258"
</pre>

+ <code> % vi GOLDEN-0122/.sta/sta2htm.corner </code>

<pre>
000	000_TT
151	151_ML
157	157_BC
231	231_WCL
258	258_WC
</pre>


## 5) Generate STA HTML Summary reports

+ <code> % cd GOLDEN-0122 </code>
+ <code> % make run </code>

+ <code> (GOLDEN-0122) sta_uniq_end -sta_group $sta_group </code>

<pre>
# $sta_group/$sta_cck.htm
# $sta_group/$sta_mode/$sta_check.htm
# $sta_group/$sta_mode/$sta_check.nvp_wns.dat
# $sta_group/$sta_mode/$sta_corner/$sta_check.vio
# $sta_group/$sta_mode/$sta_corner/$sta_check.clk
# $sta_group/$sta_mode/$sta_corner/$sta_check.nvp
# $sta_group/$sta_mode/$sta_corner/$sta_check.sum
</pre>
![run/01_sta/screenshot/uniq_end_summary.png](./run/01_sta/screenshot/uniq_end_summary.png?raw=true)

+ <code> (GOLDEN-0122) sta_index_group -sta_group $sta_group </code>

<pre>
# $sta_group/index.htm
# $sta_group/$sta_mode/index.htm
# $sta_group/$sta_mode/mode.htm
# $sta_group/$sta_mode/check.htm
# $sta_group/$sta_mode/corner.htm
....
</pre>
![run/01_sta/screenshot/uniq_end_index.png](./run/01_sta/screenshot/uniq_end_index.png?raw=true)
![run/01_sta/screenshot/uniq_end_mode.png](./run/01_sta/screenshot/uniq_end_mode.png?raw=true)

## 6) Genearte STA2HTM index page
+ <code> % make index </code>
+ <code> % sta_index_runset </code>
![run/02_trend/screenshot/sta2htm_trendchart.jpeg](./run/02_trend/screenshot/sta2htm_trendchart.jpeg?raw=true)



