#!/bin/csh -f
#set verbose=1
set prog = $0:t
if (($1 == "") || ($1 == "-h") || ($1 == "--help")) then
   echo "Usage: $prog [options] <run_dir> <report_path> <sta_group>"
   echo "       options:"
   echo "          --STA_DIR <sta_report_dir>"
   exit -1
else
   echo "$prog $*"
endif
echo "======================================================="
echo "TIME: @`date +%Y%m%d_%H%M%S` BEGIN $prog"

if ($?STA2HTM == 0) then
   setenv STA2HTM $0:h/..
endif
setenv CSH_DIR $STA2HTM/csh
setenv ETC_DIR $STA2HTM/etc

if ($1 == "--STA_DIR") then
   shift argv
   set STA_DIR = $1
   shift argv
   echo "# STA_DIR := $STA_DIR"
else
   set STA_DIR = "STA"
endif

if ($1 != "") then
   set STA_RUN = $1
   shift argv
else
   set STA_RUN = "."
endif
echo "# STA_RUN := $STA_RUN"
mkdir -p $STA_RUN/.sta
cp -fr $ETC_DIR/make/sta2htm.make $STA_RUN/Makefile
echo "# STA_RUN := $STA_RUN" > $STA_RUN/Makefile.inc

if ($1 != "") then
   set STA_RPT = $1
   shift argv
else
   set STA_RPT = $STA_RUN
endif
set STA_RPT = `realpath $STA_RPT`
echo "# STA_RPT := $STA_RPT"
echo "# STA_RPT := $STA_RPT" >> $STA_RUN/Makefile.run
cp -fr $STA_RPT/.sta/sta2htm.* $STA_RUN/.sta
rm -f $STA_RUN/$STA_DIR
ln -s $STA_RPT $STA_RUN/$STA_DIR

if ($1 == "") then
echo "STA_GROUP := uniq_end" >> $STA_RUN/Makefile.run
else
while ($1 != "")
   echo "STA_GROUP += $1" >> $STA_RUN/Makefile.run   
   set STA_GROUP = $1
   shift argv
end
endif

mkdir -p .javascript
cp -fr $ETC_DIR/html/chartjs/Chart.bundle.min.js .javascript

echo "TIME: @`date +%Y%m%d_%H%M%S` END   $prog"
echo "======================================================="
exit 0
