# Demo Case

## 01_sta/

+ <code> % make run </code>

### Makefile.run
<pre>
STA_RUN     := GOLDEN-0122
STA_RUN_DIR.GOLDEN-0122    := reports/apr0-0122
STA_RUN_GROUPS.GOLDEN-0122 := uniq_end reg2reg in2reg reg2out
</pre>

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

### STA Report File
<pre>
reports/
└── GOLDEN-0122
    ├── func
    │   ├── 000_TT
    │   │   ├── hold.rpt
    │   │   └── setup.rpt
    │   ├── 151_ML
    │   │   └── hold.rpt
    │   ├── 157_BC
    │   │   ├── hold.rpt
    │   │   └── setup.rpt
    │   └── 258_WC
    │       ├── hold.rpt
    │       └── setup.rpt
    └── scan
        ├── 000_TT
        │   ├── hold.rpt
        │   └── setup.rpt
        ├── 151_ML
        │   └── hold.rpt
        └── 157_BC
            └── setup.rpt
</pre>


### STA Summary HTML Files
<pre>
.
├── GOLDEN-0122
│   ├── in2reg
│   │   ├── func
│   │   │   └── index.htm
│   │   ├── scan01
│   │   │   └── index.htm
│   │   ├── scan02
│   │   │   └── index.htm
│   │   └── index.htm
│   ├── reg2out
│   │   ├── func
│   │   │   └── index.htm
│   │   ├── scan01
│   │   │   └── index.htm
│   │   ├── scan02
│   │   │   └── index.htm
│   │   └── index.htm
│   ├── reg2reg
│   │   ├── func
│   │   │   └── index.htm
│   │   ├── scan01
│   │   │   └── index.htm
│   │   ├── scan02
│   │   │   └── index.htm
│   │   └── index.htm
│   ├── uniq_end
│   │   ├── func
│   │   │   └── index.htm
│   │   ├── scan01
│   │   │   └── index.htm
│   │   ├── scan02
│   │   │   └── index.htm
│   │   └── index.htm
│   └── index.htm
└── index.htm
</pre>
<pre> Index </pre>
![run/01_sta/screenshot/uniq_end_index.png](./run/01_sta/screenshot/uniq_end_index.png?raw=true)
<pre> Mode </pre>
![run/01_sta/screenshot/uniq_end_mode.png](./run/01_sta/screenshot/uniq_end_mode.png?raw=true)
<pre> Corner </pre>
![run/01_sta/screenshot/uniq_end_corner.png](./run/01_sta/screenshot/uniq_end_corner.png?raw=true)
<pre> Summary </pre>
![run/01_sta/screenshot/uniq_end_summary.png](./run/01_sta/screenshot/uniq_end_summary.png?raw=true)
