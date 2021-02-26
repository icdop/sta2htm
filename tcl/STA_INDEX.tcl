#!/usr/bin/tclsh
#
# Generate Trend Chart and Report
#
# By Albert Li 
# 2021/01/28
#

puts "INFO: Loading 'STA_TREND.tcl'..."
namespace eval LIB_STA {

variable STA_DQI_LIST  "NVP WNS TNS"


#
# <Title>
#   Create STA2HTM Master index.htm file
#
# <Input>
#   
#
# <Output>
#   index.htm
#
proc report_index_runset {{plot_dir ".trendchart"}} {
  variable STA_RUN_FILE
  variable STA_RUN_LIST
  variable STA_RUN_DIR
  variable STA_RUN_GROUPS
  variable STA_GROUP_LIST
  variable STA_GROUP_REPORT
  variable STA_MODE_LIST
  variable STA_MODE_NAME
  variable STA_MODE_DEF
  variable STA_CHECK_LIST
  variable STA_CHECK_DQI
  variable STA_CHECK_DEF
  variable STA_CORNER_LIST
  variable STA_CORNER_NAME
  variable STA_CORNER
  variable STA_SCENARIO_MAP


  puts "\nINFO: Generating STA Runset Index Files ..."

  set fo [open "index.htm" "w"]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "<table border=0 width=1000 id='sta_tbl'><tr>"
  puts $fo "<th>"
  puts $fo "LYG STA2HTM Timing Report Reviewer ... "
  puts $fo "</th>"
  puts $fo "<td width=50 align=right bgcolor=#f0f080>"
  puts $fo "@<a href=http://gitee.com/icdop/sta2htm>gitee</a>"
  puts $fo "</td>"
  puts $fo "<td width=50 align=right bgcolor=#f0f080>"
  puts $fo "@<a href=http://github.com/icdop/sta2htm>github</a>"
  puts $fo "</td>"
  puts $fo "<td width=250 align=right bgcolor=#c0c0ff>"
  puts $fo "<a href=$::STA_HTML::LINK(logo_banner)>"
  puts $fo "<img src=$::STA_HTML::ICON(logo_banner) width=250 height=40>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "</tr></table>"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<iframe name=sta_output src=$STA_RUN_FILE width=1000 height=420 scrolling=auto></iframe>"

  puts $fo "<table border=1 width=1000 id=sta_tbl>"
  puts $fo "<caption><hr> GROUP <hr></caption>"
  puts $fo "<tr>"
  puts $fo "</tr>"
  puts $fo "<tr>"
  puts $fo "<th>STA_GROUP</th>"
  puts $fo "<th>STA_GROUP_REPORT</th>"
  puts $fo "</tr>"
  foreach sta_group $STA_GROUP_LIST {
    report_trend_group $plot_dir $sta_group
    puts $fo "<tr>"
    puts $fo "<td>"
    puts $fo "<a href='$plot_dir/$sta_group/index.htm'>"
    puts $fo "$sta_group"
    puts $fo "</a>"
    puts $fo "</td>"
    puts $fo "<td>"
    foreach file $STA_GROUP_REPORT($sta_group) {
      puts $fo "$file<br>"
    }
    puts $fo "</td>"
    puts $fo "</tr>"
  }
  puts $fo "</table>"
  puts $fo "<br>"

  puts $fo "<table border=1 width=1000 id=sta_tbl>"
  puts $fo "<caption bgcolor=#f0f080><hr> VERSION <hr></caption>"
  puts $fo "<tr>"
  puts $fo "</tr>"
  puts $fo "<tr>"
  puts $fo "<th>STA_RUN</th>"
  puts $fo "<th>STA_RUN_DIR</th>"
  puts $fo "<th>STA_RUN_GROUPS</th>"
  puts $fo "</tr>"
  foreach sta_run $STA_RUN_LIST {
    puts $fo "<tr>"
    puts $fo "<td>"
    puts $fo "<a href='$sta_run/index.htm'>"
    puts $fo "$sta_run"
    puts $fo "</a>"
    puts $fo "</td>"
    puts $fo "<td>"
    puts $fo "$STA_RUN_DIR($sta_run)"
    puts $fo "</td>"
    puts $fo "<td>"
    foreach sta_group $STA_RUN_GROUPS($sta_run) {
      puts $fo "<a href=$sta_run/$sta_group/index.htm>$sta_group</a> "
    }
    puts $fo "</td>"
    puts $fo "</tr>"
  }
  puts $fo "</table>"
  
  puts $fo "<br>"
  
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

#
# <Title>
#   Create trend chart sorted by sta_run 
#
# <Input>
#   $sta_run
#
# <Output>
#   $sta_run/index.htm
#
proc report_index_run {{plot_dir ".trendchart"} {sta_run "."}} {
  variable STA_CURR_RUN
  variable STA_DQI_LIST 
  variable STA_CFG_FILE
  variable STA_RUN_LIST
  variable STA_RUN_DIR
  variable STA_RUN_GROUPS
  variable STA_GROUP_LIST
  variable STA_GROUP_REPORT
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CHECK_DEF
  variable STA_CORNER_LIST
  variable STA_CORNER_NAME
  variable STA_CORNER
  variable STA_SCENARIO_MAP

  if {$sta_run == ""} { set sta_run $STA_CURR_RUN }
  puts "\nINFO: Generating STA RUN ($sta_run) Trend Index Files ..."
  set num_col [expr [llength $STA_CORNER_LIST]+[llength $STA_DQI_LIST]+2]

  file mkdir $sta_run/$plot_dir

  set fo [open "$sta_run/index.htm" "w"]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "<table border=0 width=1000 id='sta_tbl' bgcolor=#f0f0f0><tr>"
  puts $fo "<td align=left >"
  puts $fo "\[<a href='../index.htm'>\@RUNSET</a>\]"
  foreach sta_group $STA_GROUP_LIST {
    puts $fo "\[<a href='$sta_group/index.htm'>$sta_group</a>\]"
  }
  puts $fo "</td>"
  puts $fo "<td width=250 align=right>"
  puts $fo "<a href=$::STA_HTML::LINK(logo_banner)>"
  puts $fo "<img src=$::STA_HTML::ICON(logo_banner) width=250 height=40>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "</tr></table>"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=1 width=1000 id='sta_tbl'>"
  puts $fo "<caption> $STA_CURR_RUN </caption>"
  puts $fo "<tr>"
  puts $fo "<td colspan=$num_col>"
  puts $fo "<iframe name=sta_output src=sta2htm.log width=100% height=420 scrolling=auto></iframe>"
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
    puts $fo "<th>Group</th>"
    foreach sta_dqi $STA_DQI_LIST {
      puts $fo "<th>$sta_dqi</th>"
    }
    foreach sta_corner $STA_CORNER_LIST {
      puts $fo "<td align=right bgcolor=#f0f080>$sta_corner</td>"
    }
    puts $fo "</tr>"
    foreach sta_mode $STA_MODE_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
         file mkdir $sta_run/$plot_dir/$sta_mode
         set fdat [open "$sta_run/$plot_dir/$sta_mode/$sta_check.nvp_wns.dat" w]
         puts $fdat "# $sta_mode/$sta_check"
         puts $fdat [format "#%10s %10s %10s" "----------" "----------" "----------"]
         puts $fdat [format "#%-10s %10s %10s" GROUP NVP WNS]
         puts $fdat [format "#%10s %10s %10s" "----------" "----------" "----------"]
         
         set num_row [expr [llength $STA_GROUP_LIST]+2]
         puts $fo "<tr>"
#         puts $fo "<td rowspan=$num_row><a href=$plot_dir/$sta_mode/$sta_check.nvp_wns.png target=sta_output>$sta_mode</a></td>"
         puts $fo "<td rowspan=$num_row><a href=$plot_dir/$sta_mode/$sta_check.nvp_wns.htm target=sta_output>$sta_mode</a></td>"
         puts $fo "</tr>"
         foreach sta_group $STA_GROUP_LIST {
            puts $fo "<tr>"
            exec ls -al $sta_run/$sta_group/$sta_mode/.dqi/520-STA/$sta_check
            if {[file exist $sta_run/$sta_group/$sta_mode/.dqi/520-STA/$sta_check]} {
              puts $fo "<td align=left><a href='$sta_group/$sta_mode/$sta_check.htm'>$sta_group</a></td>"
              foreach sta_dqi $STA_DQI_LIST  {
                if {[catch {exec cat $sta_run/$sta_group/$sta_mode/.dqi/520-STA/$sta_check/$sta_dqi} dqi_value]} {
                  set STA_DQI($sta_dqi) "-"
                  puts $fo "<td align=right> - </td>"
                } else {
                  set STA_DQI($sta_dqi) $dqi_value
#                  puts $fo "<td align=right><a href='$plot_dir/$sta_mode/$sta_check.nvp_wns.png' target=sta_output> $dqi_value</a> </td>"
                  puts $fo "<td align=right><a href='$plot_dir/$sta_mode/$sta_check.nvp_wns.htm' target=sta_output> $dqi_value</a> </td>"
                }
              }
              foreach sta_corner $STA_CORNER_LIST {
#                puts "DEBUG: $sta_run/$sta_group/$sta_mode/$sta_corner/.dqi/520-STA/$sta_check/$STA_CHECK_DQI"
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
                puts $fdat [format "*%-9s %10d %10.2f" $sta_group 0 0.0]
              } else {
                puts $fdat [format "%-10s %10d %10.2f" $sta_group $STA_DQI(NVP) [expr -1*$STA_DQI(WNS)]]
              }
            }
            puts $fo "</tr>"
         }
         close $fdat
         puts $fo "<tr>"
         puts $fo "<td colspan=[expr $num_col-1]></td>"
         puts $fo "</tr>"
         create_nvp_wns_plot  "$sta_run/$plot_dir/$sta_mode/$sta_check"
         create_nvp_wns_chart "$sta_run/$plot_dir/$sta_mode/$sta_check"
      }
    }
    puts $fo "<tr>"
    puts $fo "<td colspan=$num_col></td>"
    puts $fo "</tr>"
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

#
# <Title>
#   Create all index files for STA_GROUP
#
# <Output>
#   $sta_group/index.htm
#
proc report_index_group {{sta_group ""}} {
  variable STA_CURR_GROUP

  if {$sta_group==""} { set sta_group $STA_CURR_GROUP}
 
  report_index_group_main $sta_group
  report_index_group_mode $sta_group
  report_index_group_check $sta_group
  report_index_group_corner $sta_group
}

#
# <Title>
#   Create master index.htm file for STA_GROUP
#
# <Output>
#   $sta_group/index.htm
#
proc report_index_group_main {sta_group} {
  variable STA_CURR_RUN
  variable STA_CFG_FILE
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER
  variable STA_CORNER_NAME
  variable STA_CORNER_DEF

  file mkdir $sta_group
  puts "INFO: Generating STA_GROUP($sta_group) Index HTML Files ..."
  set fo [open "$sta_group/index.htm" "w"]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "<table border=0 width=1000 id='sta_tbl' bgcolor=#f0f0f0><tr>"
  puts $fo "<td align=left>"
  puts $fo "\[<a href=../index.htm>$STA_CURR_RUN</a>\]"
  puts $fo "\[<a href=mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=check.htm>\@Check</a>\]"
  puts $fo "\[<a href=corner.htm>\@Corner</a>\]"
  puts $fo "</td>"
  puts $fo "<td width=250 align=right>"
  puts $fo "<a href=$::STA_HTML::LINK(logo_banner)>"
  puts $fo "<img src=../$::STA_HTML::ICON(logo_banner) width=250 height=40>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "</tr></table>"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=1 width=1000 id='sta_tbl'>"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "$STA_CURR_RUN/$sta_group/"
  puts $fo "</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<td colspan=6>"
#  puts $fo "$STA_CURR_RUN/$STA_CFG_FILE<hr>"
#  puts $fo "<iframe name=sta_config src='../$STA_CFG_FILE' width=100% height=200 scrolling=auto></iframe>"
  puts $fo "<iframe name=sta_output src=sta2htm.log width=1000 height=420 scrolling=auto></iframe>"
  puts $fo "</td>"
  puts $fo "</tr>"
  foreach sta_check $STA_CHECK_LIST {
#    set num_col [expr [llength STA_MODE_LIST] +1]
    puts $fo "<tr>"
    puts $fo "<th colspan=2 bgcolor=#80f080><a href='$sta_check.htm'>$sta_check</a></th>"
    puts $fo "<th align=right>NVP</th>"
    puts $fo "<th align=right>WNS</th>"
    puts $fo "<th align=right>TNS</th>"
    puts $fo "<th>STA Report</th>"
    puts $fo "</tr>"
    foreach sta_mode $STA_MODE_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
         set num_row [expr [llength $STA_CORNER($sta_mode,$sta_check)]+2]
         puts $fo "<tr>"
#         puts $fo "<td rowspan=$num_row bgcolor=#00c0c0><a href=$sta_mode/index.htm>$sta_mode</a></td>"
         puts $fo "<td rowspan=$num_row bgcolor=#80c0c0><a href=$sta_mode/$sta_check.htm>$sta_mode</a></td>"
         puts $fo "</tr>"
         foreach sta_corner $STA_CORNER($sta_mode,$sta_check) {
            puts $fo "<tr>"
            if {$sta_corner=="-"} {
            } elseif {[info exist STA_CORNER_NAME($sta_corner)]} {
               set corner_name $STA_CORNER_NAME($sta_corner)
               if {![catch {open $sta_group/$sta_mode/$sta_corner/$sta_check.vio r} fin]} {
                 set nvp 0
                 set wns 0.0
                 set tns 0.0
                 array unset SLACK
                 while {[gets $fin line] >= 0} { 
                   if {[regexp {^\# File : (\S+)} $line full fname]} {
                   } elseif {[regexp {^(\#|\*)} $line]} {
                   } elseif {[regexp {^\s*(\S+)\s+(\S+)\s+(\S+)} $line full slack egroup epoint]} {
                      if {$slack<$wns} { set wns $slack }
                      if {![info exist SLACK($egroup,$epoint)]} {
                         set SLACK($egroup,$epoint) $slack
                         incr nvp
                         set tns   [format "%.2f" [expr ($tns+$slack)]]
                      }
                   }
                 }
                 close $fin
                 puts $fo "<td align=left bgcolor=#f0f080><a href=$sta_mode/$sta_corner/$sta_check.vio target=sta_output> $corner_name </a></td>"
                 if {$nvp==0} {
                   puts $fo "<td align=right bgcolor=#80f080> . </td>"
                   puts $fo "<td align=right bgcolor=#80f080> $wns </td>"
                   puts $fo "<td align=right bgcolor=#80f080> . </td>"
                   puts $fo "<td align=left  bgcolor=#80f080><a href=\"$fname\">$fname</a></td>"
                 } else {
                   puts $fo "<td align=right> $nvp </td>"
                   puts $fo "<td align=right> $wns </td>"
                   puts $fo "<td align=right> $tns </td>"
                   puts $fo "<td align=left><a href=\"$fname\">$fname</a></td>"
                 }
               } elseif {[info exist STA_CORNER_DEF($sta_corner)]} {
                  puts $fo "<td align=left bgcolor=#f0f080>$corner_name</td>"
                  puts $fo "<td align=right bgcolor=#f0c0c0>*</td>"
                  puts $fo "<td align=right bgcolor=#f0c0c0>*</td>"
                  puts $fo "<td align=right bgcolor=#f0c0c0>*</td>"
                  puts $fo "<td bgcolor=#f0c0c0>Report Not Found!</td>"
               } else {
                  puts $fo "<td align=left bgcolor=#c0c080>$corner_name</td>"
                  puts $fo "<td align=right bgcolor=#f08080>*</td>"
                  puts $fo "<td align=right bgcolor=#f08080>*</td>"
                  puts $fo "<td align=right bgcolor=#f08080>*</td>"
                  puts $fo "<td bgcolor=#f08080>Corner Undefined!</td>"
               }
            } else {
               puts "ERROR: STA_CORNER_NAME($sta_corner) is not defined, but is used in STA_CORNER($sta_mode,$sta_check)!"
               puts $fo "<td bgcolor=#f00000>$sta_corner</td>"
               puts $fo "<td align=right bgcolor=#f08080>*</td>"
               puts $fo "<td align=right bgcolor=#f08080>*</td>"
               puts $fo "<td align=right bgcolor=#f08080>*</td>"
               puts $fo "<td bgcolor=#f08080>Corner Undefined!</td>"
            }
            puts $fo "</tr>"
         }
         puts $fo "<tr>"
         puts $fo "<td colspan=6></td>"
         puts $fo "</tr>"
      }
    }
    puts $fo "<tr><td colspan=6></td>"
    puts $fo "</tr>"
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

#
# <Title>
#   Create STA Mode index file for STA_GROUP
#
# <Output>
#   $sta_group/mode.htm
#
proc report_index_group_mode {sta_group} {
  variable STA_CURR_RUN
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER

  file mkdir $sta_group
  puts "\[$sta_group\] INFO: Generating Mode Index HTML Files ..."
  set fo [open "$sta_group/mode.htm" "w"]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "<table border=0 width=1200 id='sta_tbl' bgcolor=#f0f0f0><tr>"
  puts $fo "<td align=left>"
  puts $fo "\[<a href=index.htm>\@Index</a>\]"
  puts $fo "\[\@Mode\]"
  puts $fo "\[<a href=check.htm>\@Check</a>\]"
  puts $fo "\[<a href=corner.htm>\@Corner</a>\]"
  puts $fo "</td>"
  puts $fo "<td width=250 align=right>"
  puts $fo "<a href=$::STA_HTML::LINK(logo_banner)>"
  puts $fo "<img src=../$::STA_HTML::ICON(logo_banner) width=250 height=40>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "</tr></table>"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=1 id='sta_tbl'>"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "$STA_CURR_RUN/$sta_group/</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th>Mode</th>"
  foreach sta_check $STA_CHECK_LIST {
    puts $fo "<td bgcolor='#80c0c0'><a href=$sta_check.htm>$sta_check</a></td>"
  }
  puts $fo "</tr>"
  foreach sta_mode $STA_MODE_LIST {
    report_mode_summary $sta_group $sta_mode
    puts $fo "<tr>"
    puts $fo "<th><a href=$sta_mode/index.htm>$sta_mode</a></th>"
    foreach sta_check $STA_CHECK_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
        set corner_list $STA_CORNER($sta_mode,$sta_check)
        puts $fo "<td>"
        puts $fo "<a href=$sta_mode/$sta_check.htm>"
        puts $fo "<iframe src=$sta_mode/$sta_check.nvp_wns.htm width=600 height=250>"
        puts $fo "<img src=$sta_mode/$sta_check.nvp_wns.png width=600 height=250>"
        puts $fo "</iframe>"
        puts $fo "</a>"
        puts $fo "</td>"
      } else {
        set corner_list ""
        puts $fo "<td></td>"
      }
    }
    puts $fo "</tr>"
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}


#
# <Title>
#   Create STA Check index file for STA_GROUP
#
# <Output>
#   $sta_group/check.htm
#
proc report_index_group_check {sta_group} {
  variable STA_CURR_RUN
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER

  file mkdir $sta_group
  puts "\[$sta_group\] INFO: Generating Check Index HTML Files ..."
  set fo [open "$sta_group/check.htm" "w"]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "<table border=0 width=1000 id='sta_tbl' bgcolor=#f0f0f0><tr>"
  puts $fo "<td align=left>"
  puts $fo "\[<a href=index.htm>\@Index</a>\]"
  puts $fo "\[<a href=mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=check.htm>\@Check</a>\]"
  puts $fo "\[<a href=corner.htm>\@Corner</a>\]"
  puts $fo "</td>"
  puts $fo "<td width=250 align=right>"
  puts $fo "<a href=$::STA_HTML::LINK(logo_banner)>"
  puts $fo "<img src=../$::STA_HTML::ICON(logo_banner) width=250 height=40>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "</tr></table>"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=1 width=1000 id='sta_tbl'>"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "$STA_CURR_RUN/$sta_group/</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th>Check</th>"
  foreach sta_mode $STA_MODE_LIST {
    puts $fo "<th><a href=$sta_mode/index.htm>$sta_mode</a></th>"
  }
  puts $fo "</tr>"
  foreach sta_check $STA_CHECK_LIST {
    report_check_summary $sta_group $sta_check
    puts $fo "<tr>"
    puts $fo "<td bgcolor=#80c0c0><a href=$sta_check.htm>$sta_check</a></td>"
    foreach sta_mode $STA_MODE_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
        set corner_list $STA_CORNER($sta_mode,$sta_check)
        puts $fo "<td><a href=$sta_mode/$sta_check.htm>NVP</a><hr>"
        puts $fo "<iframe src=$sta_mode/$sta_check.nvp_wns.dat width=250 height=150></iframe>" 
        puts $fo "</td>"
      } else {
        set corner_list ""
        puts $fo "<td></td>"
      }
    }
    puts $fo "</tr>"
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}


#
# <Title>
#   Create STA Corner index file for STA_GROUP
#
# <Output>
#   $sta_group/corner.htm
#
proc report_index_group_corner {sta_group} {
  variable STA_CURR_RUN
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER_LIST
  variable STA_CORNER
  variable STA_CORNER_NAME
  variable STA_CORNER_DEF
  variable STA_SCENARIO_MAP
  variable VIO_FILE

  file mkdir $sta_group
  puts "\[$sta_group\] INFO: Generating Corner Index HTML Files ..."
  set fo [open "$sta_group/corner.htm" "w"]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "<table border=0 width=1000 id='sta_tbl' bgcolor=#f0f0f0><tr>"
  puts $fo "<td align=left>"
  puts $fo "\[<a href=index.htm>\@Index</a>\]"
  puts $fo "\[<a href=mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=check.htm>\@Check</a>\]"
  puts $fo "\[<a href=corner.htm>\@Corner</a>\]"
  puts $fo "</td>"
  puts $fo "<td width=250 align=right>"
  puts $fo "<a href=$::STA_HTML::LINK(logo_banner)>"
  puts $fo "<img src=../$::STA_HTML::ICON(logo_banner) width=250 height=40>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "</tr></table>"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=1 width=1000 id='sta_tbl'>"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "$STA_CURR_RUN/$sta_group/"
  puts $fo "</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th>Corner</th>"
  puts $fo "<th>Name</th>"
  puts $fo "<th>Definition</th>"
  foreach sta_check $STA_CHECK_LIST {
    foreach sta_mode $STA_MODE_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
         puts $fo "<th>"
         puts $fo "<a href=$sta_mode/$sta_check.htm>"
         puts $fo "$sta_check"
         puts $fo "<br>"
         puts $fo "$sta_mode"
         puts $fo "</a>"
         puts $fo "</th>"
      } else {
         puts $fo "<th>"
         puts $fo "$sta_check"
         puts $fo "<br>"
         puts $fo "$sta_mode"
         puts $fo "</th>"
      }
    }
  }
  puts $fo "</tr>"
  
#  set STA_CORNER_LIST [lsort -unique -increasing $STA_CORNER_LIST]
  foreach sta_corner $STA_CORNER_LIST {
    set corner_name    $STA_CORNER_NAME($sta_corner)
    set corner_detail  $STA_CORNER_DEF($sta_corner)
    puts $fo "<tr>"
    puts $fo "<td  bgcolor=#f0f080>$sta_corner</td>"
    puts $fo "<td  bgcolor=#f0f0c0>$corner_name</td>"
    puts $fo "<td  bgcolor=#f0f0c0>$corner_detail</td>"
    foreach sta_check $STA_CHECK_LIST {
      foreach sta_mode $STA_MODE_LIST {
        if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
           puts $fo "<td align=right bgcolor='#c0c0c0'></td>"
#          continue;
        } elseif {![info exist STA_SCENARIO_MAP($sta_check,$sta_mode,$sta_corner)]} {
           puts $fo "<td align=right bgcolor='#c0c0c0'></td>"
        } else {
           set vio_file $sta_group/$sta_mode/$sta_corner/$sta_check.vio
           if {![catch {open $vio_file r} fin]} {
             set nvp 0
             while {[gets $fin line] >= 0} { 
               if {![regexp {^(\#|\*)} $line]} {incr nvp }
             }
             close $fin
             if {$nvp!=0} {
               puts $fo "<td align=right>"
               puts $fo "<a href=$sta_mode/$sta_corner/$sta_check.vio>"
               puts $fo $nvp
               puts $fo "</a>"
               puts $fo "</td>"
             } else {
               puts $fo "<td align=right bgcolor=#80f080>.</td>" 
             }
           } else {
               puts $fo "<td align=right bgcolor=#f08080>*</td>" 
           }
        }
      }
    }
    puts $fo "</tr>"
  }
  puts $fo "</table>"
  puts $fo "<pre>* Missing STA report files</pre>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}


#
# <Title>
#   Create trend chart sorted by sta_group
#
# <Input>
#   $sta_group
#
# <Output>
#   index.$sta_group.htm
#
proc report_trend_group {{plot_dir ".trendchart"} {sta_group ""}} {
  variable STA_CURR_GROUP
  variable STA_DQI_LIST 
  variable STA_RUN_FILE
  variable STA_RUN_LIST
  variable STA_RUN_DIR
  variable STA_RUN_GROUPS
  variable STA_GROUP_LIST
  variable STA_GROUP_REPORT
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CHECK_DEF
  variable STA_CORNER_LIST
  variable STA_CORNER_NAME
  variable STA_CORNER
  variable STA_SCENARIO_MAP
  
  if {$sta_group == ""} { set sta_run $STA_CURR_GROUP }
  
  puts "\nINFO: Generating STA GROUP ($sta_group) Trend Index Files ..."
  set num_col [expr [llength $STA_CORNER_LIST]+[llength $STA_DQI_LIST]+2]

  file mkdir $plot_dir/$sta_group

  set fo [open "$plot_dir/$sta_group/index.htm" "w"]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "<table border=0 width=1000 id='sta_tbl' bgcolor=#f0f0f0><tr>"
  puts $fo "<td align=left>"
  puts $fo "\[<a href='../../index.htm'>\@RUNSET</a>\]"
  puts $fo "</td>"
  puts $fo "<td width=250 align=right>"
  puts $fo "<a href=$::STA_HTML::LINK(logo_banner)>"
  puts $fo "<img src=../../$::STA_HTML::ICON(logo_banner) width=250 height=40>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "</tr></table>"
  puts $fo "</head>"
  puts $fo "<body>"
  
  puts $fo "<table border=\"1\" width=1000 id=\"sta_tbl\">"
  puts $fo "<caption> $sta_group </caption>"
  puts $fo "<tr>"
  puts $fo "<td colspan=$num_col>"
  puts $fo "<iframe name=sta_output src='../../$STA_RUN_FILE' width=100% height=420 scrolling=auto></iframe>"
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
         file mkdir $plot_dir/$sta_group/$sta_mode
         set fdat [open "$plot_dir/$sta_group/$sta_mode/$sta_check.nvp_wns.dat" w]
         puts $fdat "# $sta_mode/$sta_check"
         puts $fdat [format "#%10s %10s %10s" "----------" "----------" "----------"]
         puts $fdat [format "#%-10s %10s %10s" VERSION NVP WNS]
         puts $fdat [format "#%10s %10s %10s" "----------" "----------" "----------"]
         
         set num_row [expr [llength $STA_RUN_LIST]+2]
         puts $fo "<tr>"
#         puts $fo "<td rowspan=$num_row><a href=$sta_mode/$sta_check.nvp_wns.png target=sta_output>$sta_mode</a></td>"
         puts $fo "<td rowspan=$num_row><a href=$sta_mode/$sta_check.nvp_wns.htm target=sta_output>$sta_mode</a></td>"
         puts $fo "</tr>"
         foreach sta_run $STA_RUN_LIST {
            puts $fo "<tr>"
            if {[file exist $sta_run/$sta_group/$sta_mode/.dqi/520-STA/$sta_check]} {
#              puts $fo "<td align=left><a href='../../$sta_run/$sta_group/$sta_mode/$sta_check.htm'>$sta_run</a></td>"
#              puts $fo "<td align=right><a href='../../$sta_run/$sta_group/$sta_mode/$sta_check.nvp_wns.png' target=sta_output> $sta_run </a> </td>"
              puts $fo "<td align=right><a href='../../$sta_run/$sta_group/$sta_mode/$sta_check.nvp_wns.htm' target=sta_output> $sta_run </a> </td>"
              foreach sta_dqi $STA_DQI_LIST  {
                if {[catch {exec cat $sta_run/$sta_group/$sta_mode/.dqi/520-STA/$sta_check/$sta_dqi} dqi_value]} {
                  set STA_DQI($sta_dqi) "-"
                  puts $fo "<td align=right> - </td>"
                } else {
                  set STA_DQI($sta_dqi) $dqi_value
                  puts $fo "<td align=right>$dqi_value</td>"
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
         puts $fo "<tr>"
         puts $fo "<td colspan=[expr $num_col-1]></td>"
         puts $fo "</tr>"
         create_nvp_wns_plot  "$plot_dir/$sta_group/$sta_mode/$sta_check"
         create_nvp_wns_chart "$plot_dir/$sta_group/$sta_mode/$sta_check"
      }
    }
    puts $fo "<tr>"
    puts $fo "<td colspan=$num_col></td>"
    puts $fo "</tr>"
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

proc report_sta_report_directory {} {
  variable STA_RUN_LIST
  variable STA_RUN_DIR
         foreach sta_run $STA_RUN_LIST {
            puts $fo "<tr>"
            puts $fo "<td>$sta_run</td>"
              if [info exist STA_RUN_DIR($sta_run)] {
                 set sta_report [file normalize $STA_RUN_DIR($sta_run)]
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
