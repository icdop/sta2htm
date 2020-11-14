PREV := .
CURR := GOLDEN-1114
STA  := ../report

$(CURR):
	sta_init $(CURR) --STA $(STA) --PREV $(PREV)

run: $(CURR)
	cd $(CURR); make all

clean:
	rm -fr $(CURR)

