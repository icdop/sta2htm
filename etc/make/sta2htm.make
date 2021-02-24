include Makefile.run

#STA_GROUP  := uniq_end

help:
	@echo	"Usage:"
	@echo	"  make run    # run all path group : $(STA_GROUP)"
	@echo	"  make index  # run uniq_end with all check"
	@echo	"  make clean  # clean all previous data"
	@echo

$(STA_GROUP):
	mkdir -p $@
	sta_uniq_end -sta_group $@ | tee $@.log

run:	$(STA_GROUP)

index: 
	for i in $(STA_GROUP); do ( \
	  sta_index_group -sta_group $$i ; \
	) ; done


clean:
	rm -fr $(STA_GROUP)
