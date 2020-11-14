PREV_RUN := .
CURR_RUN := GOLDEN-1114
STA_RPT  := ../report

$(CURR_RUN):
	sta_init $(CURR_RUN) --PREV $(PREV_RUN) --STA $(STA_RPT)

run: $(CURR_RUN)
	cd $(CURR_RUN); make all

clean:
	rm -fr $(CURR_RUN)

