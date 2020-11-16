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
	rm -fr $(CURR_RUN) *.log

