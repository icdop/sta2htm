STA_BIN := $(STA2HTM)/bin
PCHECK  := setup hold
PGROUP  := 

help:
	@echo	"Usage:"
	@echo	"  make all    # run all path group : $(PGROUP)"
	@echo	"  make index  # run uniq_end with all check"
	@echo	"  make setup  # explore setup corner STA"
	@echo	"  make hold   # exploer hold corner STA"
	@echo	"  make clean  # clean all previous data"
	@echo

all:	uniq_end $(PGROUP) 

uniq_end: $(PCHECK) index

index: 
	$(STA_BIN)/sta_gen_index

$(PCHECK): 
	mkdir -p uniq_end
	$(STA_BIN)/sta_rpt_uniq_end -sta_check $@ | tee uniq_end/$@.log


$(PGROUP):
	mkdir -p uniq_end_$@
	$(STA_BIN)/sta_rpt_uniq_end  -sum_dir uniq_end_$@ -rpt_postfix _$@ -sta_check hold | tee uniq_end_$@/hold.log
	$(STA_BIN)/sta_rpt_uniq_end  -sum_dir uniq_end_$@ -rpt_postfix _$@ -sta_check setup | tee uniq_end_$@/setup.log
	$(STA_BIN)/sta_gen_index -sum_dir uniq_end_$@ -rpt_postfix _$@ 

clean:
	rm -fr uniq_end
	for i in $(PGROUP); do ( \
	  rm -fr uniq_end_$$i ; \
	) ; done
