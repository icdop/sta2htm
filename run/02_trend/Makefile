include Makefile.run

#STA_RUN     := GOLDEN-0122
#GOLDEN-0122 := reports/apr0-0122

help:
	@echo	"Usage:"
	@echo	"  make run    # run all : $(STA_RUN)"
	@echo	"  make index  # create index.htm"
	@echo	"  make clean  # clean all previous data"
	@echo


$(STA_RUN):
	sta_init_dir $@ $(STA_RUN_REPORT.$@) $(STA_RUN_GROUPS.$@)


init: $(STA_RUN)


run: $(STA_RUN)
	@for i in $(STA_RUN); do ( \
	  (cd $$i; make run) | tee run.$$i.log ; \
	) ; done
	make index


index: $(STA_RUN)
	@for i in $(STA_RUN); do ( \
	  cd $$i; make index ; \
	) ; done
	sta_index_trend
	
view:
	firefox index.htm &

tree: tree.log
tree.log:
	tree $(STA_RUN) | tee tree.log

diff: tree.log
	diff -y tree.log logs/tree.log 

clean:
	rm -fr $(STA_RUN) *.log .trendchart .javascript index.htm index.*.htm

