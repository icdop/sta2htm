#!/usr/bin/tclsh
#
# Parse Timing Report File
#
# By Albert Li 
# 2020/07/02
#
# package require LIB_WAIVE
# package require LIB_CORNER
# package require LIB_PLOT
# package require LIB_HTML

puts "INFO: Loading 'LIB_STA.tcl'..."
namespace eval LIB_STA {
global env

variable STA_CURR_RUN	"."
variable STA_CFG_DIR    ".sta"
variable STA_SUM_DIR    "uniq_end"
variable STA_RPT_ROOT    "STA"
variable STA_RPT_PATH    {$sta_mode/$sta_corner\_*/rpt/$sta_check}
variable STA_RPT_FILE    {RptTimeCnst$sta_postfix.rpt*}
variable STA_POSTFIX    ""

variable STA_DATA
variable STA_CHECK      "setup"
variable STA_CHECK_LIST "setup hold"
variable STA_MODE_LIST  ""
variable STA_CORNER     
variable STA_CORNER_NAME 
variable STA_CORNER_LIST ""

variable VIO_FILE  
variable VIO_LIST  ""
variable MET_LIST  ""
variable WAV_LIST  ""
variable VIO_WNS       
variable NVP_GP
variable NVP_WAIVED_GP
variable NVP_REAL_GP
variable WNS_GP
variable WNS_HRANGE  "0 -1 -2 -3 -4 -5 -10 -15 -20 -25 -30 -40 -50 -100 -150 -200 -300 -500 -1000"
variable NVP_ACCUM
variable NVP_REAL


# SETUP
#set STA_CORNER(func,setup) "001 002 003 004"

proc init {} {
  global env
  global STA_HOME
  variable STA_CURR_RUN
  
  uplevel 1 source $STA_HOME/tcl/STA_CORNER.tcl
  uplevel 1 source $STA_HOME/tcl/STA_WAIVE.tcl
  uplevel 1 source $STA_HOME/tcl/STA_PT.tcl
  uplevel 1 source $STA_HOME/tcl/STA_MERGE.tcl
  uplevel 1 source $STA_HOME/tcl/STA_CLOCK.tcl
  uplevel 1 source $STA_HOME/tcl/STA_BLOCK.tcl
  uplevel 1 source $STA_HOME/tcl/STA_GROUP.tcl
  uplevel 1 source $STA_HOME/tcl/STA_CHART.tcl
  uplevel 1 source $STA_HOME/tcl/STA_COMP.tcl
  
  set STA_CURR_RUN [file tail $env(PWD)]
}

proc parse_argv { {argv ""} } {
  variable STA_CFG_DIR
  variable STA_SUM_DIR 
  variable STA_RPT_ROOT
  variable STA_RPT_PATH
  variable STA_RPT_FILE
  variable STA_CORNER_LIST
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CHECK
  variable STA_POSTFIX

  puts $argv
  set argc [llength $argv]
  set i 0
  while {$i<$argc} {
    set arg [lindex $argv $i]
    case $arg in {
      -config {
         incr i 
         read_config [lindex $argv $i]
      }
      -cfg_dir {
         incr i
         set STA_CFG_DIR [lindex $argv $i]
         puts "STA_CFG_DIR = $STA_CFG_DIR"
      }
      -sta_dir {
         incr i
         set STA_RPT_ROOT [lindex $argv $i]
         puts "STA_RPT_ROOT = $STA_RPT_ROOT"
      }
      -sum_dir {
         incr i
         set STA_SUM_DIR [lindex $argv $i]
         puts "STA_SUM_DIR = $STA_SUM_DIR"
      }
      -sta_check {
         incr i
         set STA_CHECK [lindex $argv $i]
         puts "STA_CHECK = $STA_CHECK"
      }
      -sta_corner_list {
         incr i
         set STA_CORNER_LIST [lindex $argv $i]
         puts "STA_CORNER_LIST = $STA_CORNER_LIST"
      }
      -rpt_path {
         incr i
         set STA_RPT_PATH [lindex $argv $i]
         puts "STA_RPT_PATH = $STA_RPT_PATH"
      }
      -rpt_fil {
         incr i
         set STA_RPT_FILE [lindex $argv $i]
         puts "STA_RPT_FILE = $STA_RPT_FILE"
      }
      -rpt_postfix {
         incr i
         set STA_POSTFIX [lindex $argv $i]
         if {$STA_POSTFIX=="_"} { set STA_POST_FIX ""}
         puts "STA_POSTFIX = $STA_POSTFIX"
      }
      -sta_offset {
         incr i
         read_config [lindex $argv $i]
      }
      default {
         lappend STA_MODE_LIST $arg
      }
    }
    incr i
  }
}

proc read_config {{config "sta.cfg"}} {
  variable STA_CFG_DIR
  variable STA_RPT_ROOT
  variable STA_RPT_PATH
  variable STA_RPT_FILE
  variable STA_CORNER_LIST
  variable STA_CHECK_LIST
  variable STA_MODE_LIST
  variable STA_CHECK 
  variable STA_CORNER   
  variable SLACK_OFFSET

  if [file exist $config] {
     puts "INFO: Reading config file '$config'..."
     source $config
  } elseif [file exist $STA_CFG_DIR/$config] { 
     puts "INFO: Reading config file '$STA_CFG_DIR/$config'..."
     source $STA_CFG_DIR/$config
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
proc report_uniq_end {{sta_check ""} } {
  variable STA_MODE_LIST
  variable STA_CHECK
  variable STA_CORNER
  if {$sta_check==""} { set sta_check $STA_CHECK}

  set error 0
  foreach sta_mode $STA_MODE_LIST {
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
       set cnt [check_corner_list $STA_CORNER($sta_mode,$sta_check)]
       if {$cnt>0} {
          set error [expr $error+$cnt]
          puts "ERROR: STA_CORNER($sta_mode,$sta_check) has undefined corner!"
       } 
    }
  }

  if {$error>0} {
     puts "INFO: $error ERRORs found, please check the config file."
     return -1
  }

  generate_vio_endpoint $sta_check 

  foreach sta_mode $STA_MODE_LIST {
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
      set corner_list $STA_CORNER($sta_mode,$sta_check)

      merge_vio_endpoint $sta_mode $sta_check $corner_list

      report_endpoint_text $sta_mode $sta_check $corner_list
      report_endpoint_html $sta_mode $sta_check $corner_list
      report_wavpoint_html $sta_mode $sta_check $corner_list

      report_index_clock $sta_mode $sta_check $corner_list
      report_index_block $sta_mode $sta_check $corner_list

      report_slack_summary $sta_mode $sta_check.uniq_end

      report_sta_check $sta_mode $sta_check

    }
  }
  report_index_main
  report_index_mode
  report_index_check
  report_index_corner
}

#
# <Title>
#   Process STA Violation Reports of All Mode 
#
# <Input>
#   STA_CHECK ($sta_check)
#   STA_MODE_LIST ($sta_mode)
#   STA_CORNER($sta_mode,$sta_check)
#
# <Output>
#  Violation Endpoint Files of All Mode and All corners
#
proc generate_vio_endpoint {{sta_check ""} } {
  global env
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK
  variable STA_CORNER
  
  if {$sta_check==""} { set sta_check $STA_CHECK}

  foreach sta_mode $STA_MODE_LIST {
     if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
        puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
        continue 
    }
    puts "\nMODE: $sta_mode $sta_check"

    parse_timing_report $sta_mode $sta_check
#    create_check_chart $sta_mode $sta_check

  }
  report_check_summary $sta_check
}

# <Title> parse_timing_report
# #   Parsing PrimeTime STA Timing Violation Report
# #
# # <Input>
# # $STA_RPT_ROOT/$STA_RPT_PATH/$STA_RPT_FILE
# #   Ex: (STA/$sta_mode/$corner_name/rpt/$sta_check/RptTimCnst.rpt)
# #
# # <Output>
# # $STA_SUM_DIR/$sta_mode/$sta_check.htm
# # $STA_SUM_DIR/$sta_mode/$sta_check.nvp_wns.dat
# # $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.vio
#

#
# <Title>
#   Create master index.htm file
#
# <Output>
#   $STA_SUM_DIR/index.htm
#
proc report_index_main {} {
  variable STA_CURR_RUN
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER
  variable CORNER_NAME

  file mkdir $STA_SUM_DIR
  puts "INFO: Generating STA Index HTML Files ..."
  set fo [open "$STA_SUM_DIR/index.htm" "w"]
  puts $fo "<html>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "\[<a href=index.htm>\@Index</a>\]"
  puts $fo "\[<a href=mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=check.htm>\@Check</a>\]"
  puts $fo "\[<a href=corner.htm>\@Corner</a>\]"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "$STA_CURR_RUN/$STA_SUM_DIR/"
  puts $fo "</h3></caption>"
  foreach sta_check $STA_CHECK_LIST {
    puts $fo "<tr>"
    puts $fo "<th>Mode</th>"
    puts $fo "<th>Check</th>"
    puts $fo "<th>Corner</th>"
    puts $fo "<th>NVP</th>"
    puts $fo "<th>WNS</th>"
    puts $fo "<th>TNS</th>"
    puts $fo "<th>STA Report</th>"
    puts $fo "</tr>"
    foreach sta_mode $STA_MODE_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
         set num_corner [expr [llength $STA_CORNER($sta_mode,$sta_check)]+2]
         puts $fo "<tr>"
         puts $fo "<td rowspan=$num_corner><a href=$sta_mode/index.htm>$sta_mode</a></td>"
         puts $fo "<td rowspan=$num_corner><a href=$sta_mode/$sta_check.htm>$sta_check</a></td>"
         puts $fo "<td colspan=6></td>"
         puts $fo "</tr>"
         foreach sta_corner $STA_CORNER($sta_mode,$sta_check) {
            if {[info exist CORNER_NAME($sta_corner)]} {
               set corner_name $CORNER_NAME($sta_corner)
               puts $fo "<tr>"
               if {![catch {open $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.vio r} fin]} {
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
                 puts $fo "<td align=right><a href=$sta_mode/$sta_check/$corner_name.vio> $corner_name </a></td>"
                 puts $fo "<td align=right> $nvp </td>"
                 puts $fo "<td align=right> $wns </td>"
                 puts $fo "<td align=right> $tns </td>"
                 puts $fo "<td><a href=\"$fname\">$fname</a></td>"
               } else {
                  puts $fo "<td align=right>$corner_name</td>"
                  puts $fo "<td></td>"
                  puts $fo "<td></td>"
                  puts $fo "<td></td>"
                  puts $fo "<td>*</td>"
               }
               puts $fo "</tr>"
            } else {
               puts "ERROR: CORNER_NAME($sta_corner) is not defined, but is used in STA_CORNER($sta_mode,$sta_check)!"
            }
         }
         puts $fo "<tr>"
         puts $fo "<td colspan=6></td>"
         puts $fo "</td></tr>"
      }
    }
    puts $fo "<tr><td colspan=8>"
    puts $fo "</td></tr>"
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

#
# <Title>
# Create index file which contains a table of all combination of modes and checks
#
# <Output>
# $STA_SUM_DIR/mode.htm
#
proc report_index_mode {{sta_check_list ""}} {
  variable STA_CURR_RUN
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER

  if {$sta_check_list!=""} { set $STA_CHECK_LIST $sta_check_list}

  file mkdir $STA_SUM_DIR
  puts "INFO: Generating Mode Index HTML Files ..."
  set fo [open "$STA_SUM_DIR/mode.htm" "w"]
  puts $fo "<html>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "\[<a href=index.htm>\@Index</a>\]"
  puts $fo "\[<a href=mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=check.htm>\@Check</a>\]"
  puts $fo "\[<a href=corner.htm>\@Corner</a>\]"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "$STA_CURR_RUN/$STA_SUM_DIR/</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th>Mode</th>"
  foreach sta_check $STA_CHECK_LIST {
    puts $fo "<th><a href=$sta_check.htm>$sta_check</a></th>"
  }
  puts $fo "</tr>"
  foreach sta_mode $STA_MODE_LIST {
    puts $fo "<tr>"
    puts $fo "<th><a href=$sta_mode/index.htm>$sta_mode</a></th>"
    foreach sta_check $STA_CHECK_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
        set corner_list $STA_CORNER($sta_mode,$sta_check)
        puts $fo "<td>"
        puts $fo "<a href=$sta_mode/$sta_check.htm>"
        puts $fo "<img src=$sta_mode/$sta_check.nvp_wns.png width=600>"
        puts $fo "</a>"
        puts $fo "</td>"
      } else {
        set corner_list ""
        puts $fo "<td></td>"
      }
    }
    puts $fo "</tr>"
    report_mode_summary $sta_mode
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

#
# <Title>
# Report Summary Page of the STA Mode
#
# <Output>
# $STA_SUM_DIR/$sta_mode/index.htm
#
proc report_mode_summary {sta_mode} {
  variable STA_CURR_RUN
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER

  file mkdir $STA_SUM_DIR/$sta_mode
  puts "INFO: Generating Mode Index Page ($sta_mode) ..."
  set fo [open "$STA_SUM_DIR/$sta_mode/index.htm" "w"]
  puts $fo "<html>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "\[<a href=../index.htm>\@Index</a>\]"
  puts $fo "\[<a href=../mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=../check.htm>\@Check</a>\]"
  puts $fo "\[<a href=../corner.htm>\@Corner</a>\]"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3 align=\"left\">$STA_CURR_RUN/$STA_SUM_DIR/"
  foreach mode $STA_MODE_LIST {
    puts $fo "<a href=../$mode/index.htm>($mode)</a>"
  }
  puts $fo "</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th>Mode</th>"
  foreach sta_check $STA_CHECK_LIST {
    puts $fo "<th><a href=../$sta_check.htm>$sta_check</a></th>"
  }
  puts $fo "</tr>"
  
  puts $fo "<tr>"
  puts $fo "<th><a href=../$sta_mode/index.htm>$sta_mode</a></th>"
  foreach sta_check $STA_CHECK_LIST { 
    puts $fo "<td>"
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
      puts $fo "<a href=$sta_check.htm>"
      puts $fo "<img src=$sta_check.nvp_wns.png width=600>"
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
# Create index file which contains a table of all combination of corners and checks
#
# <Output>
# $STA_SUM_DIR/corner.htm
#
proc report_index_corner {{sta_check_list ""}} {
  variable STA_CURR_RUN
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER
  variable STA_CORNER_NAME
  variable CORNER_NAME
  variable VIO_FILE

  if {$sta_check_list!=""} { set $STA_CHECK_LIST $sta_check_list}
 
  file mkdir $STA_SUM_DIR
  puts "INFO: Generating Corner Index HTML Files ..."
  set fo [open "$STA_SUM_DIR/corner.htm" "w"]
  puts $fo "<html>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "\[<a href=index.htm>\@Index</a>\]"
  puts $fo "\[<a href=mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=check.htm>\@Check</a>\]"
  puts $fo "\[<a href=corner.htm>\@Corner</a>\]"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "$STA_CURR_RUN/$STA_SUM_DIR/"
  puts $fo "</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th>Corner</th>"
  set STA_CORNER_LIST ""
  foreach sta_check $STA_CHECK_LIST {
    foreach sta_mode $STA_MODE_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
         puts $fo "<th><a href=$sta_mode/$sta_check.htm>"
         puts $fo "$sta_mode<br>/$sta_check"
         puts $fo "</a></th>"
         foreach sta_corner $STA_CORNER($sta_mode,$sta_check) {
            if {[info exist CORNER_NAME($sta_corner)]} {
               set STA_CORNER_NAME($sta_mode,$sta_check,$sta_corner) $CORNER_NAME($sta_corner)
               lappend STA_CORNER_LIST $sta_corner
            } else {
               puts "ERROR: CORNER_NAME($sta_corner) is not defined, but is used in STA_CORNER($sta_mode,$sta_check)!"
            }
         }
      }
#      if {![catch  {glob  $STA_SUM_DIR/$sta_mode/$sta_check/\*.vio} vio_file_list]} {
#         foreach fname $vio_file_list {
#            set fname [file tail $fname]
#            regsub {\.vio$} $fname "" corner_name
#            regsub {\_\S+$} $corner_name "" sta_corner 
#            set STA_CORNER_NAME($sta_mode,$sta_check,$sta_corner) $corner_name
#            puts "INFO: $sta_corner = $corner_name"
#         }
#      }
    }
  }
  puts $fo "</tr>"
  
  set STA_CORNER_LIST [lsort -unique -increasing $STA_CORNER_LIST]
  foreach sta_corner $STA_CORNER_LIST {
    set corner_name $CORNER_NAME($sta_corner)
    puts $fo "<tr>"
    puts $fo "<td>$corner_name</td>"
    foreach sta_check $STA_CHECK_LIST {
      foreach sta_mode $STA_MODE_LIST {
        if {![info exist STA_CORNER($sta_mode,$sta_check)]} continue
        if {[info exist STA_CORNER_NAME($sta_mode,$sta_check,$sta_corner)]} {
           puts $fo "<td align=right>"
           set vio_file $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.vio
           if {![catch {open $vio_file r} fin]} {
             set nvp 0
             while {[gets $fin line] >= 0} { 
               if {![regexp {^(\#|\*)} $line]} {incr nvp }
             }
             close $fin
             if {$nvp!=0} {
               puts $fo "<a href=$sta_mode/$sta_check/$corner_name.vio>"
               puts $fo $nvp
               puts $fo "</a>"
             } else {
               puts $fo "." 
             }
           } else {
               puts $fo "*" 
           }
           puts $fo "</td>"
        } else {
           puts $fo "<td bgcolor=\"#c0c0c0\">-</td>"         
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
# Create index file which contains a table of all combination of modes and corners
#
# <Output>
# $STA_SUM_DIR/check.htm
#
proc report_index_check {{sta_check_list ""}} {
  variable STA_CURR_RUN
  variable STA_PREV_RUN
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER

  if {$sta_check_list!=""} { set $STA_CHECK_LIST $sta_check_list}

  file mkdir $STA_SUM_DIR
  puts "INFO: Generating Check Index HTML Files ..."
  set fo [open "$STA_SUM_DIR/check.htm" "w"]
  puts $fo "<html>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "\[<a href=index.htm>\@Index</a>\]"
  puts $fo "\[<a href=mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=check.htm>\@Check</a>\]"
  puts $fo "\[<a href=corner.htm>\@Corner</a>\]"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "$STA_CURR_RUN/$STA_SUM_DIR/</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th>Check</th>"
  foreach sta_mode $STA_MODE_LIST {
    puts $fo "<th><a href=$sta_mode/index.htm>$sta_mode</a></th>"
  }
  puts $fo "</tr>"
  foreach sta_check $STA_CHECK_LIST {
    puts $fo "<tr>"
    puts $fo "<th><a href=$sta_check.htm>$sta_check</a></th>"
    foreach sta_mode $STA_MODE_LIST {
      if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
        set corner_list $STA_CORNER($sta_mode,$sta_check)
        puts $fo "<td><a href=$sta_mode/$sta_check.htm>NVP</a><hr>"
        puts $fo "<iframe src=$sta_mode/$sta_check.nvp_wns.dat width=250 height=250></iframe>" 
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
# Report Summary Page of STA_CHECK
#
# <Input>
#
# <Output>
# $STA_SUM_DIR/$sta_check.htm
#
proc report_check_summary {{sta_check ""}} {
  variable STA_CURR_RUN
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CHECK
  variable STA_CORNER
  variable STA_POSTFIX
  
  if {$sta_check==""} { set sta_check $STA_CHECK}

  set fo [open "$STA_SUM_DIR/$sta_check.htm" "w"]
  puts $fo "<html>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "\[<a href=index.htm>\@Index</a>\]"
  puts $fo "\[<a href=mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=check.htm>\@Check</a>\]"
  puts $fo "\[<a href=corner.htm>\@Corner</a>\]"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "$STA_CURR_RUN/$STA_SUM_DIR/"
  foreach check $STA_CHECK_LIST {
    puts $fo "(<a href=$check.htm>$check</a>)"
  }
  puts $fo "</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th>Mode</th>"
  puts $fo "<th><a href=$sta_check.htm>$sta_check</a></th>"
  puts $fo "<th></th>"
  puts $fo "</tr>"
  foreach sta_mode $STA_MODE_LIST {
    puts $fo "<tr>"
    puts $fo "<th><a href=$sta_mode/index.htm>$sta_mode</a></th>"
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
      puts $fo "<td>"
      puts $fo "<a href=$sta_mode/$sta_check.htm>"
      puts $fo "<img src=$sta_mode/$sta_check.nvp_wns.png width=600>"
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


#
# <Title>
# Report One Page Format of the STA Check
#
# <Output>
# $STA_SUM_DIR/$sta_mode/sta_check.htm
#

proc report_sta_check {sta_mode {sta_check ""} } {
  variable STA_CURR_RUN
  variable STA_SUM_DIR
  variable STA_RPT_ROOT
  variable STA_CHECK
  variable STA_CORNER
  variable STA_DATA

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return 
  }

  
  create_curr_nvp_plot "$sta_mode/$sta_check" $STA_SUM_DIR
    
  set fo [open "$STA_SUM_DIR/$sta_mode/$sta_check.htm" w]
  puts $fo "<html>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "\[<a href=../index.htm>\@Index</a>\]"
  puts $fo "\[<a href=../mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=../check.htm>\@Check</a>\]"
  puts $fo "\[<a href=../corner.htm>\@Corner</a>\]"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption>"
  puts $fo "<h3 align=center>"
  puts $fo "$STA_CURR_RUN/$STA_SUM_DIR/$sta_mode/$sta_check"
  puts $fo "</h3>"
  puts $fo "</caption>"
  puts $fo "<tr><td colspan=10>"
  puts $fo "<a href=../mode.htm>"
  puts $fo "<img src=$sta_check.nvp_wns.png  width=800 height=350>"
  puts $fo "</a>"
  puts $fo "</td>"
  puts $fo "<td>"
  puts $fo "<iframe src=\"$sta_check.uniq_end.nvp\" height=350></iframe>"
  puts $fo "</td>"
  puts $fo "</tr>"
  puts $fo "<tr>"
  puts $fo "<th><a href=$sta_check.uniq_end.htm>#</a></th>"
  puts $fo "<th><a href=index.htm>Mode</a></th>"
  puts $fo "<th><a href=../$sta_check.htm>Check</a></th>"
  puts $fo "<th><a href=../../.sta/sta.corner>Corner</a></th>"
  puts $fo "<th><a href=$sta_check.waive_end.rpt>Waive</a></th>"
  puts $fo "<th><a href=$sta_check.uniq_end.rpt>NVP</a></th>"
  puts $fo "<th><a href=$sta_check.uniq_end.wns>WNS</a></th>"
  puts $fo "<th><a href=$sta_check.uniq_end.wns>TNS</a></th>"
  puts $fo "<th><a href=$sta_check.clk.htm>Clock</a></th>"
  puts $fo "<th><a href=$sta_check.blk.htm>Block</a></th>"
  puts $fo "<th><a href=../../$STA_RPT_ROOT/$sta_mode/>STA Report</a>"
  puts $fo "</tr>"
  puts $fo ""

  set WNS 0.0
  set TNS 0.0
  set fid 0
  foreach sta_corner $STA_CORNER($sta_mode,$sta_check) {
    if {[info exist STA_DATA($sta_mode,$sta_check,$sta_corner)]} {
      foreach data $STA_DATA($sta_mode,$sta_check,$sta_corner) {
        incr fid
        set corner [lindex $data 0]
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
        puts $fo "<td align=left>$corner</td>"
        if {$nwp>0} {
        puts $fo "<td align=center><a href=$sta_check/$corner.htm> $nwp</a> </td>"
        } else {
        puts $fo "<td align=center> . </td>"
        }
        if {$nvp>0} {
        puts $fo "<td align=right><a href=$sta_check/$corner.nvp> $nvp </a></td>"
        puts $fo "<td align=right><a href=$sta_check/$corner.wns> $wns </a></td>"
        puts $fo "<td align=right><a href=$sta_check/$corner.vio>$tns</a></td>"
        puts $fo "<td align=center><a href=$sta_check/$corner.clk.htm> $cid </a></td>"
        puts $fo "<td align=center><a href=$sta_check/$corner.blk.htm> $bid </a></td>"
        } else {
        puts $fo "<td align=right> $nvp </td>"
        puts $fo "<td align=right> $wns </td>"
        puts $fo "<td align=right> $tns </td>"
        puts $fo "<td align=center> $cid </td>"
        puts $fo "<td align=center> $bid </td>"
        }
        puts $fo "<td><a href=\"../../$fname\">$fname</a></td>"
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
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo

}




# <Title>
#   Generate Violation Endpint Text Report
#
# <Input>
# VIO_LIST : (($egroup,$epoint) $wns $wcorner)
# VIO_WNS($egroup,$epoint,sta_corner) : $wns
#
# <Output>
# $STA_SUM_DIR/$sta_mode/$sta_check.uniq_end.rpt
# $STA_SUM_DIR/$sta_mode/$sta_check.waive_end.rpt
#
proc report_endpoint_text {sta_mode {sta_check ""} {corner_list ""}} {
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER
  variable VIO_FILE
  variable VIO_LIST
  variable VIO_WNS
  variable WAV_LIST

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "ERROR: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return -1
  }

  reset_waive_list
  read_waive_list all
  read_waive_list $sta_mode
  set waive_cnt 0
  puts "INFO($sta_mode): Generating waived endpoint TEXT format report.."
  set f0 [open "$STA_SUM_DIR/$sta_mode/$sta_check.waive_end.rpt" w]
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
  puts "INFO($sta_mode): Generating unique endpoint TEXT format report.."
  set f1 [open "$STA_SUM_DIR/$sta_mode/$sta_check.uniq_end.rpt" w]
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
#   Generate Violation Endpint HTML Report
#
# <Input>
# VIO_LIST : (($egroup,$epoint) $wns $wcorner)
# VIO_WNS($egroup,$epoint,sta_corner) : $wns
#
# <Output>
# $STA_SUM_DIR/$sta_mode/$sta_check.uniq_end.htm
#
proc report_endpoint_html {sta_mode {sta_check ""} {corner_list ""}} {
  variable STA_CURR_RUN
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER
  variable VIO_LIST
  variable VIO_WNS

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return 
  }
  puts "INFO($sta_mode): Generating unique endpoint HTML format report.."
  set fout [open "$STA_SUM_DIR/$sta_mode/$sta_check.uniq_end.htm" w]
  puts $fout "<html>"
  puts $fout "<head>"
  puts $fout $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fout "</head>"
  puts $fout "<body>"
  puts $fout "<table border=\"1\" id=\"sta_tbl\">"
  puts $fout "<caption><h3 align=\"left\">"
  puts $fout "<a href=$sta_check.htm>"
  puts $fout "$STA_CURR_RUN/$STA_SUM_DIR/$sta_mode/$sta_check"
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
# $STA_SUM_DIR/$sta_mode/$sta_check.waive_end.htm
#
proc report_wavpoint_html {sta_mode {sta_check ""} {corner_list ""}} {
  variable STA_CURR_RUN
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER
  variable WAV_LIST
  variable VIO_WNS

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return 
  }
  puts "INFO($sta_mode): Generating waived endpoint HTML format report.."
  set fout [open "$STA_SUM_DIR/$sta_mode/$sta_check.waive_end.htm" w]
  puts $fout "<html>"
  puts $fout "<head>"
  puts $fout $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fout "</head>"
  puts $fout "<body>"
  puts $fout "<table border=\"1\" id=\"sta_tbl\">"
  puts $fout "<caption><h3 align=\"left\">"
  puts $fout "<a href=$sta_check.htm>"
  puts $fout "$STA_CURR_RUN/$STA_SUM_DIR/$sta_mode/$sta_check"
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

#
# <Title>
# Report Slack Histogram Summary
#
# <Input>
# VIO_LIST : (($egroup,$epoint) $wns $wcorner)
#
# <Output>
# $STA_SUM_DIR/$sta_mode/$fname.wns
# $STA_SUM_DIR/$sta_mode/$fname.nvp
# $STA_SUM_DIR/$sta_mode/$fname.sum
#
#
proc report_slack_summary {sta_mode {fname "uniq_end"}} {
  variable STA_SUM_DIR
  variable NVP_GP
  variable NVP_WAIVED_GP
  variable NVP_REAL_GP
  variable WNS_GP
  variable WNS_HRANGE
  variable NVP_ACCUM
  variable NVP_WAIVED
  variable NVP_REAL
  variable VIO_LIST

  array unset WNS_GP
  array unset NVP_GP 
  array unset NVP_WAIVED_GP 
  array unset NVP_REAL_GP 

  array unset NVP_ACCUM
  array unset NVP_REAL

  foreach ri $WNS_HRANGE { 
     set NVP_ACCUM($ri) 0 
     set NVP_REAL($ri) 0 
  }
  
  puts "INFO: Generating Slack Summary Report.."
  foreach item $VIO_LIST {
      foreach {key slack wcorner} $item { foreach {egroup epoint} $key {}}
      #foreach {egroup epoint slack wcorner} $item {}
      if ![info exist NVP_GP($egroup)] {
         set NVP_GP($egroup) 0 
         set NVP_WAIVED_GP($egroup) 0
         set NVP_REAL_GP($egroup) 0
      }
      incr NVP_GP($egroup)
      foreach ri $WNS_HRANGE { if (($slack-$ri)<=0.00) { incr NVP_ACCUM($ri) }}
      if {![info exist WNS_GP($egroup)] || ($slack<$WNS_GP($egroup))} {
         set WNS_GP($egroup) $slack
      }
      if {[check_waive_slack $slack $egroup $epoint]==1} {
         incr NVP_WAIVED_GP($egroup)
      } else {
         incr NVP_REAL_GP($egroup)
         foreach ri $WNS_HRANGE { if (($slack-$ri)<=0.00) { incr NVP_REAL($ri) }}
      }
  }
      
  
  set S 0
  set T 0
  set V 0
  set W 0
  set flog [open $STA_SUM_DIR/$sta_mode/$fname.wns w]
  puts $flog [format "# Mode : %s" $sta_mode]
  puts $flog [format "#%10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  puts $flog [format "#%10s %10s %10s %10s %s" "REAL" "WAIVED" "NVP" "WNS" "PathGroup"]
  puts $flog [format "#%10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  puts [format "\t: %10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  puts [format "\t: %10s %10s %10s %10s %s" "REAL" "WAIVED" "NVP" "WNS" "PathGroup"]
  puts [format "\t: %10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  set pg_list ""
  foreach key [array name WNS_GP] { 
    lappend pg_list [list $key $WNS_GP($key) ]
  }
  foreach item [lsort -index 0 $pg_list] {
    foreach {p wns} $item {}
    puts [format "\t: %10s %10s %10s %10.2f  %s" $NVP_REAL_GP($p)   $NVP_WAIVED_GP($p) $NVP_GP($p) $wns $p]
    puts $flog [format " %10s %10s %10s %10s  %s" $NVP_REAL_GP($p)   $NVP_WAIVED_GP($p) $NVP_GP($p) $wns $p]
    if {$S>$wns} { set S $wns}
    incr T $NVP_GP($p)
    incr V $NVP_REAL_GP($p)
    incr W $NVP_WAIVED_GP($p)
  }
  puts $flog [format "#%10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  puts $flog [format "#%10s %10s %10s %10s  %s" $V $W $T $S [llength $pg_list]]
  puts $flog [format "#%10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  puts $flog ""
  close $flog

  set flog [open $STA_SUM_DIR/$sta_mode/$fname.nvp w]
  puts $flog [format "#==================================="]
  puts $flog [format "# %6s | %10s %10s" "Slack" "Accum" "NVP"]
  puts $flog [format "#==================================="]
  set pi 1000
  foreach ri $WNS_HRANGE {
     if {[info exist NVP_ACCUM($pi)]} {
        puts $flog [format "  %6s   %10s %10s" $pi $NVP_ACCUM($pi) [expr $NVP_ACCUM($pi)-$NVP_ACCUM($ri)]]
     }
     set pi $ri
  }
  puts $flog [format "  %6s   %10s %10s" $pi $NVP_ACCUM($ri) $NVP_ACCUM($ri)]
  close $flog

  set flog [open $STA_SUM_DIR/$sta_mode/$fname.sum w]
  puts $flog [format "#======================================================"]
  puts $flog [format "# %6s - %6s | : %10s %10s %10s" "Max" "Min" "REAL" "NVP" "Accmu"]
  puts $flog [format "#======================================================"]
  set pi 1000
  foreach ri $WNS_HRANGE {
     if {[info exist NVP_ACCUM($pi)]} {
        puts $flog [format "( %6s ~ %6s \] : %10s %10s %10s" $pi $ri [expr $NVP_REAL($pi)-$NVP_REAL($ri)] [expr $NVP_ACCUM($pi)-$NVP_ACCUM($ri)] $NVP_ACCUM($pi)]
     }
     set pi $ri
  }
  puts $flog [format "( %6s ~ %6s \] : %10s %10s %10s" $pi "" $NVP_REAL($ri) $NVP_ACCUM($ri) $NVP_ACCUM($ri)]
  close $flog
}
proc get_nvp_ymax {datfile} {
  set ymax 100
  if {[catch {open $datfile r} fin]} {
     return $ymax
  }
  while {[gets $fin line] >= 0} {
        if {[regexp {^\#} $line]} continue;
        set wns  [lindex $line 2]
        set nvp  [lindex $line 1]
        if {$nvp>$ymax} {
           if {$nvp>1000} {
              set ymax $nvp
           } else if {$nvp>100} {
              set ymax 1000
           } else if {$nvp>10} {
              set ymax 100
           }
        }
  }
  close $fin
  return $ymax
}
proc create_curr_nvp_plot {path odir} {
  set ofile [format "%s/%s.nvp_wns" $odir $path]
  set ymax [get_nvp_ymax $ofile.dat]
  set fout [open "$ofile.plt" w]
    puts $fout "set title \"$path\""
    puts $fout "set term png truecolor size 1000,400 medium"
    puts $fout "set output \"$ofile.png\""
    puts $fout "set style data histogram"
    puts $fout "set style histogram clustered gap 1"
    puts $fout "set style fill solid 0.4 border"
    puts $fout "set grid"
    puts $fout "set size 1,1"
    puts $fout "set yrange \[0:$ymax\]"
    puts $fout "set ylabel \"NVP\""
    puts $fout "set y2label \"WNS (ps)\""
    puts $fout "set ytics nomirror"
    puts $fout "set y2tics"
    puts $fout "plot \"$ofile.dat\" using 2:xticlabels(1) axis x1y1  title \"NVP\", \\"
    puts $fout "     \"\"     using 0:2:2 with labels center offset 0,1 notitle, \\"
    puts $fout "     \"\"     using 3:xticlabels(1) with linespoints lc 3 lw 2 pt 7 ps 1 axis x1y2  title \"WNS\", \\"
    puts $fout "     \"\"     using 0:3:(sprintf(\"(%d)\",\$3)) with labels center offset -0.5,2 axis x1y2 notitle lc 3"
   close $fout
  puts "INFO: Generating Violation Statistics Graph ($path)..."
  puts "\t:$ofile.png"
  catch {exec gnuplot $ofile.plt}
}


}

::LIB_STA::init

