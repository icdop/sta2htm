#!/bin/csh -f
#set verbose=1
set prog = $0:t
if (($1 == "") || ($1 == "-h") || ($1 == "--help")) then
   echo "Usage: $prog [options] <rundir> <STA_RPT>[B"
   echo "       options:"
   exit -1
endif
echo "======================================================="
echo "TIME: @`date +%Y%m%d_%H%M%S` BEGIN $prog $*"

if ($?STA_HOME == 0) then
   setenv STA_HOME $0:h/..
endif
setenv CSH_DIR $STA_HOME/csh
setenv ETC_DIR $STA_HOME/etc
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
cp -fr $ETC_DIR/sta .sta
rm -f Makefile STA
ln -s .sta/Makefile.sta Makefile
ln -s $STA_RPT/$RUN_DIR STA
echo "STA_HOME := $STA_HOME" > Makefile.bin

echo "TIME: @`date +%Y%m%d_%H%M%S` END   $prog"
echo "======================================================="
exit 0
