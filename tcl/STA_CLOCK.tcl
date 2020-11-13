#!/usr/bin/tclsh
#
## STA Group Report
##
## By Albert Li 
## 2020/07/07
## 
puts "INFO: Loading 'STA_CLOCK.tcl'..."
namespace eval LIB_STA {
variable sCLOCK_LIST 
variable eCLOCK_LIST 
variable CLOCK_LIST
variable CLOCK_NVP
variable CLOCK_WNS
variable CLOCK_VIO
variable CLOCK_NUM

proc report_clock_end {{sta_check ""}} {
  variable STA_MODE_LIST
  variable STA_CHECK
  if {$sta_check==""} { set sta_check $STA_CHECK}

  foreach sta_mode $STA_MODE_LIST {
     report_clock_table $sta_mode $sta_check
     report_index_clock $sta_mode $sta_check
  }
}

proc assign_clock_gid {{clock_list ""}} {
  variable CLOCK_LIST
  variable CLOCK_GID

  if {$clock_list == ""} { set clock_list $CLOCK_LIST}
  array unset CLOCK_GID
  set cid 0
  set CLOCK_GID(-) -
  foreach name $clock_list {
    if {![info exist CLOCK_GID($name)]} {
       incr cid
       set CLOCK_GID($name) $cid
    }
  }
  return $cid
}

proc sort_slack_by_clock {corner slack sclock eclock {report ""} } {
  variable CLOCK_NVP
  variable CLOCK_WNS
           if [info exist CLOCK_NVP($sclock,$eclock,$corner)] {
              incr CLOCK_NVP($sclock,$eclock,$corner)
              if {$CLOCK_WNS($sclock,$eclock,$corner)>$slack} {
                 set CLOCK_WNS($sclock,$eclock,$corner) $slack
              }
           } else {
              set CLOCK_NVP($sclock,$eclock,$corner) 1
              set CLOCK_WNS($sclock,$eclock,$corner) $slack
           }
         if {$sclock != "-"} {
           if [info exist CLOCK_NVP(-,$eclock,$corner)] {
              incr CLOCK_NVP(-,$eclock,$corner)
              if {$CLOCK_WNS(-,$eclock,$corner)>$slack} {
                 set CLOCK_WNS(-,$eclock,$corner) $slack
              }
           } else {
              set CLOCK_NVP(-,$eclock,$corner) 1
              set CLOCK_WNS(-,$eclock,$corner) $slack
           }
         }
         if {$corner != "-"} {
           if [info exist CLOCK_NVP($sclock,$eclock,-)] {
              incr CLOCK_NVP($sclock,$eclock,-)
              if {$CLOCK_WNS($sclock,$eclock,-)>$slack} {
                 set CLOCK_WNS($sclock,$eclock,-) $slack
              }
           } else {
              set CLOCK_NVP($sclock,$eclock,-) 1
              set CLOCK_WNS($sclock,$eclock,-) $slack
           }
        }
        if {($sclock != "-") && ($corner != "-")} {
           if [info exist CLOCK_NVP(-,$eclock,-)] {
              incr CLOCK_NVP(-,$eclock,-)
              if {$CLOCK_WNS(-,$eclock,-)>$slack} {
                 set CLOCK_WNS(-,$eclock,-) $slack
              }
           } else {
              set CLOCK_NVP(-,$eclock,-) 1
              set CLOCK_WNS(-,$eclock,-) $slack
           }
        }
}

#
# <Title>
#    Group Violation Slack based on Clock Group
#
# <Input>
# $STA_SUM_DIR/$sta_mode/$sta_check/*.vio
#
# <Output>
# CLOCK_LIST : {{$sclock,$eclock} $wns $wcorner}
# CLOCK_WNS($sclock,$eclock,$sta_corner) : $wns
#
proc report_clock_table {sta_mode {sta_check ""}  } {
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER
  variable VIO_FILE
  variable CLOCK_LIST
  variable CLOCK_NVP
  variable CLOCK_WNS

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return
  }
  array unset CLOCK_NVP
  array unset CLOCK_WNS
  puts "INFO($sta_mode): Group slack files of multiple corners ..."
  puts "$STA_SUM_DIR/$sta_mode/$sta_check/*.vio"
  if {![catch {glob $STA_SUM_DIR/$sta_mode/$sta_check/*.vio} files]} {
    foreach fname $files {
      regsub {\.vio$} [file tail $fname] "" corner_name
      if {![regexp {^(\d+)\_} $corner_name whole sta_corner]} {
         set sta_corner [get_corner_id $corner_name]
      }
      puts "($sta_corner)\t: $fname"
      set VIO_FILE($sta_mode,$sta_check,$sta_corner) $fname
      set sline ""
      set sclock -
      set sinst -
      set fin [open $fname r]
      while {[gets $fin line] >= 0} {
        if {[regexp {^\#} $line]} {
           if {[regexp {^\#\s+File\s*\:\s*(\S+)} $line whole sta_rpt]} {
#              puts "INFO: File : $sta_rpt"
           }
        } elseif {[regexp {^\*(\d+)\:(\d+)\s+(\S+)\s+(\S+)} $line sline nspt line_cnt sclock sinst]} {
           puts -nonewline stderr "INFO: Path# $nspt , Line# $line_cnt\r"
        } elseif {[regexp {^\s*(\S+)\s+(\S+)\s+(\S+)} $line eline slack eclock einst]} {
           sort_slack_by_clock $sta_corner $slack $sclock $eclock 
           set sclock -
           set sinst  -
           set sline  ""
        }
      }
      close $fin
      output_clock_table $sta_mode $sta_check $corner_name
    }
  }
}

proc extract_clock_list {sta_corner} {
  variable CLOCK_NVP
  variable CLOCK_LIST
  variable sCLOCK_LIST
  variable eCLOCK_LIST

      set sCLOCK_LIST ""
      set eCLOCK_LIST ""
      set CLOCK_LIST ""
      foreach key [array name CLOCK_NVP] {
         foreach {sclock eclock corner} [split $key ","] {
            if {$corner==$sta_corner} {
               if {[lsearch $sCLOCK_LIST $sclock]<0} { lappend sCLOCK_LIST $sclock}
               if {[lsearch $eCLOCK_LIST $eclock]<0} { lappend eCLOCK_LIST $eclock}

               if {[lsearch $CLOCK_LIST $sclock]<0} { lappend CLOCK_LIST $sclock}
               if {[lsearch $CLOCK_LIST $eclock]<0} { lappend CLOCK_LIST $eclock}
            }
         }
      }
      set sCLOCK_LIST [lsort -unique $sCLOCK_LIST]
      set eCLOCK_LIST [lsort -unique $eCLOCK_LIST]
      set CLOCK_LIST [lsort -unique $CLOCK_LIST]
}

proc output_clock_table {sta_mode sta_check corner_name} {
  variable STA_SUM_DIR
  variable CLOCK_NUM
  variable CLOCK_GID
  variable CLOCK_WNS
  variable CLOCK_NVP
  variable CLOCK_LIST
  variable sCLOCK_LIST
  variable eCLOCK_LIST

      set sta_corner [get_corner_id $corner_name]

      extract_clock_list $sta_corner
      set CLOCK_NUM [assign_clock_gid]

      set fout [open "$STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.clk.htm" w]
      puts $fout "<html>"
      puts $fout "<head>"
      puts $fout $::LIB_HTML::TABLE_CSS(sta_tbl)
      puts $fout "</head>"
      puts $fout "<body>"
      puts $fout "<div id=\"$sta_corner\" class=\"collapse\">"
      puts $fout "<table border=\"1\" id=\"sta_tbl\">"
      puts $fout "<caption><h3 align=left>"
      puts $fout "<a href=../$sta_check.clk.htm>" 
      puts $fout "$STA_SUM_DIR/$sta_mode/$sta_check/$corner_name"
      puts $fout "</a></h3></caption>"
      puts $fout "<TR>"
      puts $fout "<TH align=left><pre>#$CLOCK_NUM Clocks</a></TH>" 
#      puts $fout "<TH align=right><pre>NVP</TH>"
      puts $fout "<TH align=right><pre>WNS</TH>"
      foreach sclock $sCLOCK_LIST {
         puts $fout "<TH><pre>$CLOCK_GID($sclock)</TH>"
      }
      puts $fout "</TR>"
      foreach eclock $CLOCK_LIST {
         set cid $CLOCK_GID($eclock)
         puts $fout "<TR>"
         puts $fout "<TD><pre>$cid : $eclock</TD>"
         if {[info exist CLOCK_NVP(-,$eclock,$sta_corner)]} {
#            puts $fout "<TD align=right><pre>[format "%d" $CLOCK_NVP(-,$eclock,$sta_corner)]</TD>"
            puts $fout "<TD align=right><pre>[format "%.2f" $CLOCK_WNS(-,$eclock,$sta_corner)]</TD>"
         } else {
#            puts $fout "<TD><pre></TD>"
            puts $fout "<TD><pre></TD>"
         }
         foreach sclock $sCLOCK_LIST {
            if {$sclock==$eclock} { 
               set fmt1 "bgcolor=#80d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            } else { 
               set fmt1 "bgcolor=#d0d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            }
            if {[info exist CLOCK_WNS($sclock,$eclock,$sta_corner)]} {
               set nvp $CLOCK_NVP($sclock,$eclock,$sta_corner) 
               puts $fout "<TD $fmt1 align=right><pre>[format %4d $nvp]</TD>"
            } else {
               puts $fout "<TD $fmt0><pre>[format %4s ""]</TD>"
            }
         }
         puts $fout  "</TR>"
      }
      puts $fout "</table>"
      puts $fout "</div>"
      puts $fout "</body>"
      puts $fout "</html>"
      close $fout
      return $CLOCK_NUM
  
}

proc report_index_clock {sta_mode {sta_check ""} {corner_list ""}} {
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER
  variable CLOCK_LIST
  variable CLOCK_GID
  variable CLOCK_NVP
  variable CLOCK_WNS
  variable CLOCK_NUM

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return
  }
  if {$corner_list==""} { set corner_list $STA_CORNER($sta_mode,$sta_check) }

  extract_clock_list -
  set CLOCK_NUM [assign_clock_gid]

  puts "INFO($sta_mode): $CLOCK_NUM Clocks"

  set fout [open "$STA_SUM_DIR/$sta_mode/$sta_check.clk.htm" w]
  puts $fout "<html>"
  puts $fout "<head>"
  puts $fout $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fout "</head>"
  puts $fout "<body>"
  puts $fout "<div id=\"$sta_check.clock\" class=\"collapse\">"
  puts $fout "<table border=\"1\" id=\"sta_tbl\">"
  puts $fout "<caption><h3 align=left>"
  puts $fout "<a href=$sta_check.htm>" 
  puts $fout "$STA_SUM_DIR/$sta_mode/$sta_check"
  puts $fout "</a></h3></caption>"
  puts $fout "<TR>"
  puts $fout "<TH><pre>#$CLOCK_NUM Clocks</TH>" 
  puts $fout "<TH><pre>NVP</TH>" 
  puts $fout "<TH><pre>WNS</TH>" 
  foreach sta_corner $corner_list {
     set corner_name [get_corner_name $sta_corner]
     puts $fout "<TH><a href=$sta_check/$corner_name.clk.htm><pre>$sta_corner</a></TH>"
  }
  puts $fout "</TR>"

      foreach eclock $CLOCK_LIST {
         set cid $CLOCK_GID($eclock)
         puts $fout "<TR>"
         puts $fout "<TD><pre>$cid : $eclock</TD>"
         if {[info exist CLOCK_WNS(-,$eclock,-)]} {
            puts $fout "<TD align=right><pre>[format "%d" $CLOCK_NVP(-,$eclock,-)]</TD>"
            puts $fout "<TD align=right><pre>[format "%.2f" $CLOCK_WNS(-,$eclock,-)]</TD>"
         } else {
            puts $fout "<TD><pre></TD>"
            puts $fout "<TD><pre></TD>"
         }
         foreach sta_corner $corner_list {
            set sclock -
            if {$sclock==$eclock} { 
               set fmt1 "bgcolor=#80d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            } else { 
               set fmt1 "bgcolor=#d0d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            }
            if {[info exist CLOCK_WNS($sclock,$eclock,$sta_corner)]} {
               set wns $CLOCK_WNS($sclock,$eclock,$sta_corner) 
               puts $fout "<TD $fmt1 align=right><pre>[format %6.2f $wns]</TD>"
            } else {
               puts $fout "<TD $fmt0><pre>[format %6s ""]</TD>"
            }
         }
         puts $fout  "</TR>"
      }
  puts $fout "</table>"
  puts $fout "</div>"
  puts $fout "</body>"
  puts $fout "</html>"
  close $fout
  return $CLOCK_NUM
}

################################
}

