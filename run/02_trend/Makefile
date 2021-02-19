RPT_DIR := reports
STA_RUN_LIST := GOLDEN-0122 GOLDEN-0123 GOLDEN-0124
GOLDEN-0122 = $(RPT_DIR)/apr0-0122
GOLDEN-0123 = $(RPT_DIR)/eco1-0123
GOLDEN-0124 = $(RPT_DIR)/eco2-0124

run: $(STA_RUN_LIST)
	make tree
	make index

$(STA_RUN_LIST):
	sta_init_dir $@ $($@)
	(cd $@; sta_rpt_uniq_end) | tee run.$@.log

index: $(STA_RUN_LIST)
	sta_run_index

view:
	firefox index.htm &

tree:
	tree -P index.htm $(STA_RUN_LIST)| tee tree.log

diff:
	diff -y tree.log logs/tree.log 

clean:
	rm -fr $(STA_RUN_LIST) *.log .snapshot index.htm

