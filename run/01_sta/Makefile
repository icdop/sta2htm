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
	sta_init_run $@ $(STA_RUN_DIR.$@) $(STA_RUN_GROUPS.$@)


init: $(STA_RUN)


run: init
	@for i in $(STA_RUN); do ( \
	  (cd $$i; make run) | tee run.$$i.log ; \
	) ; done
	sta_index_runset


index: run
	@for i in $(STA_RUN); do ( \
	  cd $$i; make index ; \
	) ; done
	sta_index_runset
	tree --dirsfirst --prune -P index.htm . -o index.tree

	
view:
	firefox index.htm &

tree: tree.log
tree.log:
	tree --dirsfirst --prune -P index.htm . -o index.tree
	tree $(STA_RUN) | tee tree.log

diff: tree.log
	diff -y tree.log logs/tree.log 

clean:
	rm -fr $(STA_RUN) *.log  index.* .trendchart .javascript .icon

