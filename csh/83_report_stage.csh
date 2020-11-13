#!/bin/csh -f
#set verbose=1
set prog = $0:t
if (($1 == "-h") || ($1 == "--help")) then
   echo "Usage: $prog <DESIGN_PHASE>"
   exit -1
endif
echo "======================================================="
echo "TIME: @`date +%Y%m%d_%H%M%S` BEGIN $prog $*"

if ($?STA_HOME == 0) then
   setenv STA_HOME $0:h/..
endif
setenv ETC_DIR $STA_HOME/etc
setenv CSH_DIR $STA_HOME/csh
source $CSH_DIR/12_get_server.csh
source $CSH_DIR/13_get_project.csh
source $CSH_DIR/14_get_design.csh
source $CSH_DIR/18_get_report.csh

set project = $DESIGN_PROJT
set phase   = $DESIGN_PHASE
set block   = $DESIGN_BLOCK
set stage   = $DESIGN_STAGE
set version = $DESIGN_VERSN

if ($1 != "") then
   if (($1 != "_") && ($1 != ".")) then
      set stage = $1
    endif
    shift argv
endif
                       
echo "STAGE : $stage"

set dvc_title = "Stage $stage"
set dvc_name = $stage
set dvc_path = $phase/$block/$stage
set dvc_data = $PROJT_PATH/$dvc_path

if {(test -d $dvc_data)} then
  set stage_htm   = $dvc_data/index.htm
  set stage_css   = $dvc_data/.htm/index.css
  mkdir -p $dvc_data/.htm

  cp $html_templ/stage/index.css $stage_css
else
  echo "ERROR: stage data folder '$dvc_data' does not exist"
  exit 1
endif
(source $html_templ/stage/_index_begin.csh) >  $stage_htm
(source $html_templ/stage/_index_data.csh)  >> $stage_htm
set detail_list = `glob $html_templ/stage/_index_detail_*.csh`
foreach detail_report ( $detail_list )
  set id = $detail_report:t:r
  echo "<details id=$id>" >> $stage_htm
  (source $detail_report)  >> $stage_htm
  echo "</details>" >> $stage_htm
end
echo "<details id=version_list open=true>" >> $stage_htm
echo "<summary> Version List </summary>" >> $stage_htm
(source $html_templ/stage/_table_begin.csh) >> $stage_htm
 set version_list   = `dir $dvc_data`
 foreach version ( $version_list )
    set item_name=$version
    set item_path=$phase/$block/$stage
    set item_data=$PROJT_PATH/$item_path/$item_name
    if ($item_name != "_") then
    if {(test -d $item_data)} then
       echo "	VERSION : $version"
       (source $html_templ/stage/_table_data.csh) >> $stage_htm
    endif
    endif
 end
(source $html_templ/stage/_table_end.csh) >> $stage_htm
echo "</details>" >> $stage_htm
(source $html_templ/stage/_index_end.csh) >> $stage_htm

echo "TIME: @`date +%Y%m%d_%H%M%S` END   $prog"
echo "======================================================="
exit 0
