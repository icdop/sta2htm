STA_DIR := reports
STA_RUN := GOLDEN-0122 GOLDEN-0123 GOLDEN-0124
GOLDEN-0122 = $(STA_DIR)/apr0-0122
GOLDEN-0123 = $(STA_DIR)/eco1-0123
GOLDEN-0124 = $(STA_DIR)/eco2-0124


run: $(STA_RUN)
	make tree
	make index

$(STA_RUN):
	sta_init_dir $@ $($@)
	(cd $@; sta_rpt_uniq_end) | tee run.$@.log

index: $(STA_RUN)
	sta_gen_index

view:
	firefox index.htm &

tree:
	tree -P index.htm $(STA_RUN)| tee tree.log

diff:
	diff tree.log logs/tree.log 

clean:
	rm -fr $(STA_RUN) *.log .trend index.htm

