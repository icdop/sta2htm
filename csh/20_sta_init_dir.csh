#!/bin/csh -f
#set verbose=1
set prog = $0:t
if (($1 == "") || ($1 == "-h") || ($1 == "--help")) then
   echo "Usage: $prog [options] <rundir> <starpt>[B"
   echo "       options:"
   exit -1
endif
echo "======================================================="
echo "TIME: @`date +%Y%m%d_%H%M%S` BEGIN $prog $*"

if ($?STA2HTM == 0) then
   setenv STA2HTM $0:h/..
endif
setenv CSH_DIR $STA2HTM/csh
setenv ETC_DIR $STA2HTM/etc
setenv STA_RPT  "report"

if ($1 != "") then
   set RUN_DIR=$1
   shift argv
   echo "# RUN_DIR := $RUN_DIR"
   mkdir -p $RUN_DIR
else
   set RUN_DIR="."
endif


if ($1 != "") then
   setenv STA_RPT `realpath $1`
   shift argv
   echo "# STA_RPT := $STA_RPT"
endif


chdir $RUN_DIR
rm -f Makefile
#echo "STA2HTM := $STA2HTM" > Makefile
cat $ETC_DIR/sta/sta2htm.make >> Makefile
cp -fr $STA_RPT/.sta .sta
rm -f STA
ln -s $STA_RPT STA

echo "TIME: @`date +%Y%m%d_%H%M%S` END   $prog"
echo "======================================================="
exit 0
