# Demo Case

## 01_sta/

+ <code> % make run </code>

### Makefile
<pre>
RPT_DIR := reports
STA_RUN := GOLDEN-0122
STA_RPT := $(RPT_DIR)/apr0-0122

$(STA_RUN):
	sta_init_dir $(STA_RUN) $(STA_RPT)

run: $(STA_RUN)
	(cd $(STA_RUN); make all )| tee run.log
	make htm | tee tree.log

view:
	firefox $(STA_RUN)/uniq_end/index.htm &

htm:
	tree -P *.htm $(STA_RUN) 

diff:
	diff run.log logs/run.log 
	diff tree.log logs/tree.log 
	diff $(STA_RUN)/uniq_end/setup.log logs/setup.log
	diff $(STA_RUN)/uniq_end/hold.log logs/hold.log

clean:
	rm -fr $(STA_RUN) *.log



</pre>

### STA Report File
<pre>
reports/
└── GOLDEN-1114
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

10 directories, 11 files
</pre>

### STA Summary Directory
<pre>
 GOLDEN-1114/
├── STA -> ../reports/GOLDEN-1114
└── uniq_end
    ├── func
    │   ├── hold
    │   └── setup
    └── scan
        ├── hold
        └── setup

9 directories
</pre>

### STA Summary HTML Files

<pre>
GOLDEN-1114/
└── uniq_end
    ├── index.htm
    ├── mode.htm
    ├── check.htm
    ├── corner.htm
    ├── setup.htm
    ├── hold.htm
    ├── func
    │   ├── hold
    │   │   ├── 000_TT.blk.htm
    │   │   ├── 000_TT.clk.htm
    │   │   ├── 151_ML.blk.htm
    │   │   ├── 151_ML.clk.htm
    │   │   ├── 157_BC.blk.htm
    │   │   ├── 157_BC.clk.htm
    │   │   ├── 258_WC.blk.htm
    │   │   └── 258_WC.clk.htm
    │   ├── hold.blk.htm
    │   ├── hold.clk.htm
    │   ├── hold.htm
    │   ├── hold.uniq_end.htm
    │   ├── index.htm
    │   ├── setup
    │   │   ├── 000_TT.blk.htm
    │   │   ├── 000_TT.clk.htm
    │   │   ├── 157_BC.blk.htm
    │   │   ├── 157_BC.clk.htm
    │   │   ├── 258_WC.blk.htm
    │   │   └── 258_WC.clk.htm
    │   ├── setup.blk.htm
    │   ├── setup.clk.htm
    │   ├── setup.htm
    │   └── setup.uniq_end.htm
    ├── scan
    │   ├── hold
    │   │   ├── 000_TT.blk.htm
    │   │   ├── 000_TT.clk.htm
    │   │   ├── 151_ML.blk.htm
    │   │   └── 151_ML.clk.htm
    │   ├── hold.blk.htm
    │   ├── hold.clk.htm
    │   ├── hold.htm
    │   ├── hold.uniq_end.htm
    │   ├── index.htm
    │   ├── setup
    │   │   ├── 000_TT.blk.htm
    │   │   ├── 000_TT.clk.htm
    │   │   ├── 157_BC.blk.htm
    │   │   └── 157_BC.clk.htm
    │   ├── setup.blk.htm
    │   ├── setup.clk.htm
    │   ├── setup.htm
    │   └── setup.uniq_end.htm
    └── 

</pre>
