#!/usr/bin/tclsh
#
# Generate Trend Chart and Report
#
# By Albert Li 
# 2021/01/28
#

puts "INFO: Loading 'STA_TREND.tcl'..."
namespace eval LIB_STA {


#
# <Title>
#   Create trend index.htm file
#
# <Input>
#   $STA_RUN/$STA_SUM_DIR/index.htm
#
# <Output>
#   $STA_SUM_DIR/index.htm
#
proc report_index_trend {{out_dir ".trend"}} {
  variable STA_CFG_FILE
  variable STA_RPT_ROOT
  variable STA_SUM_DIR
  variable STA_RUN_LIST
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER_LIST
  variable STA_CORNER
  variable CORNER_NAME

  puts "INFO: Generating STA Trend Tracking HTML Files ..."
  set num_col [expr [llength $STA_CORNER_LIST]+5]
  file mkdir $out_dir
  set fo [open "index.htm" "w"]
  puts $fo "<html>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
#  puts $fo "\[<a href=index.htm>\@Trend</a>\]"
  puts $fo "\[\@Trend\]"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" width=1000 id=\"sta_tbl\">"
  puts $fo "<tr>"
  puts $fo "<td colspan=$num_col>"
  puts $fo "<iframe name=sta_output src='$STA_CFG_FILE' width=100% height=420 scrolling=auto></iframe>"
  puts $fo "</td>"
  puts $fo "</tr>"
  foreach sta_mode $STA_MODE_LIST {
    puts $fo "<tr>"
    puts $fo "<th>Mode</th>"
    puts $fo "<th>Check</th>"
    puts $fo "<th>Version</th>"
    puts $fo "<th>WNS</th>"
    puts $fo "<th>NVP</th>"
    foreach sta_corner $STA_CORNER_LIST {
      puts $fo "<td align=right bgcolor=#f0f080>$sta_corner</td>"
    }
    puts $fo "</tr>"
      foreach sta_check $STA_CHECK_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
         set fdat [open "$out_dir/$sta_mode.$sta_check.nvp_wns.dat" w]
         puts $fdat "# $sta_mode/$sta_check"
         puts $fdat [format "#%10s %10s %10s" "----------" "----------" "----------"]
         puts $fdat [format "#%-10s %10s %10s" VERSION NVP WNS]
         puts $fdat [format "#%10s %10s %10s" "----------" "----------" "----------"]
         
         set num_row [expr [llength $STA_RUN_LIST]+2]
         puts $fo "<tr>"
         puts $fo "<td rowspan=$num_row>$sta_mode</td>"
         puts $fo "<td rowspan=$num_row><a href=$out_dir/$sta_mode.$sta_check.nvp_wns.png target=sta_output>$sta_check</a></td>"
         puts $fo "</tr>"
         foreach sta_run $STA_RUN_LIST {
            puts $fo "<tr>"
            if {[file exist $sta_run/$STA_SUM_DIR/$sta_mode/$sta_check]} {
              puts $fo "<td align=left>$sta_run</td>"
              if {[catch {exec cat $sta_run/$STA_SUM_DIR/$sta_mode/$sta_check/.dqi/520-STA/WNS} WNS]} {
                set WNS "-"
                puts $fo "<td align=right> - </td>"
              } else {
                puts $fo "<td align=right><a href='$sta_run/$STA_SUM_DIR/$sta_mode/$sta_check.htm'> $WNS</a> </td>"
              }
              if {[catch {exec cat $sta_run/$STA_SUM_DIR/$sta_mode/$sta_check/.dqi/520-STA/NVP} NVP]} {
                set NVP "-"
                puts $fo "<td align=right> - </td>"
              } else {
                puts $fo "<td align=right><a href='$sta_run/$STA_SUM_DIR/$sta_mode/$sta_check.nvp_wns.png' target=sta_output> $NVP</a> </td>"
              }
              foreach sta_corner $STA_CORNER_LIST {
                set corner_name $CORNER_NAME($sta_corner)
                if {[catch {exec cat $sta_run/$STA_SUM_DIR/$sta_mode/$sta_check/$corner_name/.dqi/520-STA/NVP} nvp]} {
                  puts $fo "<td align=right> * </td>"
                } else {
                  puts $fo "<td align=right> $nvp </td>"
                }
              }
              if {$nvp=="-"} {
                puts $fdat [format "*%-9s %10d %10.2f" $sta_run 0 0.0]
              } else {
                puts $fdat [format "%-10s %10d %10.2f" $sta_run $NVP [expr -$WNS]]
              }
            }
         }
         close $fdat
         create_nvp_wns_plot "$out_dir/$sta_mode.$sta_check"
         puts $fo "<tr>"
         puts $fo "<td colspan=[expr $num_col-1]></td>"
         puts $fo "</tr>"
      }
    }
    puts $fo "<tr><td colspan=$num_col>"
    puts $fo "</td></tr>"
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

proc report_sta_report_directory {} {
  variable STA_RUN_LIST
  variable STA_RPT_ROOT
         foreach sta_run $STA_RUN_LIST {
            puts $fo "<tr>"
            puts $fo "<td>$sta_run</td>"
              if {![catch {file readlink $sta_run/$STA_RPT_ROOT} sta_report]} {
                 set sta_report [file normalize $sta_run/$STA_RPT_ROOT]
                 puts $fo "<td><a href=\"$sta_report\">$sta_report</a></td>"
              } else {
                 puts $fo "<td>$sta_run/$STA_RPT_ROOT</td>"                 
              }
           puts $fo "</tr>"
         }
}
}