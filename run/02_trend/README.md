# Demo Case

# 02_trend/

+ <code> % make run </code>

### Makefile
<pre>
RPT_DIR := reports
STA_RUN_LIST := GOLDEN-0122 GOLDEN-0123 GOLDEN-0124
GOLDEN-0122 := $(RPT_DIR)/apr0-0122
GOLDEN-0123 := $(RPT_DIR)/eco1-0123
GOLDEN-0124 := $(RPT_DIR)/eco2-0124

run: $(STA_RUN_LIST)
	make index

$(STA_RUN_LIST):
	sta_init_dir $@ $($@)
	(cd $@; make run) | tee run.$@.log

index: $(STA_RUN_LIST)
	sta_run_index


</pre>

### STA Configuration Runset File
<pre>
#
[VERSION]
#STA_RUN	STA_RUN_REPORT         STA_RUN_GROUPS
#-------------	---------------------  ----------------
GOLDEN-0122	reports/apr0-0120      uniq_end
GOLDEN-0123	reports/eco1-0123      uniq_end
GOLDEN-0124	reports/eco2-0124      uniq_end
;TRYRUN-0125	reports/eco2-0125      uniq_end
;GOLDEN-0127	reports/eco3-0127      uniq_end

[GROUP]
#STA_GROUP   STA_GROUP_FILES
#---------   -----------------------------------------------
uniq_end     $sta_mode/$corner_name/$sta_check.rpt

[CHECK]
#<sta_check> STA_CHECK_DEF
#----------- -------------------
setup        
hold         

[MODE]
#<sta_mode>   STA_MODE_NAME     STA_MODE_DEF
#-----------  ----------------- -------------------
func          functional        func_0210.sdc
scan          dc_capture        scan_0211.sdc

[CORNER]
#<sta_corner>  <corner_name>    Lib_corner	RC_corner   LibFiles
#------------  -------------    --------------  ---------- ----------
000            000_TT           TTT:0.80V:025C  RCtyp           	
151            151_ML           FFG:0.88V:125C  Cmax
157            157_BC           FFF:0.88V:-40C  Cmin
231            231_WCL          SSG:0.72V:-40C  Cmax
258            258_WC           SSG:0.72V:125C  Cmax

[SCENARIO]
#SID    CHECK   MODE	CORNERS
#-----	------	------- --------------------
S001    setup   func	000 -   157 231 258
;S002   setup	scan	000 -   157 -   -
H001    hold	func	000 151 157 -   258
H002    hold	scan	000 -   157 -   258
</pre>

### STA Report File
<pre>
reports/
├── apr0-0122
│   ├── func
│   │   ├── 000_TT
│   │   │   ├── hold.rpt
│   │   │   └── setup.rpt
│   │   ├── 151_ML
│   │   │   └── hold.rpt
│   │   ├── 157_BC
│   │   │   ├── hold.rpt
│   │   │   └── setup.rpt
│   │   ├── 231_WCL
│   │   │   └── setup.rpt
│   │   └── 258_WC
│   │       ├── hold.rpt
│   │       └── setup.rpt
│   └── scan
│       ├── 000_TT
│       │   ├── hold.rpt
│       │   └── setup.rpt
│       └── 157_BC
│           └── hold.rpt
├── eco1-0123
│   ├── func
│   │   ├── 000_TT
│   │   │   ├── hold.rpt
│   │   │   └── setup.rpt
│   │   ├── 151_ML
│   │   │   └── hold.rpt
│   │   ├── 157_BC
│   │   │   ├── hold.rpt
│   │   │   └── setup.rpt
│   │   ├── 231_WCL
│   │   │   └── setup.rpt
│   │   └── 258_WC
│   │       ├── hold.rpt
│   │       └── setup.rpt
│   └── scan
│       ├── 000_TT
│       │   ├── hold.rpt
│       │   └── setup.rpt
│       └── 157_BC
│           └── hold.rpt
└── eco2-0124
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

30 directories, 33 files
</pre>

### STA Summary Directory

<pre>
GOLDEN-0122
└── uniq_end
    ├── func
    │   ├── hold
    │   │   ├── 000_TT
    │   │   ├── 151_ML
    │   │   ├── 157_BC
    │   │   └── 258_WC
    │   ├── index.htm
    │   └── setup
    │       ├── 000_TT
    │       ├── 157_BC
    │       ├── 231_WCL
    │       └── 258_WC
    ├── index.htm
    └── scan
        ├── hold
        │   ├── 000_TT
        │   └── 157_BC
        └── index.htm
GOLDEN-0123
└── uniq_end
    ├── func
    │   ├── hold
    │   │   ├── 000_TT
    │   │   ├── 151_ML
    │   │   ├── 157_BC
    │   │   └── 258_WC
    │   ├── index.htm
    │   └── setup
    │       ├── 000_TT
    │       ├── 157_BC
    │       ├── 231_WCL
    │       └── 258_WC
    ├── index.htm
    └── scan
        ├── hold
        │   ├── 000_TT
        │   └── 157_BC
        └── index.htm
GOLDEN-0124
└── uniq_end
    ├── func
    │   ├── hold
    │   │   ├── 000_TT
    │   │   ├── 151_ML
    │   │   ├── 157_BC
    │   │   └── 258_WC
    │   ├── index.htm
    │   └── setup
    │       ├── 000_TT
    │       ├── 157_BC
    │       ├── 231_WCL
    │       └── 258_WC
    ├── index.htm
    └── scan
        ├── hold
        │   ├── 000_TT
        │   └── 157_BC
        └── index.htm

48 directories, 9 files

</pre>
