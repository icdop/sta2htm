BIN_PATH := bin
CSH_PATH := ../csh

bin: csh/* csh/
	mkdir -p $(BIN_PATH)
	rm -f $(BIN_PATH)/*
	ln -f -s $(CSH_PATH)/20_sta_init_dir.csh		$(BIN_PATH)/sta_init_dir
	ln -f -s $(CSH_PATH)/21_sta_rpt_uniq_end.tcl		$(BIN_PATH)/sta_rpt_uniq_end
	ln -f -s $(CSH_PATH)/22_sta_rpt_by_clock.tcl		$(BIN_PATH)/sta_rpt_by_clock
	ln -f -s $(CSH_PATH)/23_sta_rpt_by_block.tcl		$(BIN_PATH)/sta_rpt_by_block
	ln -f -s $(CSH_PATH)/29_sta_run_index.tcl		$(BIN_PATH)/sta_run_index

