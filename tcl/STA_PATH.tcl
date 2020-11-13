#!/usr/bin/tclsh
#
# STA Path Report
#
# By Albert Li 
# 2016/08/05
# 
namespace eval LIB_STA {
variable VIRTUAL_DELAY
variable PATH_CNT 0
variable DETAIL_PATH

proc add_virtual_delay {pname delay} {
   variable VIRTUAL_DELAY
   set VIRTUAL_DELAY($pname) $delay
}

proc read_virtual_delay fname {
   variable VIRTUAL_DELAY
   set fin [open $fname r]
      while {[gets $fin line] >= 0} {
        if {[regexp {^\s*\#} $line whole matched]} {
        } elseif {[regexp {^(\S+)\s+(\S+)} $line whole delay pname]} {
           set VIRTUAL_DELAY($pname) $delay
           puts "ADD_DELAY $delay $pname"
        } else {
        }
      }
   close $fin
}

proc read_path_report fname {
   variable VIRTUAL_DELAY
   set fin [open $fname r]
   set sname ""
   set ename ""
   set slcak -9999
   set path 0
      while {[gets $fin line] >= 0} {
        if {[regexp {Startpoint:\s+(\S+)} $line whole sname]} {
#           puts "S : $sname"
           set type ""
           set ename ""
           set LANUCH ""
           set CAPTURE ""
           set cp 0
           set add_delay 0
           incr path
           set ck_edge "s"
        } elseif {[regexp {Endpoint:\s+(\S+)} $line whole ename]} {
#           puts "E : $ename"
            set ck_edge "d"
        } elseif {[regexp {Last common pin:\s+(\S+)} $line whole cpname]} {
#           puts "P : $cpname"
        } elseif {[regexp {Path Group:\s+(\S+)} $line whole gname]} {
#           puts "G : $gname"
           set type launch
           #puts "launch"
        } elseif {[regexp {\((rising|falling)\s+(\S+)\s+(\S+)\s+clocked by\s+(\S+)\)} $line whole edge trig reg clock]} {
#           puts "$edge $trig $reg $clock"
           if {$ck_edge=="s"} {
              set sedge  $edge
              set strig  $trig
              set sreg   $reg
              set sclock $clock
           } else {
              set dedge  $edge
              set dtrig  $trig
              set dreg   $reg
              set dclock $clock
           }
        } elseif {[regexp {(\S+)\s+\(net\)} $line whole netname]} {
#           puts "N : $netname"
           if {$cp==1} {
           if {$type=="launch"} {
              lappend LAUNCH $netname
           } elseif {$type =="capture"} {
              lappend CAPTURE $netname
           } else {
           }
           }
        } elseif {[regexp {data arrival time} $line whole]} {
           set type capture
           set cp 0
           #puts "capture"
        } elseif {[regexp {data required time} $line whole]} {
           set type ""
        } elseif {[regexp {slack \(VIOLATED\)\s+(\S+)} $line whole slack] ||[regexp {slack \(MET\)\s+(\S+)} $line whole slack] } {
            set new_slack [format "%.3f" [expr $slack + $add_delay]]
            if {$new_slack<0} {
               puts [format "Slack : %.3f ( %.3f )" $new_slack $slack]
               puts [format "  Startpoint: %s" $sname]
               puts [format "  (%s %s %s clocked by %s)" $sedge $strig $sreg $sclock]
               puts [format "  Endpoint: %s" $ename]
               puts [format "  (%s %s %s clocked by %s)" $dedge $dtrig $dreg $dclock]
               puts [format "  Last common pin: %s" $cpname]
               puts [format "  Path Group: %s" $gname]
            }
            if {$slack<10} {
            if {![info exist CP($cpname)]} {
               set CP($cpname) $slack
               set CP_PAIR($cpname) ""
               puts "($path) $cpname $slack"
            }
            }
            lappend CP_PAIR($cpname) "$sname $ename $slack"
            foreach net $CAPTURE {
               set C($net,$sname) $slack
            }
            foreach net $LAUNCH {
               set L($net,$ename) $slack
            }
            set F($sname,$ename) $slack
        } elseif {[regexp {slack \(MET\)\s+(\S+)} $line whole slack]} {
#            puts "T : $slack (MET)"
        } elseif {[regexp {^\s+(\S+)\s+\((\S+)\)} $line whole pname cname]} {
           if {[info exist VIRTUAL_DELAY($pname)]} {
              if {$type=="launch"} {
                 set add_delay [expr $add_delay + $VIRTUAL_DELAY($pname)]
                 #puts " Add delay $add_delay"
              } elseif {$type=="capture"} {
                 #puts " Sub delay $VIRTUAL_DELAY($pname) $pname"
                 set add_delay [expr $add_delay - $VIRTUAL_DELAY($pname)]
                 #puts " Offset $add_delay"
              }
           }
           if {$pname==$cpname} {
              set cp 1
#              puts "CP: $pname"
           }
           if {$cp==1} {
           set iname [file dirname $pname]
           set xname [file tail $pname]
           if {$iname==$sname} {
#             puts "S : $pname $cname"
           } elseif {$iname==$ename} {
#             puts "E : $pname $cname"
           }
           }
        }
      }
   close $fin
}
}
