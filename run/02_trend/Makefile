STA_DIR := reports
STA_RUN := GOLDEN-0122 GOLDEN-0123 GOLDEN-0124
GOLDEN-0122 = $(STA_DIR)/apr0-0122
GOLDEN-0123 = $(STA_DIR)/eco1-0123
GOLDEN-0124 = $(STA_DIR)/eco2-0124

$(STA_RUN):
	mkdir -p $@
	ln -s ../$($@) $@/STA
	(cd $@; sta_rpt_uniq_end) | tee run.$@.log

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

