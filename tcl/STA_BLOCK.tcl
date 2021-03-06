#!/usr/bin/tclsh
#
## STA Block Report
##
## By Albert Li 
## 2020/08/07
## 
puts "INFO: Loading 'STA_BLOCK.tcl'..."
namespace eval LIB_STA {
variable sBLOCK_LIST 
variable eBLOCK_LIST 
variable BLOCK_LIST
variable STA_BLOCK
variable BLOCK_NVP
variable BLOCK_WNS
variable BLOCK_VIO
variable BLOCK_NUM
variable BLOCK_GID

proc reset_block_data {} {
  variable sBLOCK_LIST 
  variable eBLOCK_LIST 
  variable BLOCK_LIST
  variable BLOCK_NVP
  variable BLOCK_WNS
  variable BLOCK_NUM
  variable BLOCK_GID

  set BLOCK_NUM 0
  set BLOCK_LIST ""
  set eBLOCK_LIST ""
  set sBLOCK_LIST ""
  array unset BLOCK_NVP
  array unset BLOCK_WNS
  array unset BLOCK_GID
}

proc report_block_end {sta_group sta_check} {
  variable STA_MODE_LIST

  foreach sta_mode $STA_MODE_LIST {
     report_block_table $sta_group $sta_mode $sta_check
     report_index_block $sta_group $sta_mode $sta_check
  }
}

proc get_block_name {instpin} {
  variable STA_BLOCK
  set block "-"
  if {[info exist STA_BLOCK]} {
     foreach {key def} $STA_BLOCK {
        if {[regexp "^$def/.*" $instpin]} { set block $key }
     }
  } elseif {[file tail $instpin]!=$instpin} {
     regsub {\/.*$} $instpin "" block
  }
  return $block
}

proc assign_block_gid {{block_list ""}} {
  variable BLOCK_LIST
  variable BLOCK_GID
  variable BLOCK_NUM

  if {$block_list == ""} { set block_list $BLOCK_LIST}
  array unset BLOCK_GID
  set gid 0
  set BLOCK_GID(-) -
  foreach name $block_list {
    if {![info exist BLOCK_GID($name)]} {
       incr gid
       set BLOCK_GID($name) $gid
    }
  }
  set BLOCK_NUM $gid
  return $gid
}

proc sort_slack_by_block {corner slack sname ename {report ""} } {
  variable BLOCK_NVP
  variable BLOCK_WNS
  set sblock [get_block_name $sname]
  set eblock [get_block_name $ename]
           if [info exist BLOCK_NVP($sblock,$eblock,$corner)] {
              incr BLOCK_NVP($sblock,$eblock,$corner)
              if {$BLOCK_WNS($sblock,$eblock,$corner)>$slack} {
                 set BLOCK_WNS($sblock,$eblock,$corner) $slack
              }
           } else {
              set BLOCK_NVP($sblock,$eblock,$corner) 1
              set BLOCK_WNS($sblock,$eblock,$corner) $slack
           }
         if {$sblock != "-"} {
           if [info exist BLOCK_NVP(-,$eblock,$corner)] {
              incr BLOCK_NVP(-,$eblock,$corner)
              if {$BLOCK_WNS(-,$eblock,$corner)>$slack} {
                 set BLOCK_WNS(-,$eblock,$corner) $slack
              }
           } else {
              set BLOCK_NVP(-,$eblock,$corner) 1
              set BLOCK_WNS(-,$eblock,$corner) $slack
           }
         }
         if {$corner != "-"} {
           if [info exist BLOCK_NVP($sblock,$eblock,-)] {
              incr BLOCK_NVP($sblock,$eblock,-)
              if {$BLOCK_WNS($sblock,$eblock,-)>$slack} {
                 set BLOCK_WNS($sblock,$eblock,-) $slack
              }
           } else {
              set BLOCK_NVP($sblock,$eblock,-) 1
              set BLOCK_WNS($sblock,$eblock,-) $slack
           }
        }
        if {($sblock != "-") && ($corner != "-")} {
           if [info exist BLOCK_NVP(-,$eblock,-)] {
              incr BLOCK_NVP(-,$eblock,-)
              if {$BLOCK_WNS(-,$eblock,-)>$slack} {
                 set BLOCK_WNS(-,$eblock,-) $slack
              }
           } else {
              set BLOCK_NVP(-,$eblock,-) 1
              set BLOCK_WNS(-,$eblock,-) $slack
           }
        }
}

#
# <Title>
#    Group Violation Slack based on Clock Group
#
# <Input>
# $sta_group/$sta_mode/$sta_corner/$sta_check.vio
#
# <Output>
# BLOCK_LIST : {{$sblock,$eblock} $wns $wcorner}
# BLOCK_WNS($sblock,$eblock,$sta_corner) : $wns
#
proc report_block_table {sta_group sta_mode sta_check} {
  variable STA_CORNER
  variable VIO_FILE
  variable BLOCK_LIST
  variable BLOCK_NVP
  variable BLOCK_WNS

  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return
  }
  array unset BLOCK_NVP
  array unset BLOCK_WNS
  puts "\[$sta_mode\] INFO: Group slack files of multiple corners ..."
  foreach sta_corner $STA_CORNER($sta_mode,$sta_check) {
    if {[catch {glob $sta_group/$sta_mode/$sta_corner/$sta_check.vio} files]} continue;
    foreach fname $files {
      puts "($sta_corner)\t: $fname"
      set VIO_FILE($sta_mode,$sta_check,$sta_corner) $fname
      set sclock -
      set sinst -
      set fin [open $fname r]
      while {[gets $fin line] >= 0} {
        if {[regexp {^\#} $line]} {
           if {[regexp {^\#\s+File\s*\:\s*(\S+)} $line whole sta_rpt]} {
#              puts "INFO: File : $sta_rpt"
           }
        } elseif {[regexp {^\*(\d+)\:(\d+)\s+(\S+)\s+(\S+)} $line whole nspt line_cnt sclock sinst]} {
           puts -nonewline stderr "INFO: Path# $nspt , Line# $line_cnt\r"
        } elseif {[regexp {^\s*(\S+)\s+(\S+)\s+(\S+)} $line whole slack eclock einst]} {
           sort_slack_by_block $sta_corner $slack $sinst $einst 
           set sclock -
           set sinst  -
        }
      }
      close $fin
      output_block_table $sta_group $sta_mode $sta_check $sta_corner
    }
  }
}

proc extract_block_list {sta_corner} {
  variable BLOCK_NVP
  variable BLOCK_LIST
  variable sBLOCK_LIST
  variable eBLOCK_LIST

      set sBLOCK_LIST ""
      set eBLOCK_LIST ""
      set BLOCK_LIST ""
      foreach key [array name BLOCK_NVP] {
         foreach {sblock eblock corner} [split $key ","] {
            if {$corner==$sta_corner} {
               if {[lsearch $sBLOCK_LIST $sblock]<0} { lappend sBLOCK_LIST $sblock}
               if {[lsearch $eBLOCK_LIST $eblock]<0} { lappend eBLOCK_LIST $eblock}

               if {[lsearch $BLOCK_LIST $sblock]<0} { lappend BLOCK_LIST $sblock}
               if {[lsearch $BLOCK_LIST $eblock]<0} { lappend BLOCK_LIST $eblock}
            }
         }
      }
      set sBLOCK_LIST [lsort -unique $sBLOCK_LIST]
      set eBLOCK_LIST [lsort -unique $eBLOCK_LIST]
      set BLOCK_LIST [lsort -unique $BLOCK_LIST]
}

proc output_block_table {sta_group sta_mode sta_check sta_corner} {
  variable BLOCK_GID
  variable BLOCK_WNS
  variable BLOCK_NVP
  variable BLOCK_NUM
  variable BLOCK_LIST
  variable sBLOCK_LIST
  variable eBLOCK_LIST

      extract_block_list $sta_corner
      set BLOCK_NUM [assign_block_gid]

      set fout [open "$sta_group/$sta_mode/$sta_corner/$sta_check.blk.htm" w]
      puts $fout "<html>"
      puts $fout "<head>"
      puts $fout $::STA_HTML::TABLE_CSS(sta_tbl)
      puts $fout "</head>"
      puts $fout "<body>"
      puts $fout "<div id=sta_block class=\"collapse\">"
      puts $fout "<table border=\"1\" id=\"sta_tbl\">"
      puts $fout "<caption>"
      puts $fout "$sta_mode/$sta_corner/$sta_check"
      puts $fout "</caption>"
      puts $fout "<TR>"
      puts $fout "<TH align=left><pre>#$BLOCK_NUM Blocks</a></TH>" 
#      puts $fout "<TH align=right><pre>NVP</TH>"
      puts $fout "<TH align=right><pre>WNS</TH>"
      foreach sblock $BLOCK_LIST {
         puts $fout "<TH><pre>$BLOCK_GID($sblock)</TH>"
      }
      puts $fout "</TR>"
      foreach eblock $BLOCK_LIST {
         set gid $BLOCK_GID($eblock)
         puts $fout "<TR>"
         puts $fout "<TD><pre>$gid : $eblock</TD>"
         if {[info exist BLOCK_NVP(-,$eblock,$sta_corner)]} {
#            puts $fout "<TD align=right><pre>[format "%d" $BLOCK_NVP(-,$eblock,$sta_corner)]</TD>"
            puts $fout "<TD align=right><pre>[format "%.2f" $BLOCK_WNS(-,$eblock,$sta_corner)]</TD>"
         } else {
#            puts $fout "<TD><pre></TD>"
            puts $fout "<TD><pre></TD>"
         }
         foreach sblock $BLOCK_LIST {
            if {$sblock==$eblock} { 
               set fmt1 "bgcolor=#80d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            } else { 
               set fmt1 "bgcolor=#d0d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            }
            if {[info exist BLOCK_WNS($sblock,$eblock,$sta_corner)]} {
               set nvp $BLOCK_NVP($sblock,$eblock,$sta_corner) 
               puts $fout "<TD $fmt1><pre>[format %4d $nvp]</TD>"
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
      return $BLOCK_NUM
  
}

proc report_index_block {sta_group sta_mode sta_check {corner_list ""}} {
  variable STA_CORNER
  variable BLOCK_LIST
  variable BLOCK_GID
  variable BLOCK_NVP
  variable BLOCK_WNS
  variable BLOCK_NUM

  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return
  }
  if {$corner_list==""} { set corner_list $STA_CORNER($sta_mode,$sta_check) }

  extract_block_list -
  assign_block_gid

  puts "\[$sta_mode\] INFO: $BLOCK_NUM blocks"

  set fout [open "$sta_group/$sta_mode/$sta_check.blk.htm" w]
  puts $fout "<html>"
  puts $fout "<head>"
  puts $fout $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fout "</head>"
  puts $fout "<body>"
  puts $fout "<div id=sta_block class=\"collapse\">"
  puts $fout "<table border=\"1\" id=\"sta_tbl\">"
  puts $fout "<caption><h3 align=left>"
  puts $fout "$sta_group/$sta_mode/$sta_check"
  puts $fout "</h3></caption>"
  puts $fout "<TR>"
  puts $fout "<TH><pre>#$BLOCK_NUM Blocks</TH>" 
  puts $fout "<TH><pre>NVP</TH>" 
  puts $fout "<TH><pre>WNS</TH>" 
  foreach sta_corner $corner_list {
     puts $fout "<TH><a href=$sta_corner/$sta_check.blk.htm><pre>$sta_corner</a></TH>"
  }
  puts $fout "</TR>"


      foreach eblock $BLOCK_LIST {
         set gid $BLOCK_GID($eblock)
         puts $fout "<TR>"
         puts $fout "<TD><pre>$gid : $eblock</TD>"
         if {[info exist BLOCK_WNS(-,$eblock,-)]} {
            puts $fout "<TD align=right><pre>[format "%d" $BLOCK_NVP(-,$eblock,-)]</TD>"
            puts $fout "<TD align=right><pre>[format "%.2f" $BLOCK_WNS(-,$eblock,-)]</TD>"
         } else {
            puts $fout "<TD><pre></TD>"
            puts $fout "<TD><pre></TD>"
         }
         foreach sta_corner $corner_list {
            set sblock -
            if {$sblock==$eblock} { 
               set fmt1 "bgcolor=#80d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            } else { 
               set fmt1 "bgcolor=#d0d0d0" 
               set fmt0 "bgcolor=#c0c0c0"
            }
            if {[info exist BLOCK_WNS($sblock,$eblock,$sta_corner)]} {
               set wns $BLOCK_WNS($sblock,$eblock,$sta_corner) 
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
  return $BLOCK_NUM
}

################################
}

