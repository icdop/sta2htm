BIN_PATH := bin
CSH_PATH := ../csh

bin: csh/* csh/
	mkdir -p $(BIN_PATH)
	rm -f $(BIN_PATH)/*
	ln -f -s $(CSH_PATH)/20_sta_index.csh			$(BIN_PATH)/sta_index
	ln -f -s $(CSH_PATH)/21_sta_uniq_end.csh		$(BIN_PATH)/sta_uniq_end
	ln -f -s $(CSH_PATH)/22_sta_by_clock.csh		$(BIN_PATH)/sta_by_clock
	ln -f -s $(CSH_PATH)/23_sta_by_group.csh		$(BIN_PATH)/sta_by_group
	ln -f -s $(CSH_PATH)/31_cap_read_spef.csh		$(BIN_PATH)/sta_create_cap
	ln -f -s $(CSH_PATH)/32_cap_comp.csh		 	$(BIN_PATH)/sta_comapre_cap

