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
variable BLOCK_DEF
variable BLOCK_NVP
variable BLOCK_WNS
variable BLOCK_VIO
variable BLOCK_NUM

proc report_block_end {{sta_check ""}} {
  variable STA_MODE_LIST
  variable STA_CHECK
  if {$sta_check==""} { set sta_check $STA_CHECK}

  foreach sta_mode $STA_MODE_LIST {
     report_block_table $sta_mode $sta_check
     report_index_block $sta_mode $sta_check
  }
}

proc get_block_name {instpin} {
  variable BLOCK_DEF
  set block "-"
  if {[info exist BLOCK_DEF]} {
     foreach {key def} $BLOCK_DEF {
        if {[regexp "^$def/.*" $key]} { set block $key }
     }
  } elseif {[file tail $instpin]!=$instpin} {
     regsub {\/.*$} $instpin "" block
  }
  return $block
}

proc assign_block_gid {{block_list ""}} {
  variable BLOCK_LIST
  variable BLOCK_GID

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
# $STA_SUM_DIR/$sta_mode/$sta_check/*.vio
#
# <Output>
# BLOCK_LIST : {{$sblock,$eblock} $wns $wcorner}
# BLOCK_WNS($sblock,$eblock,$sta_corner) : $wns
#
proc report_block_table {sta_mode {sta_check ""}  } {
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER
  variable VIO_FILE
  variable BLOCK_LIST
  variable BLOCK_NVP
  variable BLOCK_WNS

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return
  }
  array unset BLOCK_NVP
  array unset BLOCK_WNS
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
      output_block_table $sta_mode $sta_check $corner_name
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

proc output_block_table {sta_mode sta_check corner_name} {
  variable STA_SUM_DIR
  variable BLOCK_GID
  variable BLOCK_WNS
  variable BLOCK_NVP
  variable BLOCK_NUM
  variable BLOCK_LIST
  variable sBLOCK_LIST
  variable eBLOCK_LIST

      set sta_corner [get_corner_id $corner_name]

      extract_block_list $sta_corner
      set BLOCK_NUM [assign_block_gid]

      set fout [open "$STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.blk.htm" w]
      puts $fout "<html>"
      puts $fout "<head>"
      puts $fout $::LIB_HTML::TABLE_CSS(sta_tbl)
      puts $fout "</head>"
      puts $fout "<body>"
      puts $fout "<div id=\"$sta_corner\" class=\"collapse\">"
      puts $fout "<table border=\"1\" id=\"sta_tbl\">"
      puts $fout "<caption><h3 align=left>"
      puts $fout "<a href=../$sta_check.blk.htm>" 
      puts $fout "$STA_SUM_DIR/$sta_mode/$sta_check/$corner_name"
      puts $fout "</a></h3></caption>"
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

proc report_index_block {sta_mode {sta_check ""} {corner_list ""}} {
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER
  variable BLOCK_LIST
  variable BLOCK_GID
  variable BLOCK_NVP
  variable BLOCK_WNS
  variable BLOCK_NUM

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return
  }
  if {$corner_list==""} { set corner_list $STA_CORNER($sta_mode,$sta_check) }

  extract_block_list -
  set BLOCK_NUM [assign_block_gid]

  puts "INFO($sta_mode): $BLOCK_NUM blocks"

  set fout [open "$STA_SUM_DIR/$sta_mode/$sta_check.blk.htm" w]
  puts $fout "<html>"
  puts $fout "<head>"
  puts $fout $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fout "</head>"
  puts $fout "<body>"
  puts $fout "<div id=\"$sta_check.block\" class=\"collapse\">"
  puts $fout "<table border=\"1\" id=\"sta_tbl\">"
  puts $fout "<caption><h3 align=left>"
  puts $fout "<a href=$sta_check.htm>"
  puts $fout "$STA_SUM_DIR/$sta_mode/$sta_check"
  puts $fout "</a></h3></caption>"
  puts $fout "<TR>"
  puts $fout "<TH><pre>#$BLOCK_NUM Blocks</TH>" 
  puts $fout "<TH><pre>NVP</TH>" 
  puts $fout "<TH><pre>WNS</TH>" 
  foreach sta_corner $corner_list {
     set corner_name [get_corner_name $sta_corner]
     puts $fout "<TH><a href=$sta_check/$corner_name.blk.htm><pre>$sta_corner</a></TH>"
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

