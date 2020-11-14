#!/bin/csh -f
#set verbose=1
set prog = $0:t
if (($1 == "") || ($1 == "-h") || ($1 == "--help")) then
   echo "Usage: $prog [options] <rundir> "
   echo "       options:"
   echo "         --PREV PREV_RUN"
   echo "         --STA  STA_RPT"
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
setenv PREV_RUN "."

if ($1 != "") then
   set CURR_RUN=$1
   shift argv
   echo "# CURR_RUN = $CURR_RUN"
else
   set CURR_RUN="."
endif


if ($1 == "--PREV") then
   shift argv
   setenv PREV_RUN $1
   shift argv
   echo "# PREV_RUN = $PREV_RUN"
endif

if ($1 == "--STA") then
   shift argv
   setenv STA_RPT $1
   shift argv
   echo "# STA_RPT  = $STA_RPT"
endif


mkdir -p $CURR_RUN
chdir $CURR_RUN
cp -fr $ETC_DIR/sta .sta
rm -f Makefile PREV STA
ln -s .sta/Makefile.sta Makefile
ln -s $PREV_RUN PREV
ln -s $STA_RPT STA
echo "STA_HOME := $STA_HOME" > Makefile.bin

echo "TIME: @`date +%Y%m%d_%H%M%S` END   $prog"
echo "======================================================="
exit 0
