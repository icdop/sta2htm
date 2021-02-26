# Demo Case

# 02_trend/

+ <code> % make run </code>

### Makefile.run
<pre>
STA_RUN += GOLDEN-0122 
STA_RUN_DIR.GOLDEN-0122 := reports/apr0-0122

STA_RUN += GOLDEN-0123
STA_RUN_DIR.GOLDEN-0123 = reports/eco1-0123

STA_RUN += GOLDEN-0124
STA_RUN_DIR.GOLDEN-0124 = reports/eco2-0124

STA_RUN += GOLDEN-0125
STA_RUN_DIR.GOLDEN-0125 = reports/eco3-0125

### Makefile
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
</pre>

### STA Runset File
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
#STA_GROUP   STA_GROUP_REPORT
#---------   -----------------------------------------------
uniq_end     $sta_mode/$corner_name/$sta_check.rpt

[CHECK]
#<sta_check> STA_CHECK_DEF
#----------- -------------------
setup        WNS
hold         NVP

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
S001    setup   func    000 -   157 231 258
S002    setup   scan    000 -   157 -   -
H001    hold    func    000 151 157 -   258
H002    hold    scan    000 -   157 -   258
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

![run/02_trend/screenshot/sta2htm_runset.jpeg](./run/02_trend/screenshot/sta2htm_runset.jpeg?raw=true)

![run/02_trend/screenshot/sta2htm_trendchart.jpeg](./run/02_trend/screenshot/sta2htm_trendchart.jpeg?rgroupue)
