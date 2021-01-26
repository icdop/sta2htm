STA_DIR := reports
STA_RUN := GOLDEN-0122
STA_RPT := $(STA_DIR)/apr0-0122

$(STA_RUN):
	sta_init_dir $(STA_RUN) $(STA_RPT)

run: $(STA_RUN)
	(cd $(STA_RUN); sta_rpt_uniq_end )| tee run.log
	make htm | tee tree.log

view:
	firefox $(STA_RUN)/uniq_end/index.htm &

htm:
	tree -P *.htm $(STA_RUN) 

diff:
	diff run.log logs/run.log 
	diff tree.log logs/tree.log 

clean:
	rm -fr $(STA_RUN) *.log

