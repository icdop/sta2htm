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
#   $STA_RUN/$sta_group/index.htm
#
# <Output>
#   $sta_group/index.htm
#
proc report_index_runset {{plot_dir ".snapshot"}} {
  variable STA_RUN_FILE
  variable STA_RUN_LIST
  variable STA_GROUP_LIST
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CHECK_DEF
  variable STA_CORNER_LIST
  variable STA_CORNER_NAME
  variable STA_CORNER
  variable STA_SCENARIO_MAP

  set STA_DQI_LIST "NVP WNS TNS"
  puts "INFO: Generating STA Trend Tracking HTML Files ..."
  set num_col [expr [llength $STA_CORNER_LIST]+[llength $STA_DQI_LIST]+2]
  set fo [open "index.htm" "w"]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "\[<a href=$STA_RUN_FILE target=sta_output>\@RUNSET</a>\]"
  puts $fo "</head>"
  puts $fo "<body>"
  
  foreach sta_group $STA_GROUP_LIST {
  set out_dir "$plot_dir/$sta_group"
  file mkdir $out_dir

  puts $fo "<table border=\"1\" width=1000 id=\"sta_tbl\">"
#  puts $fo "<caption> $sta_group </caption>"
  puts $fo "<tr>"
  puts $fo "<td colspan=$num_col>"
  puts $fo "<iframe name=sta_output src='$STA_RUN_FILE' width=100% height=420 scrolling=auto></iframe>"
  puts $fo "</td>"
  puts $fo "</tr>"
  foreach sta_check $STA_CHECK_LIST {
    if {[info exist STA_CHECK_DEF($sta_check)] && ($STA_CHECK_DEF($sta_check)!="")} {
       set STA_CHECK_DQI [lindex $STA_CHECK_DEF($sta_check) 0]
    } else {
       set STA_CHECK_DQI NVP
    }
    puts $fo "<tr>"
    puts $fo "<th>\[$sta_check\]</th>"
#    puts $fo "<th>Mode</th>"
    puts $fo "<th>Version</th>"
    foreach sta_dqi $STA_DQI_LIST {
      puts $fo "<th>$sta_dqi</th>"
    }
    foreach sta_corner $STA_CORNER_LIST {
      puts $fo "<td align=right bgcolor=#f0f080>$sta_corner</td>"
    }
    puts $fo "</tr>"
    foreach sta_mode $STA_MODE_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
         set fdat [open "$out_dir/$sta_mode.$sta_check.nvp_wns.dat" w]
         puts $fdat "# $sta_mode/$sta_check"
         puts $fdat [format "#%10s %10s %10s" "----------" "----------" "----------"]
         puts $fdat [format "#%-10s %10s %10s" VERSION NVP WNS]
         puts $fdat [format "#%10s %10s %10s" "----------" "----------" "----------"]
         
         set num_row [expr [llength $STA_RUN_LIST]+2]
         puts $fo "<tr>"
#         puts $fo "<td rowspan=$num_row>$sta_check</td>"
         puts $fo "<td rowspan=$num_row><a href=$out_dir/$sta_mode.$sta_check.nvp_wns.png target=sta_output>$sta_mode</a></td>"
         puts $fo "</tr>"
         foreach sta_run $STA_RUN_LIST {
            puts $fo "<tr>"
            if {[file exist $sta_run/$sta_group/$sta_mode/.dqi/520-STA/$sta_check]} {
              puts $fo "<td align=left><a href='$sta_run/$sta_group/$sta_mode/$sta_check.htm'>$sta_run</a></td>"
              foreach sta_dqi $STA_DQI_LIST  {
                if {[catch {exec cat $sta_run/$sta_group/$sta_mode/.dqi/520-STA/$sta_check/$sta_dqi} dqi_value]} {
                  set STA_DQI($sta_dqi) "-"
                  puts $fo "<td align=right> - </td>"
                } else {
                  set STA_DQI($sta_dqi) $dqi_value
                  puts $fo "<td align=right><a href='$sta_run/$sta_group/$sta_mode/$sta_check.nvp_wns.png' target=sta_output> $dqi_value</a> </td>"
                }
              }
              foreach sta_corner $STA_CORNER_LIST {
                if {![info exist STA_SCENARIO_MAP($sta_check,$sta_mode,$sta_corner)]} {
                    puts $fo "<td align=right bgcolor=#c0c0c0> - </td>"
                } else {
                  if {[catch {exec cat $sta_run/$sta_group/$sta_mode/$sta_corner/.dqi/520-STA/$sta_check/$STA_CHECK_DQI} dqi_value]} {
                    puts $fo "<td align=right bgcolor=#f08080> * </td>"
                  } elseif {$dqi_value==0} {
                    puts $fo "<td align=right bgcolor=#80f080> . </td>"
                  } else {
                    puts $fo "<td align=right> $dqi_value </td>"
                  }
                }
              }
              if {$STA_DQI(NVP)=="-"} {
                puts $fdat [format "*%-9s %10d %10.2f" $sta_run 0 0.0]
              } else {
                puts $fdat [format "%-10s %10d %10.2f" $sta_run $STA_DQI(NVP) [expr -1*$STA_DQI(WNS)]]
              }
            }
            puts $fo "</tr>"
         }
         close $fdat
         create_nvp_wns_plot "$out_dir/$sta_mode.$sta_check"
         puts $fo "<tr>"
         puts $fo "<td colspan=[expr $num_col-1]></td>"
         puts $fo "</tr>"
      }
    }
    puts $fo "<tr>"
    puts $fo "<td colspan=$num_col></td>"
    puts $fo "</tr>"
  }
  puts $fo "</table>"
  } 
  # end of STA_GROUP_LIST
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

proc report_sta_report_directory {} {
  variable STA_RUN_LIST
  variable STA_RUN_REPORT
         foreach sta_run $STA_RUN_LIST {
            puts $fo "<tr>"
            puts $fo "<td>$sta_run</td>"
              if [info exist STA_RUN_REPORT($sta_run)] {
                 set sta_report [file normalize $STA_RUN_REPORT($sta_run)]
                 puts $fo "<td><a href=\"$sta_report\">$sta_report</a></td>"
              } elseif {![catch {file readlink $sta_run/STA} sta_report]} {
                 set sta_report [file normalize $sta_run/STA]
                 puts $fo "<td><a href=\"$sta_report\">$sta_report</a></td>"
              } else {
                 puts $fo "<td>*</td>"
              }
           puts $fo "</tr>"
         }
}

}
