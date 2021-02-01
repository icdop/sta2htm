#!/usr/bin/tclsh
#
#
# By Albert Li 
# 2021/01/122
#

puts "INFO: Loading 'STA_COMP.tcl'..."
namespace eval LIB_STA {
#
# <Title>
# Report STA Summary Page of STA_CHECK with diff
#
# <Input>
#
# <Output>
# $STA_SUM_DIR/$sta_check.$comp.htm
#
proc report_comp_sta_html {{sta_check ""} {comp "diff"} } {
  variable STA_CURR_RUN
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK
  variable STA_CORNER
  
  if {$sta_check==""} { set sta_check $STA_CHECK}

 
  set fo [open "$STA_SUM_DIR/$sta_check.$comp.htm" "w"]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "\[<a href=index.htm>\@Index</a>\]"
  puts $fo "\[<a href=mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=check.htm>\@Check</a>\]"
  puts $fo "\[<a href=corner.htm>\@Corner</a>\]"
  puts $fo "\[<a href=$sta_check.htm>\@Prev</a>\]"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "<a href=..>$STA_CURR_RUN</a>"
  puts $fo "/"
  puts $fo "<a href=.>$STA_SUM_DIR</a>"
  puts $fo "</a>"
  puts $fo "(<a href=$sta_check.htm>$sta_check</a>)"
  puts $fo "<h3></caption>"
  foreach sta_mode $STA_MODE_LIST {
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
    puts $fo "<tr>"
    puts $fo "<th colspan=2><h3><a href=$sta_mode/$sta_check.htm>$sta_mode/$sta_check</a></h3></th>"
    puts $fo "</tr>"
    puts $fo "<tr>"
    puts $fo "<td>"
    puts $fo "<a href=\"$sta_check.htm\">"
    puts $fo "<img src=$sta_mode/$sta_check.nvp_wns.$comp.png>"
    puts $fo "</a>"
    puts $fo "</td>"
    puts $fo "<td>"
    puts $fo "<iframe src=\"$sta_mode/$sta_check.nvp_wns.$comp.rpt\" height=\"400\" width=\"500\"></iframe>"
    puts $fo "</td>"
    puts $fo "</tr>"
    }
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}


}

