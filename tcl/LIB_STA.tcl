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

variable STA_CFG_DIR    ".sta"
variable STA_SUM_DIR    "uniq_end"
variable STA_RPT_ROOT    "STA"
variable STA_RPT_PATH    {$sta_mode/$sta_corner\_*/rpt/$sta_check}
variable STA_RPT_FILE    {RptTimeCnst$sta_postfix.rpt*}
variable STA_POSTFIX    ""

variable STA_CHECK      "setup"
variable STA_CHECK_LIST "setup hold"
variable STA_MODE_LIST  ""
variable STA_CORNER     
variable STA_CORNER_NAME 
variable STA_CORNER_LIST ""

variable VIO_FILE  
variable VIO_LIST  ""
variable MET_LIST
variable WAIVE_LIST
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
  global STA_HOME
  uplevel 1 source $STA_HOME/tcl/STA_CORNER.tcl
  uplevel 1 source $STA_HOME/tcl/STA_WAIVE.tcl
  uplevel 1 source $STA_HOME/tcl/STA_PT.tcl
  uplevel 1 source $STA_HOME/tcl/STA_MERGE.tcl
  uplevel 1 source $STA_HOME/tcl/STA_CLOCK.tcl
  uplevel 1 source $STA_HOME/tcl/STA_BLOCK.tcl
  uplevel 1 source $STA_HOME/tcl/STA_GROUP.tcl
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

      merge_vio_endpoint $sta_mode $sta_check

      report_endpoint_text $sta_mode $sta_check $corner_list
      report_endpoint_html $sta_mode $sta_check $corner_list

      report_index_clock $sta_mode $sta_check $corner_list
      report_index_block $sta_mode $sta_check $corner_list

      report_slack_summary $sta_mode $sta_check.uniq_end
    }
  }
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

    report_curr_nvp_plot "$sta_mode/$sta_check" $STA_SUM_DIR
    report_comp_nvp_plot "$sta_mode/$sta_check" $STA_SUM_DIR PREV/$STA_SUM_DIR diff
    report_comp_nvp_plot "$sta_mode/$sta_check" $STA_SUM_DIR uniq_end full

  }
  report_curr_sta_html $sta_check
  report_comp_sta_html $sta_check "diff"
  report_comp_sta_html $sta_check "full"
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
proc report_index_main {{url "mode.htm"}} {
  variable STA_SUM_DIR

  file mkdir $STA_SUM_DIR
  puts "INFO: Generating Home Index Page ..."
  set fo [open "$STA_SUM_DIR/index.htm" "w"]
  puts $fo "<html>"
  puts $fo "<head>"
  puts $fo "<meta http-equiv=\"refresh\" content=\"0;url=$url\">"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "This page is redirect to : <a href=$url>$url</a>"
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
  global env
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK_LIST
  variable STA_CORNER

  if {$sta_check_list!=""} { set $STA_CHECK_LIST $sta_check_list}

  file mkdir $STA_SUM_DIR
  puts "INFO: Generating Mode Index HTML Files ..."
  set fo [open "$STA_SUM_DIR/mode.htm" "w"]
  puts $fo "<html>"
  puts $fo "<head>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3>"
  puts $fo "<a href=..>$env(PWD)</a>"
  puts $fo "/$STA_SUM_DIR/</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th><a href=corner.htm>\@Corner</a></th>"
  foreach sta_check $STA_CHECK_LIST {
    puts $fo "<th><a href=$sta_check.diff.htm>$sta_check</a></th>"
  }
  puts $fo "</tr>"
  foreach sta_mode $STA_MODE_LIST {
  puts $fo "<tr>"
  puts $fo "<td><a href=$sta_mode>$sta_mode</a></td>"
  foreach sta_check $STA_CHECK_LIST {
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
      set corner_list $STA_CORNER($sta_mode,$sta_check)
      puts $fo "<td><a href=$sta_mode/$sta_check.htm>"
      puts $fo "<img src=$sta_mode/$sta_check.nvp_wns.png width=400>"
      puts $fo "</a></td>"
    } else {
      set corner_list ""
      puts $fo "<td></td>"
    }
  }
  puts $fo "</tr>"
  report_index_check $sta_mode
  }
  puts $fo "</table>"
  puts $fo "<pre>\[<a href=../PREV/$STA_SUM_DIR/mode.htm>Prev</a>\]</pre>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

#
# <Title>
# Create index file which contains a table of all combination of corners and checks
#
# <Output>
# $STA_SUM_DIR/index.htm
#
proc report_index_corner {{sta_check_list ""}} {
  global env
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
  puts $fo "<head>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3>"
  puts $fo "<a href=..>$env(PWD)</a>"
  puts $fo "/$STA_SUM_DIR"
  puts $fo "</h3></caption>"
  puts $fo "<tr>"
  puts $fo "<th><a href=mode.htm>\@Mode</a></th>"
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
#      puts "INFO: $sta_corner = $corner_name"
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
             puts $fo "<a href=$sta_mode/$sta_check/$corner_name.clk.htm>"
             puts $fo $nvp
             puts $fo "</a>"
           } else {
             puts $fo "." 
           }
         } else {
             puts $fo "" 
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
  set prev_version [file tail [file readlink PREV]]
  puts $fo "<pre>\[<a href=../PREV/$STA_SUM_DIR/corner.htm>$prev_version</a>\]</pre>"
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
proc report_index_check {{sta_mode "func"}} {
  global env
  variable STA_SUM_DIR
  variable STA_CHECK_LIST

  file mkdir $STA_SUM_DIR/$sta_mode
  puts "INFO: Generating Mode Index Page ($sta_mode) ..."
  set fo [open "$STA_SUM_DIR/$sta_mode/index.htm" "w"]
  puts $fo "<html>"
  puts $fo "<head>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3>$env(PWD)/$STA_SUM_DIR/$sta_mode</h3></caption>"
  puts $fo "<tr>"
  foreach sta_check $STA_CHECK_LIST {
    puts $fo "<th align=center><a href=$sta_check.htm>$sta_check</a></th>"
  }
  puts $fo "</tr>"
  
#    puts $fo "<td><a href=$sta_check.htm>$sta_check</a></td>"
#  puts $fo "<tr>"
#  foreach sta_check $STA_CHECK_LIST { puts $fo "<td><img src=$sta_check.nvp_wns.full.png width=700></td>" }
#  puts $fo "</tr>"
  puts $fo "<tr>"
  foreach sta_check $STA_CHECK_LIST { 
    puts $fo "<td>"
    puts $fo "<a href=..>"
    puts $fo "<img src=$sta_check.nvp_wns.diff.png width=700>"
    puts $fo "</a>"
    puts $fo "</td>"
  }
  puts $fo "</tr>"

  puts $fo "<tr>"
  foreach sta_check $STA_CHECK_LIST { puts $fo "<td><iframe src=$sta_check.uniq_end.wns width=100% height=400></iframe></td>" }
  puts $fo "</tr>"

  puts $fo "<tr>"
  foreach sta_check $STA_CHECK_LIST { puts $fo "<td><iframe src=$sta_check.uniq_end.nvp width=100% height=400></iframe></td>" }
  puts $fo "</tr>"

  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

#
# <Title>
# Report STA Summary Page of STA_CHECK
#
# <Input>
#
# <Output>
# $STA_SUM_DIR/$sta_check.htm
#
proc report_curr_sta_html {{sta_check ""}} {
  global env
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK
  variable STA_CORNER
  variable STA_POSTFIX
  
  if {$sta_check==""} { set sta_check $STA_CHECK}

  set fo [open "$STA_SUM_DIR/$sta_check.htm" "w"]
  puts $fo "<html>"
  puts $fo "<head>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3>"
  puts $fo "<a href=..>$env(PWD)</a>"
  puts $fo "/"
  puts $fo "<a href=.>$STA_SUM_DIR</a>"
  puts $fo "(<a href=$sta_check.htm>$sta_check</a>)"
  puts $fo " @<a href=$sta_check.diff.htm>diff</a>"
  if {$STA_POSTFIX != ""} {
  puts $fo " @<a href=$sta_check.full.htm>full</a>"
  }
  puts $fo "</h3></caption>"
  foreach sta_mode $STA_MODE_LIST {
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
    puts $fo "<tr>"
    puts $fo "<td><h3><a href=$sta_mode/$sta_check>$sta_mode/$sta_check</a></h3></td>"
    puts $fo "</tr>"
    puts $fo "<tr>"
    puts $fo "<td>"
    puts $fo "<a href=$sta_mode/$sta_check.htm>"
    puts $fo "<img src=$sta_mode/$sta_check.nvp_wns.png>"
    puts $fo "</a>"
    puts $fo "</td>"
    puts $fo "<td>"
    puts $fo "<iframe src=\"$sta_mode/$sta_check.nvp_wns.dat\" height=\"400\" width=\"250\"></iframe>"
    puts $fo "</td>"
    puts $fo "</tr>"
    }
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}


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
  global env
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK
  variable STA_CORNER
  
  if {$sta_check==""} { set sta_check $STA_CHECK}

 
  set fo [open "$STA_SUM_DIR/$sta_check.$comp.htm" "w"]
  puts $fo "<html>"
  puts $fo "<head>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3>"
  puts $fo "<a href=..>$env(PWD)</a>"
  puts $fo "/"
  puts $fo "<a href=.>$STA_SUM_DIR</a>"
  puts $fo "</a>"
  puts $fo "(<a href=$sta_check.htm>$sta_check</a>)"
  puts $fo "<h3></caption>"
  foreach sta_mode $STA_MODE_LIST {
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
    puts $fo "<tr>"
    puts $fo "<td><h3><a href=$sta_mode/$sta_check.htm>$sta_mode/$sta_check</a></h3></td>"
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

# <Title>
#   Generate Violation Endpint Text Report
#
# <Input>
# VIO_LIST : {{$egroup,$epoint} $wns $wcorner}
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

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "ERROR: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return -1
  }
  reset_waive_list
  read_waive_list all
  read_waive_list $sta_mode
  puts "INFO($sta_mode): Generating unique endpoint TEXT format report.."
  set f1 [open "$STA_SUM_DIR/$sta_mode/$sta_check.uniq_end.rpt" w]
  set f0 [open "$STA_SUM_DIR/$sta_mode/$sta_check.waive_end.rpt" w]

  foreach fout [list $f0 $f1] {
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
  }

  set fout $f1
  set uniq_cnt 0
  set waive_cnt 0
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
         set mark "@"
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
# VIO_LIST : {{$egroup,$epoint} $wns $wcorner}
# VIO_WNS($egroup,$epoint,sta_corner) : $wns
#
# <Output>
# $STA_SUM_DIR/$sta_mode/$sta_check.uniq_end.htm
#
proc report_endpoint_html {sta_mode {sta_check ""} {corner_list ""}} {
  global   env
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER
  variable VIO_FILE
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
  puts $fout "<caption><h3>"
  puts $fout "<a href=$sta_check.htm>"
  puts $fout "$env(PWD)/$STA_SUM_DIR/$sta_mode/$sta_check"
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
# Report Slack Histogram Summary
#
# <Input>
# VIO_LIST : {{$egroup,$epoint} $wns $wcorner}
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
  puts $flog [format "#======================================================"]
  puts $flog [format "# %6s | %10s %10s %10s" "Slack" "Accum" "NVP" "REAL"]
  puts $flog [format "#======================================================"]
  set pi 1000
  foreach ri $WNS_HRANGE {
     if {[info exist NVP_ACCUM($pi)]} {
        puts $flog [format "  %6s   %10s %10s %10s" $pi $NVP_ACCUM($pi) [expr $NVP_ACCUM($pi)-$NVP_ACCUM($ri)] [expr $NVP_REAL($pi)-$NVP_REAL($ri)]]
     }
     set pi $ri
  }
  puts $flog [format "  %6s   %10s %10s %10s" $pi $NVP_ACCUM($ri) $NVP_ACCUM($ri) $NVP_REAL($ri)]
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
           } elseif {$nvp>100} {
              set ymax 1000
           } elseif {$nvp>10} {
              set ymax 100
           }
        }
  }
  close $fin
  return $ymax
}
proc report_curr_nvp_plot {path odir} {
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
proc report_comp_nvp_plot {path odir xdir {comp "diff"}} {
  set ofile [format "%s/%s.nvp_wns" $odir $path]
  set odir [file normalize $odir]
  set oname [format "%s/%s" [file tail [file dirname $odir]] [file tail $odir]]
  set xfile [format "%s/%s.nvp_wns" $xdir $path]
  set xdir [file normalize $xdir]
  set xname [format "%s/%s" [file tail [file dirname $xdir]] [file tail $xdir]]


  set ymax [get_nvp_ymax $ofile.dat]
  set ymax1 [get_nvp_ymax $xfile.dat]
  if {$ymax1>$ymax} { set ymax $ymax1}
  set fout [open "$ofile.$comp.plt" w]
    puts $fout "set title \"$path\""
    puts $fout "set term png truecolor size 1000,400 medium"
    puts $fout "set output \"$ofile.$comp.png\""
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
    puts $fout "plot \"$xfile.dat\" using 2:xticlabels(1) lc 0 axis x1y1  title \"$xname-NVP\", \\"
#    puts $fout "     \"$xfile.dat\" using 0:2:2 with labels right offset 0,1 notitle, \\"
    puts $fout "     \"$xfile.dat\" using 3:xticlabels(1) with linespoints lc 0 lw 1 pt 7 ps 1 axis x1y2  title \"$xname-WNS\", \\"
#    puts $fout "     \"$xfile.dat\" using 0:3:(sprintf(\"(%di)\",\$3)) with labels center offset -0.5,2 axis x1y2 notitle lc 0, \\"
    puts $fout "     \"$ofile.dat\" using 2:xticlabels(1) lc 1 axis x1y1  title \"$oname-NVP\", \\"
    puts $fout "     \"$ofile.dat\" using 0:2:2 with labels left offset 0,0 notitle, \\"
    puts $fout "     \"$ofile.dat\" using 3:xticlabels(1) with linespoints lc 3 lw 2 pt 7 ps 1 axis x1y2  title \"$oname-WNS\", \\"
    puts $fout "     \"$ofile.dat\" using 0:3:(sprintf(\"(%d)\",\$3)) with labels center offset -0.5,2 axis x1y2 notitle lc 3"
   close $fout
  puts "INFO: Generating Violation Diff Chart ($path)..."
  puts "\t:$ofile.$comp.png"
  catch {exec gnuplot $ofile.$comp.plt}
  catch {exec diff -W 60 -y $ofile.dat $xfile.dat > $ofile.$comp.rpt}
}

}

::LIB_STA::init

