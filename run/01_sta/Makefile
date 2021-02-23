STA_DIR := reports
STA_RUN := GOLDEN-0122
GOLDEN-0122 := $(STA_DIR)/apr0-0122

$(STA_RUN):
	sta_init_dir $@ $($@)
	(cd $@; make run ) | tee run.$@.log

run: $(STA_RUN)
	make index

index:
	@for i in $(STA_RUN); do ( \
	  cd $$i; make index ; \
	) ; done
	
view:
	firefox $(STA_RUN)/uniq_end/index.htm &

tree: tree.log
tree.log:
	tree $(STA_RUN) | tee tree.log

diff: tree.log
	diff -y tree.log logs/tree.log 

clean:
	rm -fr $(STA_RUN) *.log

