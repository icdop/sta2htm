STA_DIR := reports
STA_RUN := GOLDEN-0122
STA_RPT := $(STA_DIR)/apr0-0122

$(STA_RUN):
	sta_init_dir $(STA_RUN) $(STA_RPT)
	(cd $@; sta_rpt_uniq_end) | tee run.$@.log

run: $(STA_RUN)
	make tree

view:
	firefox $(STA_RUN)/uniq_end/index.htm &

tree:
	tree $(STA_RUN) | tee tree.log

diff:
	diff -r tree.log logs/tree.log 

clean:
	rm -fr $(STA_RUN) *.log

