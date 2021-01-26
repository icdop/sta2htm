STA_DIR := reports
STA_RUN := GOLDEN-0122
STA_RPT := apr0-0122

$(STA_RUN):
	sta_init_dir $(STA_RUN) $(STA_DIR)/$(STA_RPT)

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
	diff $(STA_RUN)/uniq_end/setup.log logs/setup.log
	diff $(STA_RUN)/uniq_end/hold.log logs/hold.log

clean:
	rm -fr $(STA_RUN) *.log

