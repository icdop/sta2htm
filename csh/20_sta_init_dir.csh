#!/bin/csh -f
#set verbose=1
set prog = $0:t
if (($1 == "") || ($1 == "-h") || ($1 == "--help")) then
   echo "Usage: $prog [options] <run_dir> <src_version>"
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
   set STA_DIR = $1/
   shift argv
   echo "# STA_DIR := $STA_DIR"
else
   set STA_DIR = ""
endif

if ($1 != "") then
   set RUN_DIR = $1
   shift argv
else
   set RUN_DIR = "."
endif
echo "# RUN_DIR := $RUN_DIR"

if ($1 != "") then
   set STA_RPT = $1
   shift argv
else
   set STA_RPT = $RUN_DIR
endif

set STA_RPT = `realpath $STA_DIR$STA_RPT`
echo "# STA_RPT := $STA_RPT"

mkdir -p $RUN_DIR
#echo "STA2HTM := $STA2HTM" > Makefile
cp -fr $ETC_DIR/sta/sta2htm.make $RUN_DIR/Makefile
cp -fr $STA_RPT/.sta $RUN_DIR/.sta
rm -f $RUN_DIR/STA
ln -s $STA_RPT $RUN_DIR/STA

echo "TIME: @`date +%Y%m%d_%H%M%S` END   $prog"
echo "======================================================="
exit 0
