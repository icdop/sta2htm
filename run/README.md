# Demo Case

## 01_sta/

+ <code> % make run </code>

### Makefile
<pre>
PREV_RUN := .
CURR_RUN := GOLDEN-1114
STA_RPT  := ../report

$(CURR_RUN):
	sta_init $(CURR_RUN) --PREV $(PREV_RUN) --STA $(STA_RPT)

run: $(CURR_RUN)
	(cd $(CURR_RUN); make all )| tee run.log
	make htm | tee tree.log
	make diff | tee diff.log

htm:
	tree -P *.htm $(CURR_RUN) 

diff:
	diff run.log logs/run.log 
	diff tree.log logs/tree.log 
	diff $(CURR_RUN)/uniq_end/setup.log logs/setup.log
	diff $(CURR_RUN)/uniq_end/hold.log logs/hold.log

clean:
	rm -fr $(CURR_RUN) run.log tree.log


</pre>

### STA Report File
<pre>
report/
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

### STA Summary Directory
<pre>
 GOLDEN-1114/
├── PREV -> .
├── STA -> ../report
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
    ├── corner.htm
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
    ├── hold.diff.htm
    ├── hold.full.htm
    ├── hold.htm
    ├── index.htm
    ├── mode.htm
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
    ├── setup.diff.htm
    ├── setup.full.htm
    └── setup.htm

7 directories, 49 files
</pre>
