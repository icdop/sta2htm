#!/bin/csh -f
#set verbose=1
set prog = $0:t
if (($1 == "") || ($1 == "-h") || ($1 == "--help")) then
   echo "Usage: $prog [options] <run_dir> <report_path>"
   echo "       options:"
   echo "          --STA_GROUP <sta_report_dir>"
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

if ($1 == "--STA_GROUP") then
   shift argv
   set STA_GROUP = $1
   shift argv
   echo "# STA_GROUP := $STA_GROUP"
else
   set STA_GROUP = "uniq_end"
endif

if ($1 != "") then
   set STA_RUN = $1
   shift argv
else
   set STA_RUN = "."
endif
echo "# STA_RUN := $STA_RUN"

if ($1 != "") then
   set STA_RPT = $1
   shift argv
else
   set STA_RPT = $STA_RUN
endif

set STA_RPT = `realpath $STA_RPT`
echo "# STA_RPT := $STA_RPT"

mkdir -p $STA_RUN
echo "STA_GROUP := $STA_GROUP" > $STA_RUN/Makefile.run
cp -fr $ETC_DIR/make/sta2htm.make $STA_RUN/Makefile
cp -fr $STA_RPT/.sta $STA_RUN/.sta
rm -f $STA_RUN/STA
ln -s $STA_RPT $STA_RUN/STA
mkdir -p .javascript
cp -fr $ETC_DIR/html/chartjs/Chart.bundle.min.js .javascript

echo "TIME: @`date +%Y%m%d_%H%M%S` END   $prog"
echo "======================================================="
exit 0
