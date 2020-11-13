#!/usr/bin/tclsh
#
## STA Group Report
##
## By Albert Li 
## 2020/07/07
## 
puts "INFO: Loading 'STA_GROUP.tcl'..."
namespace eval LIB_STA {
variable sGROUP_LIST 
variable eGROUP_LIST 
variable GROUP_LIST
variable GROUP_NUM
variable GROUP_NVP
variable GROUP_WNS
variable GROUP_VIO

proc report_group_end {{sta_check ""}} {
  variable STA_MODE_LIST
  variable STA_CHECK
  if {$sta_check==""} { set sta_check $STA_CHECK}

  foreach sta_mode $STA_MODE_LIST {
     report_group_table $sta_mode $sta_check
     report_index_group $sta_mode $sta_check
  }
}

proc assign_group_gid {{group_list ""}} {
  variable GROUP_LIST
  variable GROUP_GID

  if {$group_list == ""} { set group_list $GROUP_LIST}
  array unset GROUP_GID
  set cid 0
  set GROUP_GID(-) -
  foreach name $group_list {
    if {![info exist GROUP_GID($name)]} {
       incr cid
       set GROUP_GID($name) $cid
    }
  }
  return $cid
}

proc sort_slack_by_group {corner slack sgroup egroup {report ""} } {
  variable GROUP_NVP
  variable GROUP_WNS
           if [info exist GROUP_NVP($sgroup,$egroup,$corner)] {
              incr GROUP_NVP($sgroup,$egroup,$corner)
              if {$GROUP_WNS($sgroup,$egroup,$corner)>$slack} {
                 set GROUP_WNS($sgroup,$egroup,$corner) $slack
              }
           } else {
              set GROUP_NVP($sgroup,$egroup,$corner) 1
              set GROUP_WNS($sgroup,$egroup,$corner) $slack
           }
         if {$sgroup != "-"} {
           if [info exist GROUP_NVP(-,$egroup,$corner)] {
              incr GROUP_NVP(-,$egroup,$corner)
              if {$GROUP_WNS(-,$egroup,$corner)>$slack} {
                 set GROUP_WNS(-,$egroup,$corner) $slack
              }
           } else {
              set GROUP_NVP(-,$egroup,$corner) 1
              set GROUP_WNS(-,$egroup,$corner) $slack
           }
         }
         if {$corner != "-"} {
           if [info exist GROUP_NVP($sgroup,$egroup,-)] {
              incr GROUP_NVP($sgroup,$egroup,-)
              if {$GROUP_WNS($sgroup,$egroup,-)>$slack} {
                 set GROUP_WNS($sgroup,$egroup,-) $slack
              }
           } else {
              set GROUP_NVP($sgroup,$egroup,-) 1
              set GROUP_WNS($sgroup,$egroup,-) $slack
           }
        }
        if {($sgroup != "-") && ($corner != "-")} {
           if [info exist GROUP_NVP(-,$egroup,-)] {
              incr GROUP_NVP(-,$egroup,-)
              if {$GROUP_WNS(-,$egroup,-)>$slack} {
                 set GROUP_WNS(-,$egroup,-) $slack
              }
           } else {
              set GROUP_NVP(-,$egroup,-) 1
              set GROUP_WNS(-,$egroup,-) $slack
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
# GROUP_LIST : {{$sgroup,$egroup} $wns $wcorner}
# GROUP_WNS($sgroup,$egroup,$sta_corner) : $wns
#
proc report_group_table {sta_mode {sta_check ""}  } {
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER
  variable VIO_FILE
  variable GROUP_LIST
  variable GROUP_NVP
  variable GROUP_WNS

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return
  }
  array unset GROUP_NVP
  array unset GROUP_WNS
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
      set sgroup -
      set sinst -
      set fin [open $fname r]
      while {[gets $fin line] >= 0} {
        if {[regexp {^\#} $line]} {
           if {[regexp {^\#\s+File\s*\:\s*(\S+)} $line whole sta_rpt]} {
#              puts "INFO: File : $sta_rpt"
           }
        } elseif {[regexp {^\*(\d+)\:(\d+)\s+(\S+)\s+(\S+)} $line whole nspt line_cnt sgroup sinst]} {
              puts -nonewline stderr "INFO: Path# $nspt , Line# $line_cnt\r"
        } elseif {[regexp {^\s*(\S+)\s+(\S+)\s+(\S+)} $line whole slack egroup einst]} {
           sort_slack_by_group $sta_corner $slack $sgroup $egroup 
           set sgroup -
           set sinst  -
        }
      }
      close $fin
      output_group_table $sta_mode/$sta_check $corner_name
    }
  }
}
proc extract_group_list {sta_corner} {
  variable GROUP_NVP
  variable GROUP_LIST
  variable sGROUP_LIST
  variable eGROUP_LIST

      set sGROUP_LIST ""
      set eGROUP_LIST ""
      set GROUP_LIST ""
      foreach key [array name GROUP_NVP] {
         foreach {sgroup egroup corner} [split $key ","] {
            if {$corner==$sta_corner} {
               if {[lsearch $sGROUP_LIST $sgroup]<0} { lappend sGROUP_LIST $sgroup}
               if {[lsearch $eGROUP_LIST $egroup]<0} { lappend eGROUP_LIST $egroup}

               if {[lsearch $GROUP_LIST $sgroup]<0} { lappend GROUP_LIST $sgroup}
               if {[lsearch $GROUP_LIST $egroup]<0} { lappend GROUP_LIST $egroup}
            }
         }
      }
      set sGROUP_LIST [lsort -unique $sGROUP_LIST]
      set eGROUP_LIST [lsort -unique $eGROUP_LIST]
      set GROUP_LIST [lsort -unique $GROUP_LIST]
}

proc output_group_table {sta_mode sta_check corner_name} {
  variable STA_SUM_DIR
  variable GROUP_GID
  variable GROUP_WNS
  variable GROUP_NVP
  variable GROUP_NUM
  variable GROUP_LIST
  variable sGROUP_LIST
  variable eGROUP_LIST

      set sta_corner [get_corner_id $corner_name]

      extract_group_list $sta_corner
      set GROUP_NUM [assign_group_gid]

      set fout [open "$STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.grp.htm" w]
      puts $fout "<html>"
      puts $fout "<head>"
      puts $fout $::LIB_HTML::TABLE_CSS(sta_tbl)
      puts $fout "</head>"
      puts $fout "<body>"
      puts $fout "<div id=\"$sta_corner\" class=\"collapse\">"
      puts $fout "<table border=\"1\" id=\"sta_tbl\">"
      puts $fout "<caption><h3 aligh=left>"
      puts $four "<a href=../$sta_check.grp.htm>"
      puts $fout "$STA_SUM_DIR/$sta_mode/$sta_check/$corner_name"
      puts $fout "</a></h3></caption>"
      puts $fout "<TR>"
      puts $fout "<TH><pre>$corner_name</TH>" 
 #     puts $fout "<TH align=right><pre>NVP</TH>"
      puts $fout "<TH align=right><pre>WNS</TH>"
      foreach sgroup $sGROUP_LIST {
         puts $fout "<TH><pre>$GROUP_GID($sgroup)</TH>"
      }
      puts $fout "</TR>"
      foreach egroup $GROUP_LIST {
         set cid $GROUP_GID($egroup)
         puts $fout "<TR>"
         puts $fout "<TD><pre>$cid : $egroup</TD>"
         if {[info exist GROUP_NVP(-,$egroup,$sta_corner)]} {
#            puts $fout "<TD align=right><pre>[format "%d" $GROUP_NVP(-,$egroup,$sta_corner)]</TD>"
            puts $fout "<TD align=right><pre>[format "%.2f" $GROUP_WNS(-,$egroup,$sta_corner)]</TD>"
         } else {
#            puts $fout "<TD><pre></TD>"
            puts $fout "<TD><pre></TD>"
         }
         foreach sgroup $sGROUP_LIST {
            if {$sgroup==$egroup} { 
               set fmt1 "bgcolor=#80d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            } else { 
               set fmt1 "bgcolor=#d0d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            }
            if {[info exist GROUP_WNS($sgroup,$egroup,$sta_corner)]} {
               set nvp $GROUP_NVP($sgroup,$egroup,$sta_corner) 
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
      return $GROUP_NUM
  
}

proc report_index_group {sta_mode {sta_check ""} {corner_list ""}} {
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER
  variable GROUP_LIST
  variable GROUP_GID
  variable GROUP_NVP
  variable GROUP_WNS
  variable GROUP_NUM

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return
  }
  if {$corner_list==""} { set corner_list $STA_CORNER($sta_mode,$sta_check) }

  extract_group_list -
  set GROUP_NUM [assign_group_gid]

  puts "INFO($sta_mode):"

  set fout [open "$STA_SUM_DIR/$sta_mode/$sta_check.grp.htm" w]
  puts $fout "<html>"
  puts $fout "<head>"
  puts $fout $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fout "</head>"
  puts $fout "<body>"
  puts $fout "<div id=\"$sta_check.group\" class=\"collapse\">"
  puts $fout "<table border=\"1\" id=\"sta_tbl\">"
  puts $fout "<caption><h3 align=left>"
  puts $fout "<a href=$sta_check.htm>" 
  puts $fout "$STA_SUM_DIR/$sta_mode/$sta_check"
  puts $fout "</a></h3></caption>"
  puts $fout "<TR>"
  puts $fout "<TH><pre>#$GROUP_NUM Groups</TH>" 
  puts $fout "<TH><pre>NVP</TH>" 
  puts $fout "<TH><pre>WNS</TH>" 
  foreach sta_corner $corner_list {
     set corner_name [get_corner_name $sta_corner]
     puts $fout "<TH><a href=$sta_check/$corner_name.grp.htm><pre>$sta_corner</a></TH>"
  }
  puts $fout "</TR>"

      foreach egroup $GROUP_LIST {
         set cid $GROUP_GID($egroup)
         puts $fout "<TR>"
         puts $fout "<TD><pre>$cid : $egroup</TD>"
         if {[info exist GROUP_WNS(-,$egroup,-)]} {
            puts $fout "<TD align=right><pre>[format "%d" $GROUP_NVP(-,$egroup,-)]</TD>"
            puts $fout "<TD align=right><pre>[format "%.2f" $GROUP_WNS(-,$egroup,-)]</TD>"
         } else {
            puts $fout "<TD><pre></TD>"
            puts $fout "<TD><pre></TD>"
         }
         foreach sta_corner $corner_list {
            set sgroup -
            if {$sgroup==$egroup} { 
               set fmt1 "bgcolor=#80d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            } else { 
               set fmt1 "bgcolor=#d0d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            }
            if {[info exist GROUP_WNS($sgroup,$egroup,$sta_corner)]} {
               set wns $GROUP_WNS($sgroup,$egroup,$sta_corner) 
               puts $fout "<TD $fmt1 align=right><pre>[format %6.2f $wns]</TD>"
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
  return GROUP_NUM
}

################################
}

