#!/usr/bin/tclsh
#
# Create HTML Report fome STA Timing Report File
#
# By Albert Li 
# 2020/07/02
#

puts "INFO: Loading 'LIB_STA.tcl'..."
namespace eval LIB_STA {
global env
global STA2HTM  

variable STA_RUN_FILE   "sta2htm.run"
variable STA_CFG_FILE   "sta2htm.cfg"
variable STA_CFG_DIR    ".sta"
variable STA_CFG_PATH   "STA/.sta .sta ."

variable STA_CURR_RUN	"."
variable STA_CURR_GROUP ""
variable STA_RPT_PATH   "STA"
variable STA_CURR_REPORT   ""


variable STA_RUN_LIST    ""
variable STA_RUN_DIR
variable STA_RUN_GROUPS
variable STA_GROUP_LIST  ""
variable STA_GROUP_REPORT
variable STA_CHECK_LIST  ""
variable STA_CHECK_DEF
variable STA_MODE_LIST   ""
variable STA_MODE_DEF
variable STA_CORNER_LIST ""
variable STA_CORNER_NAME
variable STA_CORNER_DEF
variable STA_CORNER
variable STA_SCENARIO_LIST
variable STA_SCENARIO_DEF
variable STA_SCENARIO_MAP 


variable STA_DATA
variable VIO_FILE  
variable VIO_LIST  ""
variable MET_LIST  ""
variable WAV_LIST  ""
variable VIO_WNS       
variable NVP_GP
variable NVP_WAIVED_GP
variable NVP_REAL_GP
variable WNS_GP
variable WNS_HRANGE  "0 -1 -2 -3 -4 -5 -10 -15 -20 -30 -40 -50 -100 -200 -300 -500 -1000"
variable NVP_ACCUM
variable NVP_REAL
variable STA_DQI_LIST  "NVP WNS TNS"


# SETUP
#set STA_CORNER(func,setup) "001 002 003 004"

proc init {} {
  global env
  global STA2HTM
  variable STA_CURR_RUN

  set STA2HTM [file dirname [file dirname [file normalize [info script]]]]
  puts "###########################################################"
  puts "# STA2HTM LIBRARY ver.2021.2                             #"
  puts "###########################################################"
  puts "INFO: STA2HTM = $STA2HTM"
  
  uplevel 1 source $STA2HTM/tcl/STA_HTML.tcl
  uplevel 1 source $STA2HTM/tcl/STA_CONFIG.tcl
  uplevel 1 source $STA2HTM/tcl/STA_INDEX.tcl
  uplevel 1 source $STA2HTM/tcl/STA_CHART.tcl
  uplevel 1 source $STA2HTM/tcl/STA_PLOT.tcl
  uplevel 1 source $STA2HTM/tcl/STA_CORNER.tcl
  uplevel 1 source $STA2HTM/tcl/STA_WAIVE.tcl
  uplevel 1 source $STA2HTM/tcl/STA_PT.tcl
  uplevel 1 source $STA2HTM/tcl/STA_MERGE.tcl
  uplevel 1 source $STA2HTM/tcl/STA_HISTOGRAM.tcl
  uplevel 1 source $STA2HTM/tcl/STA_CLOCK.tcl
  uplevel 1 source $STA2HTM/tcl/STA_BLOCK.tcl
  uplevel 1 source $STA2HTM/tcl/STA_COMP.tcl
  
  set STA_CURR_RUN [file tail $env(PWD)]
}

proc parse_argv { {argv ""} } {
  variable STA_CFG_DIR
  variable STA_CURR_RUN
  variable STA_CURR_GROUP 
  variable STA_CURR_REPORT
  variable STA_GROUP_LIST
  variable STA_CORNER_LIST
  variable STA_MODE_LIST
  variable STA_CHECK_LIST

  puts "INFO: Parsing Command Line Arguments.."
  set argc [llength $argv]
  set i 0
  while {$i<$argc} {
    set arg [lindex $argv $i]
    case $arg in {
      -runset {
         incr i 
         read_sta_runset [lindex $argv $i]
      }
      -config {
         incr i 
         read_sta_config [lindex $argv $i]
      }
      -sta_run {
         incr i
         set STA_CURR_RUN [lindex $argv $i]
         puts "STA_CURR_RUN = $STA_CURR_RUN"
      }
      -sta_group {
         incr i
         set STA_CURR_GROUP [lindex $argv $i]
         puts "STA_CURR_GROUP = $STA_CURR_GROUP"
      }
      -sta_group_report {
         incr i
         set STA_CURR_REPORT [lindex $argv $i]
         puts "STA_CURR_REPORT = $STA_CURR_REPORT"
      }
      -sta_group_list {
         incr i
         set STA_GROUP_LIST [lindex $argv $i]
         puts "STA_GROUP_LIST = $STA_GROUP_LIST"
      }
      -sta_corner_list {
         incr i
         set STA_CORNER_LIST [lindex $argv $i]
         puts "STA_CORNER_LIST = $STA_CORNER_LIST"
      }
      -sta_mode_list {
         incr i
         set STA_MODE_LIST [lindex $argv $i]
         puts "STA_MODE_LIST = $STA_MODE_LIST"
      }
      -sta_check_list {
         incr i
         set STA_CHECK_LIST [lindex $argv $i]
         puts "STA_CHECK_LIST = $STA_CHECK_LIST"
      }
      -slack_offset {
         incr i
         read_slack_offset [lindex $argv $i]
      }
      default {
         puts "INFO: Unused parameter '$i'"
      }
    }
    incr i
  }
}


#
# <Title>
#   Uniquify Endpoint Main Program
#
# <Input>
#
# <Output>
#
#
proc report_uniq_end {{sta_group ""} {sta_rpt_file ""}} {
  variable STA_RPT_PATH
  variable STA_CURR_REPORT
  variable STA_CURR_GROUP
  variable STA_GROUP_REPORT
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER

  if {$sta_group!=""} {
     set STA_CURR_GROUP $sta_group
     if [info exist STA_GROUP_REPORT($sta_group)] {
        set STA_CURR_REPORT $STA_GROUP_REPORT($sta_group)
     }
  } elseif {$STA_CURR_GROUP!=""} {
     set sta_group $STA_CURR_GROUP   
  } else {
     set sta_group "uniq_end"
     set STA_CURR_GROUP $sta_group
  }
  if {$sta_rpt_file!=""} {
     set STA_CURR_REPORT $sta_rpt_file
  } elseif {$STA_CURR_REPORT!=""} {
     set sta_rpt_file $STA_CURR_REPORT
  } else {
     set STA_CURR_REPORT {$sta_mode/$corner_name/$sta_check.rpt*}
  }

  foreach sta_check $STA_CHECK_LIST {
    foreach sta_mode $STA_MODE_LIST {
       if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
          puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
          continue 
      }
      puts "\nMODE: $sta_mode $sta_check"

      parse_primetime_report $sta_group $sta_mode $sta_check $STA_RPT_PATH $STA_CURR_REPORT 

    }

    foreach sta_mode $STA_MODE_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
        set corner_list $STA_CORNER($sta_mode,$sta_check)

        unique_vio_endpoint $sta_group $sta_mode $sta_check $corner_list

        report_endpoint_text $sta_group $sta_mode $sta_check $corner_list
        report_endpoint_html $sta_group $sta_mode $sta_check $corner_list
        report_wavpoint_html $sta_group $sta_mode $sta_check $corner_list

        report_index_clock $sta_group $sta_mode $sta_check $corner_list
        report_index_block $sta_group $sta_mode $sta_check $corner_list

        report_vio_histogram $sta_group $sta_mode $sta_check.uniq_end

        report_scenario_summary $sta_group $sta_mode $sta_check

      }
    }
  }
}



#
# <Title>
# Report One Page Summary of the STA Scenario
#
# <Output>
# $sta_group/$sta_mode/$sta_check.htm
#

proc report_scenario_summary {sta_group sta_mode sta_check} {
  variable STA_CURR_RUN
  variable STA_CORNER
  variable STA_DATA

  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return 
  }

  create_nvp_wns_plot "$sta_group/$sta_mode/$sta_check" $STA_CURR_RUN/
  create_nvp_wns_chart "$sta_group/$sta_mode/$sta_check" $STA_CURR_RUN/
    
  set fo [open "$sta_group/$sta_mode/$sta_check.htm" w]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "<table border=0 width=1100 id='sta_tbl' bgcolor=#f0f0f0><tr>"
  puts $fo "<td align=left>"
  puts $fo "\[<a href=../index.htm>\@Index</a>\]"
  puts $fo "\[<a href=../mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=../check.htm>\@Check</a>\]"
  puts $fo "\[<a href=../corner.htm>\@Corner</a>\]"
  puts $fo "</td>"
  puts $fo "<td width=250 align=right>"
  puts $fo "<a href=http://www.lyg-semi.com/lyg_www/about.html>"
  puts $fo "<img src=../../../$::STA_HTML::ICON(logo_banner) width=250 height=40>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "</tr></table>"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=1 width=1100 id='sta_tbl'>"
  puts $fo "<caption>"
  puts $fo "<h3 align=left>"
  puts $fo "$STA_CURR_RUN/$sta_group/$sta_mode/$sta_check"
  puts $fo "</h3>"
  puts $fo "</caption>"
  puts $fo "<tr><td colspan=10>"
  puts $fo "<a href=../mode.htm>"
  puts $fo "<iframe name=sta_chart src='$sta_check.nvp_wns.htm' width=800 height=350>"
  puts $fo "<img src=$sta_check.nvp_wns.png  width=800 height=350>"
  puts $fo "</iframe>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "<td>"
  puts $fo "<iframe name=sta_info src=\"$sta_check.uniq_end.nvp\" height=350></iframe>"
  puts $fo "</td>"
  puts $fo "</tr>"
  puts $fo "<tr>"
  puts $fo "<th><a href=$sta_check.uniq_end.rpt target=sta_output>#</a></th>"
  puts $fo "<th><a href=index.htm>Mode</a></th>"
  puts $fo "<th><a href=../$sta_check.htm>Check</a></th>"
  puts $fo "<th><a href=../corner.htm>Corner</a></th>"
  puts $fo "<th><a href=$sta_check.waive_end.rpt target=sta_output>Waive</a></th>"
  puts $fo "<th><a href=$sta_check.uniq_end.rpt target=sta_output>NVP</a></th>"
  puts $fo "<th><a href=$sta_check.uniq_end.wns target=sta_output>WNS</a></th>"
  puts $fo "<th><a href=$sta_check.uniq_end.nvp target=sta_output>TNS</a></th>"
  puts $fo "<th><a href=$sta_check.clk.htm target=sta_output>Clock</a></th>"
  puts $fo "<th><a href=$sta_check.blk.htm target=sta_output>Block</a></th>"
  puts $fo "<th><a href=$sta_check.uniq_end.htm>Unique Endpoint</a>"
  puts $fo "</tr>"
  puts $fo ""

  set WNS 0.0
  set TNS 0.0
  set fid 0
  foreach sta_corner $STA_CORNER($sta_mode,$sta_check) {
    if {[info exist STA_DATA($sta_mode,$sta_check,$sta_corner)]} {
      foreach data $STA_DATA($sta_mode,$sta_check,$sta_corner) {
        incr fid
        set corner_name [lindex $data 0]
        set fname  [lindex $data 1]
        set nwp    [lindex $data 2]
        set nvp    [lindex $data 3]
        set wns    [lindex $data 4]
        set tns    [lindex $data 5]
        set cid    [lindex $data 6]
        set bid    [lindex $data 7]

        if {$wns<$WNS} { set WNS $wns}
        set TNS [expr ($TNS+$tns)]
        
        puts $fo "<tr>"
        puts $fo "<td>$fid</td>"
        puts $fo "<td>$sta_mode</td>"
        puts $fo "<td>$sta_check</td>"
        puts $fo "<td align=left>$sta_corner</td>"
        if {$nwp>0} {
        puts $fo "<td align=center><a href=$sta_corner/$sta_check.htm> $nwp</a> </td>"
        } else {
        puts $fo "<td align=center> . </td>"
        }
        if {$nvp>0} {
        puts $fo "<td align=right><a href=$sta_corner/$sta_check.vio target=sta_output> $nvp </a></td>"
        puts $fo "<td align=right><a href=$sta_corner/$sta_check.wns target=sta_output> $wns </a></td>"
        puts $fo "<td align=right><a href=$sta_corner/$sta_check.nvp target=sta_output>$tns</a></td>"
        puts $fo "<td align=center><a href=$sta_corner/$sta_check.clk.htm target=sta_output> $cid </a></td>"
        puts $fo "<td align=center><a href=$sta_corner/$sta_check.blk.htm target=sta_output> $bid </a></td>"
        } else {
        puts $fo "<td align=right> $nvp </td>"
        puts $fo "<td align=right> $wns </td>"
        puts $fo "<td align=right> $tns </td>"
        puts $fo "<td align=center> $cid </td>"
        puts $fo "<td align=center> $bid </td>"
        }
        puts $fo "<td><a href=\"../../$fname\" target=sta_output>$fname</a></td>"
        puts $fo "</tr>"
      }
    }
  }
  puts $fo "<tr>"
  puts $fo "<th></th>"
  puts $fo "<th></th>"
  puts $fo "<th></th>"
  puts $fo "<th></th>"
  puts $fo "<th></th>"
  puts $fo "<th></th>"
  puts $fo "<th>[format "%.2f" $WNS]</th>"
  puts $fo "<th>[format "%.2f" $TNS]</th>"
  puts $fo "<th></th>"
  puts $fo "<th></th>"
  puts $fo "<th>"
  puts $fo "</th>"
  puts $fo "</tr>"
  puts $fo "<tr>"
  puts $fo "<td colspan=11>"
  puts $fo "<iframe name=sta_output src='$sta_check.uniq_end.rpt' width=100% height=350 scrolling=auto></iframe>"
  puts $fo "</td>"
  puts $fo "</tr>"
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo

}


#
# <Title>
#   Create Summary Page of the STA_MODE
#
# <Output>
#   $sta_group/$sta_mode/index.htm
#
proc report_mode_summary {sta_group sta_mode} {
  variable STA_CURR_RUN
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER

  file mkdir $sta_group/$sta_mode
  puts "\[$sta_group\] INFO: Generating Mode Summary Page ($sta_mode) ..."
  set fo [open "$sta_group/$sta_mode/index.htm" "w"]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "<table border=0 width=1000 id='sta_tbl' bgcolor=#f0f0f0><tr>"
  puts $fo "<td align=left>"
  puts $fo "\[<a href=../index.htm>\@Index</a>\]"
  puts $fo "\[<a href=../mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=../check.htm>\@Check</a>\]"
  puts $fo "\[<a href=../corner.htm>\@Corner</a>\]"
  puts $fo "</td>"
  puts $fo "<td width=250 align=right>"
  puts $fo "<a href=http://www.lyg-semi.com/lyg_www/about.html>"
  puts $fo "<img src=../../$::STA_HTML::ICON(logo_banner) width=250 height=40>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "</tr></table>"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=1 width=1000 id='sta_tbl'>"
  puts $fo "<caption><h3 align=\"left\">$STA_CURR_RUN/$sta_group/"
  foreach mode $STA_MODE_LIST {
    puts $fo "<a href=../$mode/index.htm>($mode)</a>"
  }
  puts $fo "</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th>Mode</th>"
  foreach sta_check $STA_CHECK_LIST {
    puts $fo "<td bgcolor='#80c0c0'><a href=../$sta_check.htm>$sta_check</a></td>"
  }
  puts $fo "</tr>"
  
  puts $fo "<tr>"
  puts $fo "<th><a href=../$sta_mode/index.htm>$sta_mode</a></th>"
  foreach sta_check $STA_CHECK_LIST { 
    puts $fo "<td>"
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
      puts $fo "<a href=$sta_check.htm>"
      puts $fo "<iframe name=sta_chart src='$sta_check.nvp_wns.htm' width=600 height=250>"
      puts $fo "<img src=$sta_check.nvp_wns.png width=600>"
      puts $fo "</iframe>"
      puts $fo "</a>"
    }
    puts $fo "</td>"
  }
  puts $fo "</tr>"

  puts $fo "<tr>"
  puts $fo "<th></th>"
  foreach sta_check $STA_CHECK_LIST { 
    puts $fo "<td>"
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
      puts $fo "<iframe src=$sta_check.uniq_end.wns width=100% height=400></iframe>" 
    }
    puts $fo "</td>"
  }
  puts $fo "</tr>"

  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}


#
# <Title>
#   Create Summary Page of the STA_CHECK
#
# <Input>
#
# <Output>
#   $sta_group/$sta_check.htm
#
proc report_check_summary {sta_group sta_check} {
  variable STA_CURR_RUN
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER
  variable STA_POSTFIX
  

  puts "\[$sta_group\] INFO: Generating Check Summary Page ($sta_check) ..."
  set fo [open "$sta_group/$sta_check.htm" "w"]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "<table border=0 width=1000 id='sta_tbl' bgcolor=#f0f0f0><tr>"
  puts $fo "<td align=left>"
  puts $fo "\[<a href=../index.htm>\@Index</a>\]"
  puts $fo "\[<a href=../mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=../check.htm>\@Check</a>\]"
  puts $fo "\[<a href=../corner.htm>\@Corner</a>\]"
  puts $fo "</td>"
  puts $fo "<td width=250 align=right>"
  puts $fo "<a href=http://www.lyg-semi.com/lyg_www/about.html>"
  puts $fo "<img src=../../$::STA_HTML::ICON(logo_banner) width=250>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "</tr></table>"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=1 width=1000 id='sta_tbl'>"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "$STA_CURR_RUN/$sta_group/"
  foreach check $STA_CHECK_LIST {
    puts $fo "(<a href=$check.htm>$check</a>)"
  }
  puts $fo "</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th>Mode</th>"
  puts $fo "<td bgcolor=#80c0c0><a href=$sta_check.htm>$sta_check</a></td>"
  puts $fo "<th></th>"
  puts $fo "</tr>"
  foreach sta_mode $STA_MODE_LIST {
    puts $fo "<tr>"
    puts $fo "<th><a href=$sta_mode/index.htm>$sta_mode</a></th>"
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
      puts $fo "<td>"
      puts $fo "<a href=$sta_mode/$sta_check.htm>"
      puts $fo "<iframe name=sta_chart src='$sta_mode/$sta_check.nvp_wns.htm' width=600 height=250>"
      puts $fo "<img src=$sta_mode/$sta_check.nvp_wns.png width=600>"
      puts $fo "</iframe>"
      puts $fo "</a>"
      puts $fo "</td>"
      puts $fo "<td>"
      puts $fo "<iframe src=\"$sta_mode/$sta_check.nvp_wns.dat\" height=\"250\" width=\"250\"></iframe>"
      puts $fo "</td>"
    } else {
    }
    puts $fo "</tr>"
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}



# <Title>
#   Generate Violation Endpint Text Report
#
# <Input>
#   VIO_LIST : (($egroup,$epoint) $wns $wcorner)
#   VIO_WNS($egroup,$epoint,sta_corner) : $wns
#
# <Output>
#   $sta_group/$sta_mode/$sta_check.uniq_end.rpt
#   $sta_group/$sta_mode/$sta_check.waive_end.rpt
#
proc report_endpoint_text {sta_group sta_mode sta_check {corner_list ""}} {
  variable STA_CORNER
  variable VIO_FILE
  variable VIO_LIST
  variable VIO_WNS
  variable WAV_LIST

  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "ERROR: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return -1
  }

  reset_waive_list
  read_waive_list all
  read_waive_list $sta_mode
  set waive_cnt 0
  puts "\[$sta_mode\] INFO: Generating waived endpoint TEXT format report.."
  set f0 [open "$sta_group/$sta_mode/$sta_check.waive_end.rpt" w]
  set fout $f0
  puts -nonewline $fout [format "%8s|" "No"]
  foreach sta_corner $corner_list {
     puts -nonewline $fout [format "%8s " $sta_corner]
  }
  puts -nonewline $fout [format "| %8s " WNS]
  puts -nonewline $fout [format "| %8s " WCorner]
  puts -nonewline $fout [format "| %-40s " PathGroup]
  puts -nonewline $fout [format "| %s" InstancePin]
  puts $fout "" 
  puts -nonewline $fout [format "%8s" "--------"]
  foreach sta_corner $corner_list {
     if [info exist WAV_FILE($sta_mode,$sta_check,$sta_corner)] { 
        puts -nonewline $fout [format "+%8s" "--------"]
     } else {
        puts -nonewline $fout [format "+%8s" "xxxxxxxx"]
     }
  }
  puts -nonewline $fout [format "-+-%8s" "--------"]
  puts -nonewline $fout [format "-+-%8s" "--------"]
  puts -nonewline $fout [format "-+-%-40s-+" "----------------------------------------"]
  puts -nonewline $fout [format "%s"     "----------------------------------------"]
  puts $fout "" 

  foreach item $WAV_LIST {
      foreach {key slack wcorner} $item { foreach {egroup epoint} $key {}}
      #foreach {egroup epoint slack wcorner} $item {}
      if {[check_waive_slack $slack $egroup $epoint]==1} {
         incr waive_cnt
         set mark "@"
         puts -nonewline $fout [format "%8s|" $waive_cnt]
      } else {
         set mark "|"
      }
      foreach sta_corner $corner_list {
         if [info exist VIO_WNS($egroup,$epoint,$sta_corner)] { 
            puts -nonewline $fout [format "%8.2f " $VIO_WNS($egroup,$epoint,$sta_corner)]
         } else {
            puts -nonewline $fout [format "%8s " ". "]
         }
      }
      puts -nonewline $fout [format "| %8.2f " $slack]
      puts -nonewline $fout [format "%1s %8s " $mark $wcorner]
      puts -nonewline $fout [format "| %-40s " $egroup]
      puts -nonewline $fout [format ": %s" $epoint]
      puts $fout "" 
  }

  set uniq_cnt 0
  puts "\[$sta_mode\] INFO: Generating unique endpoint TEXT format report.."
  set f1 [open "$sta_group/$sta_mode/$sta_check.uniq_end.rpt" w]
  set fout $f1
  puts -nonewline $fout [format "%8s|" "No"]
  foreach sta_corner $corner_list {
     puts -nonewline $fout [format "%8s " $sta_corner]
  }
  puts -nonewline $fout [format "| %8s " WNS]
  puts -nonewline $fout [format "| %8s " WCorner]
  puts -nonewline $fout [format "| %-40s " PathGroup]
  puts -nonewline $fout [format "| %s" InstancePin]
  puts $fout "" 
  puts -nonewline $fout [format "%8s" "--------"]
  foreach sta_corner $corner_list {
     if [info exist VIO_FILE($sta_mode,$sta_check,$sta_corner)] { 
        puts -nonewline $fout [format "+%8s" "--------"]
     } else {
        puts -nonewline $fout [format "+%8s" "xxxxxxxx"]
     }
  }
  puts -nonewline $fout [format "-+-%8s" "--------"]
  puts -nonewline $fout [format "-+-%8s" "--------"]
  puts -nonewline $fout [format "-+-%-40s-+" "----------------------------------------"]
  puts -nonewline $fout [format "%s"     "----------------------------------------"]
  puts $fout "" 

  set fout $f1
  foreach item $VIO_LIST {
      foreach {key slack wcorner} $item { foreach {egroup epoint} $key {}}
      #foreach {egroup epoint slack wcorner} $item {}
      if {[check_waive_slack $slack $egroup $epoint]==1} {
         incr waive_cnt
         set mark "@"
         set fout $f0
         puts -nonewline $fout [format "%8s|" $waive_cnt]
      } else {
         incr uniq_cnt
         set mark "|"
         set fout $f1
         puts -nonewline $fout [format "%8s|" $uniq_cnt]
      }
      
      foreach sta_corner $corner_list {
         if [info exist VIO_WNS($egroup,$epoint,$sta_corner)] { 
            puts -nonewline $fout [format "%8.2f " $VIO_WNS($egroup,$epoint,$sta_corner)]
         } else {
            puts -nonewline $fout [format "%8s " ". "]
         }
      }
      puts -nonewline $fout [format "| %8.2f " $slack]
      puts -nonewline $fout [format "%1s %8s " $mark $wcorner]
      puts -nonewline $fout [format "| %-40s " $egroup]
      puts -nonewline $fout [format ": %s" $epoint]
      puts $fout "" 
  }
  close $f1
  close $f0
}

#
# <Title>
#   Generate Violation Endpoint HTML Report
#
# <Input>
# VIO_LIST : (($egroup,$epoint) $wns $wcorner)
# VIO_WNS($egroup,$epoint,sta_corner) : $wns
#
# <Output>
# $sta_group/$sta_mode/$sta_check.uniq_end.htm
#
proc report_endpoint_html {sta_group sta_mode sta_check {corner_list ""}} {
  variable STA_CURR_RUN
  variable STA_CORNER
  variable VIO_LIST
  variable VIO_WNS

  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return 
  }
  puts "\[$sta_mode\] INFO: Generating unique endpoint HTML format report.."
  set fout [open "$sta_group/$sta_mode/$sta_check.uniq_end.htm" w]
  puts $fout "<html>"
  puts $fout "<head>"
  puts $fout $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fout "</head>"
  puts $fout "<body>"
  puts $fout "<table border=1 id='sta_tbl'>"
  puts $fout "<caption><h3 align=left>"
  puts $fout "<a href=$sta_check.htm>"
  puts $fout "$STA_CURR_RUN/$sta_group/$sta_mode/$sta_check"
  puts $fout "</a>"
  puts $fout "</h3></caption>"
  puts $fout "<TR>"
  puts -nonewline $fout [format "<TH><pre>%8s</TH>" "No"]
  puts -nonewline $fout "<TH><pre>"
  foreach sta_corner $corner_list {
     puts -nonewline $fout [format "%8s " $sta_corner]
  }
  puts -nonewline $fout "</TH>"
  puts -nonewline $fout [format "<TH><pre>%8s</TH>" WNS]
  puts -nonewline $fout [format "<TH><pre>%8s</TH>" WCorner]
  puts -nonewline $fout [format "<TH><pre>%s</TH> " PathGroup]
  puts -nonewline $fout [format "<TH><pre>%s</TH>" InstancePin]
  puts $fout "</TR>"
  set uniq_cnt 0
  set waive_cnt 0
  foreach item $VIO_LIST {
      foreach {key slack wcorner} $item { foreach {egroup epoint} $key {}}
      if {[check_waive_slack $slack $egroup $epoint]==1} {
         incr waive_cnt
         set mark ">"
         continue
#         puts -nonewline $fout [format "<TR><TD><pre>%8s</TD>" $waive_cnt]
      } else {
         incr uniq_cnt
         set mark "@"
         puts -nonewline $fout [format "<TR><TD><pre>%8s</TD>" $uniq_cnt]
      }
      puts -nonewline $fout "<TD><pre>"
      foreach sta_corner $corner_list {
         if [info exist VIO_WNS($egroup,$epoint,$sta_corner)] { 
            puts -nonewline $fout [format "%8.2f " $VIO_WNS($egroup,$epoint,$sta_corner)]
         } else {
            puts -nonewline $fout [format "%8s " "."]
         }
      }
      puts -nonewline $fout "</TD>"
      puts -nonewline $fout [format "<TD><pre>%8.2f</TD>" $slack]
      puts -nonewline $fout [format "<TD><pre>%8s</TD>" $wcorner]
      puts -nonewline $fout [format "<TD ALIGN=\"left\"><pre>%s</pre></TD>" $egroup]
      puts -nonewline $fout [format "<TD ALIGN=\"left\"><pre>%s</pre></TD>" $epoint]
      puts $fout "</TR>"
  }
  puts $fout "</table>"
  puts $fout "</body>"
  puts $fout "</html>"
  close $fout
}

#
# <Title>
#   Generate Waived Endpint HTML Report
#
# <Input>
# WAV_LIST : (($egroup,$epoint) $wns $wcorner)
# VIO_WNS($egroup,$epoint,sta_corner) : $wns
#
# <Output>
# $sta_group/$sta_mode/$sta_check.waive_end.htm
#
proc report_wavpoint_html {sta_group sta_mode sta_check {corner_list ""}} {
  variable STA_CURR_RUN
  variable STA_CORNER
  variable WAV_LIST
  variable VIO_WNS

  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return 
  }
  puts "\[$sta_mode\] INFO: Generating waived endpoint HTML format report.."
  set fout [open "$sta_group/$sta_mode/$sta_check.waive_end.htm" w]
  puts $fout "<html>"
  puts $fout "<head>"
  puts $fout $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fout "</head>"
  puts $fout "<body>"
  puts $fout "<table border=1 id='sta_tbl'>"
  puts $fout "<caption><h3 align=left>"
  puts $fout "<a href=$sta_check.htm>"
  puts $fout "$STA_CURR_RUN/$sta_group/$sta_mode/$sta_check"
  puts $fout "</a>"
  puts $fout "</h3></caption>"
  puts $fout "<TR>"
  puts -nonewline $fout [format "<TH><pre>%8s</TH>" "No"]
  puts -nonewline $fout "<TH><pre>"
  foreach sta_corner $corner_list {
     puts -nonewline $fout [format "%8s " $sta_corner]
  }
  puts -nonewline $fout "</TH>"
  puts -nonewline $fout [format "<TH><pre>%8s</TH>" WCorner]
  puts -nonewline $fout [format "<TH><pre>%s</TH> " PathGroup]
  puts -nonewline $fout [format "<TH><pre>%s</TH>" InstancePin]
  puts $fout "</TR>"
  set uniq_cnt 0
  set waive_cnt 0
  foreach item $WAV_LIST {
      foreach {key slack wcorner} $item { foreach {egroup epoint} $key {}}
      incr waive_cnt
      puts -nonewline $fout [format "<TR><TD><pre>%8s</TD>" $waive_cnt]
      puts -nonewline $fout "<TD><pre>"
      foreach sta_corner $corner_list {
         if [info exist VIO_WNS($egroup,$epoint,$sta_corner)] { 
            puts -nonewline $fout [format "%8.2f " $VIO_WNS($egroup,$epoint,$sta_corner)]
         } else {
            puts -nonewline $fout [format "%8s " "."]
         }
      }
      puts -nonewline $fout "</TD>"
      puts -nonewline $fout [format "<TD><pre>%8.2f</TD>" $slack]
      puts -nonewline $fout [format "<TD><pre>%8s</TD>" $wcorner]
      puts -nonewline $fout [format "<TD ALIGN=\"left\"><pre>%s</pre></TD>" $egroup]
      puts -nonewline $fout [format "<TD ALIGN=\"left\"><pre>%s</pre></TD>" $epoint]
      puts $fout "</TR>"
  }
  puts $fout "</table>"
  puts $fout "</body>"
  puts $fout "</html>"
  close $fout
}


}

::LIB_STA::init

