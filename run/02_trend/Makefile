RPT_DIR := ../reports
STA_RUN := GOLDEN-0122 GOLDEN-0123 GOLDEN-0124
GOLDEN-0122 := $(RPT_DIR)/apr0-0122
GOLDEN-0123 := $(RPT_DIR)/eco1-0123
GOLDEN-0124 := $(RPT_DIR)/eco2-0124

$(STA_RUN):
	sta_init_dir $@ $($@)
	cd $@; make all | tee run.$@.log

run: $(STA_RUN)
	tree -P index.htm $(STA_RUN)| tee run.log

view:
	firefox index.htm &

htm:
	tree -P *.htm $(STA_RUN) 

diff:
	diff run.log logs/run.log 

clean:
	rm -fr $(STA_RUN) *.log

